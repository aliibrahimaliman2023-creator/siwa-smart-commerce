-- 0021_ai_guardrails.sql
alter table ai.action_requests enable row level security;
alter table ai.recommendations enable row level security;
drop policy if exists ai_action_requests_read on ai.action_requests; create policy ai_action_requests_read on ai.action_requests for select to authenticated using(requested_by=auth.uid() or platform.has_permission(auth.uid(),'orders.manage'));
drop policy if exists ai_action_requests_create on ai.action_requests; create policy ai_action_requests_create on ai.action_requests for insert to authenticated with check(requested_by=auth.uid());
drop policy if exists ai_recommendations_read on ai.recommendations; create policy ai_recommendations_read on ai.recommendations for select to authenticated using(platform.has_permission(auth.uid(),'orders.read'));
create or replace function ai.request_action(p_action_type text,p_target_type text,p_target_id uuid,p_payload jsonb,p_risk_level text default 'medium')
returns ai.action_requests language plpgsql security definer set search_path=ai,public as $$
declare r ai.action_requests;
begin
 if auth.uid() is null then raise exception 'UNAUTHENTICATED'; end if;
 if p_risk_level not in ('low','medium','high','critical') then raise exception 'INVALID_RISK_LEVEL'; end if;
 insert into ai.action_requests(action_type,target_type,target_id,proposed_payload,risk_level,status,requested_by) values(p_action_type,p_target_type,p_target_id,coalesce(p_payload,'{}'),p_risk_level,'pending',auth.uid()) returning * into r;
 return r;
end; $$;
revoke all on function ai.request_action(text,text,uuid,jsonb,text) from public; grant execute on function ai.request_action(text,text,uuid,jsonb,text) to authenticated;
create or replace function ai.approve_action(p_action_id uuid)
returns ai.action_requests language plpgsql security definer set search_path=ai,platform,public as $$
declare r ai.action_requests;
begin
 if auth.uid() is null or not platform.has_permission(auth.uid(),'orders.manage') then raise exception 'FORBIDDEN'; end if;
 select * into r from ai.action_requests where id=p_action_id for update;
 if not found then raise exception 'AI_ACTION_NOT_FOUND'; end if;
 if r.status<>'pending' then raise exception 'AI_ACTION_NOT_PENDING'; end if;
 update ai.action_requests set status='approved',approved_by=auth.uid(),approved_at=now() where id=p_action_id returning * into r;
 return r;
end; $$;
revoke all on function ai.approve_action(uuid) from public; grant execute on function ai.approve_action(uuid) to authenticated;