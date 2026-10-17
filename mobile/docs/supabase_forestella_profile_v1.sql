-- Curated Forestella profile; sources: docs/forestella_profile_sources_2026.md.
-- Idempotent. Does not touch follows or unrelated groups.
begin;

update public.kpop_entities
set discography = '["Evolution (2018)", "Mystique (2019)", "The Forestella (2021)", "The Beginning: World Tree (2022)", "THE LEGACY (2026)"]'::jsonb,
    editorial_source_url = 'https://www.universal-music.co.jp/forestella/biography/',
    updated_at = now()
where id = '58f1ceed-89d3-4930-9ec0-738f1bc150ae'
  and entity_type = 'group';

insert into public.kpop_entities (
  entity_type, name, normalized_name, bio, is_verified, status,
  image_url, image_source, image_license, attribution
) values
  ('idol', 'Bae Doo-hoon', 'bae doo-hoon', '', false, 'community',
   'https://upload.wikimedia.org/wikipedia/commons/9/94/Bae_Doohoon_SBS_Radio_2022.jpg',
   'https://commons.wikimedia.org/wiki/File:Bae_Doohoon_SBS_Radio_2022.jpg',
   'CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/',
   'SBS Radio Official YouTube / Wikimedia Commons (2022). Visualización con recorte automático.'),
  ('idol', 'Kang Hyung-ho', 'kang hyung-ho', '', false, 'community',
   'https://upload.wikimedia.org/wikipedia/commons/f/f5/Kang_Hyeongho_SBS_Radio_2022.jpg',
   'https://commons.wikimedia.org/wiki/File:Kang_Hyeongho_SBS_Radio_2022.jpg',
   'CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/',
   'SBS Radio Official YouTube / Wikimedia Commons (2022). Visualización con recorte automático.'),
  ('idol', 'Cho Min-kyu', 'cho min-kyu', '', false, 'community',
   'https://commons.wikimedia.org/wiki/Special:FilePath/Jo_Mingyu_2019_2.jpg',
   'https://commons.wikimedia.org/wiki/File:Jo_Mingyu_2019_2.jpg',
   'CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/',
   '무하wooriming_mucha / Wikimedia Commons (2019). Visualización con recorte automático.'),
  ('idol', 'Ko Woo-rim', 'ko woo-rim', '', false, 'community',
   'https://upload.wikimedia.org/wikipedia/commons/2/29/Go_Woorim_2022.jpg',
   'https://commons.wikimedia.org/wiki/File:Go_Woorim_2022.jpg',
   'CC BY-SA 4.0 — https://creativecommons.org/licenses/by-sa/4.0/',
   'Suhaengpyeongga / Wikimedia Commons (2022). Visualización con recorte automático.')
on conflict (normalized_name) do nothing;

update public.kpop_entities
set bio = v.bio,
    editorial_source_url = 'https://www.universal-music.co.jp/forestella/biography/',
    updated_at = now()
from (values
  ('bae doo-hoon',
   'Bae Doo-hoon es cantante y actor de teatro musical surcoreano, integrante del cuarteto vocal Forestella.'),
  ('kang hyung-ho',
   'Kang Hyung-ho es cantante surcoreano e integrante de Forestella. Antes de dedicarse profesionalmente a la música trabajó en ingeniería química y participó en PITTA.'),
  ('cho min-kyu',
   'Cho Min-kyu es tenor clásico y líder del cuarteto vocal surcoreano Forestella.'),
  ('ko woo-rim',
   'Ko Woo-rim es bajo clásico e integrante del cuarteto vocal surcoreano Forestella.')
) as v(normalized_name, bio)
where public.kpop_entities.normalized_name = v.normalized_name
  and public.kpop_entities.entity_type = 'idol'
  and public.kpop_entities.bio = '';

update public.kpop_entities
set image_url = v.image_url,
    image_source = v.image_source,
    image_license = 'CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/',
    attribution = 'SBS Radio Official YouTube / Wikimedia Commons (2022). Visualización con recorte automático.',
    updated_at = now()
from (values
  ('bae doo-hoon',
   'https://upload.wikimedia.org/wikipedia/commons/9/94/Bae_Doohoon_SBS_Radio_2022.jpg',
   'https://commons.wikimedia.org/wiki/File:Bae_Doohoon_SBS_Radio_2022.jpg'),
  ('kang hyung-ho',
   'https://upload.wikimedia.org/wikipedia/commons/f/f5/Kang_Hyeongho_SBS_Radio_2022.jpg',
   'https://commons.wikimedia.org/wiki/File:Kang_Hyeongho_SBS_Radio_2022.jpg')
) as v(normalized_name, image_url, image_source)
where public.kpop_entities.normalized_name = v.normalized_name
  and public.kpop_entities.entity_type = 'idol'
  and public.kpop_entities.image_url = '';

insert into public.kpop_entity_members (
  group_id, member_id, position, stage_name, is_active
)
select '58f1ceed-89d3-4930-9ec0-738f1bc150ae'::uuid,
       e.id, m.position, m.stage_name, true
from (values
  ('bae doo-hoon', 0, 'Bae Doo-hoon'),
  ('kang hyung-ho', 1, 'PITTA (Kang Hyung-ho)'),
  ('cho min-kyu', 2, 'Cho Min-kyu'),
  ('ko woo-rim', 3, 'Ko Woo-rim')
) as m(normalized_name, position, stage_name)
join public.kpop_entities e
  on e.normalized_name = m.normalized_name and e.entity_type = 'idol'
on conflict (group_id, member_id) do nothing;

do $$
begin
  if (
    select count(*) from public.kpop_entity_members
    where group_id = '58f1ceed-89d3-4930-9ec0-738f1bc150ae'
      and is_active
  ) <> 4 then
    raise exception 'Forestella must have exactly four active members';
  end if;
end;
$$;

commit;
