# FLEX

AI diligence workspace with document storage, research, and reports. Built with Next.js, TypeScript, Supabase, Gemini, and Perplexity.

Requires Node.js 22+.

```sh
npm ci
npm run dev
```

Open http://localhost:3001. Local workspaces need no API keys.

For live AI/auth, configure `.env.local` using `.env.example`, run `supabase/schema.sql`, and allow `/api/auth/callback` in Supabase Auth.

Tests: `npm test` · Production build: `npm run build`
