# Manual Decision Guide

## 1. When do we send APK to friends?

Send APK after the email confirmation pending flow is fixed, the verification
email arrives, and the owner's phone smoke test passes.

Start with 3 close testers. If no blocker appears, expand to 8-12 trusted
Android testers.

## 2. When do we upload to Google Play?

Upload to Google Play closed testing after:

- Signed AAB can be built.
- Store listing, screenshots, privacy policy, account deletion URL, Data Safety,
  and reviewer instructions are ready.
- No APK beta blocker remains.
- Tester emails are collected privately.
- Keystore and `key.properties` stay local and uncommitted.

## 3. When do we buy Apple Developer?

Buying Apple Developer now or soon is OK if using the official Apple flow.

It must happen before MacInCloud. Confirm App Store Connect access, agreements,
and Bundle ID availability before renting a Mac.

## 4. When do we rent MacInCloud?

Rent MacInCloud only when Apple Developer is active and the iOS prep docs are
ready.

Use it for build/upload day, not for open-ended planning. The target is signed
IPA upload to TestFlight, not full public launch in one day.

## 5. What if Android is ready but iOS is not?

Keep Android in closed testing. Do not delay all testing while waiting for iOS.
Use Android feedback to fix cross-platform issues, then synchronize public
launch timing after iOS catches up.

## 6. What if iOS TestFlight is delayed?

Continue Android closed testing, fix cross-platform bugs, and prepare App Store
metadata. Document the exact iOS blocker, such as signing, upload, metadata, or
deep links, and resolve it before external TestFlight.
