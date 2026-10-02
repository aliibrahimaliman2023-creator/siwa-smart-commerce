# Production Gate — 2026-10-02

## Purpose

This document is the production gate for SIWA SMART COMMERCE. It records what is verified in the repository/runtime and what still requires real operational configuration. It must not be treated as a substitute for a live end-to-end production test.

## Verified

- Main branch contains the hardened checkout and authenticated checkout-recovery runtime contracts.
- GitHub CI validates repository structure, migration sequence, typecheck, build, contract tests, and runtime contracts.
- Supabase Edge Functions `checkout`, `checkout-recovery`, and `api-v1` are active.
- `checkout` requires an authenticated request and a valid idempotency key.
- `commerce.checkout_atomic_v2` recalculates prices server-side and reserves inventory atomically.
- Core exposed tables inspected for this gate have RLS enabled.
- Cloudflare Worker preview builds use the repository-pinned Wrangler version.

## Production blockers requiring real business configuration

1. Shipping carrier(s).
2. Shipping areas.
3. Shipping methods.
4. Shipping rules and real delivery promises.
5. Payment provider and payment lifecycle/webhooks, or an explicit operational decision to launch with COD only.
6. Communication provider/templates for order and operational notifications.
7. Real staff accounts and role assignments.
8. Real catalog, prices, stock, product media and commercial policies.
9. Auth leaked-password protection must be enabled in Supabase Auth settings.
10. Full live E2E test from customer checkout through fulfillment, delivery and after-sales.

## Do not fake these values

No carrier, payment provider, shipping price, staff assignment, or commercial catalog value should be fabricated merely to make a readiness check pass. The production gate should remain blocked until real values are supplied.

## Final launch sequence

1. Configure real operational data.
2. Verify Auth/RLS/security settings.
3. Run migration and function deployment through CI/CD.
4. Verify Cloudflare production build on the configured production branch.
5. Execute live customer checkout with a real test account and real configured payment/shipping path.
6. Verify inventory reservation, order state, production/QC, fulfillment, shipment/tracking, delivery, review/loyalty and reorder flows.
7. Run failure-path tests: out-of-stock, price change, invalid coupon, duplicate checkout, payment failure, shipping unavailable, cancellation, return/refund, and unauthorized staff action.
8. Record final production evidence and only then declare the system operationally ready.
