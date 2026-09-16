import { assertEquals } from "jsr:@std/assert@1";
import { cleanSummary, cleanText, decodeHtmlEntities } from "./text_cleanup.ts";

Deno.test("decodes named, decimal and hexadecimal HTML entities", () => {
  assertEquals(
    decodeHtmlEntities(
      "BTS &#8217;ARIRANG&#8217; &amp; TWICE &#x2014; volvi&oacute; a Espa&ntilde;a",
    ),
    "BTS ’ARIRANG’ & TWICE — volvió a España",
  );
});

Deno.test("removes markup and normalizes whitespace", () => {
  assertEquals(
    cleanText("<p>BLACKPINK&nbsp; confirma <strong>su regreso</strong></p>"),
    "BLACKPINK confirma su regreso",
  );
});

Deno.test("keeps summaries brief without copying complete articles", () => {
  const summary = cleanSummary(`<p>${"noticia en español ".repeat(30)}</p>`);
  assertEquals(summary.length <= 280, true);
  assertEquals(summary.endsWith("..."), true);
});

Deno.test("removes RSS decoration without changing the Spanish summary", () => {
  assertEquals(
    cleanSummary("[] : Jennie volvi&oacute; a Espa&ntilde;a. [more...]"),
    "Jennie volvió a España.",
  );
});
