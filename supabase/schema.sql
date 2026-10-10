-- Run in Supabase SQL Editor as the project owner. No service-role key is used by the app.
create table if not exists public.deals (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(name) between 1 and 80),
  data jsonb not null,
  created_at timestamptz not null default now(),
  constraint deal_shape check (coalesce(jsonb_typeof(data) = 'object' and data->>'id' = id::text and jsonb_typeof(data->'documents') = 'array' and jsonb_array_length(data->'documents') <= 15 and octet_length(data::text) <= 2000000, false))
);
create index if not exists deals_owner_idx on public.deals(user_id);
alter table public.deals enable row level security;
drop policy if exists "Owner can manage deals" on public.deals;
create policy "Owner can manage deals" on public.deals for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
grant select, insert, update, delete on public.deals to authenticated;
revoke all on public.deals from anon;

-- Persistent account-wide cooldown prevents concurrent billable runs across app instances.
create table if not exists public.analysis_limits(user_id uuid primary key references auth.users(id) on delete cascade, last_started timestamptz not null);
alter table public.analysis_limits enable row level security;
revoke all on public.analysis_limits from anon, authenticated;
create or replace function public.claim_analysis(target_deal uuid) returns boolean language plpgsql security definer set search_path = '' as $$
declare accepted integer;
begin
 if auth.uid() is null or not exists(select 1 from public.deals where id=target_deal and user_id=auth.uid()) then return false; end if;
 insert into public.analysis_limits(user_id,last_started) values(auth.uid(),now())
 on conflict(user_id) do update set last_started=excluded.last_started where public.analysis_limits.last_started < now()-interval '10 minutes';
 get diagnostics accepted = row_count;
 return accepted = 1;
end;
$$;
revoke all on function public.claim_analysis(uuid) from public, anon;
grant execute on function public.claim_analysis(uuid) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit) values('documents','documents',false,10485760)
on conflict(id) do update set public=false,file_size_limit=10485760;
-- Paths: account UUID / owned deal UUID / unique filename.
drop policy if exists "Read own documents" on storage.objects;
drop policy if exists "Upload own documents" on storage.objects;
drop policy if exists "Delete own documents" on storage.objects;
create policy "Read own documents" on storage.objects for select to authenticated using (bucket_id='documents' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "Upload own documents" on storage.objects for insert to authenticated with check (bucket_id='documents' and (storage.foldername(name))[1]=(select auth.uid())::text and exists(select 1 from public.deals d where d.id::text=(storage.foldername(name))[2] and d.user_id=(select auth.uid())));
create policy "Delete own documents" on storage.objects for delete to authenticated using (bucket_id='documents' and (storage.foldername(name))[1]=(select auth.uid())::text);

-- Merge only the report atomically: long analyses never replace newer document/metadata edits.
create or replace function public.save_analysis_report(target_deal uuid, generated_report jsonb) returns boolean
language plpgsql security invoker set search_path = '' as $$
declare accepted integer;
begin
 if auth.uid() is null then return false; end if;
 update public.deals set data=data || jsonb_build_object('report',generated_report,'updated','Just now')
 where id=target_deal and user_id=auth.uid();
 get diagnostics accepted=row_count;
 return accepted=1;
end;
$$;
revoke all on function public.save_analysis_report(uuid,jsonb) from public, anon;
grant execute on function public.save_analysis_report(uuid,jsonb) to authenticated;

-- Workspace migration (safe for both fresh projects and the earlier deal-only schema).
create table if not exists public.workspaces (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 name text not null check(length(name) between 1 and 80),
 created_at timestamptz not null default now()
);
create index if not exists workspaces_owner_idx on public.workspaces(user_id);
alter table public.workspaces enable row level security;
drop policy if exists "Owner manages workspaces" on public.workspaces;
create policy "Owner manages workspaces" on public.workspaces for all to authenticated
 using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
grant select,insert,update on public.workspaces to authenticated;
revoke all on public.workspaces from anon;
alter table public.deals add column if not exists workspace_id uuid references public.workspaces(id);
-- Existing actual account records get an owned container; empty accounts stay empty.
insert into public.workspaces(user_id,name)
 select distinct d.user_id,'Imported workspace' from public.deals d
 where not exists(select 1 from public.workspaces w where w.user_id=d.user_id);
update public.deals d set workspace_id=(select w.id from public.workspaces w where w.user_id=d.user_id order by w.created_at limit 1)
 where d.workspace_id is null;
update public.deals set data=data||jsonb_build_object('workspaceId',workspace_id::text)
 where data->>'workspaceId' is distinct from workspace_id::text;
alter table public.deals alter column workspace_id set not null;
create index if not exists deals_workspace_idx on public.deals(workspace_id);
drop policy if exists "Owner can manage deals" on public.deals;
create policy "Owner can manage deals" on public.deals for all to authenticated
 using(user_id=(select auth.uid()))
 with check(user_id=(select auth.uid()) and exists(select 1 from public.workspaces w where w.id=workspace_id and w.user_id=(select auth.uid())) and coalesce(data->>'workspaceId'=workspace_id::text,false));

-- Ordinary record edits also merge into current server state and never replace a report.
create or replace function public.patch_deal(target_deal uuid, fields jsonb) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare result jsonb; delta jsonb;
begin
 if auth.uid() is null or coalesce(jsonb_typeof(fields),'') <> 'object' then return null; end if;
 delta=fields-'id'-'workspaceId'-'report';
 update public.deals set data=data||delta,
 name=case when delta ? 'name' then delta->>'name' else name end
 where id=target_deal and user_id=auth.uid() returning data into result;
 return result;
end;
$$;
revoke all on function public.patch_deal(uuid,jsonb) from public,anon;
grant execute on function public.patch_deal(uuid,jsonb) to authenticated;
