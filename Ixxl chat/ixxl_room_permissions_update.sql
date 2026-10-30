-- Ixxl Chat room permissions update
-- This incremental migration has ALREADY been applied to project cdvzhfqhzbmvgechmknn.
-- It assumes the existing Ixxl Chat / VUS schema and existing channel/member tables.

ALTER TABLE public.vus_channels
  ADD COLUMN IF NOT EXISTS is_pinned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS manage_rank text NOT NULL DEFAULT 'owner',
  ADD COLUMN IF NOT EXISTS everyone_ping_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE public.vus_profiles
  ADD COLUMN IF NOT EXISTS everyone_ping_opt_out boolean NOT NULL DEFAULT false;
ALTER TABLE public.vus_channels DROP CONSTRAINT IF EXISTS vus_channels_manage_rank_check;
ALTER TABLE public.vus_channels ADD CONSTRAINT vus_channels_manage_rank_check
  CHECK (manage_rank IN ('owner','co-owner','admin','mod','member','unranked'));

CREATE OR REPLACE FUNCTION public.vus_rank_level(p_rank text)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path=''
AS $$ SELECT CASE coalesce(p_rank,'unranked') WHEN 'owner' THEN 5 WHEN 'co-owner' THEN 4 WHEN 'admin' THEN 3 WHEN 'mod' THEN 2 WHEN 'member' THEN 1 ELSE 0 END $$;

DROP POLICY IF EXISTS vus_channels_select_accessible ON public.vus_channels;
CREATE POLICY vus_channels_select_accessible ON public.vus_channels FOR SELECT TO authenticated USING (
  channel_type='dm' OR server_id IS NULL OR EXISTS (
    SELECT 1 FROM public.vus_servers s WHERE s.id=vus_channels.server_id
      AND (s.visibility='public' OR EXISTS (SELECT 1 FROM public.vus_server_members m WHERE m.server_id=s.id AND m.user_id=(SELECT auth.uid())))
      AND public.vus_rank_level((SELECT p.rank FROM public.vus_profiles p WHERE p.id=(SELECT auth.uid()))) >= public.vus_rank_level(coalesce(vus_channels.required_rank,'unranked'))
  )
);

CREATE OR REPLACE FUNCTION public.vus_delete_server_channel(p_channel_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c public.vus_channels%rowtype; actor_rank text; server_owner uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  SELECT * INTO c FROM public.vus_channels WHERE id=p_channel_id FOR UPDATE;
  IF NOT FOUND OR c.server_id IS NULL THEN RAISE EXCEPTION 'Room not found'; END IF;
  SELECT owner_id INTO server_owner FROM public.vus_servers WHERE id=c.server_id;
  SELECT rank INTO actor_rank FROM public.vus_profiles WHERE id=auth.uid();
  IF coalesce(actor_rank,'unranked') NOT IN ('owner','co-owner','admin','mod') AND server_owner IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Staff permissions required to delete rooms'; END IF;
  IF c.slug='main' OR lower(c.name)='main' OR c.is_pinned OR lower(c.name)='general' THEN RAISE EXCEPTION 'This room is protected'; END IF;
  DELETE FROM public.vus_channels WHERE id=p_channel_id;
END $$;

CREATE OR REPLACE FUNCTION public.vus_update_channel_settings(
  p_channel_id uuid,p_name text DEFAULT NULL,p_image_url text DEFAULT NULL,p_pinned boolean DEFAULT NULL,
  p_required_rank text DEFAULT NULL,p_manage_rank text DEFAULT NULL,p_everyone_ping boolean DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE c public.vus_channels%rowtype; server_owner uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  SELECT * INTO c FROM public.vus_channels WHERE id=p_channel_id FOR UPDATE;
  IF NOT FOUND OR c.server_id IS NULL THEN RAISE EXCEPTION 'Room not found'; END IF;
  SELECT owner_id INTO server_owner FROM public.vus_servers WHERE id=c.server_id;
  IF server_owner IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Only this server owner can edit room settings'; END IF;
  IF c.slug='main' OR lower(c.name)='main' THEN
    IF p_name IS NOT NULL OR p_image_url IS NOT NULL OR p_pinned IS NOT NULL THEN RAISE EXCEPTION 'The main room settings are protected'; END IF;
  END IF;
  IF p_name IS NOT NULL THEN
    IF length(btrim(p_name)) NOT BETWEEN 2 AND 32 OR btrim(p_name) !~ '^[A-Za-z0-9][A-Za-z0-9_-]*$' THEN RAISE EXCEPTION 'Room name must be 2-32 letters, numbers, hyphens or underscores'; END IF;
    IF EXISTS(SELECT 1 FROM public.vus_channels x WHERE x.server_id=c.server_id AND x.id<>c.id AND lower(x.name)=lower(btrim(p_name))) THEN RAISE EXCEPTION 'That room name is already used'; END IF;
    UPDATE public.vus_channels SET name=btrim(p_name),slug=CASE WHEN slug='main' THEN slug ELSE 'ch-'||substr(replace(gen_random_uuid()::text,'-',''),1,16) END WHERE id=p_channel_id;
  END IF;
  IF p_image_url IS NOT NULL THEN UPDATE public.vus_channels SET image_url=nullif(btrim(p_image_url),'') WHERE id=p_channel_id; END IF;
  IF p_pinned IS NOT NULL THEN UPDATE public.vus_channels SET is_pinned=p_pinned WHERE id=p_channel_id; END IF;
  IF p_required_rank IS NOT NULL THEN
    IF p_required_rank NOT IN ('owner','co-owner','admin','mod','member','unranked') THEN RAISE EXCEPTION 'Invalid view rank'; END IF;
    UPDATE public.vus_channels SET required_rank=CASE WHEN p_required_rank='unranked' THEN NULL ELSE p_required_rank END WHERE id=p_channel_id;
  END IF;
  IF p_manage_rank IS NOT NULL THEN
    IF p_manage_rank NOT IN ('owner','co-owner','admin','mod','member','unranked') THEN RAISE EXCEPTION 'Invalid manage rank'; END IF;
    UPDATE public.vus_channels SET manage_rank=p_manage_rank WHERE id=p_channel_id;
  END IF;
  IF p_everyone_ping IS NOT NULL THEN UPDATE public.vus_channels SET everyone_ping_enabled=p_everyone_ping WHERE id=p_channel_id; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.vus_moderate_channel(p_channel_id uuid,p_action text,p_value integer DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE actor_rank text; c public.vus_channels%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  SELECT rank INTO actor_rank FROM public.vus_profiles WHERE id=auth.uid();
  SELECT * INTO c FROM public.vus_channels WHERE id=p_channel_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Room not found'; END IF;
  IF c.slug='main' OR lower(c.name)='main' OR c.is_pinned OR lower(c.name)='general' THEN RAISE EXCEPTION 'This room is protected from moderation actions'; END IF;
  IF public.vus_rank_level(actor_rank)<public.vus_rank_level(c.manage_rank) THEN RAISE EXCEPTION 'Your rank does not have permission to manage this room'; END IF;
  IF p_action='purge' THEN
    IF p_value IS NULL OR p_value<=0 THEN DELETE FROM public.vus_messages WHERE channel_id=p_channel_id;
    ELSIF p_value>100 THEN RAISE EXCEPTION 'Purge count must be between 1 and 100';
    ELSE DELETE FROM public.vus_messages WHERE id IN (SELECT id FROM public.vus_messages WHERE channel_id=p_channel_id ORDER BY created_at DESC,id DESC LIMIT p_value); END IF;
  ELSIF p_action='lock' THEN UPDATE public.vus_channels SET is_locked=true WHERE id=p_channel_id;
  ELSIF p_action='unlock' THEN UPDATE public.vus_channels SET is_locked=false WHERE id=p_channel_id;
  ELSIF p_action='slowmode' THEN
    IF p_value IS NULL OR p_value<0 OR p_value>300 THEN RAISE EXCEPTION 'Slowmode must be 0 to 300 seconds'; END IF;
    UPDATE public.vus_channels SET slowmode_seconds=p_value WHERE id=p_channel_id;
  ELSE RAISE EXCEPTION 'Unknown moderation action'; END IF;
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION public.vus_owner_ban_room_members(p_channel_id uuid,p_reason text DEFAULT NULL)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE actor_rank text; n integer; c public.vus_channels%rowtype;
BEGIN
  SELECT rank INTO actor_rank FROM public.vus_profiles WHERE id=auth.uid();
  IF actor_rank<>'owner' THEN RAISE EXCEPTION 'Owner only'; END IF;
  SELECT * INTO c FROM public.vus_channels WHERE id=p_channel_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Room not found'; END IF;
  IF c.slug='main' OR lower(c.name)='main' OR c.is_pinned OR lower(c.name)='general' THEN RAISE EXCEPTION 'This room is protected from room-wide actions'; END IF;
  IF c.server_id IS NOT NULL THEN
    INSERT INTO public.vus_channel_bans(channel_id,user_id,banned_by,reason)
    SELECT p_channel_id,m.user_id,auth.uid(),left(coalesce(p_reason,''),300) FROM public.vus_server_members m JOIN public.vus_profiles p ON p.id=m.user_id
    WHERE m.server_id=c.server_id AND m.user_id<>auth.uid() AND coalesce(p.rank,'unranked')<>'owner' ON CONFLICT(channel_id,user_id) DO NOTHING;
  ELSE
    INSERT INTO public.vus_channel_bans(channel_id,user_id,banned_by,reason)
    SELECT p_channel_id,m.user_id,auth.uid(),left(coalesce(p_reason,''),300) FROM public.vus_channel_members m JOIN public.vus_profiles p ON p.id=m.user_id
    WHERE m.channel_id=p_channel_id AND m.user_id<>auth.uid() AND coalesce(p.rank,'unranked')<>'owner' ON CONFLICT(channel_id,user_id) DO NOTHING;
  END IF;
  GET DIAGNOSTICS n=ROW_COUNT;
  INSERT INTO public.vus_command_logs(actor_id,command,details) VALUES(auth.uid(),'roombanall',jsonb_build_object('channel_id',p_channel_id,'count',n,'reason',left(coalesce(p_reason,''),300)));
  RETURN n;
END $$;

CREATE OR REPLACE FUNCTION public.vus_ban_user(p_target_user uuid,p_reason text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE r text; tr text;
BEGIN
  SELECT rank INTO r FROM public.vus_profiles WHERE id=auth.uid(); SELECT rank INTO tr FROM public.vus_profiles WHERE id=p_target_user;
  IF r NOT IN ('owner','co-owner','admin') THEN RAISE EXCEPTION 'Admin+ required'; END IF;
  IF p_target_user=auth.uid() THEN RAISE EXCEPTION 'You cannot ban yourself'; END IF;
  IF tr='owner' THEN RAISE EXCEPTION 'The owner is protected from all moderation actions'; END IF;
  IF tr='co-owner' AND r<>'owner' THEN RAISE EXCEPTION 'Only the owner may moderate co-owners'; END IF;
  UPDATE public.vus_profiles SET banned=true,ban_reason=left(coalesce(p_reason,''),300),banned_at=now() WHERE id=p_target_user;
  IF NOT FOUND THEN RAISE EXCEPTION 'User not found'; END IF;
  INSERT INTO public.vus_command_logs(actor_id,command,target_id,details) VALUES(auth.uid(),'ban',p_target_user,jsonb_build_object('reason',left(coalesce(p_reason,''),300)));
END $$;

CREATE OR REPLACE FUNCTION public.vus_unban_user(p_target_user uuid,p_reason text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE r text; tr text;
BEGIN
  SELECT rank INTO r FROM public.vus_profiles WHERE id=auth.uid(); SELECT rank INTO tr FROM public.vus_profiles WHERE id=p_target_user;
  IF r NOT IN ('owner','co-owner','admin') THEN RAISE EXCEPTION 'Admin+ required'; END IF;
  IF tr='owner' THEN RAISE EXCEPTION 'The owner is protected from all moderation actions'; END IF;
  UPDATE public.vus_profiles SET banned=false,ban_reason=null,banned_at=null WHERE id=p_target_user;
  IF NOT FOUND THEN RAISE EXCEPTION 'User not found'; END IF;
  INSERT INTO public.vus_command_logs(actor_id,command,target_id,details) VALUES(auth.uid(),'unban',p_target_user,jsonb_build_object('reason',left(coalesce(p_reason,''),300)));
END $$;

CREATE OR REPLACE FUNCTION public.vus_set_rank(p_target_user uuid,p_new_rank text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE actor_rank text; target_rank text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required'; END IF;
  IF p_new_rank NOT IN ('owner','co-owner','admin','mod','member','unranked') THEN RAISE EXCEPTION 'Invalid rank'; END IF;
  SELECT rank INTO actor_rank FROM public.vus_profiles WHERE id=auth.uid(); SELECT rank INTO target_rank FROM public.vus_profiles WHERE id=p_target_user FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'User not found'; END IF;
  IF target_rank='owner' THEN RAISE EXCEPTION 'The owner is protected from all rank changes'; END IF;
  IF actor_rank='owner' THEN IF p_new_rank='owner' THEN RAISE EXCEPTION 'Owner rank cannot be assigned through this action'; END IF;
  ELSIF actor_rank='co-owner' THEN IF p_new_rank NOT IN ('admin','mod','member','unranked') OR target_rank IN ('owner','co-owner') THEN RAISE EXCEPTION 'Co-owner rank permissions do not allow that change'; END IF;
  ELSIF actor_rank='admin' THEN IF p_new_rank NOT IN ('mod','member','unranked') OR target_rank IN ('owner','co-owner','admin') THEN RAISE EXCEPTION 'Admin rank permissions do not allow that change'; END IF;
  ELSE RAISE EXCEPTION 'Admin permissions required'; END IF;
  UPDATE public.vus_profiles SET rank=p_new_rank,updated_at=now() WHERE id=p_target_user;
  RETURN true;
END $$;

REVOKE EXECUTE ON FUNCTION public.vus_rank_level(text) FROM PUBLIC,anon;
REVOKE EXECUTE ON FUNCTION public.vus_update_channel_settings(uuid,text,text,boolean,text,text,boolean) FROM PUBLIC,anon;
REVOKE EXECUTE ON FUNCTION public.vus_delete_server_channel(uuid) FROM PUBLIC,anon;
REVOKE EXECUTE ON FUNCTION public.vus_owner_ban_room_members(uuid,text) FROM PUBLIC,anon;
REVOKE EXECUTE ON FUNCTION public.vus_moderate_channel(uuid,text,integer) FROM PUBLIC,anon;
REVOKE EXECUTE ON FUNCTION public.vus_ban_user(uuid,text) FROM PUBLIC,anon;
REVOKE EXECUTE ON FUNCTION public.vus_unban_user(uuid,text) FROM PUBLIC,anon;
REVOKE EXECUTE ON FUNCTION public.vus_set_rank(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.vus_rank_level(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vus_update_channel_settings(uuid,text,text,boolean,text,text,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vus_delete_server_channel(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vus_owner_ban_room_members(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vus_moderate_channel(uuid,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vus_ban_user(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vus_unban_user(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vus_set_rank(uuid,text) TO authenticated;
