export type DetectedLanguage =
  | "es"
  | "en"
  | "pt"
  | "ko"
  | "ja"
  | "zh"
  | "unknown";

const SPANISH_WORDS = new Set([
  "al",
  "anuncia",
  "con",
  "confirma",
  "de",
  "del",
  "el",
  "en",
  "estrena",
  "la",
  "las",
  "los",
  "nuevo",
  "nueva",
  "para",
  "por",
  "presenta",
  "que",
  "regresa",
  "se",
  "será",
  "su",
  "sus",
  "tras",
  "una",
  "y",
]);

const ENGLISH_WORDS = new Set([
  "a",
  "after",
  "and",
  "announces",
  "as",
  "at",
  "for",
  "from",
  "in",
  "is",
  "new",
  "of",
  "on",
  "releases",
  "returns",
  "the",
  "their",
  "to",
  "with",
]);

const PORTUGUESE_WORDS = new Set([
  "a",
  "ao",
  "com",
  "da",
  "das",
  "de",
  "do",
  "dos",
  "e",
  "em",
  "lança",
  "na",
  "no",
  "novo",
  "nova",
  "o",
  "os",
  "para",
  "por",
  "que",
  "seu",
  "sua",
]);

export function detectOriginalLanguage(value: string): DetectedLanguage {
  const text = String(value ?? "").trim();
  if (!text) return "unknown";

  if (/\p{Script=Hangul}/u.test(text)) return "ko";
  if (/\p{Script=Hiragana}|\p{Script=Katakana}/u.test(text)) return "ja";
  if (/\p{Script=Han}/u.test(text)) return "zh";

  const tokens = text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .match(/[a-zñ]+/g) ?? [];
  if (tokens.length < 6) return "unknown";

  const count = (words: Set<string>) =>
    tokens.reduce((score, token) => score + (words.has(token) ? 1 : 0), 0);
  const accentBonus = (text.match(/[áéíóúüñ¿¡]/gi) ?? []).length > 0 ? 2 : 0;
  const portugueseBonus = (text.match(/[ãõç]/gi) ?? []).length > 0 ? 2 : 0;
  const scores = {
    es: count(SPANISH_WORDS) + accentBonus,
    en: count(ENGLISH_WORDS),
    pt: count(PORTUGUESE_WORDS) + portugueseBonus,
  };

  if (
    scores.es >= 5 && scores.es >= scores.en + 2 && scores.es >= scores.pt + 2
  ) {
    return "es";
  }
  if (
    scores.en >= 5 && scores.en >= scores.es + 2 && scores.en >= scores.pt + 2
  ) {
    return "en";
  }
  if (
    scores.pt >= 5 && scores.pt >= scores.es + 2 && scores.pt >= scores.en + 2
  ) {
    return "pt";
  }
  return "unknown";
}
