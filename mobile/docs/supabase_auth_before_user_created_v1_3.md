# Before User Created v1.3

La función `public.hallyu_before_user_created_v1_3(jsonb)` queda preparada en
la migración v1.3, pero no activada. Debe configurarse manualmente en Supabase
Authentication > Hooks como **Before User Created** después de probar en staging.

Lee únicamente `user.user_metadata.birth_date`, rechaza ausente, inválida,
futura o menor de 16 años, y permite exactamente 16. Devuelve el evento sin
guardar datos adicionales. Solo `supabase_auth_admin` tiene EXECUTE; `public`,
`anon` y `authenticated` quedan revocados. El trigger de `profiles` permanece
como segunda defensa.
