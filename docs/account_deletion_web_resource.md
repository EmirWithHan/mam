# Account Deletion Web Resource TODO

Date: 2026-06-06

Google Play and public launch need a public web resource where users can request
account/data deletion without opening the app.

Current MVP state:

- In-app Settings includes an account deletion request path.
- The request records `account_deletion_requests`.
- The public profile identity is deactivated/anonymized.
- Future events are cancelled and posts are archived.
- Supabase Auth user deletion and final data retention/removal remain a manual
  backend/admin process for closed beta.

Do not claim a public deletion URL exists until it is actually published.

## Required Public Page Content

The public page should include:

- App name: Match A Man.
- A support/contact method controlled by the project owner.
- Required request fields: account email, username if known, reason optional,
  and whether the user requests account deletion or a data-access/data-deletion
  question.
- Expected processing time.
- What is deleted or anonymized.
- What may be retained where legally or operationally required, such as abuse
  reports, safety logs, dispute records, moderation records, or legal records.
- A note that the requester may need to prove account ownership.
- A note that deleting the app from a device does not delete the account.

## Release TODO

- Publish the deletion web page.
- Add the public URL to store listings and privacy policy where required.
- Define the admin/backend final deletion runbook for Supabase Auth, Storage,
  profile data, user-generated content, reports, and moderation records.
- Have the deletion language reviewed by a lawyer or privacy advisor before
  public release.
