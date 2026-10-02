drop policy if exists "staff manage gap closure" on logistics.shipping_areas;

create policy shipping_areas_staff_manage
on logistics.shipping_areas
for all to authenticated
using (platform.has_permission((select auth.uid()), 'shipping.manage'))
with check (platform.has_permission((select auth.uid()), 'shipping.manage'));

create policy inventory_items_staff_manage
on inventory.items
for all to authenticated
using (platform.has_permission((select auth.uid()), 'inventory.manage'))
with check (platform.has_permission((select auth.uid()), 'inventory.manage'));

create or replace function inventory.adjust_stock(
  p_item_id uuid,
  p_quantity numeric,
  p_adjustment_type text,
  p_reason text
)
returns inventory.items
language plpgsql
security invoker
set search_path = pg_catalog, inventory, platform, auth
as $$
declare
  v_item inventory.items;
begin
  if not platform.has_permission((select auth.uid()), 'inventory.manage') then
    raise exception 'FORBIDDEN';
  end if;

  if p_quantity = 0 then
    raise exception 'INVALID_QUANTITY';
  end if;

  update inventory.items
  set on_hand = on_hand + p_quantity,
      updated_at = now()
  where id = p_item_id
    and on_hand + p_quantity >= 0
  returning * into v_item;

  if v_item.id is null then
    raise exception 'INSUFFICIENT_STOCK_OR_ITEM_NOT_FOUND';
  end if;

  insert into inventory.stock_adjustments(
    product_variant_id, location_id, adjustment_type, quantity,
    reason, reference_type, notes, created_by
  )
  values (
    v_item.product_variant_id, v_item.location_id, p_adjustment_type,
    abs(p_quantity), p_reason, 'admin_dashboard', p_adjustment_type,
    (select auth.uid())
  );

  return v_item;
end;
$$;

revoke all on function inventory.adjust_stock(uuid,numeric,text,text) from public;
grant execute on function inventory.adjust_stock(uuid,numeric,text,text) to authenticated;
