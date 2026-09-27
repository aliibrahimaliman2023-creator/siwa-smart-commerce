-- 0014_rls_and_search_path_hardening.sql
-- Closes RLS policy gaps and pins function search paths.

create or replace function platform.touch_updated_at()
returns trigger language plpgsql set search_path=platform,public
as $$ begin new.updated_at=now(); return new; end; $$;

create or replace function commerce.resolve_active_price(p_variant uuid,p_currency text)
returns table(price_id uuid, amount numeric, currency text)
language sql stable set search_path=commerce,catalog,public
as $$
select id,amount,currency from catalog.prices
where product_variant_id=p_variant and currency=p_currency and is_active
and valid_from<=now() and (valid_to is null or valid_to>now())
order by priority desc,valid_from desc,created_at desc limit 1;
$$;

create policy addresses_self on customer.addresses for all to authenticated
using (customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid()) or platform.has_permission(auth.uid(),'customers.manage'))
with check (customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid()) or platform.has_permission(auth.uid(),'customers.manage'));

create policy product_categories_public_read on catalog.product_categories for select to anon,authenticated using (
 exists(select 1 from catalog.products p where p.id=product_id and p.status='active')
 and exists(select 1 from catalog.categories c where c.id=category_id and c.is_active));

create policy product_media_public_read on catalog.product_media for select to anon,authenticated using (exists(select 1 from catalog.products p where p.id=product_id and p.status='active'));
create policy product_stories_public_read on catalog.product_stories for select to anon,authenticated using (exists(select 1 from catalog.products p where p.id=product_id and p.status='active'));
create policy product_education_public_read on catalog.product_education for select to anon,authenticated using (exists(select 1 from catalog.products p where p.id=product_id and p.status='active'));
create policy bundles_public_read on catalog.bundles for select to anon,authenticated using (status='active');
create policy bundle_items_public_read on catalog.bundle_items for select to anon,authenticated using (exists(select 1 from catalog.bundles b where b.id=bundle_id and b.status='active'));

create policy order_addresses_owner_or_staff on commerce.order_addresses for select to authenticated using (
 exists(select 1 from commerce.orders o where o.id=order_id and (o.customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid()) or platform.has_permission(auth.uid(),'orders.read'))));
create policy order_status_history_owner_or_staff on commerce.order_status_history for select to authenticated using (
 exists(select 1 from commerce.orders o where o.id=order_id and (o.customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid()) or platform.has_permission(auth.uid(),'orders.read'))));

create policy point_accounts_self on customer.point_accounts for select to authenticated using (
 customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid()) or platform.has_permission(auth.uid(),'loyalty.read'));
create policy point_transactions_self on customer.point_transactions for select to authenticated using (
 exists(select 1 from customer.point_accounts pa where pa.id=point_account_id and (pa.customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid()) or platform.has_permission(auth.uid(),'loyalty.read'))));

create policy finance_transactions_staff on finance.financial_transactions for select to authenticated using (platform.has_permission(auth.uid(),'finance.read'));
create policy finance_settlements_staff on finance.settlements for select to authenticated using (platform.has_permission(auth.uid(),'finance.read'));
create policy finance_reconciliations_staff on finance.reconciliations for select to authenticated using (platform.has_permission(auth.uid(),'finance.read'));

create policy attribution_events_insert on marketing.attribution_events for insert to anon,authenticated with check (true);
create policy attribution_events_staff_read on marketing.attribution_events for select to authenticated using (platform.has_permission(auth.uid(),'marketing.read'));
create policy experiments_staff_read on marketing.experiments for select to authenticated using (platform.has_permission(auth.uid(),'marketing.read'));
create policy experiment_variants_staff_read on marketing.experiment_variants for select to authenticated using (platform.has_permission(auth.uid(),'marketing.read'));
