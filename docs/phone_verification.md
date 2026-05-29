# Phone Verification

## Foundation

- Fake phone verification is not allowed.
- One phone number can belong to only one account.
- Phone numbers are normalized before storage.
- `phone_verified` must remain `false` until a real OTP/provider flow confirms
  ownership.
- OTP codes must not be stored in `profiles`.

## Future Verification

A real provider is required before setting `phone_verified = true`, for example:

- Supabase Phone Auth
- A trusted SMS/OTP provider

When implemented, the OTP flow should set:

- `profiles.phone_verified = true`
- `profiles.phone_verified_at = now()`

Only after successful provider verification.

## Future Product Use

Business events may later require verified phone numbers for joining,
confirming participation, or check-in-sensitive flows. This foundation does not
enforce phone verification yet.
