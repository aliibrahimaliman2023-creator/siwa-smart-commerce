create extension if not exists pgcrypto;
create schema if not exists identity;
create schema if not exists platform;
create schema if not exists customer;
create schema if not exists catalog;
create schema if not exists commerce;
create schema if not exists inventory;
create schema if not exists production;
create schema if not exists logistics;
create schema if not exists marketing;
create schema if not exists communication;
create schema if not exists cms;
create schema if not exists finance;
create schema if not exists ai;

create type platform.job_status as enum ('queued','running','completed','failed','retrying','cancelled');
create type platform.flag_type as enum ('boolean','percentage','string','json');

create table identity.user_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 public_id text not null unique default ('USR-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12))),
 display_name text, phone text, locale text not null default 'ar-EG',
 timezone text not null default 'Africa/Cairo', is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table identity.roles (id uuid primary key default gen_random_uuid(), code text unique not null, name text not null, description text, is_system boolean not null default false, created_at timestamptz not null default now());
create table identity.permissions (id uuid primary key default gen_random_uuid(), code text unique not null, name text not null, description text, created_at timestamptz not null default now());
create table identity.user_roles (user_id uuid not null references identity.user_profiles(id) on delete cascade, role_id uuid not null references identity.roles(id) on delete cascade, assigned_by uuid references identity.user_profiles(id), assigned_at timestamptz not null default now(), primary key(user_id,role_id));
create table identity.role_permissions (role_id uuid not null references identity.roles(id) on delete cascade, permission_id uuid not null references identity.permissions(id) on delete cascade, primary key(role_id,permission_id));

create table platform.platform_settings (id uuid primary key default gen_random_uuid(), setting_key text unique not null, value_json jsonb not null default '{}', is_public boolean not null default false, updated_by uuid references identity.user_profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table platform.feature_flags (id uuid primary key default gen_random_uuid(), flag_key text unique not null, flag_type platform.flag_type not null, enabled boolean not null default false, percentage int check(percentage between 0 and 100), value_json jsonb, environment text not null default 'development', created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table platform.audit_logs (id uuid primary key default gen_random_uuid(), actor_id uuid references identity.user_profiles(id), action text not null, entity_type text not null, entity_id uuid, before_json jsonb, after_json jsonb, reason text, request_id uuid, created_at timestamptz not null default now());
create table platform.system_events (event_id uuid primary key default gen_random_uuid(), event_type text not null, aggregate_type text not null, aggregate_id uuid, occurred_at timestamptz not null default now(), actor_id uuid references identity.user_profiles(id), payload jsonb not null default '{}', schema_version int not null default 1, created_at timestamptz not null default now());
create table platform.background_jobs (id uuid primary key default gen_random_uuid(), job_type text not null, status platform.job_status not null default 'queued', payload jsonb not null default '{}', attempts int not null default 0, max_attempts int not null default 5, available_at timestamptz not null default now(), locked_at timestamptz, completed_at timestamptz, last_error text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table platform.idempotency_keys (id uuid primary key default gen_random_uuid(), key text not null, operation text not null, actor_id uuid references identity.user_profiles(id), request_hash text, response_status int, response_json jsonb, expires_at timestamptz, created_at timestamptz not null default now(), unique(operation,key));
create table platform.files (id uuid primary key default gen_random_uuid(), bucket text not null, object_path text not null, file_name text not null, mime_type text, size_bytes bigint check(size_bytes>=0), owner_id uuid references identity.user_profiles(id), visibility text not null default 'private' check(visibility in ('private','public')), metadata jsonb not null default '{}', created_at timestamptz not null default now(), unique(bucket,object_path));

create index idx_user_roles_role on identity.user_roles(role_id);
create index idx_role_permissions_permission on identity.role_permissions(permission_id);
create index idx_audit_entity on platform.audit_logs(entity_type,entity_id,created_at desc);
create index idx_events_aggregate on platform.system_events(aggregate_type,aggregate_id,occurred_at desc);
create index idx_jobs_status on platform.background_jobs(status,available_at);

create or replace function platform.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end; $$;
create trigger trg_user_profiles_updated before update on identity.user_profiles for each row execute function platform.touch_updated_at();
create trigger trg_settings_updated before update on platform.platform_settings for each row execute function platform.touch_updated_at();
create trigger trg_flags_updated before update on platform.feature_flags for each row execute function platform.touch_updated_at();
create trigger trg_jobs_updated before update on platform.background_jobs for each row execute function platform.touch_updated_at();

create or replace function platform.has_permission(p_user_id uuid,p_permission text)
returns boolean language sql stable security definer set search_path=identity,public as $$
select exists(select 1 from identity.user_roles ur join identity.role_permissions rp on rp.role_id=ur.role_id join identity.permissions p on p.id=rp.permission_id where ur.user_id=p_user_id and p.code=p_permission);
$$;

create or replace function platform.record_event(p_event_type text,p_aggregate_type text,p_aggregate_id uuid,p_actor_id uuid,p_payload jsonb,p_schema_version int default 1)
returns uuid language plpgsql security definer set search_path=platform,public as $$
declare v_id uuid; begin insert into platform.system_events(event_type,aggregate_type,aggregate_id,actor_id,payload,schema_version) values(p_event_type,p_aggregate_type,p_aggregate_id,p_actor_id,coalesce(p_payload,'{}'),p_schema_version) returning event_id into v_id; return v_id; end; $$;

alter table identity.user_profiles enable row level security;
alter table identity.roles enable row level security;
alter table identity.permissions enable row level security;
alter table identity.user_roles enable row level security;
alter table identity.role_permissions enable row level security;
alter table platform.platform_settings enable row level security;
alter table platform.feature_flags enable row level security;
alter table platform.audit_logs enable row level security;
alter table platform.system_events enable row level security;
alter table platform.background_jobs enable row level security;
alter table platform.idempotency_keys enable row level security;
alter table platform.files enable row level security;

create policy user_profile_select on identity.user_profiles for select to authenticated using(id=auth.uid() or platform.has_permission(auth.uid(),'users.read'));
create policy user_profile_update on identity.user_profiles for update to authenticated using(id=auth.uid() or platform.has_permission(auth.uid(),'users.update'));
create policy roles_select on identity.roles for select to authenticated using(platform.has_permission(auth.uid(),'roles.read'));
create policy permissions_select on identity.permissions for select to authenticated using(platform.has_permission(auth.uid(),'permissions.read'));
create policy user_roles_admin on identity.user_roles for all to authenticated using(platform.has_permission(auth.uid(),'roles.assign')) with check(platform.has_permission(auth.uid(),'roles.assign'));
create policy role_permissions_admin on identity.role_permissions for all to authenticated using(platform.has_permission(auth.uid(),'roles.manage')) with check(platform.has_permission(auth.uid(),'roles.manage'));
create policy settings_select on platform.platform_settings for select to anon,authenticated using(is_public or platform.has_permission(auth.uid(),'settings.read'));
create policy settings_admin on platform.platform_settings for all to authenticated using(platform.has_permission(auth.uid(),'settings.manage')) with check(platform.has_permission(auth.uid(),'settings.manage'));
create policy flags_select on platform.feature_flags for select to authenticated using(platform.has_permission(auth.uid(),'flags.read'));
create policy flags_admin on platform.feature_flags for all to authenticated using(platform.has_permission(auth.uid(),'flags.manage')) with check(platform.has_permission(auth.uid(),'flags.manage'));
create policy audit_select on platform.audit_logs for select to authenticated using(platform.has_permission(auth.uid(),'audit.read'));
create policy events_select on platform.system_events for select to authenticated using(platform.has_permission(auth.uid(),'events.read'));
create policy jobs_admin on platform.background_jobs for all to authenticated using(platform.has_permission(auth.uid(),'jobs.manage')) with check(platform.has_permission(auth.uid(),'jobs.manage'));
create policy idempotency_select on platform.idempotency_keys for select to authenticated using(actor_id=auth.uid() or platform.has_permission(auth.uid(),'idempotency.read'));
create policy files_select on platform.files for select to authenticated using(owner_id=auth.uid() or platform.has_permission(auth.uid(),'files.read'));

create or replace function identity.handle_new_auth_user() returns trigger language plpgsql security definer set search_path=identity,public as $$
begin insert into identity.user_profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',new.email)) on conflict(id) do nothing; return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function identity.handle_new_auth_user();
