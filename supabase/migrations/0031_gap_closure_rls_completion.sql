-- 0031_gap_closure_rls_completion.sql
do $$
declare r record;
begin
 for r in select * from (values
 ('catalog','attributes'),('catalog','product_badges'),('catalog','product_relations'),('catalog','product_type_attributes'),('catalog','search_synonyms'),('catalog','seo_metadata'),
 ('cms','blog_posts'),('cms','homepage_blocks'),('cms','pages'),
 ('commerce','coupon_redemptions'),('commerce','offer_redemptions'),
 ('communication','message_logs'),('communication','message_templates'),
 ('finance','cost_entries'),('finance','documents'),('finance','product_costs'),
 ('growth','preorders'),('growth','subscriptions'),
 ('logistics','delivery_promises'),('logistics','shipping_areas'),('logistics','shipping_rule_methods'),
 ('marketing','ad_sets'),('marketing','creatives'),('marketing','landing_pages'),
 ('platform','automation_runs'),('platform','automations'),('platform','business_rules'),('platform','integrations'),('platform','risk_events')
 ) x(s,t) loop
   execute format('alter table %I.%I enable row level security',r.s,r.t);
   execute format('drop policy if exists "staff manage gap closure" on %I.%I',r.s,r.t);
   execute format('create policy "staff manage gap closure" on %I.%I for all to authenticated using(platform.has_permission((select auth.uid()),''orders.manage'')) with check(platform.has_permission((select auth.uid()),''orders.manage''))',r.s,r.t);
 end loop;
end $$;
drop policy if exists "catalog attributes read" on catalog.attributes; create policy "catalog attributes read" on catalog.attributes for select to anon,authenticated using(true);
drop policy if exists "catalog badges read" on catalog.product_badges; create policy "catalog badges read" on catalog.product_badges for select to anon,authenticated using(status='active');
drop policy if exists "catalog relations read" on catalog.product_relations; create policy "catalog relations read" on catalog.product_relations for select to anon,authenticated using(true);
drop policy if exists "catalog type attrs read" on catalog.product_type_attributes; create policy "catalog type attrs read" on catalog.product_type_attributes for select to anon,authenticated using(true);
drop policy if exists "catalog synonyms read" on catalog.search_synonyms; create policy "catalog synonyms read" on catalog.search_synonyms for select to anon,authenticated using(status='active');
drop policy if exists "catalog seo read" on catalog.seo_metadata; create policy "catalog seo read" on catalog.seo_metadata for select to anon,authenticated using(true);
drop policy if exists "growth preorder owner read" on growth.preorders; create policy "growth preorder owner read" on growth.preorders for select to authenticated using(customer_id=(select c.id from customer.customers c where c.auth_user_id=(select auth.uid()) limit 1) or platform.has_permission((select auth.uid()),'orders.manage'));
drop policy if exists "growth preorder owner create" on growth.preorders; create policy "growth preorder owner create" on growth.preorders for insert to authenticated with check(customer_id=(select c.id from customer.customers c where c.auth_user_id=(select auth.uid()) limit 1));
drop policy if exists "growth subscription owner read" on growth.subscriptions; create policy "growth subscription owner read" on growth.subscriptions for select to authenticated using(customer_id=(select c.id from customer.customers c where c.auth_user_id=(select auth.uid()) limit 1) or platform.has_permission((select auth.uid()),'orders.manage'));
drop policy if exists "growth subscription owner create" on growth.subscriptions; create policy "growth subscription owner create" on growth.subscriptions for insert to authenticated with check(customer_id=(select c.id from customer.customers c where c.auth_user_id=(select auth.uid()) limit 1));