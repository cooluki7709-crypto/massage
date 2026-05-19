# APK Analysis Report

## Scope And Guardrails

Target file: `C:\Users\laboy\Downloads\Glow+-+Massage+&+Spa+24_7_3.11.4_apkcombo.com.xapk`

This analysis is limited to safe static inspection. It does not bypass authentication, certificate pinning, payment controls, or access private user data. Proprietary source, images, logos, videos, and brand assets are not reused.

## Package Metadata

- Package: `com.glow.mobileApp`
- App name: Glow
- Version: `3.11.4`
- Version code: `534`
- Min SDK: `24`
- Target SDK: `36`
- Split APKs: base, `config.arm64_v8a`, `config.en`, `config.xhdpi`
- Input SHA-256 from prior blackbox report: `6a18fa8b73dc09b2c7b20a1ef863012aa4395863b31f1f68c803a429946be797`

## Permissions

Observed permissions include:

- Network: `INTERNET`, `ACCESS_NETWORK_STATE`
- Location: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- Media/camera: `CAMERA`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`
- Push and badges: `POST_NOTIFICATIONS`, `com.google.android.c2dm.permission.RECEIVE`, badge-count vendor permissions
- Payments: `com.android.vending.BILLING`
- Advertising/attribution: `AD_ID`, Android Ad Services attribution/topics/custom audience permissions
- Background: `WAKE_LOCK`, `FOREGROUND_SERVICE`

## Inferred SDKs And Libraries

- React Native with Hermes bytecode and CodePush-style update evidence
- Firebase Auth, Analytics/Measurement, Cloud Messaging, Installations/IID
- Google Play Services Auth, Phone Auth, Maps, Location, Ads Identifier
- OneSignal push notification stack
- Google Play Billing
- React Native WebView
- ML Kit barcode scanning
- Facebook login/custom tab components
- Kotlin/AndroidX/WorkManager support libraries

## Network Domains

First-party domains found statically:

- `https://api.glowvietnam.com`
- `https://api.glowvietnam.com/api`
- `https://ph-api.glowvietnam.com`
- `https://th-api.glowvietnam.com`
- `https://affiliateapi.glowvietnam.com/api`
- `https://version.glowvietnam.com/`
- `https://glowvietnam.com`

Third-party/service domains inferred from SDKs include Firebase, Google APIs, OneSignal, Facebook, and Google Play Billing endpoints.

## Exported Components

JADX resource-only decoding confirmed the base APK manifest without decompiling proprietary source. Exported Android components include main launch/deep-link activity, OneSignal notification receivers/activities, Firebase Auth `GenericIdpActivity` and `RecaptchaActivity`, Facebook custom tab activities, Firebase messaging receiver, WorkManager receivers/services, and profile installer receivers. These are mostly expected SDK components, but externally reachable components should be reviewed in a security pass.

## Deep Links

Manifest-level deep links include:

- Custom scheme: `glow://...`
- App links for Vietnam, Thailand, and Philippines `me.*` hosts
- Branch links for `glowvn.app.link` and alternate host
- Firebase Auth callback scheme/host entries
- Facebook custom tab callback entries

For our MVP, reuse only the pattern: app links for booking, auth callback, provider/customer routing, and notification landing. Do not reuse proprietary hosts, keys, branding, or route copy.

## Dynamic Analysis

Dynamic analysis was performed first on local emulators and then on an owned physical Android phone.

Emulator results:

- XAPK extracted successfully into a local analysis workspace.
- Target XAPK split set contains `base`, `config.arm64_v8a`, `config.en`, and `config.xhdpi`.
- Working emulator ABI was `x86_64` on Android API 33.
- Installing base, language, and density splits without the ABI split failed with `INSTALL_FAILED_MISSING_SPLIT`.
- Installing all splits on the `x86_64` emulator failed with `INSTALL_FAILED_NO_MATCHING_ABIS`.
- Attempted ARM64 AVD boot did not become available through ADB in the current Windows environment.

Physical device results:

- Device: Samsung `SM-S901E`
- Android API: `36`
- ABI list: `arm64-v8a, armeabi-v7a, armeabi`
- `adb install-multiple -r` succeeded with the provided XAPK splits: base, `config.arm64_v8a`, `config.en`, `config.xhdpi`.
- Installed package confirmed as `com.glow.mobileApp`, version `3.11.4`, version code `534`.
- Foreground launch succeeded: `com.glow.mobileApp/com.glow.MainActivity`.
- Runtime log confirms ARM64 native libraries loaded from the provided split APKs.
- Runtime log confirms Firebase, Firebase Crashlytics, Firebase Sessions, Branch SDK, React Native, Hermes, CodePush bundle loading, WorkManager, SoLoader, and React Native Maps component initialization.
- AppOps/package checks show location and camera are foreground-scoped permissions on the device; notification permission is runtime-controlled.

Captured local artifacts:

- `logs/apk-dynamic/glow-logcat-launch.txt`
- `logs/apk-dynamic/glow-logcat-xapk-phone-launch.txt`

The dynamic pass did not bypass authentication, certificate pinning, payment controls, or app security controls. Existing app data on the physical phone was not read or extracted. Screen capture/UI hierarchy capture is intentionally deferred until the app is confirmed to be on a logged-out, test-account, or otherwise non-private screen.

## Legal Reuse Boundary

Reusable: flow concepts, information architecture, category naming patterns at a generic level, and engineering risk lessons.

Not reusable: proprietary code, extracted media, original icons, logos, visual identity, copy, private API payloads, or hidden business logic.
