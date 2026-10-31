-- Ixxl Chat server owner controls
-- Applied to Supabase project cdvzhfqhzbmvgechmknn.

create table if not exists public.vus_server_bans (
  server_id uuid not null references public.vus_servers(id) on delete cascade,
  user_id uuid not null references public.vus_profiles(id) on delete cascade,
  banned_by uuid not null references public.vus_profiles(id),
  reason text,
  created_at timestamptz not null default now(),
  primary key (server_id, user_id)
);
alter table public.vus_server_bans enable row level security;
revoke all on public.vus_server_bans from anon, authenticated;

create or replace function public.vus_owner_ban_server_members(
  p_server_id uuid,
  p_except_user_ids uuid[] default '{}'::uuid[],
  p_reason text default null
) returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid; v_count integer;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select owner_id into v_owner from public.vus_servers where id=p_server_id for update;
  if not found then raise exception 'Server not found'; end if;
  if v_owner is distinct from auth.uid() then raise exception 'Only the server owner can ban server members'; end if;
  insert into public.vus_server_bans(server_id,user_id,banned_by,reason)
  select p_server_id,m.user_id,auth.uid(),left(coalesce(p_reason,''),300)
  from public.vus_server_members m
  join public.vus_profiles p on p.id=m.user_id
  where m.server_id=p_server_id and m.user_id<>auth.uid()
    and coalesce(p.rank,'unranked')<>'owner'
    and not (m.user_id=any(coalesce(p_except_user_ids,'{}'::uuid[])))
  on conflict(server_id,user_id) do update
    set banned_by=excluded.banned_by,reason=excluded.reason,created_at=now();
  get diagnostics v_count=row_count;
  delete from public.vus_server_members m
  where m.server_id=p_server_id and m.user_id<>auth.uid()
    and coalesce((select p.rank from public.vus_profiles p where p.id=m.user_id),'unranked')<>'owner'
    and not (m.user_id=any(coalesce(p_except_user_ids,'{}'::uuid[])));
  return v_count;
end $$;

create or replace function public.vus_update_server_visibility(p_server_id uuid,p_visibility text)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid; v_code text;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if p_visibility not in ('public','private') then raise exception 'Invalid visibility'; end if;
  select owner_id into v_owner from public.vus_servers where id=p_server_id for update;
  if not found then raise exception 'Server not found'; end if;
  if v_owner is distinct from auth.uid() then raise exception 'Only the server owner can change visibility'; end if;
  if p_visibility='private' then
    update public.vus_servers set visibility='private',
      invite_code=coalesce(invite_code,upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)))
      where id=p_server_id returning invite_code into v_code;
  else
    update public.vus_servers set visibility='public',invite_code=null where id=p_server_id;
    v_code:=null;
  end if;
  return v_code;
end $$;

create or replace function public.vus_join_server(p_code_or_name text)
returns uuid language plpgsql security definer set search_path=public as $$
declare s public.vus_servers%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into s from public.vus_servers
  where (visibility='public' and lower(name)=lower(btrim(p_code_or_name)))
     or (visibility='private' and upper(invite_code)=upper(btrim(p_code_or_name))) limit 1;
  if s.id is null then raise exception 'No public server found with that name or matching invite code'; end if;
  if exists(select 1 from public.vus_server_bans b where b.server_id=s.id and b.user_id=auth.uid()) then
    raise exception 'You are banned from this server';
  end if;
  insert into public.vus_server_members(server_id,user_id,member_role)
  values(s.id,auth.uid(),'member') on conflict do nothing;
  return s.id;
end $$;

revoke execute on function public.vus_owner_ban_server_members(uuid,uuid[],text) from public,anon;
revoke execute on function public.vus_update_server_visibility(uuid,text) from public,anon;
revoke execute on function public.vus_join_server(text) from public,anon;
grant execute on function public.vus_owner_ban_server_members(uuid,uuid[],text) to authenticated;
grant execute on function public.vus_update_server_visibility(uuid,text) to authenticated;
grant execute on function public.vus_join_server(text) to authenticated;
