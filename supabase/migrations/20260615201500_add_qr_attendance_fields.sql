-- Katılımcı yoklama ve doğrulama alanları
ALTER TABLE public.event_participants 
  ADD COLUMN IF NOT EXISTS check_in_token text UNIQUE,
  ADD COLUMN IF NOT EXISTS checked_in_by uuid REFERENCES public.business_accounts(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.event_participants.check_in_token IS 'Katılımcıya özel üretilen güvenli QR check-in anahtarı.';
COMMENT ON COLUMN public.event_participants.checked_in_by IS 'Yoklamayı alan işletme hesabı IDsi.';
