-- 0011_pre_supabase_security_hardening.sql
-- Final pre-Supabase hardening: inventory reservation must only be reachable
-- through the atomic checkout path, not directly by storefront users.

revoke all on function inventory.reserve_items(uuid,jsonb,timestamptz) from public;
revoke all on function inventory.reserve_items(uuid,jsonb,timestamptz) from authenticated;

create or replace function inventory.reserve_items(
  p_order_id uuid,
  p_items jsonb,
  p_expires_at timestamptz default now() + interval '20 minutes'
) returns jsonb
language plpgsql
security definer
set search_path = inventory, commerce, customer, catalog, platform, public
as $$
declare
  item jsonb;
  v_variant uuid;
  v_location uuid;
  v_qty numeric(18,3);
  v_available numeric(18,3);
  v_reservation uuid;
  v_order_customer uuid;
  v_order_status text;
  v_actor uuid := auth.uid();
  result jsonb := '[]'::jsonb;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_order_id is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'INVALID_RESERVATION_REQUEST';
  end if;

  select customer_id, status into v_order_customer, v_order_status
    from commerce.orders
   where id = p_order_id
   for update;

  if v_order_customer is null then raise exception 'ORDER_NOT_FOUND_OR_NO_CUSTOMER'; end if;
  if v_order_status not in ('pending','payment_pending') then
    raise exception 'ORDER_NOT_RESERVABLE';
  end if;

  if not (
    platform.has_permission(v_actor, 'orders.manage')
    or v_order_customer = (select c.id from customer.customers c where c.auth_user_id = v_actor limit 1)
  ) then
    raise exception 'FORBIDDEN';
  end if;

  for item in select value from jsonb_array_elements(p_items)
  loop
    v_variant := (item->>'product_variant_id')::uuid;
    v_location := (item->>'location_id')::uuid;
    v_qty := (item->>'quantity')::numeric;

    if v_variant is null or v_location is null or v_qty is null or v_qty <= 0 then
      raise exception 'INVALID_RESERVATION_ITEM';
    end if;

    select on_hand - reserved - damaged - quarantine
      into v_available
      from inventory.items
     where product_variant_id = v_variant
       and location_id = v_location
     for update;

    if not found or coalesce(v_available, 0) < v_qty then
      raise exception 'INSUFFICIENT_INVENTORY:%', v_variant;
    end if;

    update inventory.items
       set reserved = reserved + v_qty, updated_at = now()
     where product_variant_id = v_variant and location_id = v_location;

    insert into inventory.reservations(product_variant_id, location_id, order_id, quantity, status, expires_at)
    values(v_variant, v_location, p_order_id, v_qty, 'pending', p_expires_at)
    returning id into v_reservation;

    insert into inventory.transactions(
      product_variant_id, location_id, transaction_type, quantity,
      reference_type, reference_id, created_by
    )
    values(v_variant, v_location, 'reserve', v_qty, 'order', p_order_id, v_actor);

    result := result || jsonb_build_array(jsonb_build_object(
      'reservation_id', v_reservation,
      'product_variant_id', v_variant,
      'location_id', v_location,
      'quantity', v_qty
    ));
  end loop;

  return result;
end;
$$;

revoke all on function inventory.reserve_items(uuid,jsonb,timestamptz) from public;
revoke all on function inventory.reserve_items(uuid,jsonb,timestamptz) from authenticated;

-- Checkout remains the only public authenticated entry point.
revoke all on function commerce.checkout_atomic(text,text,uuid,jsonb,jsonb,jsonb) from public;
grant execute on function commerce.checkout_atomic(text,text,uuid,jsonb,jsonb,jsonb) to authenticated;
