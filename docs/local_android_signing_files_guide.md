# Local Android Signing Files Guide

Create these files locally only:

```text
android/key.properties
android/app/upload-keystore.jks
```

Never commit these files. Never send them to testers. Never paste signing
passwords into docs, chat, screenshots, or Git.

## Generate Upload Keystore

Run from the project root:

```powershell
keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Use strong passwords and save the keystore plus passwords in a private password
manager or secure offline backup.

## key.properties Template

Create `android/key.properties` locally:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

Replace placeholders only in your local file. Do not commit it.

## Warnings

- If the upload key is lost, the Play Store release process becomes painful.
- Do not paste passwords into docs/chat/repo.
- Do not send the keystore to anyone.
- Do not put real signing values in CI logs.
- Keep a private backup before uploading the first closed test build.
