import { assertEquals } from "jsr:@std/assert@1";
import { detectOriginalLanguage } from "./language_detector.ts";

Deno.test("detects Spanish K-pop copy", () => {
  assertEquals(
    detectOriginalLanguage(
      "TWICE, Stray Kids y J.Y. Park son invitados a unirse a la Academia de la Grabación como miembros con derecho a voto.",
    ),
    "es",
  );
});

Deno.test("rejects English and Portuguese as Spanish", () => {
  assertEquals(
    detectOriginalLanguage(
      "BTS announces a new album and returns to the stage with their world tour.",
    ),
    "en",
  );
  assertEquals(
    detectOriginalLanguage(
      "O grupo anuncia seu novo álbum e lança uma música para os fãs no Brasil.",
    ),
    "pt",
  );
});

Deno.test("detects Korean and Japanese scripts", () => {
  assertEquals(
    detectOriginalLanguage("방탄소년단이 새로운 앨범을 발표했습니다"),
    "ko",
  );
  assertEquals(detectOriginalLanguage("新しいアルバムを発表しました"), "ja");
});

Deno.test("fails closed for short or ambiguous text", () => {
  assertEquals(
    detectOriginalLanguage("BTS ARIRANG World Tour 2026"),
    "unknown",
  );
});
