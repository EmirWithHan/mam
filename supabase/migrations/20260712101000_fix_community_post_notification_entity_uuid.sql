create or replace function public.create_community_post(
  p_community_id uuid,
  p_content text,
  p_type text,
  p_image_urls text[],
  p_business_account_id uuid default null,
  p_pin_announcement boolean default false,
  p_send_announcement_push boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_user_id uuid;
  v_post_id uuid;
  v_normalized_content text;
  v_image_url text;
  v_role text;
  v_member_rec record;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Unauthorized' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.community_memberships
    where community_id = p_community_id
      and user_id = v_user_id
      and status = 'active'
  ) then
    raise exception 'community_membership_required' using errcode = 'C0004';
  end if;

  if p_business_account_id is not null then
    if p_type = 'announcement' then
      raise exception 'community_announcement_permission_required'
        using errcode = 'C0007';
    end if;

    if not exists (
      select 1 from public.community_memberships
      where community_id = p_community_id
        and business_account_id = p_business_account_id
        and status = 'active'
    ) then
      raise exception 'community_membership_required' using errcode = 'C0004';
    end if;

    if not exists (
      select 1 from public.business_accounts ba
      where ba.id = p_business_account_id
        and (
          ba.owner_user_id = v_user_id
          or exists (
            select 1 from public.business_members bm
            where bm.business_id = ba.id and bm.user_id = v_user_id
          )
        )
    ) then
      raise exception 'business_identity_invalid' using errcode = 'B0001';
    end if;
  end if;

  v_normalized_content := trim(coalesce(p_content, ''));
  if length(v_normalized_content) = 0
    and (p_image_urls is null or array_length(p_image_urls, 1) = 0) then
    raise exception 'empty_post' using errcode = 'MOD09';
  end if;

  if length(v_normalized_content) > 0 then
    if v_normalized_content ~*
      '(casino|gambling|bahis|şans oyunu|betting|poker|porn|adult|escort)' then
      raise exception 'community_content_moderation_blocked'
        using errcode = 'MOD01';
    end if;

    if v_normalized_content ~ '([a-z0-9])\1{5,}' then
      raise exception 'community_content_moderation_blocked'
        using errcode = 'MOD03';
    end if;
  end if;

  if p_type = 'announcement' then
    if not public.has_community_permission(
      p_community_id,
      v_user_id,
      'manage_members'
    ) then
      raise exception 'community_announcement_permission_required'
        using errcode = 'C0007';
    end if;

    if p_pin_announcement then
      update public.community_posts
      set is_pinned = false
      where community_id = p_community_id and is_pinned = true;
    end if;
  end if;

  insert into public.community_posts (
    community_id,
    user_id,
    business_account_id,
    type,
    content,
    is_pinned
  ) values (
    p_community_id,
    case when p_business_account_id is null then v_user_id else null end,
    p_business_account_id,
    p_type,
    p_content,
    case when p_type = 'announcement' then p_pin_announcement else false end
  ) returning id into v_post_id;

  if p_image_urls is not null and array_length(p_image_urls, 1) > 0 then
    foreach v_image_url in array p_image_urls loop
      insert into public.community_post_images (post_id, image_url)
      values (v_post_id, v_image_url);
    end loop;
  end if;

  if p_type = 'announcement' and p_send_announcement_push then
    for v_member_rec in
      select user_id from public.community_memberships
      where community_id = p_community_id
        and status = 'active'
        and user_id is not null
        and user_id <> v_user_id
    loop
      insert into public.notifications (
        recipient_id,
        actor_id,
        type,
        title,
        body,
        entity_type,
        entity_id,
        metadata
      ) values (
        v_member_rec.user_id,
        v_user_id,
        'community_announcement',
        'Topluluk Duyurusu',
        substring(v_normalized_content from 1 for 100),
        'community_post',
        v_post_id,
        jsonb_build_object('community_id', p_community_id, 'post_id', v_post_id)
      );
    end loop;
  end if;

  return v_post_id;
end;
$function$;

revoke execute on function public.create_community_post(
  uuid, text, text, text[], uuid, boolean, boolean
) from public, anon, authenticated;
grant execute on function public.create_community_post(
  uuid, text, text, text[], uuid, boolean, boolean
) to authenticated;
