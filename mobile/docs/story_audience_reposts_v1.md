# Story audience and reposts v1

This change prepares the Flutter client and a review-only Supabase migration
for per-story audiences and relational reposts. The migration has **not** been
executed and no production behavior should be enabled until it is reviewed and
applied.

## Current implementation

- `StoryDraft` and `Story` carry `StoryAudienceType`, selected audience IDs,
  and an optional shared content reference.
- `StoryEditorScreen` exposes “Quién puede ver esta historia”. The default is
  the account's existing Story Privacy value; private and 16–17 profiles cannot
  select `Todos` in the client. Backend policy remains authoritative.
- Supabase story publishing sends `audience_type` and stores explicit audience
  members only after the migration exists. A failed remote write is surfaced as
  an error; it is not silently published with weaker privacy.
- `RepostService` exposes idempotent create/remove operations. The Supabase
  implementation calls protected RPCs and never copies original media.
- `HallyuPostCard` supports an optional `onRepost` action so feed owners can
  wire the same secured service without duplicating card logic.

## Migration contents

`supabase_story_audience_reposts_v1_review.sql` adds the audience columns and
tables, RLS visibility checks, close-friends ownership rules, relational
reposts, and backend RPCs. It also supports story references to a post, Drop,
or Fancam. Original visibility and bilateral blocks are checked server-side.

## Important deployment gate

The current Flutter code intentionally expects the new columns/tables/RPCs.
Apply and validate the migration in a controlled Supabase review window before
shipping a client that publishes advanced audiences or reposts. Do not run the
SQL from Flutter or from this repository automatically.
