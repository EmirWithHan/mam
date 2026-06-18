# Email Verification Setup

Email verification now uses Supabase link-based confirmation, not a 6-digit OTP
code screen.

Use the current setup guide:

```text
docs/email_auth_link_setup.md
```

The primary Supabase email template token is:

```text
{{ .ConfirmationURL }}
```

Do not use `{{ .Token }}` as the main app flow.
