# HallyuHub Supabase setup

1. Create a Supabase project.
2. Open the Supabase SQL Editor and run `supabase-schema.sql`.
3. Open `supabase-config.js`.
4. Paste your project URL and anon public key:

```js
window.HALLYUHUB_SUPABASE_CONFIG = {
  url: "https://YOUR_PROJECT.supabase.co",
  anonKey: "YOUR_ANON_PUBLIC_KEY",
};
```

5. Deploy the folder to Vercel.

The app uses Supabase Auth for login/session persistence, Postgres tables for profiles/posts/follows/likes/comments/messages/trends, and Supabase Storage for uploaded photos and videos.

If the config is empty, HallyuHub keeps working in local demo mode.
