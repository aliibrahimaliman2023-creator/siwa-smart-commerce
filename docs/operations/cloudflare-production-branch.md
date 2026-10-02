# Cloudflare Production Branch

- Worker: `siwa-smart-commerce`
- Production branch: `feature/core-commerce-storefront`
- Repository: `aliibrahimaliman2023-creator/siwa-smart-commerce`
- Root directory: `apps/storefront`
- Build command: `npm run build`
- Deploy command: `npx wrangler deploy`
- Preview command: `npx wrangler preview`
- Wrangler is pinned in `apps/storefront/package.json` to keep preview and production builds reproducible.

Cloudflare Workers Builds deploys commits pushed to the configured production branch. A successful production build creates a new Worker version and, when the deploy command is configured, promotes it to the active deployment.

This file exists as an operational marker so production-branch changes are explicit in repository history.

## Final synchronization marker

The production branch is intentionally receiving a real commit after the branch mapping was corrected, so the connected Workers Build integration gets a normal push event and can execute the configured production build/deploy pipeline.