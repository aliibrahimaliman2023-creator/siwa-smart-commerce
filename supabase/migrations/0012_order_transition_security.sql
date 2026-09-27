-- 0012_order_transition_security.sql
-- Customers may only cancel early-stage orders. Operational transitions are staff-only.

create or replace function commerce.transition_order(
  p_order_id uuid,
  p_to_status text,
  p_reason text default null
) returns commerce.orders
language plpgsql
security definer
set search_path=commerce,identity,customer,platform,public
as $$
declare
  v_order commerce.orders;
  v_actor uuid := auth.uid();
  v_from text;
  v_staff boolean;
begin
  if v_actor is null then raise exception 'AUTH_REQUIRED'; end if;

  select * into v_order
    from commerce.orders
   where id=p_order_id
   for update;

  if not found then raise exception 'ORDER_NOT_FOUND'; end if;

  v_staff := platform.has_permission(v_actor,'orders.manage');

  if not v_staff and v_order.customer_id <> (
    select c.id from customer.customers c where c.auth_user_id=v_actor limit 1
  ) then
    raise exception 'FORBIDDEN';
  end if;

  v_from := v_order.status;

  if p_to_status = v_from then
    return v_order;
  end if;

  if v_staff then
    if not (
      (v_from='pending' and p_to_status in ('payment_pending','cancelled')) or
      (v_from='payment_pending' and p_to_status in ('paid','cancelled')) or
      (v_from='paid' and p_to_status in ('processing','cancelled')) or
      (v_from='processing' and p_to_status in ('shipped','cancelled')) or
      (v_from='shipped' and p_to_status in ('delivered','returned')) or
      (v_from='delivered' and p_to_status='returned')
    ) then
      raise exception 'INVALID_ORDER_TRANSITION:%:%',v_from,p_to_status;
    end if;
  else
    if not (
      p_to_status='cancelled'
      and v_from in ('pending','payment_pending')
    ) then
      raise exception 'CUSTOMER_TRANSITION_NOT_ALLOWED';
    end if;
  end if;

  update commerce.orders
     set status=p_to_status,updated_at=now()
   where id=p_order_id
   returning * into v_order;

  insert into commerce.order_status_history(
    order_id,from_status,to_status,actor_id,reason
  )
  values(
    p_order_id,v_from,p_to_status,
    (select id from identity.user_profiles where id=v_actor),
    p_reason
  );

  return v_order;
end;
$$;

revoke all on function commerce.transition_order(uuid,text,text) from public;
grant execute on function commerce.transition_order(uuid,text,text) to authenticated;

revoke all on function platform.record_event(text,text,uuid,uuid,jsonb,int) from public;
revoke all on function platform.record_event(text,text,uuid,uuid,jsonb,int) from authenticated;
