-- Staff management permissions for the operational dashboard.
-- All writes remain behind the platform RBAC permission layer.

create policy products_staff_manage
on catalog.products
for all to authenticated
using (platform.has_permission((select auth.uid()), 'catalog.manage'))
with check (platform.has_permission((select auth.uid()), 'catalog.manage'));

create policy variants_staff_manage
on catalog.product_variants
for all to authenticated
using (platform.has_permission((select auth.uid()), 'catalog.manage'))
with check (platform.has_permission((select auth.uid()), 'catalog.manage'));

create policy prices_staff_manage
on catalog.prices
for all to authenticated
using (platform.has_permission((select auth.uid()), 'catalog.manage'))
with check (platform.has_permission((select auth.uid()), 'catalog.manage'));

create policy categories_staff_manage
on catalog.categories
for all to authenticated
using (platform.has_permission((select auth.uid()), 'catalog.manage'))
with check (platform.has_permission((select auth.uid()), 'catalog.manage'));

create policy product_categories_staff_manage
on catalog.product_categories
for all to authenticated
using (platform.has_permission((select auth.uid()), 'catalog.manage'))
with check (platform.has_permission((select auth.uid()), 'catalog.manage'));

create policy carriers_staff_manage
on logistics.carriers
for all to authenticated
using (platform.has_permission((select auth.uid()), 'shipping.manage'))
with check (platform.has_permission((select auth.uid()), 'shipping.manage'));

create policy shipping_methods_staff_manage
on logistics.shipping_methods
for all to authenticated
using (platform.has_permission((select auth.uid()), 'shipping.manage'))
with check (platform.has_permission((select auth.uid()), 'shipping.manage'));
