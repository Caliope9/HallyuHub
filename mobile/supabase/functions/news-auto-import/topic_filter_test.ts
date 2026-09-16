import { assertEquals } from "jsr:@std/assert@1";
import {
  evaluateKpopTopic,
  type KpopEntity,
  matchKpopEntities,
} from "./topic_filter.ts";

const entityNames = [
  "BTS",
  "BLACKPINK",
  "Stray Kids",
  "aespa",
  "IVE",
  "NewJeans",
  "TWICE",
  "EXO",
  "SEVENTEEN",
  "Jungkook",
];

const entities: KpopEntity[] = entityNames.map((name, index) => ({
  id: `entity-${index}`,
  name,
  aliases: name === "BTS"
    ? ["ARMY", "Bangtan"]
    : name === "Stray Kids"
    ? ["STAY", "SKZ"]
    : name === "IVE"
    ? ["DIVE"]
    : [],
}));

Deno.test("accepts required K-pop groups and soloists by catalog entity", () => {
  for (const name of entityNames) {
    const result = evaluateKpopTopic({
      title: `${name} announces a new release`,
      summary: "The artist shared official details about the upcoming project.",
      categories: ["Music"],
      sourceName: "Billboard",
      entities,
    });
    assertEquals(result.isRelevant, true, name);
    assertEquals(
      result.matchedEntities.some((entity) => entity.name === name),
      true,
    );
  }
});

Deno.test("accepts explicit K-pop categories and specialist signals", () => {
  const categoryMatch = evaluateKpopTopic({
    title: "A new group prepares its first mini album",
    summary: "The members shared details ahead of release.",
    categories: ["Music", "kpop"],
    sourceName: "Soompi",
    entities: [],
  });
  const awardMatch = evaluateKpopTopic({
    title: "The Fact Music Awards announces first lineup",
    summary: "The ceremony shared its first performers.",
    categories: ["Music"],
    sourceName: "Soompi",
    entities: [],
  });

  assertEquals(categoryMatch.isRelevant, true);
  assertEquals(categoryMatch.matchedKeywords.includes("k-pop"), true);
  assertEquals(awardMatch.isRelevant, true);
  assertEquals(awardMatch.matchedKeywords.includes("kpop-awards"), true);
});

Deno.test("accepts Spanish K-pop copy with exact catalog entities", () => {
  const result = evaluateKpopTopic({
    title: "Stray Kids anuncia nuevas fechas para su gira mundial",
    summary:
      "El grupo surcoreano confirmó los conciertos y compartió los detalles oficiales para sus fans.",
    categories: ["K-Pop"],
    sourceName: "Unnie Pop",
    entities,
  });

  assertEquals(result.isRelevant, true);
  assertEquals(
    result.matchedEntities.some((entity) => entity.name === "Stray Kids"),
    true,
  );
});

Deno.test("rejects general western music and festival coverage", () => {
  const rejectedTitles = [
    "Iron Maiden members sell half of their catalog",
    "Nickelback announce new album Everything Under The Sun",
    "Jay-Z returns to Yankee Stadium with special guests",
    "Reading and Leeds announces its biggest staging overhaul",
    "A western pop star reveals a new world tour",
  ];

  for (const title of rejectedTitles) {
    const result = evaluateKpopTopic({
      title,
      summary: "General international music coverage without a Korean artist.",
      categories: ["Music"],
      sourceName: "NME",
      entities,
    });
    assertEquals(result.isRelevant, false, title);
    assertEquals(result.rejectionReason, "non_kpop");
  }
});

Deno.test("rejects film or variety coverage without a K-pop entity", () => {
  const result = evaluateKpopTopic({
    title: "Award-winning actress is in talks for a new film",
    summary: "The production is currently reviewing its cast.",
    categories: ["Film", "TV/Film", "Drama"],
    sourceName: "Soompi",
    entities,
  });

  assertEquals(result.isRelevant, false);
  assertEquals(result.rejectionReason, "non_kpop");
});

Deno.test("matches complete tokens, not substrings such as IVE inside live", () => {
  const matches = matchKpopEntities(
    "Live festival coverage and five new stages",
    entities.filter((entity) => entity.name === "IVE"),
  );
  assertEquals(matches, []);
});

Deno.test("does not accept ambiguous fandom aliases as entity evidence", () => {
  const result = evaluateKpopTopic({
    title: "An army of fans stay late once the festival ends",
    summary: "Festival visitors dive into a broad selection of rock acts.",
    categories: ["Music"],
    sourceName: "NME",
    entities,
  });

  assertEquals(result.isRelevant, false);
  assertEquals(result.matchedEntities, []);
});
