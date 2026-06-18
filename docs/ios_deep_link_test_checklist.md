# iOS Deep Link Test Checklist

Use this after installing a TestFlight build on an iPhone.

## Email Confirmation

1. Register with a new email/password account.
2. Confirm the app shows `E-postanı doğrula`.
3. Open the confirmation email on the iPhone.
4. Tap the confirmation link.
5. Confirm the link opens Match A Man or returns to a valid app auth state.
6. Confirm the verified user can log in and reach username onboarding.
7. Confirm the user cannot reach the main shell before verification.

## Password Reset

1. Open forgot password.
2. Request a reset link.
3. Open the reset email on the iPhone.
4. Tap the reset link.
5. Confirm the app opens the reset password flow.
6. Set a new password.
7. Confirm login works with the new password.

## If A Link Opens Safari Only

- Confirm the installed build has URL scheme `matchaman`.
- Confirm Supabase redirect allowlist includes:
  - `matchaman://auth/callback`
  - `matchaman://reset-password`
- Confirm the app code uses the same redirect URLs.
- Confirm the TestFlight build is installed before tapping the email link.
- Try copying the link into Notes and opening it again after app install.

## Safety Notes

- Do not paste real confirmation or reset links into bug reports.
- Do not log tokens, passwords, or auth callback URLs with secrets.
- Screenshots should hide email tokens and private account data.
