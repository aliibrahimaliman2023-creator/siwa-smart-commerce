# Admin Production URL

The business console is built into the same Cloudflare Worker artifact as the storefront so it does not require a second Cloudflare project.

- Storefront: `/`
- Admin dashboard: `/admin/`
- Build source: `apps/admin`
- Production Worker: `siwa-smart-commerce`

The admin bundle is generated into `apps/storefront/dist/admin` during the storefront production build. Vite uses `/admin/` as the asset base so the dashboard can be opened directly at `/admin/` on the production Worker.

This document does not claim a deployment is active; the final URL is only considered live after the Cloudflare production build for the merged commit succeeds.
