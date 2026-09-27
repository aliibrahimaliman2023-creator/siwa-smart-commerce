# SIWA SMART COMMERCE

Implementation baseline for a modular, AI-ready commerce and operations platform built around Supabase + Cloudflare + GitHub.

## Principles
- Free-first / open-source-first
- Server-authoritative commerce logic
- PostgreSQL transactions and row locking for inventory-sensitive operations
- RLS + permissions + auditability
- Provider adapters to avoid lock-in
- No silent business decisions

See `MASTER_INDEX.md` and `docs/52_MASTER_EXECUTION_ORDER.md`.

## Runtime MVP
The repository contains runnable Vite Storefront/Admin shells and an authenticated Supabase checkout RPC.

Before production: configure Supabase, apply migrations, seed data, define OPEN business decisions, connect provider adapters, and run the full CI/E2E suite in a network-enabled environment.
