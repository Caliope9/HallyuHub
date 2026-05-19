const DEFAULT_ARTISTS = ["BTS", "BLACKPINK", "Stray Kids", "NewJeans", "TWICE", "SEVENTEEN", "ATEEZ", "IVE", "TXT"];

module.exports = async function handler(request, response) {
  const url = new URL(request.url, `https://${request.headers.host || "localhost"}`);
  const artists = (url.searchParams.get("artists") || DEFAULT_ARTISTS.join(","))
    .split(",")
    .map((artist) => artist.trim())
    .filter(Boolean)
    .slice(0, 12);
  const lang = url.searchParams.get("lang") || "es";
  const country = url.searchParams.get("country") || "AR";

  try {
    const results = await Promise.allSettled(artists.map((artist) => fetchArtistNews(artist, lang, country)));
    const items = dedupeNews(results.flatMap((result) => (result.status === "fulfilled" ? result.value : []))).slice(0, 60);
    response.setHeader("Cache-Control", "s-maxage=3600, stale-while-revalidate=7200");
    response.status(200).json({ updatedAt: new Date().toISOString(), items });
  } catch (error) {
    response.status(500).json({ error: "No se pudieron actualizar las noticias.", detail: error.message });
  }
};

async function fetchArtistNews(artist, lang, country) {
  const query = `${artist} K-pop when:7d`;
  const rssUrl = `https://news.google.com/rss/search?q=${encodeURIComponent(query)}&hl=${lang}-419&gl=${country}&ceid=${country}:${lang}-419`;
  const result = await fetch(rssUrl, {
    headers: {
      "User-Agent": "HallyuHubNewsBot/1.0",
      Accept: "application/rss+xml,text/xml",
    },
  });
  if (!result.ok) throw new Error(`Google News RSS ${result.status}`);
  const xml = await result.text();
  return extractItems(xml, artist, lang, country);
}

function extractItems(xml, artist, lang, country) {
  return Array.from(xml.matchAll(/<item>([\s\S]*?)<\/item>/g)).map((match, index) => {
    const itemXml = match[1];
    const title = cleanText(readTag(itemXml, "title"));
    const link = cleanText(readTag(itemXml, "link"));
    const pubDate = readTag(itemXml, "pubDate");
    const description = cleanSummary(readTag(itemXml, "description"));
    const source = cleanText(readSource(itemXml)) || "Google News";
    const image = readImage(itemXml);
    return {
      id: stableId(`${artist}-${link || title}-${index}`),
      artist,
      title,
      link,
      source,
      date: pubDate ? new Date(pubDate).toISOString() : new Date().toISOString(),
      summary: description,
      image,
      language: lang,
      country,
      status: "pending",
      trending: /trend|viral|chart|tour|comeback|challenge|billboard|record/i.test(`${title} ${description}`),
    };
  });
}

function readTag(xml, tag) {
  return (xml.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, "i")) || [])[1] || "";
}

function readSource(xml) {
  return (xml.match(/<source[^>]*>([\s\S]*?)<\/source>/i) || [])[1] || "";
}

function readImage(xml) {
  const media = xml.match(/<media:content[^>]+url="([^"]+)"/i) || xml.match(/<media:thumbnail[^>]+url="([^"]+)"/i);
  if (media?.[1]) return decodeEntities(media[1]);
  const description = readTag(xml, "description");
  return (description.match(/<img[^>]+src="([^"]+)"/i) || [])[1] || "";
}

function cleanSummary(value) {
  return cleanText(value)
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 220);
}

function cleanText(value) {
  return decodeEntities(String(value || "").replace(/<!\[CDATA\[|\]\]>/g, "").replace(/<[^>]+>/g, " ").trim());
}

function decodeEntities(value) {
  return String(value || "")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">");
}

function dedupeNews(items) {
  const seen = new Set();
  return items.filter((item) => {
    const key = `${item.link || item.title}`.toLowerCase().replace(/\s+/g, " ").trim();
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function stableId(value) {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash << 5) - hash + value.charCodeAt(index);
    hash |= 0;
  }
  return `news-${Math.abs(hash)}`;
}
