-- Keep Production PostgREST schema exposure aligned with the live Supabase configuration.
-- These are the application schemas used by the authenticated admin dashboard.
ALTER ROLE authenticator SET pgrst.db_schemas = 'public, graphql_public, catalog, inventory, logistics';
NOTIFY pgrst, 'reload config';
