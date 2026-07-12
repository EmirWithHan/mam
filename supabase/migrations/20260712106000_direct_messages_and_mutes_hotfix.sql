-- 20260712106000_direct_messages_and_mutes_hotfix.sql
-- Add reply_to_message_id to public.direct_messages if not exists.

ALTER TABLE public.direct_messages 
  ADD COLUMN IF NOT EXISTS reply_to_message_id uuid 
  REFERENCES public.direct_messages(id) ON DELETE SET NULL;
