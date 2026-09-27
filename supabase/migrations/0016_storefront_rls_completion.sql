-- 0016_storefront_rls_completion.sql
-- Idempotent completion of customer storefront/order-tracking read paths.

do $$ begin
 if not exists (select 1 from pg_policies where schemaname='catalog' and tablename='product_categories' and policyname='product_categories_public_read') then
  create policy product_categories_public_read on catalog.product_categories for select to anon, authenticated using (exists (select 1 from catalog.products p where p.id=product_id and p.status='active'));
 end if;
 if not exists (select 1 from pg_policies where schemaname='catalog' and tablename='product_media' and policyname='product_media_public_read') then
  create policy product_media_public_read on catalog.product_media for select to anon, authenticated using (exists (select 1 from catalog.products p where p.id=product_id and p.status='active'));
 end if;
 if not exists (select 1 from pg_policies where schemaname='catalog' and tablename='product_stories' and policyname='product_stories_public_read') then
  create policy product_stories_public_read on catalog.product_stories for select to anon, authenticated using (exists (select 1 from catalog.products p where p.id=product_id and p.status='active'));
 end if;
 if not exists (select 1 from pg_policies where schemaname='catalog' and tablename='product_education' and policyname='product_education_public_read') then
  create policy product_education_public_read on catalog.product_education for select to anon, authenticated using (exists (select 1 from catalog.products p where p.id=product_id and p.status='active'));
 end if;
 if not exists (select 1 from pg_policies where schemaname='customer' and tablename='addresses' and policyname='addresses_self') then
  create policy addresses_self on customer.addresses for all to authenticated using (customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid())) with check (customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid()));
 end if;
 if not exists (select 1 from pg_policies where schemaname='commerce' and tablename='order_status_history' and policyname='order_status_history_self') then
  create policy order_status_history_self on commerce.order_status_history for select to authenticated using (order_id in (select o.id from commerce.orders o where o.customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid())) or platform.has_permission(auth.uid(),'orders.read'));
 end if;
 if not exists (select 1 from pg_policies where schemaname='commerce' and tablename='order_addresses' and policyname='order_addresses_self') then
  create policy order_addresses_self on commerce.order_addresses for select to authenticated using (order_id in (select o.id from commerce.orders o where o.customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid())) or platform.has_permission(auth.uid(),'orders.read'));
 end if;
end $$;
create index if not exists idx_product_categories_category on catalog.product_categories(category_id,product_id);
create index if not exists idx_product_media_product on catalog.product_media(product_id,sort_order);
create index if not exists idx_order_status_history_order on commerce.order_status_history(order_id,created_at desc);