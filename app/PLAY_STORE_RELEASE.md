# Play Store Release Checklist (Phone + Wear)

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

Phone version source:
- `app/pubspec.yaml` -> `version: x.y.z+N`

Wear version source:
- Derived from `app/android/local.properties` Flutter version values during build.
- Wear `versionCode` is computed as `(phoneVersionCode * 1000) + 1` to avoid collisions.

Before each upload:
1. Bump `app/pubspec.yaml` version/build number.
2. Run `flutter pub get` in `app/`.

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
- Manual: Actions tab -> `Android Release` -> `Run workflow`
- Branch trigger: push `release`
  - This builds artifacts and uploads both AABs to the Play Console internal track.
