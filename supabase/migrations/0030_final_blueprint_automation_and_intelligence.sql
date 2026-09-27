-- 0030_final_blueprint_automation_and_intelligence.sql
create or replace function platform.enqueue_automation_for_event(p_event_id uuid)
returns integer language plpgsql security definer set search_path=platform,public as $$
declare e platform.system_events; a record; n integer:=0;
begin
 select * into e from platform.system_events where id=p_event_id;
 if not found then raise exception 'EVENT_NOT_FOUND'; end if;
 for a in select id from platform.automations where status='active' and (trigger->>'event_type')=e.event_type loop
   insert into platform.automation_runs(automation_id,event_id,status,current_step,context)
   values(a.id,e.id,'queued',0,coalesce(e.payload,'{}'))
   on conflict do nothing;
   n:=n+1;
 end loop;
 return n;
end $$;
revoke all on function platform.enqueue_automation_for_event(uuid) from public;
grant execute on function platform.enqueue_automation_for_event(uuid) to authenticated;

create or replace function platform.run_automation(p_run_id uuid,p_max_steps integer default 20)
returns platform.automation_runs language plpgsql security definer set search_path=platform,communication,customer,public as $$
declare r platform.automation_runs; a platform.automations; step jsonb; action jsonb; idx integer; msg_id uuid;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if not platform.has_permission(auth.uid(),'orders.manage') then raise exception 'FORBIDDEN'; end if;
 select * into r from platform.automation_runs where id=p_run_id for update;
 if not found then raise exception 'AUTOMATION_RUN_NOT_FOUND'; end if;
 select * into a from platform.automations where id=r.automation_id;
 if a.status<>'active' then update platform.automation_runs set status='cancelled',completed_at=now() where id=r.id returning * into r; return r; end if;
 update platform.automation_runs set status='running',started_at=coalesce(started_at,now()),attempts=attempts+1 where id=r.id returning * into r;
 for idx in r.current_step..least(jsonb_array_length(a.steps)-1,r.current_step+p_max_steps-1) loop
   step:=a.steps->idx; action:=coalesce(step->'action',step);
   if action->>'type'='log_event' then
     perform platform.record_event(coalesce(action->>'event_type','automation.action'),coalesce(action->>'aggregate_type','automation'),r.id,
       auth.uid(),coalesce(action->'payload','{}'),1);
   elsif action->>'type'='queue_message' then
     insert into communication.message_logs(template_id,customer_id,channel,recipient,status,payload)
     select null,null,coalesce(action->>'channel','email'),action->>'recipient','queued',coalesce(action->'payload','{}');
   elsif action->>'type'='create_ai_action' then
     insert into ai.action_requests(action_type,target_type,target_id,proposed_payload,risk_level,status,requested_by)
     values(action->>'action_type',action->>'target_type',null,coalesce(action->'payload','{}'),coalesce(action->>'risk_level','medium'),'pending',auth.uid());
   end if;
   r.current_step:=idx+1;
 end loop;
 if r.current_step>=jsonb_array_length(a.steps) then
   update platform.automation_runs set status='completed',current_step=r.current_step,completed_at=now() where id=r.id;
 else
   update platform.automation_runs set status='queued',current_step=r.current_step,scheduled_at=coalesce(r.scheduled_at,now()) where id=r.id;
 end if;
 select * into r from platform.automation_runs where id=r.id; return r;
end $$;
revoke all on function platform.run_automation(uuid,integer) from public;
grant execute on function platform.run_automation(uuid,integer) to authenticated;

create or replace function ai.generate_product_recommendations(p_customer_id uuid default null,p_product_id uuid default null)
returns integer language plpgsql security definer set search_path=ai,customer,catalog,public as $$
declare a uuid:=auth.uid(); c uuid; n integer:=0; r record;
begin
 if a is null then raise exception 'AUTH_REQUIRED'; end if;
 select id into c from customer.customers where auth_user_id=a limit 1;
 if p_customer_id is not null and p_customer_id<>c and not platform.has_permission(a,'orders.read') then raise exception 'FORBIDDEN'; end if;
 c:=coalesce(p_customer_id,c);
 if p_product_id is not null then
   for r in select pr.related_product_id,pr.score from catalog.product_relations pr where pr.product_id=p_product_id order by pr.score desc nulls last,pr.sort_order limit 12 loop
     insert into ai.recommendations(type,title,evidence,confidence,status)
     values('product_related','Recommended product',jsonb_build_object('customer_id',c,'source_product_id',p_product_id,'related_product_id',r.related_product_id),least(0.99,greatest(0.1,coalesce(r.score,0.5))),'active'); n:=n+1;
   end loop;
 else
   for r in select s.product_variant_id,s.score from customer.buy_again_signals s where s.customer_id=c order by s.score desc limit 12 loop
     insert into ai.recommendations(type,title,evidence,confidence,status)
     values('buy_again','Buy again',jsonb_build_object('customer_id',c,'product_variant_id',r.product_variant_id),least(0.99,greatest(0.1,r.score)),'active'); n:=n+1;
   end loop;
 end if;
 return n;
end $$;
revoke all on function ai.generate_product_recommendations(uuid,uuid) from public;
grant execute on function ai.generate_product_recommendations(uuid,uuid) to authenticated;

create or replace view ai.product_recommendation_feed with (security_invoker=true) as
select r.id,r.type,r.title,r.evidence,r.confidence,r.status,r.created_at from ai.recommendations r where r.status='active';

create or replace view commerce.checkout_recovery_queue with (security_invoker=true) as
select s.id,s.customer_id,s.session_key,s.failure_code,s.last_step,s.updated_at,
       case when s.failure_code='OUT_OF_STOCK' then 'inventory'
            when s.failure_code like 'COUPON_%' then 'promotion'
            when s.failure_code like 'SHIPPING_%' then 'shipping'
            when s.failure_code like 'PAYMENT_%' then 'payment'
            when s.failure_code='ADDRESS_INVALID' then 'address'
            else 'unknown' end as recovery_reason
from customer.checkout_sessions s
where s.status='open' and s.recovered_order_id is null
  and s.updated_at < now()-interval '15 minutes';

grant select on ai.product_recommendation_feed to authenticated;
grant select on commerce.checkout_recovery_queue to authenticated;
