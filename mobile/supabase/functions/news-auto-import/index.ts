import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.49.8";
import { XMLParser } from "npm:fast-xml-parser@4.5.3";
import {
  type DetectedLanguage,
  detectOriginalLanguage,
} from "./language_detector.ts";
import { cleanSummary, cleanText, cleanTitle } from "./text_cleanup.ts";
import { evaluateKpopTopic, type KpopEntity } from "./topic_filter.ts";

const NEWS_AUTO_REFRESH_MINUTES = 60;
const MAX_ITEMS_PER_SOURCE = 30;
const MAX_NEWS_AGE_DAYS = 14;

type EditorialStatus =
  | "official"
  | "confirmed"
  | "developing"
  | "rumor"
  | "trending";

type TrustedSource = {
  name: string;
  domain: string;
  feedUrl: string;
  language: string;
  kind: "editorial" | "official";
};

type FeedItem = {
  title?: unknown;
  link?: unknown;
  description?: unknown;
  pubDate?: unknown;
  category?: unknown;
  "dc:date"?: unknown;
};

type ImportCounters = {
  imported: number;
  published: number;
  rumor: number;
  skipped: number;
};

type TopicRejection = {
  source: string;
  title: string;
  rejection_reason: "non_kpop";
  matched_entities: string[];
  matched_keywords: string[];
};

type LanguageRejection = {
  source: string;
  title: string;
  rejection_reason: "language_not_supported";
  detected_language: DetectedLanguage;
};

type ImportResult = ImportCounters & {
  topicRejection?: TopicRejection;
  languageRejection?: LanguageRejection;
};

// The Edge Function uses tables added by SQL migrations without generated types.
// deno-lint-ignore no-explicit-any
type BackendClient = SupabaseClient<any, "public", any>;

const TRUSTED_SOURCES: TrustedSource[] = [
  {
    name: "KBS World Español - Espectáculo",
    domain: "world.kbs.co.kr",
    feedUrl: "https://world.kbs.co.kr/rss/rss_enternews.htm?lang=s",
    language: "es",
    kind: "official",
  },
  {
    name: "KBS World Español - Cultura",
    domain: "world.kbs.co.kr",
    feedUrl: "https://world.kbs.co.kr/rss/rss_news.htm?lang=s&id=Cu",
    language: "es",
    kind: "official",
  },
  {
    name: "Unnie Pop",
    domain: "unniepop.cl",
    feedUrl: "https://unniepop.cl/category/k-pop/feed/",
    language: "es",
    kind: "editorial",
  },
];

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  processEntities: true,
  trimValues: true,
});

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Backend configuration is incomplete" }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const providedSecret = request.headers.get("x-cron-secret") ?? "";
  const { data: secretIsValid, error: secretError } = await supabase.rpc(
    "verify_news_cron_secret",
    { provided_secret: providedSecret },
  );

  if (secretError || secretIsValid !== true) {
    console.warn(
      "NEWS_IMPORT_UNAUTHORIZED",
      secretError?.message ?? "invalid secret",
    );
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  const { data: activeRun } = await supabase
    .from("news_import_runs")
    .select("id")
    .eq("status", "running")
    .gte("started_at", fifteenMinutesAgo)
    .limit(1)
    .maybeSingle();

  if (activeRun) {
    console.info("NEWS_IMPORT_SKIPPED active_run=true");
    return jsonResponse({ status: "skipped", reason: "already_running" }, 202);
  }

  const { data: run, error: runError } = await supabase
    .from("news_import_runs")
    .insert({
      status: "running",
      details: {
        content_policy: "kpop_spanish_only",
        refresh_minutes: NEWS_AUTO_REFRESH_MINUTES,
        sources: TRUSTED_SOURCES.map((source) => source.name),
      },
    })
    .select("id")
    .single();

  if (runError || !run?.id) {
    console.error(
      "NEWS_IMPORT_RUN_CREATE_ERROR",
      runError?.message ?? "missing run id",
    );
    return jsonResponse({ error: "Could not create import run" }, 500);
  }

  const counters: ImportCounters = {
    imported: 0,
    published: 0,
    rumor: 0,
    skipped: 0,
  };
  const sourceErrors: Record<string, string> = {};
  const topicRejections: TopicRejection[] = [];
  const languageRejections: LanguageRejection[] = [];

  try {
    const entities = await loadKpopEntities(supabase);

    for (const source of TRUSTED_SOURCES) {
      try {
        const items = await fetchFeed(source);
        for (const item of items.slice(0, MAX_ITEMS_PER_SOURCE)) {
          const result = await importItem({
            supabase,
            runId: run.id,
            source,
            item,
            entities,
          });
          counters.imported += result.imported;
          counters.published += result.published;
          counters.rumor += result.rumor;
          counters.skipped += result.skipped;
          if (result.topicRejection) {
            topicRejections.push(result.topicRejection);
          }
          if (result.languageRejection) {
            languageRejections.push(result.languageRejection);
          }
        }
      } catch (error) {
        sourceErrors[source.name] = safeError(error);
        console.error(`NEWS_IMPORT_SOURCE_ERROR source=${source.name}`, error);
      }
    }

    const status = Object.keys(sourceErrors).length === 0
      ? "success"
      : "partial";
    const { error: finishError } = await supabase
      .from("news_import_runs")
      .update({
        finished_at: new Date().toISOString(),
        status,
        imported_count: counters.imported,
        published_count: counters.published,
        rumor_count: counters.rumor,
        skipped_count: counters.skipped,
        error_message: Object.entries(sourceErrors)
          .map(([source, message]) => `${source}: ${message}`)
          .join(" | ") || null,
        details: {
          content_policy: "kpop_spanish_only",
          refresh_minutes: NEWS_AUTO_REFRESH_MINUTES,
          sources: TRUSTED_SOURCES.map((source) => source.name),
          source_errors: sourceErrors,
          language_rejections: languageRejections,
          topic_rejections: topicRejections,
        },
      })
      .eq("id", run.id);

    if (finishError) {
      console.error("NEWS_IMPORT_RUN_FINISH_ERROR", finishError.message);
    }

    console.info("NEWS_IMPORT_OK", { status, ...counters });
    return jsonResponse({ status, ...counters, sourceErrors });
  } catch (error) {
    const message = safeError(error);
    console.error("NEWS_IMPORT_FATAL_ERROR", error);
    await supabase
      .from("news_import_runs")
      .update({
        finished_at: new Date().toISOString(),
        status: "failed",
        imported_count: counters.imported,
        published_count: counters.published,
        rumor_count: counters.rumor,
        skipped_count: counters.skipped,
        error_message: message,
      })
      .eq("id", run.id);
    return jsonResponse({ error: "News import failed" }, 500);
  }
});

async function loadKpopEntities(supabase: BackendClient) {
  const { data, error } = await supabase
    .from("kpop_entities")
    .select("id,name,aliases")
    .limit(1000);
  if (error) throw new Error(`kpop_entities: ${error.message}`);

  return (data ?? [])
    .map((row) => ({
      id: String(row.id ?? ""),
      name: cleanText(row.name),
      aliases: toStringArray(row.aliases),
    }))
    .filter((entity) => entity.id && entity.name) as KpopEntity[];
}

async function fetchFeed(source: TrustedSource): Promise<FeedItem[]> {
  const response = await fetch(source.feedUrl, {
    headers: {
      Accept: "application/rss+xml, application/xml, text/xml",
      "User-Agent": "HallyuHubNewsBot/2.0 (+https://www.hallyuhub.net)",
    },
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`RSS ${response.status}`);

  const parsed = xmlParser.parse(await response.text());
  const items = parsed?.rss?.channel?.item ?? parsed?.feed?.entry ?? [];
  return asArray(items).filter((item): item is FeedItem => item != null);
}

async function importItem({
  supabase,
  runId,
  source,
  item,
  entities,
}: {
  supabase: BackendClient;
  runId: string;
  source: TrustedSource;
  item: FeedItem;
  entities: KpopEntity[];
}): Promise<ImportResult> {
  const title = cleanTitle(item.title);
  const summary = cleanSummary(item.description);
  const rawArticleUrl = canonicalizeUrl(readLink(item.link));
  const articleUrl = urlMatchesDomain(rawArticleUrl, source.domain)
    ? rawArticleUrl
    : "";
  const publishedAt = parsePublishedAt(item.pubDate ?? item["dc:date"]);
  const categories = toStringArray(item.category);

  if (!title) {
    return { imported: 0, published: 0, rumor: 0, skipped: 1 };
  }
  const detectedLanguage = detectOriginalLanguage(`${title}. ${summary}`);
  if (source.language !== "es" || detectedLanguage !== "es") {
    const languageRejection: LanguageRejection = {
      source: source.name,
      title,
      rejection_reason: "language_not_supported",
      detected_language: detectedLanguage,
    };
    console.info("NEWS_IMPORT_LANGUAGE_REJECTED", languageRejection);
    return {
      imported: 0,
      published: 0,
      rumor: 0,
      skipped: 1,
      languageRejection,
    };
  }

  const topic = evaluateKpopTopic({
    title,
    summary,
    categories,
    sourceName: source.name,
    entities,
  });
  const matchedEntities = topic.matchedEntities;
  if (!topic.isRelevant) {
    const topicRejection: TopicRejection = {
      source: source.name,
      title,
      rejection_reason: "non_kpop",
      matched_entities: matchedEntities.map((entity) => entity.name),
      matched_keywords: topic.matchedKeywords,
    };
    console.info("NEWS_IMPORT_TOPIC_REJECTED", topicRejection);
    return {
      imported: 0,
      published: 0,
      rumor: 0,
      skipped: 1,
      topicRejection,
    };
  }
  if (!publishedAt || isOutsideImportWindow(publishedAt)) {
    return { imported: 0, published: 0, rumor: 0, skipped: 1 };
  }

  const editorialStatus = classifyEditorialStatus(title, summary, source.kind);
  const qualityScore = calculateQualityScore({
    title,
    summary,
    articleUrl,
    publishedAt,
    sourceName: source.name,
    matchedEntityCount: matchedEntities.length,
  });
  const clickbait = isExtremeClickbait(title);
  const isComplete = qualityScore >= 85 && summary.length >= 45 && !clickbait;
  const fingerprint = await sha256(
    `${source.domain}:${normalize(title)}:${publishedAt.slice(0, 10)}`,
  );
  const importKey = await sha256(articleUrl || fingerprint);
  const tags = uniqueStrings([
    ...matchedEntities.slice(0, 2).map((entity) => entity.name),
    "K-pop",
  ]).slice(0, 3);

  const existing = await findExistingNews(
    supabase,
    importKey,
    articleUrl,
    fingerprint,
  );
  if (existing?.auto_update_locked === true) {
    return { imported: 0, published: 0, rumor: 0, skipped: 1 };
  }

  const previousSummary = cleanSummary(existing?.summary);
  const payload = {
    import_key: importKey,
    content_fingerprint: fingerprint,
    original_title: title,
    original_summary: summary || null,
    original_language: detectedLanguage,
    title,
    summary: summary.length >= previousSummary.length
      ? summary
      : previousSummary,
    why_it_matters: null,
    article_url: articleUrl || null,
    canonical_url: articleUrl || null,
    google_news_url: null,
    source_name: source.name,
    source_domain: source.domain,
    ingestion_source: `rss:${source.domain}`,
    published_at: publishedAt,
    imported_at: new Date().toISOString(),
    image_url: null,
    image_source: null,
    image_license: null,
    image_attribution: null,
    editorial_status: editorialStatus,
    entity_ids: matchedEntities.map((entity) => entity.id),
    entity_names: matchedEntities.map((entity) => entity.name),
    tags,
    language: "es",
    translation_status: "not_required",
    translated_at: null,
    is_published: isComplete,
    auto_published: isComplete,
    quality_score: qualityScore,
    last_seen_at: new Date().toISOString(),
    import_run_id: runId,
    rejection_reason: isComplete
      ? null
      : incompleteReason({ articleUrl, summary, qualityScore, clickbait }),
  };

  const query = existing?.id
    ? supabase.from("news_items").update(payload).eq("id", existing.id)
    : supabase.from("news_items").upsert(payload, { onConflict: "import_key" });
  const { error: upsertError } = await query;
  if (upsertError) throw new Error(`news upsert: ${upsertError.message}`);

  return {
    imported: 1,
    published: isComplete ? 1 : 0,
    rumor: isComplete && editorialStatus === "rumor" ? 1 : 0,
    skipped: isComplete ? 0 : 1,
  };
}

async function findExistingNews(
  supabase: BackendClient,
  importKey: string,
  articleUrl: string,
  fingerprint: string,
) {
  const columns = "id,summary,auto_update_locked";
  const byKey = await supabase
    .from("news_items")
    .select(columns)
    .eq("import_key", importKey)
    .maybeSingle();
  if (byKey.error) throw new Error(`news lookup: ${byKey.error.message}`);
  if (byKey.data) return byKey.data;

  const byFingerprint = await supabase
    .from("news_items")
    .select(columns)
    .eq("content_fingerprint", fingerprint)
    .limit(1)
    .maybeSingle();
  if (byFingerprint.error) {
    throw new Error(`news fingerprint lookup: ${byFingerprint.error.message}`);
  }
  if (byFingerprint.data) return byFingerprint.data;

  if (!articleUrl) return null;

  const byCanonical = await supabase
    .from("news_items")
    .select(columns)
    .eq("canonical_url", articleUrl)
    .limit(1)
    .maybeSingle();
  if (byCanonical.error) {
    throw new Error(`news canonical lookup: ${byCanonical.error.message}`);
  }
  if (byCanonical.data) return byCanonical.data;

  const byArticle = await supabase
    .from("news_items")
    .select(columns)
    .eq("article_url", articleUrl)
    .limit(1)
    .maybeSingle();
  if (byArticle.error) {
    throw new Error(`news article lookup: ${byArticle.error.message}`);
  }
  return byArticle.data;
}

function incompleteReason({
  articleUrl,
  summary,
  qualityScore,
  clickbait,
}: {
  articleUrl: string;
  summary: string;
  qualityScore: number;
  clickbait: boolean;
}) {
  if (!articleUrl) return "No se encontró un enlace directo al medio original";
  if (clickbait) return "Título bloqueado por señales de clickbait extremo";
  if (summary.length < 45) return "El feed no entregó un resumen suficiente";
  return `Calidad insuficiente para publicación automática (${qualityScore}/100)`;
}

function isExtremeClickbait(title: string) {
  const letters = title.replace(/[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]/g, "");
  const uppercase = letters.replace(/[^A-ZÁÉÍÓÚÜÑ]/g, "").length;
  const uppercaseRatio = letters.length === 0 ? 0 : uppercase / letters.length;
  const punctuationBursts = (title.match(/[!?]{2,}/g) ?? []).length;
  return uppercaseRatio > 0.72 ||
    punctuationBursts > 0 ||
    /you won'?t believe|shocking truth|breaks the internet|must see/i.test(
      title,
    );
}

function classifyEditorialStatus(
  title: string,
  summary: string,
  sourceKind: TrustedSource["kind"],
): EditorialStatus {
  const text = `${title} ${summary}`;
  if (
    /rumou?rs?|alleged|speculation|unconfirmed|rumores?|sin confirmar|no confirmado|supuest[oa]s?/i
      .test(text)
  ) {
    return "rumor";
  }
  if (
    /reportedly|in talks|considering|may |might |could |expected to|según reportes|en conversaciones|podría|tendría|estaría|se espera que/i
      .test(text)
  ) {
    return "developing";
  }
  return sourceKind === "official" ? "official" : "confirmed";
}

function calculateQualityScore({
  title,
  summary,
  articleUrl,
  publishedAt,
  sourceName,
  matchedEntityCount,
}: {
  title: string;
  summary: string;
  articleUrl: string;
  publishedAt: string;
  sourceName: string;
  matchedEntityCount: number;
}) {
  let score = 0;
  if (articleUrl) score += 30;
  if (sourceName) score += 20;
  if (publishedAt) score += 15;
  if (title.length >= 20 && title.length <= 240) score += 15;
  if (summary.length >= 45) score += 10;
  if (matchedEntityCount > 0 || /k[ -]?pop/i.test(`${title} ${summary}`)) {
    score += 10;
  }
  return score;
}

function readLink(value: unknown): string {
  if (Array.isArray(value)) return readLink(value[0]);
  if (value && typeof value === "object") {
    const row = value as Record<string, unknown>;
    return cleanText(row.href ?? row["@_href"] ?? row["#text"]);
  }
  return cleanText(value);
}

function canonicalizeUrl(value: string) {
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" && url.protocol !== "http:") return "";
    for (const key of [...url.searchParams.keys()]) {
      if (/^(utm_|fbclid|gclid|ref$|source$)/i.test(key)) {
        url.searchParams.delete(key);
      }
    }
    url.hash = "";
    return url.toString();
  } catch (_) {
    return "";
  }
}

function urlMatchesDomain(value: string, expectedDomain: string) {
  try {
    const host = new URL(value).hostname.toLowerCase().replace(/^www\./, "");
    const expected = expectedDomain.toLowerCase().replace(/^www\./, "");
    return host === expected || host.endsWith(`.${expected}`);
  } catch (_) {
    return false;
  }
}

function parsePublishedAt(value: unknown) {
  const date = new Date(cleanText(value));
  return Number.isNaN(date.getTime()) ? "" : date.toISOString();
}

function isOutsideImportWindow(publishedAt: string) {
  const published = new Date(publishedAt).getTime();
  const age = Date.now() - published;
  return age < -2 * 60 * 60 * 1000 ||
    age > MAX_NEWS_AGE_DAYS * 24 * 60 * 60 * 1000;
}

function normalize(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function toStringArray(value: unknown): string[] {
  return asArray(value).map(cleanText).filter(Boolean);
}

function asArray<T>(value: T | T[] | null | undefined): T[] {
  if (value == null) return [];
  return Array.isArray(value) ? value : [value];
}

function uniqueStrings(values: string[]) {
  const seen = new Set<string>();
  return values.filter((value) => {
    const key = normalize(value);
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function safeError(error: unknown) {
  return (error instanceof Error ? error.message : String(error)).slice(
    0,
    1000,
  );
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}
