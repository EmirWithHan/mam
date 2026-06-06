# Match A Man Account/Data Deletion Web Page Plan

Date: 2026-06-06

This document is an MVP planning artifact, not legal advice. The final wording
and deletion process should be reviewed before public release.

## Purpose

Google Play requires apps that allow account creation to provide both an
in-app deletion path and a web resource where users can request account/data
deletion. This page is for Match A Man users who cannot access the app but need
to request deletion of their account and associated data.

The final hosted URL must be entered in Play Console Data Safety / Data
deletion settings. No hosted URL exists yet, so do not claim one exists until it
is actually published.

This page must use Match A Man branding only. Do not mix it with unrelated
business or site branding such as Öz Ada Çadır.

## Minimum Required Page Content

The future page should include:

- App name: Match A Man.
- Clear purpose: account/data deletion request for Match A Man.
- Requester email.
- Username if known.
- User ID if known, optional.
- Deletion type:
  - Delete account and associated data.
  - Delete only specific data.
- Extra explanation/message.
- Confirmation checkbox:
  "Bu talebin hesabım ve verilerim üzerinde geri alınamaz sonuçları
  olabileceğini anlıyorum."
- Submit button: "Silme talebi gönder".
- Contact/support email placeholder.
- Expected processing time placeholder.
- Explanation that some data may be retained for safety, legal, abuse
  prevention, dispute, or moderation reasons.
- Privacy policy URL placeholder.

## What The Page Must NOT Do

- Must not expose a Supabase `service_role` key.
- Must not delete arbitrary users without verification.
- Must not accept only a username without email/account ownership verification.
- Must not promise instant deletion if manual review is required.
- Must not say all data is deleted immediately if some data may be retained.
- Must not use unrelated business/site branding.
- Must not create a fake deletion endpoint that pretends deletion happened.

## Recommended MVP Implementation Options

### Option 1 - Static Page + Email Request

- Host a simple static page.
- User submits by `mailto:` or a trusted contact form provider.
- Manual admin verifies ownership and processes the request in Supabase.
- Fastest for closed beta and early Play Store preparation.
- Weakness: manual work and response tracking.

### Option 2 - Static Page + Supabase Edge Function

- Public page posts request to a Supabase Edge Function.
- Edge Function validates input and stores the request.
- `service_role` stays only inside Edge Function secrets.
- Better long-term auditability and lower manual intake work.
- Requires deployment, rate limiting, abuse prevention, and security testing.

### Option 3 - Existing Website Page

- Use only if Match A Man has a real website.
- Must use Match A Man branding, privacy wording, and support ownership.
- Do not mix with Öz Ada Çadır or any unrelated business website.

## Recommendation

For the current beta, prepare the static page template and documentation. Before
public launch, host a real page and connect either:

- email/manual admin processing, or
- a tested Edge Function request intake flow.

The Play Console wording must match the actual flow. If the MVP uses manual
email review, do not overclaim automated deletion.

## Security Notes

- Never process deletion only by public `user_id`.
- Verify account ownership before processing.
- Never request a user password by email.
- Keep `service_role` only on trusted server/Edge Function infrastructure.
- Log deletion processing decisions.
- Restrict admin processing to `admin_users`.
- Keep the audit trail minimal but sufficient for safety, abuse prevention,
  dispute handling, and legal review.
