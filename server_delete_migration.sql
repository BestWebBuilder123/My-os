create or replace function public.vus_delete_server(p_server_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_owner uuid; v_slug text; begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 select owner_id,slug into v_owner,v_slug from public.vus_servers where id=p_server_id for update;
 if not found then raise exception 'Server not found'; end if;
 if v_owner is distinct from auth.uid() then raise exception 'Only the server owner can delete this server'; end if;
 if v_slug='ixxl-chat' then raise exception 'The default Ixxl Chat server cannot be deleted'; end if;
 delete from public.vus_servers where id=p_server_id; end $$;
revoke all on function public.vus_delete_server(uuid) from public,anon;
grant execute on function public.vus_delete_server(uuid) to authenticated;
