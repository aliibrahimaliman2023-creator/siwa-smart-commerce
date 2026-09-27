-- 0030_gap_closure_checkout_and_security.sql
-- Canonical checkout v2 replay for fresh environments.
create or replace function commerce.checkout_atomic_v2(p_idempotency_key text,p_currency text,p_location_id uuid,p_items jsonb,p_shipping_address jsonb default '{}',p_customer_snapshot jsonb default '{}',p_coupon_code text default null)
returns jsonb language plpgsql security definer set search_path=commerce,customer,catalog,inventory,logistics,platform,identity,public as $$
declare a uuid:=auth.uid();c uuid;o uuid;onum text;x jsonb;v uuid;q numeric;pr record;prod record;sub numeric(18,2):=0;disc numeric(18,2):=0;ship numeric(18,2):=0;total numeric(18,2);coupon commerce.coupons;rule logistics.shipping_rules;items jsonb:='[]';existing jsonb;h text;oldh text;
begin
if a is null then raise exception 'AUTH_REQUIRED';end if;if coalesce(length(trim(p_idempotency_key)),0)<16 then raise exception 'INVALID_IDEMPOTENCY_KEY';end if;if p_location_id is null then raise exception 'LOCATION_REQUIRED';end if;
select id into c from customer.customers where auth_user_id=a limit 1;if c is null then raise exception 'CUSTOMER_NOT_FOUND';end if;
h:=encode(digest(convert_to(p_items::text||'|'||p_currency||'|'||p_location_id::text||'|'||coalesce(p_shipping_address,'{}')::text||'|'||coalesce(p_coupon_code,''),'utf8'),'sha256'),'hex');
select request_hash,response_json into oldh,existing from platform.idempotency_keys where operation='checkout_atomic_v2' and key=p_idempotency_key and actor_id=a for update;
if oldh is not null and oldh<>h then raise exception 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST';end if;if existing is not null then return existing;end if;
insert into platform.idempotency_keys(key,operation,actor_id,request_hash,expires_at) values(p_idempotency_key,'checkout_atomic_v2',a,h,now()+interval '24 hours') on conflict(operation,key) do nothing;
select request_hash,response_json into oldh,existing from platform.idempotency_keys where operation='checkout_atomic_v2' and key=p_idempotency_key and actor_id=a for update;
if oldh<>h then raise exception 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST';end if;if existing is not null then return existing;end if;
for x in select value from jsonb_array_elements(p_items) loop
 v:=(x->>'product_variant_id')::uuid;q:=(x->>'quantity')::numeric;if v is null or q is null or q<=0 then raise exception 'INVALID_CART_ITEM';end if;
 select * into pr from commerce.resolve_active_price(v,p_currency);if pr.price_id is null then raise exception 'PRICE_NOT_FOUND:%',v;end if;
 select pv.id,pv.product_id,pv.sku,p.name_ar,p.name_en into prod from catalog.product_variants pv join catalog.products p on p.id=pv.product_id where pv.id=v and pv.status='active' and p.status='active';if prod.id is null then raise exception 'PRODUCT_NOT_AVAILABLE:%',v;end if;
 sub:=sub+round(pr.amount*q,2);items:=items||jsonb_build_array(jsonb_build_object('product_variant_id',v,'quantity',q,'unit_price',pr.amount,'currency',p_currency));
end loop;
if nullif(trim(coalesce(p_coupon_code,'')),'') is not null then
 select * into coupon from commerce.coupons where upper(code)=upper(trim(p_coupon_code)) and status='active' and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>now()) for update;
 if not found then raise exception 'COUPON_INVALID';end if;
 if coupon.min_subtotal is not null and sub<coupon.min_subtotal then raise exception 'COUPON_MIN_SUBTOTAL';end if;
 if coupon.usage_limit is not null and (select count(*) from commerce.coupon_redemptions where coupon_id=coupon.id)>=coupon.usage_limit then raise exception 'COUPON_USAGE_LIMIT';end if;
 if coupon.discount_type='percent' then disc:=round(sub*coupon.discount_value/100,2);else disc:=coupon.discount_value;end if;
 if coupon.max_discount is not null then disc:=least(disc,coupon.max_discount);end if;disc:=least(disc,sub);
end if;
select * into rule from logistics.shipping_rules where status='active' and (min_order is null or sub-disc>=min_order) and (max_order is null or sub-disc<=max_order) order by priority desc,created_at desc limit 1;
if found then if rule.free_shipping_threshold is not null and sub-disc>=rule.free_shipping_threshold then ship:=0;else ship:=rule.price;end if;end if;
total:=greatest(0,round(sub-disc+ship,2));onum:='SW-'||to_char(now(),'YYYYMMDDHH24MISS')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
insert into commerce.orders(order_number,customer_id,status,currency,subtotal,discount_total,shipping_total,grand_total,customer_snapshot,shipping_address_snapshot,pricing_snapshot)
values(onum,c,'pending',p_currency,sub,disc,ship,total,p_customer_snapshot,coalesce(p_shipping_address,'{}'),jsonb_build_object('currency',p_currency,'items',items,'shipping',ship,'tax',0,'discount',disc,'coupon_code',p_coupon_code,'pricing_version','v2')) returning id into o;
for x in select value from jsonb_array_elements(items) loop
 v:=(x->>'product_variant_id')::uuid;q:=(x->>'quantity')::numeric;select pv.product_id,pv.sku,p.name_ar,p.name_en into prod from catalog.product_variants pv join catalog.products p on p.id=pv.product_id where pv.id=v;
 insert into commerce.order_items(order_id,product_id,product_variant_id,sku_snapshot,product_name_ar_snapshot,product_name_en_snapshot,quantity,unit_price,line_total) values(o,prod.product_id,v,prod.sku,prod.name_ar,prod.name_en,q,(x->>'unit_price')::numeric,round((x->>'unit_price')::numeric*q,2));
end loop;
perform inventory.reserve_items(o,(select jsonb_agg(jsonb_build_object('product_variant_id',x->>'product_variant_id','location_id',p_location_id,'quantity',x->>'quantity')) from jsonb_array_elements(items) x));
if coupon.id is not null then insert into commerce.coupon_redemptions(coupon_id,customer_id,order_id,discount_amount) values(coupon.id,c,o,disc);end if;
insert into commerce.order_status_history(order_id,to_status,actor_id,reason) values(o,'pending',(select id from identity.user_profiles where id=a),'checkout_created');
insert into logistics.delivery_promises(order_id,location_id,promised_from,promised_to,calculation) values(o,p_location_id,now()+make_interval(days=>coalesce(rule.eta_min_days,0)),now()+make_interval(days=>coalesce(rule.eta_max_days,0)),jsonb_build_object('rule',rule.code,'source','configured_shipping_rule'));
existing:=jsonb_build_object('order_id',o,'order_number',onum,'status','pending','currency',p_currency,'subtotal',sub,'discount',disc,'shipping',ship,'grand_total',total);
update platform.idempotency_keys set response_status=200,response_json=existing where operation='checkout_atomic_v2' and key=p_idempotency_key and actor_id=a;return existing;
end $$;
revoke all on function commerce.checkout_atomic_v2(text,text,uuid,jsonb,jsonb,jsonb,text) from public;
grant execute on function commerce.checkout_atomic_v2(text,text,uuid,jsonb,jsonb,jsonb,text) to authenticated;

drop view if exists catalog.machine_products;
create view catalog.machine_products with (security_invoker=true) as
select p.id,p.public_id,p.slug,p.name_ar,p.name_en,p.description_ar,p.description_en,p.product_type,v.id as variant_id,v.sku,v.name_ar as variant_name_ar,v.name_en as variant_name_en,v.attributes,pr.amount,pr.currency,coalesce(sum(i.on_hand-i.reserved),0) as available_stock
from catalog.products p join catalog.product_variants v on v.product_id=p.id
left join catalog.prices pr on pr.product_variant_id=v.id and pr.is_active=true and pr.currency='EGP'
left join inventory.items i on i.product_variant_id=v.id
where p.status='active' and v.status='active'
group by p.id,v.id,pr.amount,pr.currency;
grant select on catalog.machine_products to authenticated;