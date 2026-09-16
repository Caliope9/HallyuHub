# HallyuHub — enrichment de perfiles K-pop v1.0

Estado: REVIEW ONLY. No se ejecutó SQL, no se modificó Supabase y no se
modificó código productivo.

## Esquema confirmado

Esta pasada usa únicamente:

- `bio`
- `official_url`
- `updated_at`

No usa ni crea `fandom_name`, `debut_year`, `discography`, `members`,
`country` ni `agency`, porque no forman parte del esquema real confirmado.
Tampoco modifica `id`, `entity_type`, `aliases`, imágenes, atribución,
verificación ni estado.

El SQL actualiza por `normalized_name` exacto y solo cuando `bio` u
`official_url` están vacíos. No sobrescribe datos editoriales existentes.
La escritura de `official_url` está protegida por una allowlist: solo se
escriben seis URLs verificadas. Las demás referencias permanecen excluidas de
la escritura hasta una validación oficial individual.
Cada lote tiene su propio `WITH enrichment (...) AS (...) UPDATE` y su propio
punto y coma; no existe una CTE compartida.

## Lote 1 — primeros 12 grupos restantes

| Nombre | normalized_name | Bio | Debut/fandom/members/discografía | official_url | Fuente / duda |
|---|---|---|---|---|---|
| EXO | `exo` | Preparada | No soportados por esquema | SM Entertainment | Página oficial de SM |
| SHINee | `shinee` | Preparada | No soportados por esquema | SM Entertainment | Página oficial de SM |
| NCT 127 | `nct 127` | Preparada | No soportados por esquema | SM Entertainment | Página oficial de SM |
| NCT DREAM | `nct dream` | Preparada | No soportados por esquema | SM Entertainment | Página oficial de SM |
| GOT7 | `got7` | Preparada | No soportados por esquema | JYP / sitio oficial | Confirmar página vigente antes de ejecutar |
| MONSTA X | `monsta x` | Preparada | No soportados por esquema | Starship | Confirmar URL vigente |
| THE BOYZ | `the boyz` | Preparada | No soportados por esquema | Sitio oficial | Confirmar agencia/URL vigente |
| ASTRO | `astro` | Preparada | No soportados por esquema | Fantagio | Confirmar URL vigente |
| P1Harmony | `p1harmony` | Preparada | No soportados por esquema | FNC Entertainment | Página oficial de agencia |
| ONEUS | `oneus` | Preparada | No soportados por esquema | RBW | Confirmar roster vigente |
| DAY6 | `day6` | Preparada | No soportados por esquema | JYP / sitio oficial | Página oficial de grupo |
| Xdinary Heroes | `xdinary heroes` | Preparada | No soportados por esquema | JYP / sitio oficial | Página oficial de grupo |

## Lote 2 — siguientes 12 grupos restantes

| Nombre | normalized_name | Bio | Debut/fandom/members/discografía | official_url | Fuente / duda |
|---|---|---|---|---|---|
| NEXZ | `nexz` | Preparada | No soportados por esquema | JYP / sitio oficial | Página oficial de grupo |
| KickFlip | `kickflip` | Preparada | No soportados por esquema | JYP / sitio oficial | Confirmar URL vigente |
| NCT WISH | `nct wish` | Preparada | No soportados por esquema | SM Entertainment | Página oficial de SM |
| WayV | `wayv` | Preparada | No soportados por esquema | SM Entertainment | Página oficial de SM |
| Red Velvet | `red velvet` | Preparada | No soportados por esquema | SM Entertainment | Página oficial de SM |
| ILLIT | `illit` | Preparada | No soportados por esquema | BELIFT LAB | Perfil oficial |
| KISS OF LIFE | `kiss of life` | Preparada | No soportados por esquema | S2 Entertainment | Confirmar URL vigente |
| MEOVV | `meovv` | Preparada | No soportados por esquema | THEBLACKLABEL | Página oficial de agencia |
| Hearts2Hearts | `hearts2hearts` | Preparada | No soportados por esquema | SM Entertainment | Confirmar página oficial vigente |
| MAMAMOO+ | `mamamoo+` | Preparada | No soportados por esquema | RBW | Confirmar roster vigente |
| Dreamcatcher | `dreamcatcher` | Preparada | No soportados por esquema | Sitio oficial | Confirmar URL vigente |
| STAYC | `stayc` | Preparada | No soportados por esquema | High Up Entertainment | Página oficial |

## Lote 3 — resto de grupos

| Nombre | normalized_name | Bio | Debut/fandom/members/discografía | official_url | Fuente / duda |
|---|---|---|---|---|---|
| tripleS | `triples` | Preparada | No soportados por esquema | MODHAUS | Página oficial de proyecto |
| Kep1er | `kep1er` | Preparada | No soportados por esquema | Agencia/sitio de referencia | Confirmar agencia y URL vigente |
| EVERGLOW | `everglow` | Preparada | No soportados por esquema | Yuehua | Confirmar roster vigente |
| fromis_9 | `fromis_9` | Preparada | No soportados por esquema | Agencia/sitio de referencia | Confirmar agencia y URL vigente |
| PURPLE KISS | `purple kiss` | Preparada | No soportados por esquema | RBW | Confirmar roster vigente |
| WJSN | `wjsn` | Preparada | No soportados por esquema | Starship | Confirmar URL vigente |
| NewJeans | `newjeans` | Preparada | No soportados por esquema | HYBE | Situación contractual/representación compleja; bio prudente |
| TWICE | `twice` | Preparada | No soportados por esquema | JYP / sitio oficial | Página oficial |
| SEVENTEEN | `seventeen` | Preparada | No soportados por esquema | PLEDIS | Página oficial |
| IVE | `ive` | Preparada | No soportados por esquema | Starship | Confirmar URL vigente |
| LE SSERAFIM | `le sserafim` | Preparada | No soportados por esquema | SOURCE MUSIC | Página oficial de agencia |
| NCT | `nct` | Preparada | No soportados por esquema | SM Entertainment | Proyecto con unidades; no se afirma estado de integrantes |
| ATEEZ | `ateez` | Preparada | No soportados por esquema | KQ Entertainment | Confirmar URL vigente |

## Lote 4 — artistas e idols

| Nombre | Tipo | normalized_name | Bio | official_url | Duda |
|---|---|---|---|---|---|
| IU | artist | `iu` | Preparada | EDAM | Verificar URL vigente |
| TAEYEON | artist | `taeyeon` | Preparada | SM Entertainment | Página oficial |
| TAEYANG | artist | `taeyang` | Preparada | YG / BIGBANG | Verificar URL vigente |
| G-DRAGON | artist | `g-dragon` | Preparada | Galaxy Corporation | Verificar URL vigente |
| ZICO | artist | `zico` | Preparada | KOZ Entertainment | Página oficial de agencia |
| PSY | artist | `psy` | Preparada | PSY Studio | Verificar URL vigente |
| SUNMI | artist | `sunmi` | Preparada | ABYSS Company | Página oficial de agencia |
| CHUNG HA | artist | `chung ha` | Preparada | MORE VISION | Verificar URL vigente |
| Ailee | artist | `ailee` | Preparada | Agencia oficial | Confirmar URL vigente |
| BIBI | artist | `bibi` | Preparada | FeelGhood Music | Confirmar URL vigente |
| Heize | artist | `heize` | Preparada | P NATION | Confirmar representación vigente |
| Kang Daniel | artist | `kang daniel` | Preparada | Agencia histórica | Confirmar situación/URL vigente |
| LEE HI | artist | `lee hi` | Preparada | AOMG | Confirmar representación vigente |
| DEAN | artist | `dean` | Preparada | Universal Music | URL de referencia; confirmar sitio primario |
| BAEKHYUN | artist | `baekhyun` | Preparada | INB100 | Página oficial de agencia |
| TAEMIN | artist | `taemin` | Preparada | SM Entertainment | Confirmar URL vigente |
| KEY | artist | `key` | Preparada | SM Entertainment | Confirmar URL vigente |
| HWASA | artist | `hwasa` | Preparada | RBW | Confirmar representación vigente |
| KAI | artist | `kai` | Preparada | SM Entertainment | Confirmar URL vigente |
| WOODZ | artist | `woodz` | Preparada | EDAM | Confirmar URL vigente |
| Yerin Baek | artist | `yerin baek` | Preparada | Blue Vinyl | Página oficial de sello |
| Jungkook | idol | `jungkook` | Preparada | BIGHIT MUSIC | Perfil oficial de BTS |
| Jimin | idol | `jimin` | Preparada | BIGHIT MUSIC | Perfil oficial de BTS |
| Lisa | idol | `lisa` | Preparada | YG / BLACKPINK | Perfil oficial de BLACKPINK |
| Jennie | idol | `jennie` | Preparada | YG / BLACKPINK | Perfil oficial de BLACKPINK |
| Bang Chan | idol | `bang chan` | Preparada | JYP / Stray Kids | Perfil oficial de Stray Kids |

## Perfiles excluidos

No se tocan los seis perfiles mejorados anteriormente:

- BTS
- BLACKPINK
- Stray Kids
- TXT
- ENHYPEN
- aespa

## Resumen

- Entidades de producción: 69.
- Enrichment preparado en esta nueva pasada: 63.
- Enrichment previo excluido: 6.
- Grupos cubiertos en esta pasada: 37.
- Artistas cubiertos: 21.
- Idols cubiertos: 5.
- Bio propuesta: 63 entidades de esta pasada.
- URLs verificadas y habilitadas para escritura: 6 (`seventeen`, `jungkook`,
  `jimin`, `lisa`, `jennie`, `bang chan`).
- URLs dudosas o no encontradas excluidas de la escritura: 57.
- Lotes independientes: Lote 1 = 12 grupos; Lote 2 = 12 grupos; Lote 3 = 13
  grupos; Lote 4 = 21 artistas + 5 idols = 26 entidades.
- Campos que siguen vacíos por diseño: país, agencia, fandom, debut, members y
  discografía, porque no existen en el esquema real confirmado.
- Datos dudosos: representación vigente de algunos artistas, URLs de agencias
  cambiantes y situación contractual de NewJeans. Se evitó afirmar estados
  contractuales o integrantes actuales cuando podían ser ambiguos.

## Fuentes principales

- [BIGHIT MUSIC — BTS](https://bts.ibighit.com/eng/profile/)
- [BIGHIT MUSIC — TXT](https://txt.ibighit.com/eng/profile/)
- [JYP Entertainment](https://m.jype.com/)
- [Stray Kids — JYP](https://straykids.jype.com/profile)
- [YG Entertainment — BLACKPINK](https://ygfamily.com/en/artists/blackpink/profile)
- [BELIFT LAB — ENHYPEN](https://beliftlab.com/artist/profile/ENHYPEN)
- [PLEDIS — SEVENTEEN](https://www.pledis.co.kr/artist/detail/seventeen)
- [SM Entertainment](https://www.smentertainment.com/)
- [RBW](https://www.rbbridge.com/?page_id=17131)

No se usaron fandom wikis como fuente única. Las bios son redacción original y
no copian párrafos de las fuentes. Las URLs no incluidas en la allowlist no se
escriben.
