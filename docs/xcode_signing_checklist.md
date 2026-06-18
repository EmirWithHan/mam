# Xcode Signing Checklist

Use this before building the App Store IPA.

- [ ] Runner target selected.
- [ ] Team selected.
- [ ] Bundle Identifier matches App Store Connect: `com.matchaman.app`.
- [ ] Automatically manage signing enabled if using the simple path.
- [ ] Signing certificate valid.
- [ ] Provisioning profile valid.
- [ ] Release scheme selected.
- [ ] No debug signing for App Store IPA.
- [ ] Capabilities only include what the app uses.
- [ ] Do not add push capability unless Firebase/push is actually implemented.
- [ ] Do not add Sign in with Apple unless implemented.
- [ ] Do not add tracking capability unless tracking exists.
- [ ] Display name is `Match A Man`.
- [ ] URL scheme `matchaman` is present.
- [ ] App icon is the Match A Man icon.

Do not commit Apple certificates, provisioning profiles, API keys, `.p8` files,
or generated IPA output.
