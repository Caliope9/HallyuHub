-- HallyuHub Beta Real - Ocultar noticias no relacionadas con K-pop
-- Revision: 2026-07-14
--
-- Este archivo NO borra filas. Solo despublica las 7 noticias detectadas en la
-- primera importacion y conserva cada registro para diagnostico editorial.

begin;

update public.news_items
set
  is_published = false,
  auto_published = false,
  rejection_reason = 'non_kpop',
  updated_at = now()
where canonical_url in (
  'https://www.billboard.com/pro/iron-maiden-sells-half-their-catalog-pophouse-entertainment/',
  'https://www.billboard.com/video/jay-z-yankee-stadium-shows-recap-beyonce-rihanna-nas/',
  'https://www.nme.com/news/music/liz-lawrence-announces-2026-uk-tour-buy-tickets-3956920',
  'https://www.nme.com/news/music/reading-leeds-announces-biggest-staging-and-arena-overhaul-ever-for-2026-3955680',
  'https://www.nme.com/news/music/reading-leeds-boss-talks-biggest-ever-arena-overhaul-and-strength-of-uk-and-irish-music-on-line-up-were-buzzing-with-ideas-for-the-future-3955730',
  'https://www.nme.com/news/music/the-rolling-stones-mick-jagger-explains-the-different-ways-he-was-competitive-with-david-bowie-and-john-lennon-3956938',
  'https://www.nme.com/news/music/nickelback-announce-new-album-everything-under-the-sun-with-explosive-rattle-the-cage-3956981'
)
or article_url in (
  'https://www.billboard.com/pro/iron-maiden-sells-half-their-catalog-pophouse-entertainment/',
  'https://www.billboard.com/video/jay-z-yankee-stadium-shows-recap-beyonce-rihanna-nas/',
  'https://www.nme.com/news/music/liz-lawrence-announces-2026-uk-tour-buy-tickets-3956920',
  'https://www.nme.com/news/music/reading-leeds-announces-biggest-staging-and-arena-overhaul-ever-for-2026-3955680',
  'https://www.nme.com/news/music/reading-leeds-boss-talks-biggest-ever-arena-overhaul-and-strength-of-uk-and-irish-music-on-line-up-were-buzzing-with-ideas-for-the-future-3955730',
  'https://www.nme.com/news/music/the-rolling-stones-mick-jagger-explains-the-different-ways-he-was-competitive-with-david-bowie-and-john-lennon-3956938',
  'https://www.nme.com/news/music/nickelback-announce-new-album-everything-under-the-sun-with-explosive-rattle-the-cage-3956981'
);

-- Resultado esperado: 7 filas, todas ocultas y conservadas.
select
  id,
  source_name,
  title,
  is_published,
  auto_published,
  rejection_reason,
  canonical_url
from public.news_items
where rejection_reason = 'non_kpop'
order by source_name, published_at desc;

commit;
