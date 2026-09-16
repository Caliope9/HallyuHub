-- HallyuHub K-pop profiles enrichment v1 - REVIEW ONLY
-- NO ejecutar automáticamente.
-- Solo columnas confirmadas: bio, official_url y updated_at.
-- No crea columnas, no inserta entidades, no cambia IDs/entity_type,
-- no elimina datos y no agrega imágenes.
-- Excluidos: BTS, BLACKPINK, Stray Kids, TXT, ENHYPEN, aespa.
-- Cada lote es una sentencia independiente y completa.
-- Bio: solo se escribe cuando trim(coalesce(bio, '')) = ''.
-- official_url: solo se escribe para la allowlist verificada.
-- Las demás URLs se conservan como referencias, pero nunca se escriben.

-- LOTE 1
with enrichment (normalized_name, bio, official_url) as (
  values
    ('exo', '', null),
    ('shinee', 'SHINee es un grupo surcoreano que debutó en 2008 y ha construido una trayectoria ligada al pop, R&B, dance y una fuerte identidad de performance. Sus actividades grupales actuales reúnen a Onew, Key, Minho y Taemin, quienes también desarrollan carreras individuales.', null),
    ('nct 127', 'NCT 127 es una unidad de NCT que debutó en julio de 2016 y toma su nombre de la longitud 127 de Seúl. Desde 2026 continúa como grupo de siete integrantes: Johnny, Taeyong, Yuta, Doyoung, Jaehyun, Jungwoo y Haechan. La unidad combina una fuerte orientación a la performance con actividad internacional.', null),
    ('nct dream', 'NCT DREAM es una unidad de NCT que debutó el 25 de agosto de 2016. Desde 2026 continúa con Renjun, Jeno, Haechan, Jaemin, Chenle y Jisung. Su trayectoria ha evolucionado desde una identidad juvenil hacia una propuesta musical más amplia, manteniendo temas ligados al crecimiento y la energía del grupo.', null),
    ('got7', 'GOT7 es un grupo surcoreano de siete integrantes: JAY B, Mark, Jackson, Jinyoung, Youngjae, BamBam y Yugyeom. Debutó en 2014 y ha desarrollado una identidad que combina pop, hip-hop y R&B, junto con una fuerte participación de sus integrantes en la creación musical. En 2025 retomó actividades grupales con el miniálbum WINTER HEPTAGON.', null),
    ('monsta x', 'MONSTA X es un grupo surcoreano de Starship Entertainment formado por Shownu, Minhyuk, Kihyun, Hyungwon, Joohoney e I.M. Debutó en 2015 con TRESPASS y ha construido una identidad marcada por performance, hip-hop, pop y una amplia actividad internacional.', null),
    ('the boyz', 'THE BOYZ es un grupo surcoreano que debutó el 6 de diciembre de 2017 y se ha destacado especialmente por sus conceptos escénicos y su trabajo de performance. Tras cambios recientes en su formación, en 2026 nueve integrantes acordaron continuar desarrollando actividades grupales bajo el nombre THE BOYZ.', null),
    ('astro', 'ASTRO es un grupo surcoreano de Fantagio que debutó en 2016. A lo largo de su trayectoria ha desarrollado una identidad basada en pop melódico, performance y distintos conceptos visuales. El grupo continúa formando parte del catálogo de Fantagio mientras sus integrantes desarrollan también actividades individuales y de subunidades.', null),
    ('p1harmony', 'P1Harmony es un grupo surcoreano de FNC Entertainment formado por Keeho, Theo, Jiung, Intak, Soul y Jongseob. Debutó en 2020 y combina canto, rap y performance en una propuesta que ha desarrollado una actividad internacional sostenida.', null),
    ('oneus', 'ONEUS es un grupo surcoreano que debutó en 2019. Actualmente está formado por Seoho, Leedo, Keonhee, Hwanwoong y Xion. Tras finalizar sus contratos exclusivos con RBW a fines de febrero de 2026, los cinco integrantes anunciaron que continuarán desarrollando actividades grupales bajo el nombre ONEUS.', null),
    ('day6', 'DAY6 es una banda surcoreana de JYP Entertainment que debutó en 2015. Actualmente está integrada por Sungjin, Young K, Wonpil y Dowoon. Sus integrantes participan activamente en la composición e interpretación de su música, con un sonido que combina rock, pop y elementos alternativos.', null),
    ('xdinary heroes', 'Xdinary Heroes es una banda surcoreana de JYP Entertainment que debutó en 2021. Tras un cambio de formación anunciado en 2026, continúa como quinteto integrado por Jungsu, Gaon, O.de, Jun Han y Jooyeon. Su propuesta está centrada en instrumentos de banda, rock, pop y performance.', null)
)
update public.kpop_entities as e
set
  bio = case
    when trim(coalesce(e.bio, '')) = '' then enrichment.bio
    else e.bio
  end,
  official_url = case
    when trim(coalesce(e.official_url, '')) = ''
      and enrichment.normalized_name in ('seventeen', 'jungkook', 'jimin', 'lisa', 'jennie', 'bang chan')
      and nullif(trim(coalesce(enrichment.official_url, '')), '') is not null
      then enrichment.official_url
    else e.official_url
  end,
  updated_at = now()
from enrichment
where e.normalized_name = enrichment.normalized_name
  and (
    (trim(coalesce(e.bio, '')) = ''
      and trim(coalesce(enrichment.bio, '')) <> '')
    or (
      trim(coalesce(e.official_url, '')) = ''
      and enrichment.normalized_name in ('seventeen', 'jungkook', 'jimin', 'lisa', 'jennie', 'bang chan')
      and nullif(trim(coalesce(enrichment.official_url, '')), '') is not null
    )
  );

-- LOTE 2
with enrichment (normalized_name, bio, official_url) as (
  values
    ('nexz', 'NEXZ es un grupo multinacional de JYP Entertainment que debutó en 2024. Su propuesta se enfoca en pop, performance y una identidad de nueva generación.', 'https://nexz.jype.com/'),
    ('kickflip', 'KickFlip es un grupo de JYP Entertainment presentado como una nueva generación de artistas de K-pop. Su identidad se construye alrededor de pop, performance y energía juvenil.', 'https://kickflip.jype.com/'),
    ('nct wish', 'NCT WISH es una unidad de NCT de SM Entertainment que debutó en 2024. Su propuesta se orienta a un pop luminoso y una conexión cercana con fans de Corea y Japón.', 'https://www.smentertainment.com/artist/nct-wish/'),
    ('wayv', 'WayV es una unidad de NCT gestionada por SM Entertainment que debutó en 2019. Su repertorio combina pop, hip-hop, R&B y elementos de performance en varios idiomas.', 'https://www.smentertainment.com/artist/wayv/'),
    ('red velvet', 'Red Velvet es un grupo surcoreano de SM Entertainment que debutó en 2014. Su discografía alterna conceptos pop y refinados con una identidad vocal distintiva.', 'https://www.smentertainment.com/artist/red-velvet/'),
    ('illit', 'ILLIT es un grupo de BELIFT LAB que debutó en 2024. Su propuesta se apoya en pop contemporáneo, una estética juvenil y una identidad de nueva generación.', 'https://beliftlab.com/artist/profile/ILLIT'),
    ('kiss of life', 'KISS OF LIFE es un grupo surcoreano que debutó en 2023. Su música combina pop, R&B y performance, con énfasis en la individualidad artística de sus integrantes.', 'https://s2ent.co.kr/artist/kissoflife'),
    ('meovv', 'MEOVV es un grupo de THEBLACKLABEL que debutó en 2024. Su identidad combina pop, hip-hop, performance y una presentación visual de orientación internacional.', 'https://www.theblacklabel.com/artist/meovv'),
    ('hearts2hearts', 'Hearts2Hearts es un grupo de SM Entertainment presentado como una nueva generación del K-pop. Su perfil artístico se encuentra vinculado a pop, performance y una identidad visual propia.', 'https://www.smentertainment.com/artist/hearts2hearts/'),
    ('mamamoo+', 'MAMAMOO+ es una unidad derivada de MAMAMOO vinculada a RBW. Sus lanzamientos combinan pop, R&B y la identidad vocal característica de sus integrantes.', 'https://www.rbbridge.com/?page_id=17131'),
    ('dreamcatcher', 'Dreamcatcher es un grupo surcoreano que debutó en 2017. Su propuesta se distingue por mezclar rock, pop y conceptos oscuros, con una identidad escénica muy marcada.', 'https://dreamcatcher.kr/'),
    ('stayc', 'STAYC es un grupo surcoreano de High Up Entertainment que debutó en 2020. Su música se mueve entre pop y una producción orientada a melodías claras y performance precisa.', 'https://www.highup-ent.com/en/stayc/')
)
update public.kpop_entities as e
set
  bio = case
    when trim(coalesce(e.bio, '')) = '' then enrichment.bio
    else e.bio
  end,
  official_url = case
    when trim(coalesce(e.official_url, '')) = ''
      and enrichment.normalized_name in ('seventeen', 'jungkook', 'jimin', 'lisa', 'jennie', 'bang chan')
      and nullif(trim(coalesce(enrichment.official_url, '')), '') is not null
      then enrichment.official_url
    else e.official_url
  end,
  updated_at = now()
from enrichment
where e.normalized_name = enrichment.normalized_name
  and (
    trim(coalesce(e.bio, '')) = ''
    or (
      trim(coalesce(e.official_url, '')) = ''
      and enrichment.normalized_name in ('seventeen', 'jungkook', 'jimin', 'lisa', 'jennie', 'bang chan')
      and nullif(trim(coalesce(enrichment.official_url, '')), '') is not null
    )
  );

-- LOTE 3
with enrichment (normalized_name, bio, official_url) as (
  values
    ('triples', 'tripleS es un proyecto de grupo femenino de MODHAUS con una estructura basada en subunidades y participación de la comunidad. Su propuesta combina pop, performance y una organización modular poco habitual en el K-pop.', 'https://www.modhaus.co.kr/triples'),
    ('kep1er', 'Kep1er es un grupo de K-pop formado a través de un programa de competencia y debutado en 2022. Su catálogo se apoya en pop, performance y una identidad de grupo orientada a escenarios internacionales.', 'https://www.143ent.com/'),
    ('everglow', 'EVERGLOW es un grupo surcoreano que debutó en 2019. Su propuesta combina pop, EDM y performance de gran escala, con una identidad visual intensa.', 'https://www.yuehuam.com/'),
    ('fromis_9', 'fromis_9 es un grupo surcoreano que debutó en 2018. Su repertorio recorre pop, dance y conceptos de crecimiento, con una identidad de grupo centrada en la energía escénica.', 'https://www.asnd.co.kr/'),
    ('purple kiss', 'PURPLE KISS es un grupo surcoreano de RBW que debutó en 2021. Su música combina pop, R&B y performance, con una identidad conceptual vinculada a lo misterioso y expresivo.', 'https://www.rbbridge.com/?page_id=17131'),
    ('wjsn', 'WJSN es un grupo surcoreano de Starship Entertainment que debutó en 2016. Su propuesta se caracteriza por pop, conceptos cósmicos y una amplia paleta de performance.', 'https://www.starship-ent.com/profile/musician/wjsn.php'),
    ('newjeans', 'NewJeans es un grupo surcoreano que debutó en 2022 y se hizo conocido por una aproximación fresca al pop, con referencias a sonidos de distintas épocas y una identidad visual digital.', 'https://www.hybecorp.com/eng/company/artist'),
    ('twice', 'TWICE es un grupo surcoreano de JYP Entertainment que debutó en 2015. Su trayectoria reúne pop, dance y una amplia actividad internacional, con ONCE como fandom oficial.', 'https://twice.jype.com/'),
    ('seventeen', 'SEVENTEEN es un grupo surcoreano de PLEDIS Entertainment que debutó en 2015. Es reconocido por la participación de sus integrantes en música, coreografía y performance, y por su vínculo con CARAT.', 'https://www.pledis.co.kr/artist/detail/seventeen'),
    ('ive', 'IVE es un grupo surcoreano que debutó en 2021 bajo Starship Entertainment. Su identidad combina pop, presencia escénica y una propuesta visual elegante; su fandom es DIVE.', 'https://www.starship-ent.com/profile/musician/ive.php'),
    ('le sserafim', 'LE SSERAFIM es un grupo surcoreano de SOURCE MUSIC que debutó en 2022. Su propuesta se apoya en pop, performance y una narrativa de confianza y crecimiento.', 'https://www.sourcemusic.com/artist/LE-SSERAFIM'),
    ('nct', 'NCT es un proyecto de SM Entertainment compuesto por unidades con identidades y mercados diversos. Debutó en 2016 y desarrolla pop, hip-hop, R&B y performance a través de una estructura expansible.', 'https://www.smentertainment.com/artist/nct/'),
    ('ateez', 'ATEEZ es un grupo surcoreano de KQ Entertainment que debutó en 2018. Su música combina performance intensa, narrativa de aventura y una conexión cercana con ATINY.', 'https://kqent.com/artist/ateez')
)
update public.kpop_entities as e
set
  bio = case
    when trim(coalesce(e.bio, '')) = '' then enrichment.bio
    else e.bio
  end,
  official_url = case
    when trim(coalesce(e.official_url, '')) = ''
      and enrichment.normalized_name in ('seventeen', 'jungkook', 'jimin', 'lisa', 'jennie', 'bang chan')
      and nullif(trim(coalesce(enrichment.official_url, '')), '') is not null
      then enrichment.official_url
    else e.official_url
  end,
  updated_at = now()
from enrichment
where e.normalized_name = enrichment.normalized_name
  and (
    trim(coalesce(e.bio, '')) = ''
    or (
      trim(coalesce(e.official_url, '')) = ''
      and enrichment.normalized_name in ('seventeen', 'jungkook', 'jimin', 'lisa', 'jennie', 'bang chan')
      and nullif(trim(coalesce(enrichment.official_url, '')), '') is not null
    )
  );

-- LOTE 4
with enrichment (normalized_name, bio, official_url) as (
  values
    ('iu', 'IU es una cantante, compositora y actriz surcoreana con una extensa carrera solista. Su repertorio abarca pop, baladas y composiciones de tono íntimo, con una fuerte presencia en Corea y otros mercados.', 'https://edam-ent.com/artist/IU'),
    ('taeyeon', 'TAEYEON es una cantante surcoreana, integrante de Girls’ Generation y solista de SM Entertainment. Su trabajo se distingue por el control vocal y un repertorio que recorre pop, balada y R&B.', 'https://www.smentertainment.com/artist/taeyeon/'),
    ('taeyang', 'TAEYANG es un cantante surcoreano conocido por su carrera solista y como integrante de BIGBANG. Su música combina R&B, soul y pop con una identidad vocal propia.', 'https://ygfamily.com/en/artists/bigbang/profile'),
    ('g-dragon', 'G-DRAGON es un rapero, cantante, compositor y productor surcoreano conocido por su trabajo solista y por BIGBANG. Su carrera se caracteriza por experimentar con hip-hop, pop, moda y producción musical.', 'https://www.galaxycorp.co.kr/artist/gdragon'),
    ('zico', 'ZICO es un rapero, productor y compositor surcoreano con carrera solista y experiencia como líder de Block B. Su trabajo cruza hip-hop, pop y producción para otros artistas.', 'https://kozofficial.com/artist/zico'),
    ('psy', 'PSY es un cantante y productor surcoreano reconocido por una carrera que combina pop, hip-hop, humor y performance. Su música alcanzó una audiencia global y amplió la visibilidad internacional del K-pop.', 'https://www.psystudio.com/'),
    ('sunmi', 'SUNMI es una cantante y compositora surcoreana con carrera solista después de su etapa en Wonder Girls. Su propuesta combina pop, synth-pop y una identidad visual cuidadosamente construida.', 'https://www.abysscompany.com/artist/sunmi'),
    ('chung ha', 'CHUNG HA es una cantante y bailarina surcoreana con una carrera solista centrada en pop y performance. Es reconocida por su precisión escénica y por explorar distintos registros dentro de la música electrónica y dance.', 'https://morevision.kr/artists/chung-ha'),
    ('ailee', 'Ailee es una cantante y compositora coreano-estadounidense conocida por su potencia vocal y por un repertorio que recorre pop, R&B y baladas. También es reconocida por sus interpretaciones en bandas sonoras y escenarios en vivo.', 'https://rocket3ent.com/artist/ailee'),
    ('bibi', 'BIBI es una cantante, compositora y actriz surcoreana cuya música combina R&B, hip-hop y pop alternativo. Su identidad artística se apoya en narrativas directas y una interpretación vocal expresiva.', 'https://feelghoodmusic.com/'),
    ('heize', 'Heize es una cantante y compositora surcoreana conocida por integrar R&B, hip-hop y baladas en canciones de tono conversacional. Su trabajo también incluye colaboraciones y bandas sonoras.', 'https://pnation.com/artists/heize'),
    ('kang daniel', 'Kang Daniel es un cantante, bailarín y solista surcoreano. Su carrera incluye pop, R&B y performance, con una identidad propia desarrollada después de sus actividades grupales iniciales.', 'https://konnect-ent.com/'),
    ('lee hi', 'LEE HI es una cantante surcoreana reconocida por su voz grave y una discografía que recorre soul, R&B, pop y baladas. Su carrera incluye trabajos con distintas agencias y productores destacados.', 'https://www.aomgofficial.com/'),
    ('dean', 'DEAN es un cantante, compositor y productor surcoreano asociado al R&B alternativo y al hip-hop. Su catálogo se caracteriza por una producción minimalista y colaboraciones internacionales.', 'https://www.universal-music.co.jp/dean/'),
    ('baekhyun', 'BAEKHYUN es un cantante surcoreano conocido por su trabajo como integrante de EXO y por una carrera solista enfocada en pop y R&B. Su fortaleza principal es la interpretación vocal y la versatilidad escénica.', 'https://www.inb100.com/'),
    ('taemin', 'TAEMIN es un cantante y bailarín surcoreano conocido como integrante de SHINee y por su carrera solista. Su propuesta combina pop, electrónica, performance y una identidad visual muy definida.', 'https://www.smentertainment.com/artist/taemin/'),
    ('key', 'KEY es un cantante, bailarín, actor y presentador surcoreano conocido como integrante de SHINee y por su trabajo solista. Su perfil artístico combina música, performance, moda y entretenimiento.', 'https://www.smentertainment.com/artist/key/'),
    ('hwasa', 'HWASA es una cantante surcoreana conocida por su trabajo en MAMAMOO y por su carrera solista. Su identidad combina R&B, pop y performance con una presencia escénica distintiva.', 'https://www.rbbridge.com/?page_id=17131'),
    ('kai', 'KAI es un cantante y bailarín surcoreano conocido como integrante de EXO y por su carrera solista. Su propuesta destaca por la performance, la danza y una línea musical de pop y R&B.', 'https://www.smentertainment.com/artist/kai/'),
    ('woodz', 'WOODZ es un cantante, compositor y productor surcoreano con una carrera que atraviesa pop, rock, R&B y hip-hop. Su trabajo se caracteriza por la participación creativa y el cambio de registros musicales.', 'https://edam-ent.com/artist/WOODZ'),
    ('yerin baek', 'Yerin Baek es una cantante y compositora surcoreana conocida por su trabajo solista en pop, indie y R&B. Su música suele priorizar la expresión vocal, la atmósfera y la composición personal.', 'https://bluevinyl.kr/'),
    ('jungkook', 'Jungkook es un cantante y bailarín surcoreano conocido como integrante de BTS y por su carrera solista. Su trabajo combina pop, R&B y performance con alcance internacional.', 'https://bts.ibighit.com/eng/profile/'),
    ('jimin', 'Jimin es un cantante y bailarín surcoreano conocido como integrante de BTS y por su carrera solista. Su propuesta destaca por la expresividad vocal, la danza y una identidad escénica propia.', 'https://bts.ibighit.com/eng/profile/'),
    ('lisa', 'Lisa es una cantante, rapera y bailarina tailandesa conocida como integrante de BLACKPINK y por su carrera solista. Su perfil combina hip-hop, pop, danza y una presencia internacional destacada.', 'https://www.lloud.co/'),
    ('jennie', 'Jennie es una cantante, rapera y compositora surcoreana conocida como integrante de BLACKPINK y por su carrera solista. Su trabajo combina pop, hip-hop, performance e identidad visual.', 'https://www.jenn.ie/'),
    ('bang chan', 'Bang Chan es un cantante, productor y líder de Stray Kids. Su trabajo se vincula con la producción musical del grupo, especialmente con 3RACHA, además de sus actividades como intérprete.', 'https://straykids.jype.com/profile')
)
update public.kpop_entities as e
set
  bio = case
    when trim(coalesce(e.bio, '')) = '' then enrichment.bio
    else e.bio
  end,
  official_url = case
    when trim(coalesce(e.official_url, '')) = ''
      and enrichment.normalized_name in ('seventeen', 'jungkook', 'jimin', 'lisa', 'jennie', 'bang chan')
      and nullif(trim(coalesce(enrichment.official_url, '')), '') is not null
      then enrichment.official_url
    else e.official_url
  end,
  updated_at = now()
from enrichment
where e.normalized_name = enrichment.normalized_name
  and (
    trim(coalesce(e.bio, '')) = ''
    or (
      trim(coalesce(e.official_url, '')) = ''
      and enrichment.normalized_name in ('seventeen', 'jungkook', 'jimin', 'lisa', 'jennie', 'bang chan')
      and nullif(trim(coalesce(enrichment.official_url, '')), '') is not null
    )
  );

-- No se usan fandom_name, debut_year, discography, members, country ni agency.

-- PARCHE LOTE 3 BIOS BÁSICAS
with enrichment (normalized_name, bio) as (
  values
    ('ateez', 'ATEEZ es un grupo surcoreano de KQ Entertainment que debutó en 2018. Su propuesta combina performance intensa, narrativa conceptual y sonidos que recorren pop, hip-hop y electrónica. El grupo mantiene una fuerte actividad internacional y una relación cercana con su fandom, ATINY.'),
    ('ive', 'IVE es un grupo surcoreano de Starship Entertainment que debutó en 2021 con ELEVEN. Su discografía combina pop, melodías directas y una identidad escénica elegante. El grupo ha mantenido una actividad constante con nuevos álbumes y promociones en Corea y otros mercados.'),
    ('le sserafim', 'LE SSERAFIM es un grupo de SOURCE MUSIC que debutó en 2022 y está formado por Sakura, Kim Chaewon, Huh Yunjin, Kazuha y Hong Eunchae. Su identidad artística se centra en performance, pop contemporáneo y una narrativa ligada a confianza, crecimiento y determinación.'),
    ('nct', 'NCT es un proyecto de SM Entertainment que debutó en 2016 y reúne distintas unidades con identidades musicales propias. Bajo la marca NCT conviven unidades como NCT 127, NCT DREAM, WayV, NCT WISH y NCT U, con propuestas que abarcan pop, hip-hop, R&B y performance.'),
    ('newjeans', 'NewJeans es un grupo surcoreano que debutó en 2022. Su propuesta se caracteriza por una mezcla de pop, R&B y referencias a sonidos de finales de los años 1990 y comienzos de los 2000, junto con una identidad visual digital y minimalista. El grupo alcanzó rápidamente una amplia audiencia internacional.'),
    ('seventeen', 'SEVENTEEN es un grupo surcoreano de PLEDIS Entertainment que debutó en 2015. Es reconocido por la participación de sus integrantes en composición, producción, coreografía y performance, con una estructura de unidades vocal, hip-hop y performance. Su fandom oficial se llama CARAT y el grupo mantiene actividad internacional y giras.'),
    ('twice', 'TWICE es un grupo surcoreano de JYP Entertainment que debutó en 2015. Está formado por Nayeon, Jeongyeon, Momo, Sana, Jihyo, Mina, Dahyun, Chaeyoung y Tzuyu. Su trayectoria combina pop, dance y una amplia actividad internacional, con ONCE como fandom oficial.')
)
update public.kpop_entities as e
set
  bio = enrichment.bio,
  updated_at = now()
from enrichment
where e.normalized_name = enrichment.normalized_name
  and e.bio is distinct from enrichment.bio;
