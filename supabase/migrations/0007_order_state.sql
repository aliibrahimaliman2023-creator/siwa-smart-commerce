create or replace function commerce.transition_order(p_order_id uuid,p_to_status text,p_reason text default null)
returns commerce.orders language plpgsql security definer set search_path=commerce,identity,customer,platform,public as $$
declare v_order commerce.orders; v_actor uuid:=auth.uid(); v_from text;
begin
 select * into v_order from commerce.orders where id=p_order_id for update;
 if not found then raise exception 'ORDER_NOT_FOUND'; end if;
 if not(platform.has_permission(v_actor,'orders.manage') or v_order.customer_id=(select c.id from customer.customers c where c.auth_user_id=v_actor limit 1)) then raise exception 'FORBIDDEN'; end if;
 v_from:=v_order.status; if p_to_status=v_from then return v_order; end if;
 if not((v_from='pending' and p_to_status in('payment_pending','cancelled')) or(v_from='payment_pending' and p_to_status in('paid','cancelled')) or(v_from='paid' and p_to_status in('processing','cancelled')) or(v_from='processing' and p_to_status in('shipped','cancelled')) or(v_from='shipped' and p_to_status in('delivered','returned')) or(v_from='delivered' and p_to_status='returned')) then raise exception 'INVALID_ORDER_TRANSITION:%:%',v_from,p_to_status; end if;
 update commerce.orders set status=p_to_status,updated_at=now() where id=p_order_id returning * into v_order;
 insert into commerce.order_status_history(order_id,from_status,to_status,actor_id,reason) values(p_order_id,v_from,p_to_status,(select id from identity.user_profiles where id=v_actor),p_reason);
 return v_order;
end; $$;
grant execute on function commerce.transition_order(uuid,text,text) to authenticated;
create or replace function inventory.release_expired_reservations(p_now timestamptz default now()) returns integer language plpgsql security definer set search_path=inventory,public as $$
declare r record; released integer:=0;
begin
 for r in select id,product_variant_id,location_id,order_id,quantity from inventory.reservations where status='pending' and expires_at is not null and expires_at<=p_now for update skip locked loop
  update inventory.items set reserved=greatest(0,reserved-r.quantity),updated_at=now() where product_variant_id=r.product_variant_id and location_id=r.location_id;
  update inventory.reservations set status='expired',updated_at=now() where id=r.id;
  insert into inventory.transactions(product_variant_id,location_id,transaction_type,quantity,reference_type,reference_id) values(r.product_variant_id,r.location_id,'release',r.quantity,'order',r.order_id);
  released:=released+1;
 end loop; return released;
end; $$;
revoke all on function inventory.release_expired_reservations(timestamptz) from public;