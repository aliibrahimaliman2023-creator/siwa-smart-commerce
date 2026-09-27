-- 0016_storefront_rls_completion.sql
-- Completes read paths required by the customer storefront and order tracking.

create policy product_categories_public_read
on catalog.product_categories
for select to anon, authenticated
using (
  exists (
    select 1
    from catalog.products p
    where p.id = product_id and p.status = 'active'
  )
);

create policy product_media_public_read
on catalog.product_media
for select to anon, authenticated
using (
  exists (
    select 1
    from catalog.products p
    where p.id = product_id and p.status = 'active'
  )
);

create policy product_stories_public_read
on catalog.product_stories
for select to anon, authenticated
using (
  exists (
    select 1
    from catalog.products p
    where p.id = product_id and p.status = 'active'
  )
);

create policy product_education_public_read
on catalog.product_education
for select to anon, authenticated
using (
  exists (
    select 1
    from catalog.products p
    where p.id = product_id and p.status = 'active'
  )
);

create policy addresses_self
on customer.addresses
for all to authenticated
using (
  customer_id = (
    select c.id from customer.customers c
    where c.auth_user_id = auth.uid()
  )
)
with check (
  customer_id = (
    select c.id from customer.customers c
    where c.auth_user_id = auth.uid()
  )
);

create policy order_status_history_self
on commerce.order_status_history
for select to authenticated
using (
  order_id in (
    select o.id
    from commerce.orders o
    where o.customer_id = (
      select c.id from customer.customers c
      where c.auth_user_id = auth.uid()
    )
  )
  or platform.has_permission(auth.uid(),'orders.read')
);

create policy order_addresses_self
on commerce.order_addresses
for select to authenticated
using (
  order_id in (
    select o.id
    from commerce.orders o
    where o.customer_id = (
      select c.id from customer.customers c
      where c.auth_user_id = auth.uid()
    )
  )
  or platform.has_permission(auth.uid(),'orders.read')
);

create index if not exists idx_product_categories_category
on catalog.product_categories(category_id,product_id);

create index if not exists idx_product_media_product
on catalog.product_media(product_id,sort_order);

create index if not exists idx_order_status_history_order
on commerce.order_status_history(order_id,created_at desc);
