create or replace function commerce.create_payment_intent(p_order_id uuid,p_provider text,p_idempotency_key text)
returns commerce.payment_intents language plpgsql security definer set search_path=commerce,customer,platform,public as $$
declare v_order commerce.orders; v_existing commerce.payment_intents; v_pi commerce.payment_intents;
begin
 if auth.uid() is null then raise exception 'UNAUTHENTICATED'; end if;
 select * into v_order from commerce.orders where id=p_order_id for update;
 if not found then raise exception 'ORDER_NOT_FOUND'; end if;
 if not (v_order.customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid()) or platform.has_permission(auth.uid(),'payments.manage')) then raise exception 'FORBIDDEN'; end if;
 select * into v_existing from commerce.payment_intents where idempotency_key=p_idempotency_key limit 1;
 if found then
  if v_existing.order_id<>p_order_id or v_existing.amount<>v_order.grand_total or v_existing.currency<>v_order.currency then raise exception 'IDEMPOTENCY_KEY_REUSE'; end if;
  return v_existing;
 end if;
 insert into commerce.payment_intents(order_id,provider,amount,currency,status,idempotency_key)
 values(p_order_id,coalesce(nullif(p_provider,''),'manual'),v_order.grand_total,v_order.currency,'created',p_idempotency_key) returning * into v_pi;
 if v_order.status='pending' then perform commerce.transition_order(p_order_id,'payment_pending','payment_intent_created'); end if;
 return v_pi;
end; $$;
revoke all on function commerce.create_payment_intent(uuid,text,text) from public;
grant execute on function commerce.create_payment_intent(uuid,text,text) to authenticated;

create or replace function commerce.record_payment_intent_result(p_payment_intent_id uuid,p_status text,p_provider_reference text default null,p_raw_response jsonb default '{}')
returns commerce.payment_intents language plpgsql security definer set search_path=commerce,finance,platform,public as $$
declare v_pi commerce.payment_intents; v_order commerce.orders;
begin
 if auth.uid() is null then raise exception 'UNAUTHENTICATED'; end if;
 if not platform.has_permission(auth.uid(),'payments.manage') then raise exception 'FORBIDDEN'; end if;
 select * into v_pi from commerce.payment_intents where id=p_payment_intent_id for update;
 if not found then raise exception 'PAYMENT_INTENT_NOT_FOUND'; end if;
 select * into v_order from commerce.orders where id=v_pi.order_id for update;
 if p_status not in ('created','pending','succeeded','failed','cancelled') then raise exception 'INVALID_PAYMENT_STATUS'; end if;
 if v_pi.status in ('succeeded','failed','cancelled') and p_status<>v_pi.status then raise exception 'PAYMENT_INTENT_FINAL'; end if;
 update commerce.payment_intents set status=p_status,provider_reference=coalesce(p_provider_reference,provider_reference),raw_response=coalesce(p_raw_response,'{}'),updated_at=now() where id=p_payment_intent_id returning * into v_pi;
 if p_status='succeeded' then
  insert into finance.payments(order_id,provider_code,provider_reference,amount,currency,status,paid_at,payload)
  values(v_order.id,v_pi.provider,v_pi.provider_reference,v_pi.amount,v_pi.currency,'succeeded',now(),coalesce(p_raw_response,'{}'));
  if v_order.status='payment_pending' then perform commerce.transition_order(v_order.id,'paid','payment_succeeded'); end if;
 elsif p_status in ('failed','cancelled') and v_order.status='payment_pending' then
  perform commerce.transition_order(v_order.id,'cancelled','payment_'||p_status);
 end if;
 return v_pi;
end; $$;
revoke all on function commerce.record_payment_intent_result(uuid,text,text,jsonb) from public;
grant execute on function commerce.record_payment_intent_result(uuid,text,text,jsonb) to authenticated;
