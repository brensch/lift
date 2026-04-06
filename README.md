# schlift Deployment Guide

This repo ships:
- Android phone app (`app/android/app`)
- Wear OS app (`app/android/wear`)
- iOS app placeholder CI (`app/ios`)

Current mobile package/bundle ID target is `com.brensch.schlift`.

## Android + Wear Release (Play Store)

### 1) One-time signing setup

Generate upload keystore locally:

```bash
keytool -genkeypair -v \
  -keystore ~/upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

Base64 it for GitHub secret:

```bash
base64 -w 0 ~/upload-keystore.jks
```

### 2) Required GitHub Actions secrets (Android)

Set in `Settings -> Secrets and variables -> Actions`:
- `RELEASE_KEYSTORE_BASE64`
- `RELEASE_KEYSTORE_PASSWORD`
- `RELEASE_KEY_ALIAS`
- `RELEASE_KEY_PASSWORD`

### 3) Release workflow trigger

Workflow file: `.github/workflows/android-release.yml`

Triggers:
- Manual: `workflow_dispatch`
- Branch push: `release`

When triggered, CI:
1. Builds signed phone AAB
2. Builds signed wear AAB
3. Uploads both AABs to Google Play `internal` track

### 4) Version bump before tag

Update `app/pubspec.yaml`:
- `version: x.y.z+N`

Then:

```bash
cd app
flutter pub get
```

### 5) Push release branch

```bash
git push origin release
```

### Local CI-equivalent checks

Use Make targets that mirror the GitHub Android workflow:

```bash
# Fast fail (signing only)
make ci-android-check-signing

# Full local release build (phone + wear)
make ci-android-build-release

# Full chain (check + build)
make ci-android-release-local

# Remove local generated signing files
make ci-android-clean-signing
```

### 6) Upload to Play Console

Site: https://play.google.com/console

CI uploads both generated AAB files to Google Play Internal testing. You can also download the workflow artifacts if you need the raw bundles.

Detailed Android checklist: `app/PLAY_STORE_RELEASE.md`

## iOS Release CI

Workflow file: `.github/workflows/ios-build.yml`

Current behavior:
- Runs on `release` branch pushes or manual dispatch
- Regenerates `Runner.xcodeproj` from `app/ios/project.yml`
- If Apple signing secrets are present:
  - imports the Apple distribution certificate into a temporary CI keychain
  - installs provisioning profiles for the iPhone app and watch app
  - archives the signed app and exports an IPA artifact
- If Apple signing secrets are missing:
  - builds an unsigned iOS app with `--no-codesign`
  - uploads the unsigned `Runner.app.zip` artifact
- Does not upload to App Store Connect automatically

### Required for real iOS distribution

You need Apple Developer Program + signing assets:
- Distribution certificate (`.p12`) and password
- iPhone app provisioning profile
- watch app provisioning profile
- Apple Team ID
- (Later) App Store Connect API key for automated upload

Required GitHub Actions secrets:
- `IOS_CERT_P12_BASE64`
- `IOS_CERT_PASSWORD`
- `IOS_APP_PROVISION_PROFILE_BASE64`
- `IOS_WATCH_PROVISION_PROFILE_BASE64`
- `APPLE_TEAM_ID`

## Recommended Release Flow

1. Merge release-ready code to `main`.
2. Bump app version.
3. Push `android-vX.Y.Z` tag to build Android/Wear release.
4. Merge `main` into `release` to run the signed iOS workflow and collect IPA/AAB artifacts for store submission.
