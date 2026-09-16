const NAMED_ENTITIES: Record<string, string> = {
  aacute: "á",
  Aacute: "Á",
  amp: "&",
  apos: "'",
  eacute: "é",
  Eacute: "É",
  gt: ">",
  hellip: "…",
  iacute: "í",
  Iacute: "Í",
  iexcl: "¡",
  iquest: "¿",
  ldquo: "“",
  laquo: "«",
  lsquo: "‘",
  lt: "<",
  mdash: "—",
  nbsp: " ",
  ndash: "–",
  ntilde: "ñ",
  Ntilde: "Ñ",
  oacute: "ó",
  Oacute: "Ó",
  quot: '"',
  raquo: "»",
  rdquo: "”",
  rsquo: "’",
  uacute: "ú",
  Uacute: "Ú",
  uuml: "ü",
  Uuml: "Ü",
};

export function decodeHtmlEntities(value: string) {
  let decoded = value;
  for (let pass = 0; pass < 2; pass += 1) {
    decoded = decoded.replace(
      /&(#x[0-9a-f]+|#\d+|[a-z]+);/gi,
      (entity, code: string) => {
        const normalized = code.toLowerCase();
        if (normalized.startsWith("#x")) {
          return safeCodePoint(
            Number.parseInt(normalized.slice(2), 16),
            entity,
          );
        }
        if (normalized.startsWith("#")) {
          return safeCodePoint(
            Number.parseInt(normalized.slice(1), 10),
            entity,
          );
        }
        return NAMED_ENTITIES[code] ?? NAMED_ENTITIES[normalized] ?? entity;
      },
    );
  }
  return decoded;
}

export function cleanText(value: unknown): string {
  if (value && typeof value === "object" && "#text" in value) {
    return cleanText((value as Record<string, unknown>)["#text"]);
  }
  return decodeHtmlEntities(String(value ?? ""))
    .replace(/<!\[CDATA\[|\]\]>/g, "")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function cleanTitle(value: unknown) {
  return cleanText(value).slice(0, 240);
}

export function cleanSummary(value: unknown) {
  const text = cleanText(value)
    .replace(/^\[\]\s*:\s*/i, "")
    .replace(/\s*\[(?:more|m[aá]s)\.{3}\]\s*$/i, "")
    .replace(/The post .*? appeared first on .*?\.?$/i, "")
    .replace(/Esta entrada .*? se publicó primero en .*?\.?$/i, "")
    .replace(/(?:Continue reading|Seguir leyendo).*$/i, "")
    .trim();
  if (text.length <= 280) return text;
  const shortened = text.slice(0, 277);
  const lastSpace = shortened.lastIndexOf(" ");
  return `${shortened.slice(0, Math.max(lastSpace, 180)).trim()}...`;
}

function safeCodePoint(codePoint: number, fallback: string) {
  if (!Number.isFinite(codePoint) || codePoint < 0 || codePoint > 0x10ffff) {
    return fallback;
  }
  try {
    return String.fromCodePoint(codePoint);
  } catch (_) {
    return fallback;
  }
}
