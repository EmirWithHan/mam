-- Drop old constraint if exists
alter table public.event_participants drop constraint if exists event_participants_attendance_status_check;

-- Add new constraint with 'removed'
alter table public.event_participants
  add constraint event_participants_attendance_status_check
  check (
    attendance_status in (
      'pending',
      'approved',
      'rejected',
      'cancelled',
      'left',
      'planned',
      'attended',
      'pending_confirmation',
      'confirmed',
      'waitlisted',
      'checked_in',
      'no_show',
      'removed'
    )
  );

-- Add audit columns to public.event_participants
alter table public.event_participants add column if not exists removed_by uuid references auth.users(id) on delete set null;
alter table public.event_participants add column if not exists removed_at timestamptz;

-- Recreate remove_event_participant function
create or replace function public.remove_event_participant(p_event_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_event public.events%rowtype;
  v_is_host boolean := false;
begin
  if v_actor_id is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_event from public.events where id = p_event_id;
  if v_event.id is null then
    raise exception 'event_not_found';
  end if;

  -- Check if the actor is the host (creator) of the event
  if v_event.host_id = v_actor_id then
    v_is_host := true;
  end if;

  -- Or if it is a business event, check if the actor is the business owner
  if not v_is_host and coalesce(v_event.organizer_type, 'user') = 'business' then
    select exists (
      select 1
      from public.business_accounts business
      where business.id = v_event.organizer_business_id
        and business.owner_user_id = v_actor_id
        and business.status = 'active'
    ) into v_is_host;
  end if;

  if not v_is_host then
    raise exception 'not_event_host';
  end if;

  -- Do not allow host to remove themselves
  if p_user_id = v_event.host_id then
    raise exception 'cannot_remove_host';
  end if;

  -- Update event_participants status to 'removed' and set audit fields
  update public.event_participants
  set attendance_status = 'removed',
      removed_by = v_actor_id,
      removed_at = now()
  where event_id = p_event_id
    and user_id = p_user_id;

  -- Also update the join request status to 'rejected' so they can request again or stay rejected
  update public.event_join_requests
  set status = 'rejected',
      updated_at = now()
  where event_id = p_event_id
    and user_id = p_user_id;
end;
$$;

revoke all on function public.remove_event_participant(uuid, uuid) from public;
grant execute on function public.remove_event_participant(uuid, uuid) to authenticated;

-- Update RLS select policy on event_join_requests to allow business hosts to view requests
drop policy if exists "Event requests are visible to requester or host" on public.event_join_requests;
create policy "Event requests are visible to requester or host"
on public.event_join_requests
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.events event
    where event.id = event_join_requests.event_id
      and (
        event.host_id = auth.uid()
        or (
          event.organizer_type = 'business'
          and event.organizer_business_id is not null
          and exists (
            select 1
            from public.business_accounts business
            where business.id = event.organizer_business_id
              and business.owner_user_id = auth.uid()
              and business.status = 'active'
          )
        )
      )
  )
);

-- Create trigger function to automatically notify host/business owner on join requests
create or replace function public.on_event_join_request_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recipient_id uuid;
  v_actor_id uuid := new.user_id;
  v_event_id uuid := new.event_id;
  v_event public.events%rowtype;
  v_notification_type text;
  v_title text;
  v_body text;
begin
  -- Fetch the event details
  select * into v_event from public.events where id = v_event_id;
  if v_event.id is null then
    return new;
  end if;

  -- Determine the recipient host
  if coalesce(v_event.organizer_type, 'user') = 'business' and v_event.organizer_business_id is not null then
    select owner_user_id
    into v_recipient_id
    from public.business_accounts
    where id = v_event.organizer_business_id;
  end if;

  if v_recipient_id is null then
    v_recipient_id := v_event.host_id;
  end if;

  -- Do not notify self
  if v_recipient_id = v_actor_id then
    return new;
  end if;

  -- Determine title/body based on the new status
  if new.status = 'pending' then
    v_notification_type := 'event_join_request';
    v_title := 'Yeni katılım isteği';
    v_body := 'Etkinliğine yeni bir katılım isteği geldi.';
  elsif new.status = 'confirmed' then
    v_notification_type := 'event_joined';
    v_title := 'Yeni katılımcı';
    v_body := 'Etkinliğine yeni bir katılımcı katıldı.';
  elsif new.status = 'waitlisted' then
    v_notification_type := 'event_waitlist';
    v_title := 'Yedek katılım';
    v_body := 'Etkinliğinin yedek listesine yeni bir katılımcı eklendi.';
  else
    return new;
  end if;

  -- Insert notification if no unread duplicate exists
  if not exists (
    select 1
    from public.notifications
    where recipient_id = v_recipient_id
      and actor_id = v_actor_id
      and type = v_notification_type
      and entity_id = v_event_id
      and is_read = false
  ) then
    insert into public.notifications (
      recipient_id,
      actor_id,
      type,
      title,
      body,
      entity_type,
      entity_id,
      metadata,
      is_read
    )
    values (
      v_recipient_id,
      v_actor_id,
      v_notification_type,
      v_title,
      v_body,
      'event',
      v_event_id,
      jsonb_build_object(
        'event_id', v_event_id::text,
        'request_id', new.id::text
      ),
      false
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_on_event_join_request_change on public.event_join_requests;
create trigger trg_on_event_join_request_change
after insert or update of status
on public.event_join_requests
for each row
execute function public.on_event_join_request_change();
