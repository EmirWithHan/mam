# Android App Icon

Date: 2026-06-06

## Source Asset

Android launcher icons are generated from:

```text
assets/branding/mam_logo.jpg
```

The source is the Match A Man logo mark. It is currently a square JPEG asset.

## Generator Config

Android-only launcher icon generation uses:

```text
flutter_launcher_icons.yaml
```

The config keeps iOS generation disabled and uses the brand color `#FF7E79` as
the Android adaptive icon background.

## Generation Command

```powershell
dart run flutter_launcher_icons -f flutter_launcher_icons.yaml
```

## Generated Android Resources

Default launcher icons:

```text
android/app/src/main/res/mipmap-mdpi/ic_launcher.png
android/app/src/main/res/mipmap-hdpi/ic_launcher.png
android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
```

Adaptive icon resources:

```text
android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png
android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png
android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png
android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png
android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png
android/app/src/main/res/values/colors.xml
```

## Manifest

`android/app/src/main/AndroidManifest.xml` should point to:

```xml
android:icon="@mipmap/ic_launcher"
```

No package name/application ID changes are needed for icon generation.

## Tester Note

Android launchers and installers may cache app icons. If the old Flutter icon
still appears after installing a new APK, uninstall the old app from the device
first, then install the new APK again.
