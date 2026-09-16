export type KpopEntity = {
  id: string;
  name: string;
  aliases: string[];
};

export type TopicDecision = {
  isRelevant: boolean;
  matchedEntities: KpopEntity[];
  matchedKeywords: string[];
  rejectionReason: "non_kpop" | null;
};

type KeywordRule = {
  label: string;
  pattern: RegExp;
};

// Fandom names such as "ARMY" and "STAY" are ordinary English words too.
// They must never be sufficient on their own to classify an article as K-pop.
const AMBIGUOUS_ENTITY_ALIASES = new Set([
  "army",
  "atiny",
  "blink",
  "bunnies",
  "carat",
  "dive",
  "engene",
  "exo l",
  "fearnot",
  "moa",
  "my",
  "nctzen",
  "once",
  "stay",
]);

const STRONG_KPOP_KEYWORDS: KeywordRule[] = [
  { label: "k-pop", pattern: /\bk[\s-]?pop\b/i },
  {
    label: "korean-idol",
    pattern:
      /(?:\bkorean\s+(?:idol|boy\s+group|girl\s+group|singer|music\s+act)\b|\b(?:idol|grupo|cantante|solista|artista)s?\s+(?:corean[oa]s?|surcorean[oa]s?)\b)/i,
  },
  {
    label: "kpop-program",
    pattern:
      /\b(?:music\s+bank|inkigayo|m\s+countdown|show\s+champion|the\s+show|music\s+core)\b/i,
  },
  {
    label: "kpop-awards",
    pattern:
      /\b(?:mama\s+awards?|melon\s+music\s+awards?|golden\s+disc\s+awards?|circle\s+chart\s+music\s+awards?|the\s+fact\s+music\s+awards?|seoul\s+music\s+awards?)\b/i,
  },
  {
    label: "korean-agency",
    pattern:
      /\b(?:hybe|bighit|sm\s+entertainment|jyp\s+entertainment|yg\s+entertainment|starship\s+entertainment|cube\s+entertainment|pledis\s+entertainment|ador|source\s+music|wakeone|kq\s+entertainment|rbw|fnc\s+entertainment|p\s+nation|koz\s+entertainment|pocketdol\s+studio)\b/i,
  },
];

export function evaluateKpopTopic({
  title,
  summary,
  categories,
  entities,
}: {
  title: string;
  summary: string;
  categories: string[];
  sourceName: string;
  entities: KpopEntity[];
}): TopicDecision {
  const text = `${title} ${summary} ${categories.join(" ")}`;
  const matchedEntities = matchKpopEntities(text, entities);
  const matchedKeywords = STRONG_KPOP_KEYWORDS
    .filter((rule) => rule.pattern.test(text))
    .map((rule) => rule.label);

  const isRelevant = matchedEntities.length > 0 || matchedKeywords.length > 0;
  return {
    isRelevant,
    matchedEntities,
    matchedKeywords,
    rejectionReason: isRelevant ? null : "non_kpop",
  };
}

export function matchKpopEntities(text: string, entities: KpopEntity[]) {
  const haystack = ` ${normalizeTopicText(text)} `;
  return entities.filter((entity) => {
    const candidates = [entity.name, ...entity.aliases]
      .map((candidate, index) => ({
        normalized: normalizeTopicText(candidate),
        isCanonicalName: index === 0,
      }))
      .filter(({ normalized, isCanonicalName }) =>
        normalized.length >= 3 &&
        (isCanonicalName || !AMBIGUOUS_ENTITY_ALIASES.has(normalized))
      );

    return candidates.some(({ normalized }) =>
      haystack.includes(` ${normalized} `)
    );
  });
}

export function normalizeTopicText(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}
