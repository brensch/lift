# Release Values

This file lists the current repo values used by GitHub Actions for Android and Apple release builds.

## Current Fixed App Values

- App name: `Schlift`
- Current version: `0.7.1+8`
- Main Android package ID: `com.brensch.schlift`
- Wear OS published package ID: `com.brensch.schlift`
- Wear OS module namespace: `com.brensch.schlift.wear`
- iPhone bundle ID: `com.brensch.schlift`
- Watch app bundle ID: `com.brensch.schlift.watchkitapp`
- iOS associated domain entitlement: `webcredentials:schlift.com`
- Recommended Android key alias: `upload`

## GitHub Secrets To Create

### Android

- `RELEASE_KEYSTORE_BASE64`
- `RELEASE_KEYSTORE_PASSWORD`
- `RELEASE_KEY_ALIAS`
- `RELEASE_KEY_PASSWORD`

### Apple

- `APPLE_TEAM_ID`
- `IOS_CERT_P12_BASE64`
- `IOS_CERT_PASSWORD`
- `IOS_APP_PROVISION_PROFILE_BASE64`
- `IOS_WATCH_PROVISION_PROFILE_BASE64`

## Android Keystore Creation

Create the Android upload keystore locally:

```bash
keytool -genkeypair -v \
  -keystore ~/upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

This command creates:

- keystore file: `~/upload-keystore.jks`
- alias: `upload`

You will be prompted for:

- keystore password
- key password
- certificate identity fields

If you want the simplest setup, use the same password for both the keystore and the key.

Then base64-encode it for GitHub:

```bash
base64 -w 0 ~/upload-keystore.jks
```

Set the Android secrets to:

- `RELEASE_KEYSTORE_BASE64` = output of the base64 command above
- `RELEASE_KEYSTORE_PASSWORD` = the keystore password you chose
- `RELEASE_KEY_ALIAS` = `upload`
- `RELEASE_KEY_PASSWORD` = the key password you chose

## Apple Signing Inputs

You need these assets from your Apple Developer account:

- Apple Distribution certificate exported as `.p12`
- password for that `.p12`
- provisioning profile for `com.brensch.schlift`
- provisioning profile for `com.brensch.schlift.watchkitapp`
- Apple Team ID

Base64-encode each binary file before putting it in GitHub:

```bash
base64 -w 0 /path/to/dist-cert.p12
base64 -w 0 /path/to/Schlift.mobileprovision
base64 -w 0 /path/to/SchliftWatch.mobileprovision
```

Set the Apple secrets to:

- `APPLE_TEAM_ID` = your Apple Developer Team ID
- `IOS_CERT_P12_BASE64` = base64 of the `.p12`
- `IOS_CERT_PASSWORD` = password for the `.p12`
- `IOS_APP_PROVISION_PROFILE_BASE64` = base64 of the provisioning profile for `com.brensch.schlift`
- `IOS_WATCH_PROVISION_PROFILE_BASE64` = base64 of the provisioning profile for `com.brensch.schlift.watchkitapp`

## Where These Values Come From

- Android package IDs: `app/android/app/build.gradle.kts`, `app/android/wear/build.gradle.kts`
- iOS bundle IDs: `app/ios/project.yml`
- watch companion link: `app/ios/SchliftWatch/Info.plist`
- associated domain entitlement: `app/ios/Runner/Runner.entitlements`
- app version: `app/pubspec.yaml`
