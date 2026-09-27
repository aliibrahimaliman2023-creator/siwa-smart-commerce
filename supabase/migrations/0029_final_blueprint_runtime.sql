-- 0029_final_blueprint_runtime.sql
-- Final Blueprint runtime: customer growth, profit intelligence, checkout recovery,
-- automation execution contracts, AI-safe read models, and API-ready event contracts.

create schema if not exists analytics;

create table if not exists customer.checkout_sessions(
 id uuid primary key default gen_random_uuid(), customer_id uuid references customer.customers(id) on delete cascade,
 session_key text unique not null, cart_snapshot jsonb not null default '[]', pricing_snapshot jsonb not null default '{}',
 shipping_snapshot jsonb not null default '{}', last_step text, failure_code text, status text not null default 'open',
 started_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 recovered_order_id uuid references commerce.orders(id)
);

create table if not exists customer.buy_again_signals(
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references customer.customers(id) on delete cascade,
 product_variant_id uuid not null references catalog.product_variants(id), score numeric(10,4) not null default 0,
 estimated_repurchase_at timestamptz, last_ordered_at timestamptz, order_count integer not null default 0,
 metadata jsonb not null default '{}', updated_at timestamptz not null default now(),
 unique(customer_id,product_variant_id)
);

create table if not exists customer.referral_links(
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references customer.customers(id) on delete cascade,
 code text unique not null, landing_path text, clicks integer not null default 0, created_at timestamptz not null default now()
);

create table if not exists customer.preference_consents(
 customer_id uuid primary key references customer.customers(id) on delete cascade,
 marketing_email boolean not null default false, marketing_sms boolean not null default false,
 marketing_whatsapp boolean not null default false, analytics boolean not null default true,
 updated_at timestamptz not null default now()
);

create table if not exists analytics.kpis_daily(
 day date primary key, orders_count integer not null default 0, paid_orders_count integer not null default 0,
 gross_sales numeric(18,2) not null default 0, discounts numeric(18,2) not null default 0,
 shipping_revenue numeric(18,2) not null default 0, refunds numeric(18,2) not null default 0,
 estimated_cogs numeric(18,2) not null default 0, payment_cost numeric(18,2) not null default 0,
 contribution_profit numeric(18,2) not null default 0, currency text not null default 'EGP',
 refreshed_at timestamptz not null default now()
);

create table if not exists analytics.customer_metrics(
 customer_id uuid primary key references customer.customers(id) on delete cascade,
 order_count integer not null default 0, lifetime_revenue numeric(18,2) not null default 0,
 lifetime_profit numeric(18,2) not null default 0, average_order_value numeric(18,2) not null default 0,
 first_order_at timestamptz, last_order_at timestamptz, clv_estimate numeric(18,2) not null default 0,
 segment text, updated_at timestamptz not null default now()
);

create table if not exists analytics.product_metrics(
 product_variant_id uuid primary key references catalog.product_variants(id) on delete cascade,
 units_sold numeric(18,3) not null default 0, revenue numeric(18,2) not null default 0,
 gross_margin numeric(18,2) not null default 0, return_rate numeric(10,4) not null default 0,
 stock_turnover numeric(10,4) not null default 0, updated_at timestamptz not null default now()
);

create table if not exists platform.webhook_deliveries(
 id uuid primary key default gen_random_uuid(), event_id uuid references platform.system_events(id),
 endpoint text not null, provider text, status text not null default 'queued',
 attempt_count integer not null default 0, next_attempt_at timestamptz, response_code integer,
 response_body text, idempotency_key text unique, created_at timestamptz not null default now(),
 delivered_at timestamptz
);

create table if not exists platform.ai_tool_permissions(
 tool_code text primary key, enabled boolean not null default false,
 risk_level text not null default 'low', read_only boolean not null default true,
 allowed_roles text[] not null default '{}', description text
);

create table if not exists platform.api_keys(
 id uuid primary key default gen_random_uuid(), name text not null, key_prefix text not null unique,
 key_hash text not null unique, status text not null default 'active', scopes text[] not null default '{}',
 expires_at timestamptz, last_used_at timestamptz, created_at timestamptz not null default now()
);

create or replace function customer.upsert_checkout_session(
 p_session_key text,p_cart jsonb,p_pricing jsonb default '{}',p_shipping jsonb default '{}',
 p_last_step text default null,p_failure_code text default null
) returns customer.checkout_sessions
language plpgsql security definer set search_path=customer,commerce,platform,public as $$
declare a uuid:=auth.uid(); c uuid; v customer.checkout_sessions;
begin
 if a is null then raise exception 'AUTH_REQUIRED'; end if;
 select id into c from customer.customers where auth_user_id=a limit 1;
 if c is null then raise exception 'CUSTOMER_NOT_FOUND'; end if;
 if length(trim(coalesce(p_session_key,'')))<8 then raise exception 'INVALID_SESSION_KEY'; end if;
 insert into customer.checkout_sessions(customer_id,session_key,cart_snapshot,pricing_snapshot,shipping_snapshot,last_step,failure_code)
 values(c,p_session_key,coalesce(p_cart,'[]'),coalesce(p_pricing,'{}'),coalesce(p_shipping,'{}'),p_last_step,p_failure_code)
 on conflict(session_key) do update set cart_snapshot=excluded.cart_snapshot,pricing_snapshot=excluded.pricing_snapshot,
 shipping_snapshot=excluded.shipping_snapshot,last_step=excluded.last_step,failure_code=excluded.failure_code,updated_at=now()
 returning * into v;
 return v;
end $$;
revoke all on function customer.upsert_checkout_session(text,jsonb,jsonb,jsonb,text,text) from public;
grant execute on function customer.upsert_checkout_session(text,jsonb,jsonb,jsonb,text,text) to authenticated;

create or replace function customer.add_wishlist_item(p_product_variant_id uuid,p_wishlist_id uuid default null)
returns customer.wishlist_items
language plpgsql security definer set search_path=customer,catalog,public as $$
declare a uuid:=auth.uid(); c uuid; w uuid; v customer.wishlist_items;
begin
 if a is null then raise exception 'AUTH_REQUIRED'; end if;
 select id into c from customer.customers where auth_user_id=a limit 1;
 if c is null then raise exception 'CUSTOMER_NOT_FOUND'; end if;
 select id into w from customer.wishlists where id=coalesce(p_wishlist_id,id) and customer_id=c order by created_at limit 1;
 if w is null then insert into customer.wishlists(customer_id,name) values(c,'Default') returning id into w; end if;
 if not exists(select 1 from catalog.product_variants where id=p_product_variant_id and status='active') then raise exception 'VARIANT_NOT_FOUND'; end if;
 insert into customer.wishlist_items(wishlist_id,product_variant_id) values(w,p_product_variant_id)
 on conflict(wishlist_id,product_variant_id) do nothing returning * into v;
 if v.id is null then select * into v from customer.wishlist_items where wishlist_id=w and product_variant_id=p_product_variant_id; end if;
 return v;
end $$;
revoke all on function customer.add_wishlist_item(uuid,uuid) from public;
grant execute on function customer.add_wishlist_item(uuid,uuid) to authenticated;

create or replace function customer.rebuild_buy_again_signals(p_customer_id uuid default null)
returns integer language plpgsql security definer set search_path=customer,commerce,catalog,public as $$
declare a uuid:=auth.uid(); c uuid; n integer:=0; r record;
begin
 if a is null then raise exception 'AUTH_REQUIRED'; end if;
 select id into c from customer.customers where auth_user_id=a limit 1;
 if p_customer_id is not null and p_customer_id<>c and not platform.has_permission(a,'orders.manage') then raise exception 'FORBIDDEN'; end if;
 c:=coalesce(p_customer_id,c);
 delete from customer.buy_again_signals where customer_id=c;
 for r in
   select oi.product_variant_id,max(o.created_at) last_ordered_at,count(distinct o.id) order_count,
          greatest(0,least(1,(count(distinct o.id)::numeric/10))) score
   from commerce.orders o join commerce.order_items oi on oi.order_id=o.id
   where o.customer_id=c and o.status in ('paid','processing','shipped','delivered')
   group by oi.product_variant_id
 loop
   insert into customer.buy_again_signals(customer_id,product_variant_id,score,last_ordered_at,order_count)
   values(c,r.product_variant_id,r.score,r.last_ordered_at,r.order_count); n:=n+1;
 end loop;
 return n;
end $$;
revoke all on function customer.rebuild_buy_again_signals(uuid) from public;
grant execute on function customer.rebuild_buy_again_signals(uuid) to authenticated;

create or replace function customer.award_points(p_customer_id uuid,p_points numeric,p_type text,p_reference_type text default null,p_reference_id uuid default null)
returns customer.point_accounts language plpgsql security definer set search_path=customer,platform,public as $$
declare a uuid:=auth.uid(); pa customer.point_accounts;
begin
 if a is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_points=0 then raise exception 'INVALID_POINTS'; end if;
 if p_customer_id<>(select id from customer.customers where auth_user_id=a limit 1)
   and not platform.has_permission(a,'orders.manage') then raise exception 'FORBIDDEN'; end if;
 insert into customer.point_accounts(customer_id,balance) values(p_customer_id,greatest(0,p_points))
 on conflict(customer_id) do update set balance=greatest(0,customer.point_accounts.balance+p_points),updated_at=now()
 returning * into pa;
 insert into customer.point_transactions(point_account_id,transaction_type,points,reference_type,reference_id)
 values(pa.id,p_type,p_points,p_reference_type,p_reference_id);
 return pa;
end $$;
revoke all on function customer.award_points(uuid,numeric,text,text,uuid) from public;
grant execute on function customer.award_points(uuid,numeric,text,text,uuid) to authenticated;

create or replace view analytics.customer_360 with (security_invoker=true) as
select c.id customer_id,c.email,c.phone,c.created_at,
       coalesce(cm.order_count,0) order_count,coalesce(cm.lifetime_revenue,0) lifetime_revenue,
       coalesce(cm.lifetime_profit,0) lifetime_profit,cm.average_order_value,
       cm.first_order_at,cm.last_order_at,cm.clv_estimate,cm.segment
from customer.customers c left join analytics.customer_metrics cm on cm.customer_id=c.id;

create or replace view analytics.product_profitability with (security_invoker=true) as
select v.id product_variant_id,v.sku,p.name_ar,p.name_en,
       coalesce(pm.units_sold,0) units_sold,coalesce(pm.revenue,0) revenue,
       coalesce(pm.gross_margin,0) gross_margin,coalesce(pc.material_cost+pc.labor_cost+pc.energy_cost+pc.packaging_cost+
       pc.shipping_allocation+pc.marketing_allocation+pc.payment_fee_allocation+pc.return_risk_allocation+pc.other_cost,0) true_unit_cost
from catalog.product_variants v join catalog.products p on p.id=v.product_id
left join analytics.product_metrics pm on pm.product_variant_id=v.id
left join finance.product_costs pc on pc.product_variant_id=v.id;

alter table customer.checkout_sessions enable row level security;
alter table customer.buy_again_signals enable row level security;
alter table customer.referral_links enable row level security;
alter table customer.preference_consents enable row level security;
alter table analytics.kpis_daily enable row level security;
alter table analytics.customer_metrics enable row level security;
alter table analytics.product_metrics enable row level security;
alter table platform.webhook_deliveries enable row level security;
alter table platform.ai_tool_permissions enable row level security;
alter table platform.api_keys enable row level security;

drop policy if exists "checkout session owner" on customer.checkout_sessions;
create policy "checkout session owner" on customer.checkout_sessions for all to authenticated
using(customer_id=(select id from customer.customers where auth_user_id=(select auth.uid()) limit 1))
with check(customer_id=(select id from customer.customers where auth_user_id=(select auth.uid()) limit 1));
drop policy if exists "buy again owner" on customer.buy_again_signals;
create policy "buy again owner" on customer.buy_again_signals for select to authenticated
using(customer_id=(select id from customer.customers where auth_user_id=(select auth.uid()) limit 1) or platform.has_permission((select auth.uid()),'orders.read'));
drop policy if exists "preferences owner" on customer.preference_consents;
create policy "preferences owner" on customer.preference_consents for all to authenticated
using(customer_id=(select id from customer.customers where auth_user_id=(select auth.uid()) limit 1))
with check(customer_id=(select id from customer.customers where auth_user_id=(select auth.uid()) limit 1));
drop policy if exists "referral links owner" on customer.referral_links;
create policy "referral links owner" on customer.referral_links for all to authenticated
using(customer_id=(select id from customer.customers where auth_user_id=(select auth.uid()) limit 1))
with check(customer_id=(select id from customer.customers where auth_user_id=(select auth.uid()) limit 1));
drop policy if exists "analytics staff" on analytics.kpis_daily;
create policy "analytics staff" on analytics.kpis_daily for select to authenticated using(platform.has_permission((select auth.uid()),'orders.read'));
drop policy if exists "customer metrics staff" on analytics.customer_metrics;
create policy "customer metrics staff" on analytics.customer_metrics for select to authenticated using(platform.has_permission((select auth.uid()),'orders.read'));
drop policy if exists "product metrics staff" on analytics.product_metrics;
create policy "product metrics staff" on analytics.product_metrics for select to authenticated using(platform.has_permission((select auth.uid()),'orders.read'));
drop policy if exists "webhook staff" on platform.webhook_deliveries;
create policy "webhook staff" on platform.webhook_deliveries for all to authenticated using(platform.has_permission((select auth.uid()),'orders.manage')) with check(platform.has_permission((select auth.uid()),'orders.manage'));
drop policy if exists "ai tool staff" on platform.ai_tool_permissions;
create policy "ai tool staff" on platform.ai_tool_permissions for select to authenticated using(platform.has_permission((select auth.uid()),'orders.manage'));
drop policy if exists "api keys staff" on platform.api_keys;
create policy "api keys staff" on platform.api_keys for all to authenticated using(platform.has_permission((select auth.uid()),'orders.manage')) with check(platform.has_permission((select auth.uid()),'orders.manage'));

insert into platform.ai_tool_permissions(tool_code,enabled,risk_level,read_only,allowed_roles,description) values
('catalog.read',true,'low',true,array['super_admin','manager','customer_service'],'Approved product/catalog read model'),
('customer.360',true,'medium',true,array['super_admin','manager','customer_service'],'Customer 360 read model'),
('analytics.profit',true,'medium',true,array['super_admin','manager','finance'],'Profitability read model'),
('commerce.checkout',false,'high',false,array['super_admin'],'Checkout mutation requires explicit approval'),
('finance.refund',false,'high',false,array['super_admin','finance'],'Refund mutation requires explicit approval')
on conflict(tool_code) do nothing;

comment on view analytics.customer_360 is 'AI-safe read model; mutations must use ai.action_requests approval flow.';
comment on view analytics.product_profitability is 'Operational profitability model; tax/accounting treatment remains configurable business policy.';
