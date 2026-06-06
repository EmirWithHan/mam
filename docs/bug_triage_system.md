# Real Device Bug Triage System

Date: 2026-06-06

## Purpose

This document is for closed beta testing with real phones and real tester
accounts.

It standardizes how bugs are reported, reproduced, prioritized, fixed, and
verified during the APK beta phase. The goal is to keep friend/testing feedback
actionable and prevent screenshots or WhatsApp messages from becoming
untrackable.

Use this system for issues such as startup white screens, friendly error copy,
permission errors, Android layout overflows, RLS/RPC failures, stale
notification state, and language inconsistencies.

## Bug Severity Levels

### BLOCKER

Use when testing cannot continue or there is a serious safety/privacy risk.

Examples:

- App does not open.
- Login or register is impossible.
- Main navigation is broken.
- Home, Events, or Profile is unusable.
- White screen.
- Crash.
- Serious data, privacy, or security issue.

### HIGH

Use when a core flow is broken but the app is still partly usable.

Examples:

- Event creation is broken.
- Join, approve, or reject is broken.
- Username search is broken.
- Business application, approval, or delete is broken.
- Notifications are completely broken.
- A normal page repeatedly shows a permission error.

### MEDIUM

Use when a workaround exists or a non-critical screen is affected.

Examples:

- Layout overflow on one device.
- Text inconsistency.
- State does not update until manual refresh.
- One non-critical screen is broken.

### LOW

Use for polish that does not block testing.

Examples:

- Copy/text polish.
- Minor spacing issue.
- Minor animation or performance issue.
- Visual inconsistency.

## Bug Status Flow

### NEW

The report has arrived but has not been reviewed yet.

Move to `NEEDS_REPRO` if the report is missing steps, account, device, or media.
Move to `CONFIRMED` if the issue is clear and reproducible from the report.

### NEEDS_REPRO

The issue needs more evidence or clearer steps.

Ask the tester for a screenshot, video, account used, approximate time, device
model, OS version, and exact steps.

### CONFIRMED

The issue was reproduced or the report includes enough evidence to treat it as
real.

Assign severity and owner before moving to `IN_PROGRESS`.

### IN_PROGRESS

The issue is being investigated or fixed.

Keep the scope tight. Group only strongly related bugs in the same fix.

### FIXED_PENDING_TEST

A fix exists locally or in a new build, but it has not been verified on a real
device yet.

Retest the exact original flow before closing.

### VERIFIED

The fix was confirmed on a real device or with the same conditions that caused
the bug.

Attach the build, account, device, and verification notes.

### WONT_FIX_FOR_BETA

The issue is known but intentionally not fixed for the closed beta.

Use only when the issue is safe, non-blocking, and documented.

### POSTPONED

The issue is real but belongs to a later milestone or needs a larger product or
technical decision.

Do not use this for blocker/high issues unless the beta scope is explicitly
changed.

## Bug Report Template

```text
Bug ID:
Reporter:
Date:
Device model:
Android/iOS version:
App build:
Screen/page:
Account used:
Steps to reproduce:
Expected result:
Actual result:
Screenshot/video:
Logs if available:
Severity:
Status:
Owner:
Notes:
```

## Reproduction Rules

- Always try to reproduce on the developer device first.
- If it is not reproducible, ask the tester for a video.
- If it looks backend related, check Supabase logs, RLS policies, RPC grants,
  and client queries.
- If it looks UI related, ask for screenshot/video and device size.
- If it is auth related, test both fresh install and existing session.
- If it is state/realtime related, test manual refresh vs automatic update.
- Record account type: normal, private, business applicant, approved business,
  admin, or non-admin.
- Record whether the app was debug APK, release APK, split APK, or AAB install.

## Fix Rules

- Fix blocker/high issues before adding anything new.
- Use one prompt per bug cluster unless issues are strongly related.
- Do not hide errors without fixing the root cause.
- User-facing errors must stay friendly Turkish copy.
- Developer logs can include code/message only.
- Do not log or expose secrets, tokens, passwords, Supabase service keys, or
  private user data.
- Do not expose raw `PostgrestException`, SQLSTATE, stack traces, SQL, or
  policy internals to users.
- Permission copy should appear only for truly forbidden actions such as
  admin-only, business-only, or owner-only actions.
- Layout fixes should be scoped: use scrolling, wrapping, truncation, and
  flexible sizing without redesigning the screen.

## Known Recent Bug Clusters

- Missing dart-defines caused startup white screen.
- Generic `Bir seyler ters gitti` appeared without enough developer logs.
- `Bu islem icin yetkin yok` appeared on pages that should be public to normal
  authenticated users.
- Android small screens showed yellow/black overflow stripes.
- Events RLS policy caused infinite recursion.
- Events page header stayed pinned and consumed too much mobile space.
- Notification/state counts sometimes needed manual refresh.
- UI language was inconsistent between English and Turkish.
