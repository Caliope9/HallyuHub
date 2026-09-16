-- HallyuHub K-pop catalog v1 - REVIEW ONLY
--
-- NO ejecutar automáticamente.
-- Este archivo propone entidades que no aparecen en el catálogo local actual
-- (23 grupos + 159 idols). No crea miembros, no actualiza perfiles existentes
-- y no carga imágenes ni datos no verificados.
--
-- Esquema revisado: public.kpop_entities soporta entity_type =
-- 'group' | 'idol' | 'artist'. Los solistas usan 'artist'.
-- La unicidad se basa en normalized_name.
-- Fuentes de validación web consultadas:
-- HYBE: https://hybecorp.com/eng/company/artist
-- JYP: https://m.jype.com/ y https://www.jype.com/es/JYP/History
-- SMTOWN: https://faq.smtown.com/16dc8519-88b9-8187-b760-c4a72761a32a
-- YG: https://ygfamily.com/contents/attachments/2025/08/YG%2BEntertainment%2B2025%2BSustainability%2BReport%2B%28ENG%29.pdf
-- Starship: https://www.starship-ent.com/musician
-- RBW: https://www.rbbridge.com/?page_id=17131
-- High Up: https://www.highup-ent.com/en/stayc/
--
-- La sentencia propuesta solo inserta nombre, nombre normalizado y tipo.
-- ON CONFLICT DO NOTHING evita duplicados y no sobrescribe perfiles existentes.

insert into public.kpop_entities (
  name,
  normalized_name,
  entity_type
)
values
  -- Grupos masculinos y mixtos
  ('EXO', 'exo', 'group'),
  ('SHINee', 'shinee', 'group'),
  ('NCT 127', 'nct 127', 'group'),
  ('NCT DREAM', 'nct dream', 'group'),
  ('GOT7', 'got7', 'group'),
  ('MONSTA X', 'monsta x', 'group'),
  ('THE BOYZ', 'the boyz', 'group'),
  ('ASTRO', 'astro', 'group'),
  ('P1Harmony', 'p1harmony', 'group'),
  ('ONEUS', 'oneus', 'group'),
  ('DAY6', 'day6', 'group'),
  ('Xdinary Heroes', 'xdinary heroes', 'group'),
  ('NEXZ', 'nexz', 'group'),
  ('KickFlip', 'kickflip', 'group'),
  ('NCT WISH', 'nct wish', 'group'),
  ('WayV', 'wayv', 'group'),
  -- Grupos femeninos
  ('Red Velvet', 'red velvet', 'group'),
  ('ILLIT', 'illit', 'group'),
  ('KISS OF LIFE', 'kiss of life', 'group'),
  ('MEOVV', 'meovv', 'group'),
  ('Hearts2Hearts', 'hearts2hearts', 'group'),
  ('MAMAMOO+', 'mamamoo+', 'group'),
  ('Dreamcatcher', 'dreamcatcher', 'group'),
  ('STAYC', 'stayc', 'group'),
  ('tripleS', 'triples', 'group'),
  ('Kep1er', 'kep1er', 'group'),
  ('EVERGLOW', 'everglow', 'group'),
  ('fromis_9', 'fromis_9', 'group'),
  ('PURPLE KISS', 'purple kiss', 'group'),
  ('WJSN', 'wjsn', 'group'),
  -- Solistas / artistas individuales
  ('IU', 'iu', 'artist'),
  ('TAEYEON', 'taeyeon', 'artist'),
  ('TAEYANG', 'taeyang', 'artist'),
  ('G-DRAGON', 'g-dragon', 'artist'),
  ('ZICO', 'zico', 'artist'),
  ('PSY', 'psy', 'artist'),
  ('SUNMI', 'sunmi', 'artist'),
  ('CHUNG HA', 'chung ha', 'artist'),
  ('Ailee', 'ailee', 'artist'),
  ('BIBI', 'bibi', 'artist'),
  ('Heize', 'heize', 'artist'),
  ('Kang Daniel', 'kang daniel', 'artist'),
  ('LEE HI', 'lee hi', 'artist'),
  ('DEAN', 'dean', 'artist'),
  ('BAEKHYUN', 'baekhyun', 'artist'),
  ('TAEMIN', 'taemin', 'artist'),
  ('KEY', 'key', 'artist'),
  ('HWASA', 'hwasa', 'artist'),
  ('KAI', 'kai', 'artist'),
  ('WOODZ', 'woodz', 'artist'),
  ('Yerin Baek', 'yerin baek', 'artist')
on conflict (normalized_name) do nothing;

-- Revisión externa sugerida antes de autorizar:
-- 1. Comparar estas filas con el estado actual de public.kpop_entities.
-- 2. Confirmar país/agencia y completar solo columnas verificadas si se desea.
-- 3. Agregar image_url únicamente con una URL cuya licencia/uso esté aprobado.
-- 4. Verificar que los valores normalizados coincidan con la función de
--    normalización vigente antes de ejecutar.
