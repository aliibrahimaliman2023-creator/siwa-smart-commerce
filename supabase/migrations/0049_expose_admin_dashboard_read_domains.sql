-- Expose the authenticated admin dashboard's read domains through PostgREST.
-- RLS remains the row-level authorization boundary; only authenticated gets these schema/table grants.

ALTER ROLE authenticator SET pgrst.db_schemas =
  'public, graphql_public, catalog, inventory, logistics, commerce, production, analytics, customer, marketing, finance, ai, platform, communication, cms, identity';

NOTIFY pgrst, 'reload config';

GRANT USAGE ON SCHEMA
  commerce, production, analytics, customer, marketing, finance,
  ai, platform, communication, cms, identity
TO authenticated;

GRANT SELECT ON
  commerce.orders,
  production.items,
  production.orders,
  analytics.kpis_daily,
  customer.customers,
  marketing.campaigns,
  finance.payments,
  finance.settlements,
  finance.reconciliations,
  ai.recommendations,
  ai.action_requests,
  platform.integrations,
  platform.feature_flags,
  platform.platform_settings,
  communication.message_templates,
  cms.homepage_blocks,
  identity.user_profiles,
  identity.user_roles
TO authenticated;
