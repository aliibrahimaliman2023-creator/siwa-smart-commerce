-- Grant the authenticated Data API role table privileges required by the admin data manager.
-- RLS and RBAC policies remain the authorization boundary for writes.

grant usage on schema catalog, inventory, logistics to authenticated;

grant select, insert, update, delete on
  catalog.products,
  catalog.product_variants,
  catalog.prices,
  catalog.categories,
  catalog.product_categories
to authenticated;

grant select on inventory.items to authenticated;

grant select, insert, update, delete on
  logistics.carriers,
  logistics.shipping_areas,
  logistics.shipping_methods,
  logistics.shipping_rules
to authenticated;

grant usage, select on all sequences in schema catalog to authenticated;
grant usage, select on all sequences in schema inventory to authenticated;
grant usage, select on all sequences in schema logistics to authenticated;
