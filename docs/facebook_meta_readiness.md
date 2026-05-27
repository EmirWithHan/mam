# Facebook / Meta Readiness

Facebook OAuth works through the app-side Supabase flow, but Meta dashboard and submission readiness still need completion.

## Meta Dashboard Checklist

- Upload 1024x1024 app icon.
- Add Privacy Policy URL.
- Add User Data Deletion URL or deletion instructions.
- Select app category.
- Confirm app mode: Development vs Live.
- Add roles/test users for development testing.
- Enable Facebook Login product.
- Add Supabase callback URL in valid OAuth redirect URIs.
- Confirm production domains before public launch.

## Notes

- Flutter should not try to fix Meta submission state.
- Public users cannot rely on Development Mode.
- Closed beta can use Meta roles/test users first.
- If Meta says the app is ineligible or not active, handle it in Meta Developer settings unless logs show a real app-side redirect/provider bug.
- Do not commit Facebook app secrets.
