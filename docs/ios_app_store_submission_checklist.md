# iOS App Store Submission Checklist

Use this only after `docs/public_launch_hard_gate.md` passes for iOS.

1. Confirm launch candidate.
2. Bump build number if needed.
3. Build/upload IPA from Mac/Xcode.
4. Confirm App Store Connect metadata.
5. Confirm App Privacy answers.
6. Confirm privacy policy URL.
7. Confirm account deletion URL.
8. Confirm reviewer test account privately.
9. Confirm review notes.
10. Select uploaded build.
11. Submit for App Review.
12. Monitor review.
13. If rejected, create a specific hotfix/review-response prompt.
14. After approval, release manually or scheduled.

## Rules

- Do not add Apple Sign In unless review specifically requires it.
- Do not add push capability unless push is implemented.
- Do not add tracking declarations unless tracking exists.
- Do not commit IPA/certificates/provisioning profiles/API keys/`.p8` files.
- Do not commit reviewer credentials.
