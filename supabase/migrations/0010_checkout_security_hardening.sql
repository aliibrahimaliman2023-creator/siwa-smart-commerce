-- 0010_checkout_security_hardening.sql
-- Hardens checkout reservation authorization and idempotency replay semantics.

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
  v_actor uuid := auth.uid();
  result jsonb := '[]'::jsonb;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_order_id is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'INVALID_RESERVATION_REQUEST';
  end if;

  select customer_id into v_order_customer
    from commerce.orders
   where id = p_order_id
   for update;
  if v_order_customer is null then raise exception 'ORDER_NOT_FOUND_OR_NO_CUSTOMER'; end if;

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
       set reserved = reserved + v_qty,
           updated_at = now()
     where product_variant_id = v_variant
       and location_id = v_location;

    insert into inventory.reservations(product_variant_id, location_id, order_id, quantity, status, expires_at)
    values(v_variant, v_location, p_order_id, v_qty, 'pending', p_expires_at)
    returning id into v_reservation;

    insert into inventory.transactions(product_variant_id, location_id, transaction_type, quantity, reference_type, reference_id, created_by)
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
grant execute on function inventory.reserve_items(uuid,jsonb,timestamptz) to authenticated;

create or replace function commerce.checkout_atomic(
  p_idempotency_key text,
  p_currency text,
  p_location_id uuid,
  p_items jsonb,
  p_shipping_address jsonb default '{}',
  p_customer_snapshot jsonb default '{}'
) returns jsonb
language plpgsql
security definer
set search_path = commerce, customer, catalog, inventory, platform, identity, public
as $$
declare
  v_auth uuid := auth.uid();
  v_customer uuid;
  v_order uuid;
  v_order_number text;
  v_item jsonb;
  v_variant uuid;
  v_qty numeric(18,3);
  v_price record;
  v_product record;
  v_subtotal numeric(18,2) := 0;
  v_items jsonb := '[]'::jsonb;
  v_reservations jsonb;
  v_existing jsonb;
  v_existing_hash text;
  v_hash text;
begin
  if v_auth is null then raise exception 'AUTH_REQUIRED'; end if;
  if coalesce(length(trim(p_idempotency_key)),0) < 16 then raise exception 'INVALID_IDEMPOTENCY_KEY'; end if;
  if p_currency is null or p_currency = '' then raise exception 'CURRENCY_REQUIRED'; end if;
  if p_location_id is null then raise exception 'LOCATION_REQUIRED'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'EMPTY_CART'; end if;

  select c.id into v_customer from customer.customers c where c.auth_user_id = v_auth limit 1;
  if v_customer is null then raise exception 'CUSTOMER_NOT_FOUND'; end if;

  v_hash := encode(digest(convert_to(p_items::text || '|' || p_currency || '|' || p_location_id::text || '|' || coalesce(p_shipping_address,'{}'::jsonb)::text, 'utf8'),'sha256'),'hex');

  select request_hash, response_json into v_existing_hash, v_existing
    from platform.idempotency_keys
   where operation = 'checkout_atomic' and key = p_idempotency_key and actor_id = v_auth
   for update;

  if v_existing_hash is not null and v_existing_hash <> v_hash then
    raise exception 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST';
  end if;
  if v_existing is not null then return v_existing; end if;

  insert into platform.idempotency_keys(key, operation, actor_id, request_hash, expires_at)
  values(p_idempotency_key, 'checkout_atomic', v_auth, v_hash, now() + interval '24 hours')
  on conflict(operation,key) do nothing;

  select request_hash, response_json into v_existing_hash, v_existing
    from platform.idempotency_keys
   where operation='checkout_atomic' and key=p_idempotency_key and actor_id=v_auth
   for update;

  if v_existing_hash <> v_hash then
    raise exception 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST';
  end if;
  if v_existing is not null then return v_existing; end if;

  v_order_number := 'SW-' || to_char(now(),'YYYYMMDDHH24MISS') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
  insert into commerce.orders(order_number, customer_id, status, currency, customer_snapshot, shipping_address_snapshot)
  values(v_order_number, v_customer, 'pending', p_currency, p_customer_snapshot, coalesce(p_shipping_address,'{}'))
  returning id into v_order;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_variant := (v_item->>'product_variant_id')::uuid;
    v_qty := (v_item->>'quantity')::numeric;
    if v_variant is null or v_qty is null or v_qty <= 0 then raise exception 'INVALID_CART_ITEM'; end if;

    select * into v_price from commerce.resolve_active_price(v_variant, p_currency);
    if v_price.price_id is null then raise exception 'PRICE_NOT_FOUND:%', v_variant; end if;

    select pv.id, pv.product_id, pv.sku, p.name_ar, p.name_en into v_product
      from catalog.product_variants pv join catalog.products p on p.id=pv.product_id
     where pv.id=v_variant and pv.status='active';
    if v_product.id is null then raise exception 'PRODUCT_NOT_AVAILABLE:%', v_variant; end if;

    insert into commerce.order_items(order_id, product_id, product_variant_id, sku_snapshot, product_name_ar_snapshot, product_name_en_snapshot, quantity, unit_price, line_total)
    values(v_order, v_product.product_id, v_variant, v_product.sku, v_product.name_ar, v_product.name_en, v_qty, v_price.amount, round(v_price.amount*v_qty,2));

    v_subtotal := v_subtotal + round(v_price.amount*v_qty,2);
    v_items := v_items || jsonb_build_array(jsonb_build_object('product_variant_id',v_variant,'quantity',v_qty,'unit_price',v_price.amount,'currency',p_currency));
  end loop;

  v_reservations := inventory.reserve_items(v_order, (
    select jsonb_agg(jsonb_build_object('product_variant_id',x->>'product_variant_id','location_id',p_location_id,'quantity',x->>'quantity'))
      from jsonb_array_elements(v_items) x
  ));

  update commerce.orders
     set subtotal=v_subtotal, grand_total=v_subtotal,
         pricing_snapshot=jsonb_build_object('currency',p_currency,'items',v_items,'shipping',0,'tax',0,'discount',0,'pricing_version','v1'),
         updated_at=now()
   where id=v_order;

  insert into commerce.order_status_history(order_id,to_status,actor_id,reason)
  values(v_order,'pending',v_auth,'checkout_created');

  v_existing := jsonb_build_object('order_id',v_order,'order_number',v_order_number,'status','pending','currency',p_currency,'subtotal',v_subtotal,'grand_total',v_subtotal,'reservations',v_reservations);
  update platform.idempotency_keys
     set response_status=200,response_json=v_existing
   where operation='checkout_atomic' and key=p_idempotency_key and actor_id=v_auth;
  return v_existing;
end;
$$;

revoke all on function commerce.checkout_atomic(text,text,uuid,jsonb,jsonb,jsonb) from public;
grant execute on function commerce.checkout_atomic(text,text,uuid,jsonb,jsonb,jsonb) to authenticated;
