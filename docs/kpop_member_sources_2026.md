# K-pop member audit — 2026-09-20

Estado: dataset preparado para revisión. No se escribieron entidades ni relaciones en Supabase.

## Reglas de carga

- Solo se cargarán relaciones con `is_active = true`.
- `group_id` debe apuntar a `entity_type = 'group'` y `member_id` a `entity_type = 'idol'`.
- Una fuente oficial que confirme el grupo, pero no publique una formación vigente, no alcanza para cargar miembros.
- Los casos marcados `REVISAR` quedan fuera de la primera carga.
- No se crean entidades hasta confirmar nombre artístico, identidad y fuente.

## Inventario remoto

- Grupos: 43.
- Idols existentes: 5: Bang Chan, Jennie, Jimin, Jungkook y Lisa.
- Relaciones actuales: 0.

## Tabla completa

| Grupo | Miembros activos según revisión | Idols existentes | Idols nuevos candidatos | Fuente oficial | Observaciones |
|---|---|---|---|---|---|
| aespa | Karina, Giselle, Winter, Ningning | — | 4 | [SM artist roster](https://www.smentertainment.com/artist/) | Formación estable; confirmar nombres desde ficha individual SM antes de cargar. |
| ASTRO | MJ, JinJin, Cha Eun-woo, Yoon Sanha | — | 4 | [Fantagio artists](https://www.fantagio.kr/artists/) | **REVISAR**: actividad individual/militar y estado grupal actual. No cargar hasta confirmación de Fantagio. |
| ATEEZ | Hongjoong, Seonghwa, Yunho, Yeosang, San, Mingi, Wooyoung, Jongho | — | 8 | [KQ Entertainment](https://kqent.com/) | Confirmar roster vigente en ficha oficial KQ. |
| BLACKPINK | Jisoo, Jennie, Rosé, Lisa | Jennie, Lisa | 2 | [YG official profile](https://ygfamily.com/en/artists/blackpink/profile) | Formación oficial de cuatro confirmada. |
| BTS | RM, Jin, SUGA, j-hope, Jimin, V, Jung Kook | Jimin, Jungkook | 5 | [BIGHIT official profile](https://bts.ibighit.com/eng/profile/) | Formación oficial de siete confirmada. |
| DAY6 | Sungjin, Young K, Wonpil, Dowoon | — | 4 | [JYP artist roster](https://www.jype.com/Artist) | Confirmar ficha oficial del grupo. |
| Dreamcatcher | JiU, SuA, Siyeon, Handong, Yoohyeon, Dami, Gahyeon | — | 7 | [Dreamcatcher Company](https://dreamcatcher.kr/) | Confirmar actividad vigente y nombres de ficha. |
| ENHYPEN | Jungwon, Jay, Jake, Sunghoon, Sunoo, Ni-Ki | — | 6 | [BELIFT official profile](https://beliftlab.com/artist/profile/ENHYPEN) | Formación de seis confirmada oficialmente; Heeseung excluido. |
| EVERGLOW | E:U, Sihyeon, Mia, Onda, Aisha | — | 5 | [Yuehua Entertainment](https://www.yhfamily.cn/) | **REVISAR**: confirmar salida/estado contractual de Yiren y roster 2026. |
| EXO | Suho, Xiumin, Lay, Baekhyun, Chen, Chanyeol, D.O., Kai, Sehun | — | 9 | [SM artist roster](https://www.smentertainment.com/artist/) | **REVISAR**: contratos, actividades individuales y definición de formación activa. |
| fromis_9 | Jiwon, Jisun, Seoyeon, Chaeyoung, Nagyung | — | 5 | [PLEDIS artists](https://www.pledis.co.kr/) | **REVISAR**: estado posterior a cambios contractuales; no cargar aún. |
| GOT7 | Jay B, Mark, Jackson, Jinyoung, Youngjae, BamBam, Yugyeom | — | 7 | [JYP history/artist archive](https://www.jype.com/History) | **REVISAR**: grupo activo con agencias individuales; confirmar fuente oficial grupal vigente. |
| Hearts2Hearts | Carmen, Jiwoo, Yuha, Stella, Juun, A-na, Ian, Ye-on | — | 8 | [SM artist roster](https://www.smentertainment.com/artist/) | Confirmar nombres romanizados en ficha oficial SM. |
| ILLIT | Yunah, Minju, Moka, Wonhee, Iroha | — | 5 | [HYBE artist roster](https://hybecorp.com/eng/company/artist) | Confirmar ficha BELIFT/official profile. |
| IVE | Gaeul, An Yujin, Rei, Jang Wonyoung, Liz, Leeseo | — | 6 | [STARSHIP Entertainment](https://www.starship-ent.com/) | Confirmar ficha oficial STARSHIP. |
| Kep1er | Choi Yujin, Shen Xiaoting, Mashiro, Kim Chaehyun, Kim Dayeon, Hikaru, Huening Bahiyyih | — | 7 | [WAKEONE artists](https://wake-one.com/) | **REVISAR**: cambios de integrantes y continuidad contractual. |
| KickFlip | Kyehoon, Amaru, Donghwa, Juwang, Minje, Keiju, Donghyeon | — | 7 | [JYP artist roster](https://www.jype.com/Artist) | Confirmar perfil oficial y romanización. |
| KISS OF LIFE | Julie, Natty, Belle, Haneul | — | 4 | [S2 Entertainment](https://s2ent.co.kr/) | Confirmar ficha oficial S2. |
| LE SSERAFIM | Sakura, Chaewon, Yunjin, Kazuha, Eunchae | — | 5 | [HYBE artist roster](https://hybecorp.com/eng/company/artist) | Confirmar ficha SOURCE MUSIC. |
| MAMAMOO+ | Solar, Moonbyul | — | 2 | [RBW artists](https://www.rbbridge.com/) | Subunidad; relación separada de MAMAMOO si se incorpora en el futuro. |
| MEOVV | Sooin, Gawon, Anna, Narin, Ella | — | 5 | [THEBLACKLABEL artists](https://tblcompany.com/) | Confirmar roster oficial vigente. |
| MONSTA X | Shownu, Minhyuk, Kihyun, Hyungwon, Joohoney, I.M | — | 6 | [STARSHIP Entertainment](https://www.starship-ent.com/) | **REVISAR**: servicio militar y condición activa individual. |
| NCT | Taeyong, Johnny, Yuta, Kun, Doyoung, Ten, Jaehyun, Winwin, Jungwoo, Mark, Xiaojun, Hendery, Renjun, Jeno, Haechan, Jaemin, Chenle, Jisung, Sion, Riku, Yushi, Jaehee, Ryo, Sakuya | — | 23 | [SM artist roster](https://www.smentertainment.com/artist/) | **REVISAR**: grupo paraguas; no duplicar automáticamente miembros de unidades y confirmar roster NCT vigente. |
| NCT 127 | Johnny, Taeyong, Yuta, Doyoung, Jaehyun, Jungwoo, Mark, Haechan | — | 8 | [SM artist roster](https://www.smentertainment.com/artist/) | **REVISAR**: Taeil excluido por salida; confirmar estado de miembros en servicio militar. |
| NCT DREAM | Mark, Renjun, Jeno, Haechan, Jaemin, Chenle, Jisung | — | 7 | [SM artist roster](https://www.smentertainment.com/artist/) | Confirmar ficha de unidad y no duplicar entidades. |
| NCT WISH | Sion, Riku, Yushi, Jaehee, Ryo, Sakuya | — | 6 | [SM artist roster](https://www.smentertainment.com/artist/) | Confirmar ficha de unidad. |
| NewJeans | Minji, Hanni, Danielle, Haerin, Hyein | — | 5 | [HYBE artist roster](https://hybecorp.com/eng/company/artist) | **REVISAR**: disputa contractual y nombre/actividad vigente; no cargar hasta resolución oficial. |
| NEXZ | Tomoya, Yu, Haru, So Geon, Seita, Hyui, Yuki | — | 7 | [NEXZ official profile](https://nexz.jype.com/profile) | Formación de siete confirmada oficialmente. |
| ONEUS | Ravn, Seoho, Leedo, Keonhee, Hwanwoong, Xion | — | 6 | [RBW artists](https://www.rbbridge.com/) | **REVISAR**: Ravn salió del grupo; excluirlo si la fuente vigente confirma formación de cinco. |
| P1Harmony | Keeho, Theo, Jiung, Intak, Soul, Jongseob | — | 6 | [FNC Entertainment artists](https://www.fncent.com/) | Confirmar ficha oficial FNC. |
| PURPLE KISS | Na Go-eun, Dosie, Ireh, Yuki, Chaein, Swan | — | 6 | [RBW artists](https://www.rbbridge.com/) | **REVISAR**: Park Ji-eun salió; confirmar formación vigente de cinco. |
| Red Velvet | Irene, Seulgi, Wendy, Joy, Yeri | — | 5 | [SM artist roster](https://www.smentertainment.com/artist/) | Confirmar ficha oficial SM. |
| SEVENTEEN | S.Coups, Jeonghan, Joshua, Jun, Hoshi, Wonwoo, Woozi, The 8, Mingyu, DK, Seungkwan, Vernon, Dino | — | 13 | [PLEDIS artists](https://www.pledis.co.kr/) | **REVISAR**: enlistment/hiatus no elimina la pertenencia; distinguir miembro del grupo de actividad temporal. |
| SHINee | Onew, Key, Minho, Taemin | — | 4 | [SM artist roster](https://www.smentertainment.com/artist/) | Jonghyun no es integrante activo; confirmar roster oficial actual. |
| STAYC | Sumin, Sieun, Isa, Seeun, Yoon, J | — | 6 | [High Up Entertainment](https://www.highup-ent.com/) | Confirmar ficha oficial. |
| Stray Kids | Bang Chan, Lee Know, Changbin, Hyunjin, Han, Felix, Seungmin, I.N | Bang Chan | 7 | [Stray Kids official profile](https://straykids.jype.com/profile) | Formación de ocho confirmada oficialmente. |
| THE BOYZ | Sangyeon, Jacob, Younghoon, Hyunjae, Juyeon, Kevin, New, Q, Ju Haknyeon, Sunwoo, Eric | — | 11 | [IST Entertainment](https://ist-ent.co.kr/) | **REVISAR**: cambios de agencia/formación recientes. |
| tripleS | Seo DaHyun, Kim ChaeYeon, Lee JiWoo, Kim YooYeon, Kim NaKyoung, Gong YuBin, Kaede, Kotone, YeonJi, ChaeWon, SooMin, ShiOn, Mayu, Lynn, JooBin, HaYeon, Nien, SoHyun, Xinyu, JiYeon, Chaewon, Sullin, SeoAh, member 24 pending official roster confirmation | — | 24 | [MODHAUS](https://www.modhaus.co.kr/) | **REVISAR**: grupo modular; no crear un nombre pendiente ni cargar hasta confirmar las 24 entidades. |
| TWICE | Nayeon, Jeongyeon, Momo, Sana, Jihyo, Mina, Dahyun, Chaeyoung, Tzuyu | — | 9 | [JYP artist roster](https://www.jype.com/Artist) | Confirmar ficha individual/oficial. |
| TXT | Soobin, Yeonjun, Beomgyu, Taehyun, Huening Kai | — | 5 | [HYBE artist roster](https://hybecorp.com/eng/company/artist) | Confirmar ficha BIGHIT MUSIC. |
| WayV | Kun, Ten, Winwin, Xiaojun, Hendery, Yangyang | — | 6 | [SM artist roster](https://www.smentertainment.com/artist/) | **REVISAR**: separación de Lucas y actividad de Winwin; confirmar unidad vigente. |
| WJSN | Seola, Xuanyi, Bona, Exy, Soobin, Luda, Dawon, Eunseo, Cheng Xiao, Meiqi, Yeoreum, Dayoung, Yeonjung | — | 13 | [STARSHIP Entertainment](https://www.starship-ent.com/) | **REVISAR**: miembros chinos/contratos y formación activa; no cargar sin fuente vigente. |
| Xdinary Heroes | Gunil, Jungsu, Gaon, O.de, Jun Han, Jooyeon | — | 6 | [JYP artist roster](https://www.jype.com/Artist) | Confirmar ficha oficial. |

## Resultado de revisión

## Clasificación cerrada

| Grupo | Estado | Miembros activos | Fuente oficial | Observaciones |
|---|---|---|---|---|
| aespa | READY | Karina, Giselle, Winter, Ningning | [SM](https://www.smentertainment.com/artist/) | Roster estable; confirmar romanización final. |
| ASTRO | REVISAR | MJ, JinJin, Cha Eun-woo, Yoon Sanha | [Fantagio](https://www.fantagio.kr/artists/) | Actividad individual/militar y estado grupal actual. |
| ATEEZ | READY | Hongjoong, Seonghwa, Yunho, Yeosang, San, Mingi, Wooyoung, Jongho | [KQ](https://kqent.com/) | Sin ambigüedad de membresía detectada. |
| BLACKPINK | READY | Jisoo, Jennie, Rosé, Lisa | [YG](https://ygfamily.com/en/artists/blackpink/profile) | Formación de cuatro confirmada. |
| BTS | READY | RM, Jin, SUGA, j-hope, Jimin, V, Jung Kook | [BIGHIT](https://bts.ibighit.com/eng/profile/) | Formación de siete confirmada. |
| DAY6 | READY | Sungjin, Young K, Wonpil, Dowoon | [JYP](https://www.jype.com/Artist) | Roster estable. |
| Dreamcatcher | READY | JiU, SuA, Siyeon, Handong, Yoohyeon, Dami, Gahyeon | [Dreamcatcher Company](https://dreamcatcher.kr/) | Roster estable. |
| ENHYPEN | READY | Jungwon, Jay, Jake, Sunghoon, Sunoo, Ni-Ki | [BELIFT](https://beliftlab.com/artist/profile/ENHYPEN) | Seis miembros; Heeseung excluido. |
| EVERGLOW | REVISAR | E:U, Sihyeon, Mia, Onda, Aisha | [Yuehua](https://www.yhfamily.cn/) | Confirmar estado de Yiren y roster 2026. |
| EXO | REVISAR | Suho, Xiumin, Lay, Baekhyun, Chen, Chanyeol, D.O., Kai, Sehun | [SM](https://www.smentertainment.com/artist/) | Contratos y actividades individuales hacen ambigua la formación activa. |
| fromis_9 | REVISAR | Jiwon, Jisun, Seoyeon, Chaeyoung, Nagyung | [PLEDIS](https://www.pledis.co.kr/) | Cambios contractuales y falta de roster vigente inequívoco. |
| GOT7 | REVISAR | Jay B, Mark, Jackson, Jinyoung, Youngjae, BamBam, Yugyeom | [JYP archive](https://www.jype.com/History) | Agencias individuales; confirmar fuente grupal vigente. |
| Hearts2Hearts | READY | Carmen, Jiwoo, Yuha, Stella, Juun, A-na, Ian, Ye-on | [SM](https://www.smentertainment.com/artist/) | Roster de debut; confirmar romanización final. |
| ILLIT | READY | Yunah, Minju, Moka, Wonhee, Iroha | [HYBE](https://hybecorp.com/eng/company/artist) | Roster estable. |
| IVE | READY | Gaeul, An Yujin, Rei, Jang Wonyoung, Liz, Leeseo | [STARSHIP](https://www.starship-ent.com/) | Roster estable. |
| Kep1er | REVISAR | Choi Yujin, Shen Xiaoting, Mashiro, Kim Chaehyun, Kim Dayeon, Hikaru, Huening Bahiyyih | [WAKEONE](https://wake-one.com/) | Cambios de integrantes y continuidad contractual. |
| KickFlip | READY | Kyehoon, Amaru, Donghwa, Juwang, Minje, Keiju, Donghyeon | [JYP](https://www.jype.com/Artist) | Roster estable. |
| KISS OF LIFE | READY | Julie, Natty, Belle, Haneul | [S2](https://s2ent.co.kr/) | Roster estable. |
| LE SSERAFIM | READY | Sakura, Chaewon, Yunjin, Kazuha, Eunchae | [HYBE](https://hybecorp.com/eng/company/artist) | Roster estable. |
| MAMAMOO+ | REVISAR | Solar, Moonbyul | [RBW](https://www.rbbridge.com/) | Subunidad; requiere política explícita frente a MAMAMOO. |
| MEOVV | READY | Sooin, Gawon, Anna, Narin, Ella | [THEBLACKLABEL](https://tblcompany.com/) | Roster estable; confirmar ficha vigente. |
| MONSTA X | REVISAR | Shownu, Minhyuk, Kihyun, Hyungwon, Joohoney, I.M | [STARSHIP](https://www.starship-ent.com/) | Servicio militar y actividad individual afectan “activo”. |
| NCT | REVISAR | Roster paraguas pendiente de confirmación | [SM](https://www.smentertainment.com/artist/) | No cargar hasta resolver duplicación con unidades y roster agregado. |
| NCT 127 | REVISAR | Johnny, Taeyong, Yuta, Doyoung, Jaehyun, Jungwoo, Mark, Haechan | [SM](https://www.smentertainment.com/artist/) | Taeil excluido; confirmar miembros en servicio y ficha actual. |
| NCT DREAM | READY | Mark, Renjun, Jeno, Haechan, Jaemin, Chenle, Jisung | [SM](https://www.smentertainment.com/artist/) | Unidad de siete; entidades compartidas deben reutilizarse. |
| NCT WISH | READY | Sion, Riku, Yushi, Jaehee, Ryo, Sakuya | [SM](https://www.smentertainment.com/artist/) | Unidad de seis; entidades propias. |
| NewJeans | REVISAR | Minji, Hanni, Danielle, Haerin, Hyein | [HYBE](https://hybecorp.com/eng/company/artist) | Disputa contractual y nombre/actividad vigente. |
| NEXZ | READY | Tomoya, Yu, Haru, So Geon, Seita, Hyui, Yuki | [NEXZ](https://nexz.jype.com/profile) | Siete miembros confirmados. |
| ONEUS | REVISAR | Seoho, Leedo, Keonhee, Hwanwoong, Xion | [RBW](https://www.rbbridge.com/) | Ravn salió; confirmar roster actual antes de cargar. |
| P1Harmony | READY | Keeho, Theo, Jiung, Intak, Soul, Jongseob | [FNC](https://www.fncent.com/) | Roster estable. |
| PURPLE KISS | REVISAR | Na Go-eun, Dosie, Ireh, Yuki, Chaein, Swan | [RBW](https://www.rbbridge.com/) | Park Ji-eun salió; confirmar formación vigente. |
| Red Velvet | READY | Irene, Seulgi, Wendy, Joy, Yeri | [SM](https://www.smentertainment.com/artist/) | Roster estable. |
| SEVENTEEN | REVISAR | S.Coups, Jeonghan, Joshua, Jun, Hoshi, Wonwoo, Woozi, The 8, Mingyu, DK, Seungkwan, Vernon, Dino | [PLEDIS](https://www.pledis.co.kr/) | Servicio militar/hiatus; distinguir pertenencia de actividad temporal. |
| SHINee | REVISAR | Onew, Key, Minho, Taemin | [SM](https://www.smentertainment.com/artist/) | Confirmar roster vigente y tratamiento de actividad individual. |
| STAYC | READY | Sumin, Sieun, Isa, Seeun, Yoon, J | [High Up](https://www.highup-ent.com/) | Roster estable. |
| Stray Kids | READY | Bang Chan, Lee Know, Changbin, Hyunjin, Han, Felix, Seungmin, I.N | [JYP](https://straykids.jype.com/profile) | Ocho miembros confirmados. |
| THE BOYZ | REVISAR | Sangyeon, Jacob, Younghoon, Hyunjae, Juyeon, Kevin, New, Q, Ju Haknyeon, Sunwoo, Eric | [IST](https://ist-ent.co.kr/) | Cambios recientes de agencia/formación. |
| tripleS | REVISAR | Roster modular pendiente de confirmación | [MODHAUS](https://www.modhaus.co.kr/) | Confirmar 24 entidades y unidad activa en la fecha de carga. |
| TWICE | READY | Nayeon, Jeongyeon, Momo, Sana, Jihyo, Mina, Dahyun, Chaeyoung, Tzuyu | [JYP](https://www.jype.com/Artist) | Roster estable. |
| TXT | READY | Soobin, Yeonjun, Beomgyu, Taehyun, Huening Kai | [HYBE](https://hybecorp.com/eng/company/artist) | Roster estable. |
| WayV | REVISAR | Kun, Ten, Winwin, Xiaojun, Hendery, Yangyang | [SM](https://www.smentertainment.com/artist/) | Lucas excluido; confirmar actividad vigente de Winwin y unidad. |
| WJSN | REVISAR | Seola, Xuanyi, Bona, Exy, Soobin, Luda, Dawon, Eunseo, Cheng Xiao, Meiqi, Yeoreum, Dayoung, Yeonjung | [STARSHIP](https://www.starship-ent.com/) | Contratos/actividad de miembros chinos y formación activa. |
| Xdinary Heroes | READY | Gunil, Jungsu, Gaon, O.de, Jun Han, Jooyeon | [JYP](https://www.jype.com/Artist) | Roster estable. |

## Resumen numérico

- READY: **24** grupos.
- REVISAR: **19** grupos.
- Total: **43** grupos.
- Relaciones estimadas para READY: **145**.
- Apariciones de idols existentes dentro de READY: **5** (Jennie, Lisa, Jimin, Jungkook, Bang Chan).
- Idols nuevos estimados para READY: **140**, antes de la deduplicación canónica de nombres.
- Duplicados compartidos detectados dentro de READY: ninguno adicional confirmado; NCT DREAM y NCT WISH no comparten miembros en esta primera clasificación.

Las cantidades son estimaciones de dataset, no escrituras remotas. No se deben convertir en carga hasta validar las fichas oficiales de cada grupo READY y resolver los 19 casos REVISAR.

### Confirmados para una primera carga

- ENHYPEN: 6 integrantes, confirmado por BELIFT.
- BLACKPINK: 4 integrantes, confirmado por YG.
- BTS: 7 integrantes, confirmado por BIGHIT.
- Stray Kids: 8 integrantes, confirmado por JYP.
- NEXZ: 7 integrantes, confirmado por JYP.

### Casos que deben permanecer fuera de la carga hasta una segunda confirmación oficial

ASTRO, EVERGLOW, EXO, fromis_9, GOT7, Kep1er, MAMAMOO+, MONSTA X, NCT, NCT 127, NewJeans, ONEUS, PURPLE KISS, SEVENTEEN, SHINee, THE BOYZ, tripleS, WayV y WJSN.

La razón no es falta de entidades en Supabase, sino cambios contractuales, servicio militar, subunidades, grupos modulares o fuentes oficiales que no exponen una formación vigente inequívoca.

Este documento es el dataset de auditoría local previo a la carga. No se modificó Supabase.
