# Release Guide (Android, Wear & iOS)

Releases are triggered by pushing a `v*` tag (e.g. `git tag v0.9.6 origin/main &&
git push origin v0.9.6`), which runs the signed Android/Wear and iOS build
workflows. This document covers signing setup, required secrets, and the store
checklists. The backend deploys separately on push to `main`
(`.github/workflows/backend-deploy.yml`).

## Android / Wear (Play Store)

This project publishes two Android artifacts under one package:
- Phone app module: `app/android/app`
- Wear app module: `app/android/wear`

## 1) Create Play Console App Entry

Site:
- https://play.google.com/console

In Play Console, create an app and fill:
- App name: `Schlift` (or your final name)
- Default language
- App or game: `App`
- Free or paid
- Contact email
- Privacy policy URL

Then complete:
- `Store presence > Main store listing`
- `Dashboard > App content` (Data safety, ads, permissions declarations)
- `Testing > Internal testing` (first upload track)

## 2) Choose Package Name (Application ID)

Current package ID is:
- `com.brensch.schlift` in `app/android/app/build.gradle.kts`
- `com.brensch.schlift` in `app/android/wear/build.gradle.kts`

Rules:
- Must use dot-separated Java package format.
- `com:brensch:schlift` is invalid.
- Valid examples: `com.brensch.schlift`, `io.brensch.schlift`.
- You should choose this before first publish. Changing it later means a new Play listing/app.

If you change it later, update both Gradle files above and update your backend domain asset links to match.

## 3) Configure Release Signing

Generate a keystore once:

```bash
keytool -genkeypair -v -keystore ~/upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Create `app/android/key.properties`:

```properties
storeFile=/home/REPLACE_ME/upload-keystore.jks
storePassword=REPLACE_ME
keyAlias=upload
keyPassword=REPLACE_ME
```

`key.properties` is already gitignored.

## 4) Set Release Version

For CI release builds there is **no manual version step** — the version is
derived from the release tag and run number (see `Resolve version from tag +
run number` in `.github/workflows/android-release.yml`):
- **name** = the `v*` tag with the `v` stripped (`v0.9.6` → `0.9.6`)
- **phone build number** = `1000 + GITHUB_RUN_NUMBER`
- **wear `versionCode`** = `(phoneBuildNumber * 1000) + 1` to avoid collisions

`app/pubspec.yaml` holds a frozen `0.0.0+1` placeholder (local/dev only). The CI
step rewrites it at build time so the phone build and the separate wear gradle
build (which reads the version from `app/android/local.properties`) stay in
sync. For a purely local build, pass the version yourself:
`flutter build appbundle --build-name=x.y.z --build-number=N`.

## 5) Build Release Artifacts

Phone AAB:

```bash
cd app
flutter build appbundle --release
```

Output:
- `app/build/app/outputs/bundle/release/app-release.aab`

Wear AAB:

```bash
cd app/android
./gradlew :wear:bundleRelease
```

Output:
- `app/android/wear/build/outputs/bundle/release/wear-release.aab`

## 6) Upload and Rollout

In Play Console Internal testing release:
1. Upload both `.aab` files.
2. Add release notes.
3. Resolve warnings/errors.
4. Roll out to testers.

After validation, promote to Closed/Production.

## 7) WebAuthn / Passkey Production Values

This app uses asset links and Android signing identity.
Before production, ensure backend and site use release values:
- Update your `assetlinks.json` `package_name` to your final application ID.
- Add release certificate SHA-256 fingerprint.
- Keep debug and release environments separate.

You can print certificate hashes with:

```bash
make print-cert-hashes DEBUG_KEYSTORE=/path/to/upload-keystore.jks DEBUG_ALIAS=upload DEBUG_STOREPASS=...
```

## 8) GitHub Actions Release Builder

Workflow file:
- `.github/workflows/android-release.yml`

It builds signed release AABs for both phone and wear, uploads them as workflow artifacts, and then uploads both bundles to the Google Play `internal` track.

Create these GitHub repository secrets before running:
- `RELEASE_KEYSTORE_BASE64`: base64 of your JKS keystore file
- `RELEASE_KEYSTORE_PASSWORD`
- `RELEASE_KEY_ALIAS`
- `RELEASE_KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: raw JSON contents of a Google Cloud service-account key with Play Console app access

Create base64 keystore value:

```bash
base64 -w 0 ~/upload-keystore.jks
```

Run options:
- Manual: Actions tab -> `Android Release` -> `Run workflow` (test builds only;
  versioned `0.0.0-dev`)
- Tag trigger: push a `v*` tag (e.g. `git tag v0.9.6 origin/main && git push
  origin v0.9.6`)
  - This builds artifacts and uploads both AABs to the Play Console internal track.

## iOS (App Store)

Workflow file: `.github/workflows/ios-build.yml`, triggered on `v*` tags or
manual dispatch. It regenerates `Runner.xcodeproj` from `app/ios/project.yml`,
then:

- **If Apple signing secrets are present:** imports the distribution
  certificate into a temporary CI keychain, installs the iPhone + watch
  provisioning profiles, archives the signed app, and exports an IPA artifact.
- **If they are missing:** builds an unsigned app with `--no-codesign` and
  uploads `Runner.app.zip`.

It does not upload to App Store Connect automatically.

Required for real iOS distribution (Apple Developer Program needed):
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
