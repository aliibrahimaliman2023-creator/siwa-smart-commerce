-- 0022_growth_rls_completion.sql
drop policy if exists growth_referral_events_read on growth.referral_events;
create policy growth_referral_events_read on growth.referral_events for select to authenticated using(exists(select 1 from growth.referrals r where r.id=referral_events.referral_id and (r.referrer_customer_id=(select c.id from customer.customers c where c.auth_user_id=auth.uid()) or platform.has_permission(auth.uid(),'orders.manage'))));
drop policy if exists growth_referral_events_manage on growth.referral_events;
create policy growth_referral_events_manage on growth.referral_events for insert to authenticated with check(platform.has_permission(auth.uid(),'orders.manage'));