# Schlift — website

The React + Vite site: the landing page (`/`), the routine library
(`/routines`), the signed-in dashboard (`/dashboard`) and its demo (`/demo`),
the admin page (`/admin`), and the privacy and delete-account pages the stores
link to.

`npm run dev` and `npm run build` first run `scripts/sync-content.mjs`, which
copies the store listing, the template library, the latest release notes and
the screenshots out of the repo, so the site says what the store says.

See [`docs/makefile.md`](../docs/makefile.md) for running it against a local
backend and [`docs/linting.md`](../docs/linting.md) for its checks.
