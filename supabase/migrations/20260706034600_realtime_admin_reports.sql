-- Migration: Realtime Admin Reports (AG-22)
-- 1. Enable realtime publication for reports and message_reports tables idempotently.
-- 2. Add SELECT RLS policy for message_reports to allow admins to read all rows (if missing).

-- 1. Enable Realtime Publication
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    -- Add reports if not already present
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'reports'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.reports;
    END IF;
    
    -- Add message_reports if not already present
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'message_reports'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reports;
    END IF;
  END IF;
END;
$$;


-- 2. RLS policy update for message_reports
DROP POLICY IF EXISTS "Admins can read all message reports" ON public.message_reports;
CREATE POLICY "Admins can read all message reports"
ON public.message_reports
FOR SELECT
TO authenticated
USING (
  public.is_current_user_admin()
);
