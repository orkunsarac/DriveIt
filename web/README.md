# DriveIt web

Vite + React + TypeScript application. Run `npm install`, then `npm run dev` or `npm run build` in this directory. Configure SPA history fallback to `index.html` on any future host. No deployment is configured.

Copy `.env.example` to `.env.local` for local configuration. Only use a Supabase public publishable/anon key: never a secret or service role key. Auth defaults off. Password recovery additionally requires an explicitly enabled flag and an approved redirect URL registered with Supabase; SMTP and domain settings are managed outside this app and are not changed here. Signup is intentionally unavailable. Account deletion uses the existing support email flow; the Edge Function is not exposed here until browser CORS, secure receipt recovery, legal approval, and deployment are separately accepted. Legal texts under `site/` remain drafts and are not published by this app.

Vite variables are public build-time values. Do not place secrets in them. Never point a local test at production without appropriate authorization.
