# Play Console Upload Troubleshooting

## 1. versionCode Already Used

Fix:

- Increment `pubspec.yaml` versionCode.
- Rebuild signed AAB.
- Upload the new AAB.

## 2. App Not Signed Or Wrong Signing

Fix:

- Check `android/key.properties`.
- Check `android/app/upload-keystore.jks`.
- Confirm `keyAlias=upload`.
- Rebuild release AAB.

## 3. Missing Privacy Policy

Fix:

- Provide a live privacy policy URL.
- Make sure the URL is publicly accessible without login.

## 4. Missing Account Deletion URL

Fix:

- Provide a live account/data deletion URL or accepted deletion request page.
- Make sure Play Console wording does not overclaim automation if deletion is
  manual support review.

## 5. App Access Required

Fix:

- Provide reviewer test account privately in Play Console.
- Make sure reviewer account is email-confirmed.
- Do not commit reviewer email/password.

## 6. Data Safety Incomplete

Fix:

- Complete Data Safety based on actual data collected.
- Include auth/profile/content/location/photos/reports/feedback only if they
  apply to the shipped build.

## 7. Screenshots Rejected

Fix:

- Replace with correct phone screenshots.
- Avoid misleading claims or cropped unusable screens.

## 8. App Icon Or Label Issue

Fix:

- Correct launcher resources or app label.
- Rebuild and upload a new AAB with a new versionCode if needed.
