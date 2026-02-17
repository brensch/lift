# lift Deployment Guide

This repo ships:
- Android phone app (`app/android/app`)
- Wear OS app (`app/android/wear`)
- iOS app placeholder CI (`app/ios`)

Current mobile package/bundle ID target is `com.brensch.lift`.

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
- Tag push: `android-v*` (example: `android-v1.0.1`)

When tag-triggered, CI:
1. Builds signed phone AAB
2. Builds signed wear AAB
3. Creates a GitHub Release and attaches both AABs

### 4) Version bump before tag

Update `app/pubspec.yaml`:
- `version: x.y.z+N`

Then:

```bash
cd app
flutter pub get
```

### 5) Push release tag

```bash
git tag -a android-v1.0.1 -m "Android release 1.0.1"
git push origin android-v1.0.1
```

### 6) Upload to Play Console

Site: https://play.google.com/console

Upload both generated AAB files from the GitHub Release (or Actions artifacts) to Internal testing, then promote.

Detailed Android checklist: `app/PLAY_STORE_RELEASE.md`

## iOS Release CI (Placeholder)

Workflow file: `.github/workflows/ios-release-placeholder.yml`

Current behavior:
- Builds iOS simulator app without signing
- Checks for signing secrets
- Prints missing-secret guidance
- Does not yet produce signed IPA/App Store upload

Triggers:
- Manual: `workflow_dispatch`
- Branch push: `ios-release/**`
- Tag push: `ios-v*`

### Required for real iOS distribution

You need Apple Developer Program + signing assets:
- Distribution certificate (`.p12`) and password
- Provisioning profile
- Apple Team ID
- (Later) App Store Connect API key for automated upload

Placeholder secrets expected by workflow:
- `IOS_CERT_P12_BASE64`
- `IOS_CERT_PASSWORD`
- `IOS_PROVISION_PROFILE_BASE64`
- `APPLE_TEAM_ID`

## Recommended Release Flow

1. Merge release-ready code to `main`.
2. Bump app version.
3. Push `android-vX.Y.Z` tag to build Android/Wear release.
4. Use `ios-release/*` branch (or `ios-v*` tag) for iOS CI work until full signing pipeline is implemented.
