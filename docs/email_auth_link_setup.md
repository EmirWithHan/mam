# Email Auth Link Setup

This app uses Supabase Auth for email/password accounts. Closed beta email/password accounts should use link-based email confirmation before entering the main app.

## 1. Enable Email Confirmation

In Supabase Dashboard:

Authentication -> Sign In / Providers -> Email -> Confirm Email = ON

## 2. Confirm Signup Email Template

In Supabase Dashboard:

Authentication -> Emails -> Confirm signup

Use the link-based confirmation URL:

```text
{{ .ConfirmationURL }}
```

Do not use the 6-digit OTP token as the main app flow:

```text
{{ .Token }}
```

The app now shows a pending confirmation screen and asks the user to click the email link. It does not show a 6-digit code input.

## 3. Password Reset Email Template

In Supabase Dashboard:

Authentication -> Emails -> Reset Password

Use:

```text
{{ .ConfirmationURL }}
```

The reset link should return to the app, then the app calls Supabase `updateUser` with the new password. Passwords are not stored in Flutter.

## 4. URL Configuration

In Supabase Dashboard:

Authentication -> URL Configuration

Set the Site URL for the current environment and add redirect URLs:

```text
matchaman://auth/callback
matchaman://reset-password
```

During beta/dev, Supabase may also allow:

```text
matchaman://**
```

Tighten wildcard redirect URLs before public launch.

Also add any future hosted website callback URL. Add localhost/dev URLs only when needed for local development.

Existing OAuth still uses:

```text
matchaman://login-callback/
```

## 5. SMTP Note

Supabase default emails are acceptable for early beta testing. Production should use a custom SMTP/domain email for reliability and branding.

Do not commit SMTP credentials. Do not put SMTP secrets in Flutter.

## 6. Closed Beta Test Checklist

- [ ] Register with a real email.
- [ ] App shows the email confirmation pending screen.
- [ ] Confirmation email contains a clickable link.
- [ ] Link verifies the email and returns to the app if redirect URLs are configured.
- [ ] Verified user can log in and continue to profile completion/main flow.
- [ ] Unverified user cannot log in or enter the main shell.
- [ ] Resend confirmation link works from the pending screen.
- [ ] Forgot password sends a reset link without confirming whether the email exists.
- [ ] Reset link opens the new password screen.
- [ ] New password can be saved and used for login.
- [ ] Wrong or expired reset link shows a friendly error.
- [ ] Google/OAuth users are not forced into the manual email confirmation screen.

## 7. Existing Users

Existing test users may already be confirmed or unconfirmed. Check the Supabase Auth Users table before closed beta.

Do not break existing admin/test accounts. For closed beta, create fresh reviewer/test accounts after confirming the dashboard settings.

## 8. Postponed Auth Polish

If email change is added later, require Supabase email-change confirmation links and do not instantly trust the changed address.

If a logged-in password change screen is added later, keep passwords out of logs/storage and map backend errors to friendly Turkish messages.

## 9. Real Device Troubleshooting

- If a confirmation or reset link opens the browser but not the app, check the
  Android intent filters and Supabase redirect URLs first.
- `matchaman://auth/callback` must parse as scheme `matchaman`, host `auth`,
  path `/callback`.
- `matchaman://reset-password` must parse as scheme `matchaman`, host
  `reset-password`, with an empty path.
- If a link says expired or invalid, check the Supabase email template,
  redirect URL allow-list, and whether the link was already used.
- Do not log full auth URLs, access tokens, refresh tokens, or reset codes.
