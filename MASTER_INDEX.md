# SIWA SMART COMMERCE — MASTER INDEX

Architecture and technical specification through implementation baseline.

Docs 01–13: architecture/database/API/security/business rules/events/automation/testing/deployment/runbooks/decisions/gaps/ERD.
Docs 14–22: build order, domain contracts, state machines, acceptance, errors, ownership, free-first, gap audit, release checklist.
Docs 23–39: growth, finance, AI, automation, Customer 360, executive, machine commerce, PWA, observability, performance, privacy, adapters, phases, system map, gap matrix, no-silent-decisions, handoff.
Docs 40–46: implementation status, local setup, checkout/provider contracts, release gate, final handoff, checkout execution.
Docs 47–53: server-side pricing, payment/shipping adapters, storefront/admin acceptance, final gap closure, execution order, final status.

## Latest hardening
- Migration 0008: provider-neutral payment intents.
- Migration 0009: customer signup/payment RLS.
- Migration 0010: checkout security hardening.
- Checkout reservation authorization hardened.
- Idempotency key reuse with a different request is rejected.
- Migration count: 10.

Core rule: free-first. Paid/external services are not core dependencies unless explicitly approved.
