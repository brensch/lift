# Operations runbook: deploy, release, promote, store listing

This is the one place for everything that moves code or content out of the
repo: backend deploys, app builds, production promotion, and the store
listings. Each step is a tag push or a workflow dispatch; nothing is versioned
or uploaded by hand.

## Everything at a glance

| What | Trigger | Workflow | Result |
|---|---|---|---|
| Deploy the prod backend | merge to `main` | `backend-deploy.yml` | `schlift.com`, migration runs at boot |
| Deploy the dev backend + dev app | push `dev-<anything>` | `dev-backend-deploy.yml`, `android-dev-release.yml` | `dev.schlift.com`, side-by-side APK ([dev channel](dev-channel.md)) |
| Build the apps | push `vX.Y.Z` | `android-release.yml`, `ios-build.yml` | Play internal/alpha/beta + TestFlight |
| Promote to production | push `prod-vX.Y.Z` | `store-promote.yml` | Play production + App Store review |
| Update the store listing | dispatch `store-assets.yml` | `store-assets.yml` | text + screenshots on both stores |
| Refresh raw screenshots | `make store-capture` (local) | — | `store/screenshots/raw/` to commit |

Files you edit, all checked in CI on every pull request:

| File | What it is | Limit check |
|---|---|---|
| `release-notes/<version>.md` | "What's new" for one release | `scripts/check_release_notes.py` (500 chars) |
| `store/listing.yaml` | Listing text for both stores + screenshot captions | `scripts/check_store_text.py` (every field) |
| `store/screenshots/raw/*.png` | Raw app captures the framed slides are made from | referenced by `listing.yaml` |
| `marketing/` | Icon and Play feature graphic | — |

A normal release, start to finish:

```bash
# 1. code lands on main → prod backend deploys itself
# 2. build the apps onto the testing tracks
git tag v0.10.2 origin/main && git push origin v0.10.2
# 3. write release-notes/0.10.2.md, merge it, then promote
git tag prod-v0.10.2 origin/main && git push origin prod-v0.10.2
# 4. (only when the listing changed) push text + screenshots
gh workflow run store-assets.yml -f action=push -f dry_run=true   # then dry_run=false
```

The version comes from the tag (`v0.10.2` ships as `0.10.2`, build number
`1000 + run number`). `app/pubspec.yaml` stays at its `0.0.0+1` placeholder.

---

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

CI does this: a `v*` tag uploads both `.aab` files to the `internal`, `alpha`
and `beta` tracks (phone) and `wear:internal` / `wear:beta watch` (watch),
rolled out to testers immediately. A `prod-v*` tag then promotes the `beta`
release to `production` — see [Promote to production](#promote-to-production).

For a one-off manual upload, use Play Console → Testing → Internal testing,
upload both bundles, add notes, resolve warnings, roll out.

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

It builds signed release AABs for both phone and wear, uploads them as workflow artifacts, and then uploads both bundles to the Google Play testing tracks (`internal`, `alpha`, `beta` for the phone; `wear:internal`, `wear:beta watch` for the watch) via `scripts/upload_google_play.py`.

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
  - This builds artifacts and uploads both AABs to the Play testing tracks.

## iOS (App Store)

Workflow file: `.github/workflows/ios-build.yml`, triggered on `v*` tags or
manual dispatch. It regenerates `Runner.xcodeproj` from `app/ios/project.yml`,
then:

- **If Apple signing secrets are present:** imports the distribution
  certificate into a temporary CI keychain, installs the iPhone + watch
  provisioning profiles, archives the signed app, and exports an IPA artifact.
- **If they are missing:** builds an unsigned app with `--no-codesign` and
  uploads `Runner.app.zip`.

When the App Store Connect API key secrets are also present, the signed IPA
is uploaded with `altool`, which lands it in TestFlight once Apple has
processed it (usually 5–15 minutes).

Required for real iOS distribution (Apple Developer Program needed):
- Distribution certificate (`.p12`) and password
- iPhone app provisioning profile
- watch app provisioning profile
- Apple Team ID
- App Store Connect API key (App Manager role) for upload and promotion

Required GitHub Actions secrets:
- `IOS_CERT_P12_BASE64`
- `IOS_CERT_PASSWORD`
- `IOS_APP_PROVISION_PROFILE_BASE64`
- `IOS_WATCH_PROVISION_PROFILE_BASE64`
- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` (base64 of the `.p8` file)

## Promote to production

Workflow file: `.github/workflows/store-promote.yml`. It **does not build
anything**. It takes a version that a `v*` tag already built and uploaded,
and moves it to production on both stores by API:

- **Google Play:** reads the `beta` track (phone) and the `wear:beta watch`
  track (watch), finds the release for that version, and writes its version
  codes to `production` / `wear:production` with release notes, optionally as
  a staged rollout. Same service account as the upload.
  Script: `scripts/promote_google_play.py`.
- **App Store:** finds the processed TestFlight build for that version,
  creates (or reuses) the App Store version record, attaches the build, sets
  "What's New", optionally enables phased release, and submits it for review.
  Apple still reviews it; the app goes live after approval (`AFTER_APPROVAL`).
  Script: `scripts/promote_app_store.py`.

Both jobs run in the `production` GitHub environment, so any reviewers or
wait timers configured there apply.

### 1. Write the release notes

Create `release-notes/<version>.md` (plain text; Play allows 500 characters,
the App Store 4000) and commit it to `main`. This is what users read in the
store. CI validates every file in that directory on each pull request
(`scripts/check_release_notes.py`: name is `X.Y.Z.md`, not empty, 500
characters or under), so a bad note fails the PR rather than the promotion.
The promote workflow refuses to run without the file.

### 2. Trigger

Tag flow, the normal path — promotes both stores, full rollout:

```bash
git fetch origin
git tag prod-v0.10.1 origin/main && git push origin prod-v0.10.1
```

Tag the **current** `main` (which must contain the release-notes file and
this workflow), not the commit the `v0.10.1` build came from. The version is
parsed from the tag name.

Manual flow — Actions → **Store Promote** → *Run workflow* — adds options:

| Input | Meaning |
|---|---|
| `version` | e.g. `0.10.1`; must already be on the testing tracks |
| `platforms` | `both`, `android` or `ios` |
| `play_rollout` | Play rollout fraction, `0.1` = 10 % of users; `1` = everyone |
| `ios_phased_release` | App Store 7-day phased release after approval |
| `dry_run` | Do every lookup and print the plan without committing |

Or from the terminal:

```bash
gh workflow run store-promote.yml -f version=0.10.1 -f platforms=both \
  -f play_rollout=1 -f ios_phased_release=false -f dry_run=true
gh run list --workflow store-promote.yml --limit 1
```

Run it with `dry_run=true` first if you are unsure: it validates the plan
against both stores' APIs and writes nothing.

### 3. Afterwards

- **Play:** the release is live (or rolling out) as soon as the edit
  commits. If the account has managed publishing on, it waits for you in the
  console. To widen a staged rollout, rerun with a larger `play_rollout`.
- **App Store:** the version sits in *Waiting for Review*. Apple's review
  takes hours to days; you get the usual emails. Rejections come back to
  App Store Connect and the workflow can be rerun once fixed.

### What can go wrong

- *No release named vX.Y.Z-\* on track 'beta'* — the `v*` build has not
  finished uploading, or that tag never built. Check the Android Release run.
- *No build for version X.Y.Z in App Store Connect* — the iOS Release run
  failed or the upload was skipped. The script waits up to 30 minutes for
  Apple to finish processing a build that did upload.
- *App Store version X.Y.Z is already WAITING_FOR_REVIEW* — it was already
  submitted; nothing to do.
- *A review submission is already IN_REVIEW* — resolve or cancel it in App
  Store Connect first.
- Export compliance never blocks: `ITSAppUsesNonExemptEncryption` is `false`
  in `app/ios/Runner/Info.plist`.

## Store listing and screenshots

Workflow file: `.github/workflows/store-assets.yml`. It never builds the app.
It frames committed screenshots and pushes text + images to both stores by
API, from two committed sources:

- **`store/listing.yaml`** — the single source of listing text: `name`,
  `tagline` (App Store subtitle, feature graphic byline, and the first half
  of Play's one-liner), `promotional_text` (App Store promo; Play's one-liner
  is tagline + promo, 80 max), `keywords` (App Store), and the description
  as typed pieces: `about` (paragraphs), `testimonials_heading` +
  `testimonials` (quote, name), `other_features` (heading, items). The
  stores get those composed into one description in that order
  (`compose_description` in `scripts/check_store_text.py`); the website
  uses each piece as its own section. The same text goes to every language
  the listing has. Screenshot captions live here too.
- **`store/screenshots/raw/`** — raw captures: `store_NN.png` phone slides
  (1080×2400, dark mode), `wear_*.png` Wear OS captures (384×384),
  `apple_watch_*.png` Apple Watch captures (396×484).

CI checks `listing.yaml` on every pull request against both stores' limits
(`scripts/check_store_text.py`), including that each referenced screenshot
file exists.

### Icon and feature graphic

`make brand` renders the app icon concepts and Play feature graphic
directions (`scripts/render_brand.py`, SVG in the app's own typeface) into
`marketing/icons/candidates/` and `marketing/feature_graphic_candidates/`.
Edit shapes or copy there; a change is a diff, not a design-tool export.

To adopt an icon on every platform (iOS, watchOS, macOS, Android legacy +
adaptive, Wear OS, web, Windows, and the Play store icon):

```bash
make icons ICON_SOURCE=marketing/icons/candidates/<name>.png
```

To adopt a feature graphic: copy it to `marketing/feature_graphic.png`.
Both are pushed to Play by the Store Assets workflow (the App Store icon
ships inside the build). Commit the results with the `v*` release that
should carry them.

### The website says the same thing

schlift.com's landing page has no copy of its own. At build time
`web/scripts/sync-content.mjs` reads `store/listing.yaml` (tagline,
promotional text, `about`, `testimonials`, `other_features`, the slides and
their captions, the `website:` section for the few site-only lines), the
latest `release-notes/<version>.md`, `templates/library.yaml` (the
`/templates` page), the raw
screenshots, the app icon (favicon) and the feature graphic (link preview),
and writes them under `web/src/generated/` and `web/public/generated/`
(gitignored). `npm run dev` and `npm run build` run it automatically. The
site deploys with the backend on every push to `main`, so a listing edit is
live on schlift.com as soon as it merges, before either store has reviewed
it.

### Refresh the screenshots

```bash
make store-capture      # emulator + seeded backend → store/screenshots/raw/store_NN.png
make store-frame        # optional: render the framed slides locally to store/screenshots/out/
```

`store-capture` boots the `lift_api34` emulator (dark mode, animations off),
starts a throwaway backend on `:50051` with dev login and the seeded `demo`
account (`SEED_DEMO_USER=demo`; nine weeks of progressing history, compiled
only with `--features test-auth`, see `src/demo_seed.rs`), then drives
`app/integration_test/store_shots_test.dart`, which takes one shot per slide.
Add, remove or reorder slides there and in `listing.yaml` together. Commit the
new PNGs.

Watch captures are not automated (two emulators cannot be paired from the
CLI); the committed ones are reused. To redo them see the Wear OS notes in
`docs/android_dev.md` and the watch notes in `docs/architecture/wearable.md`.

### Render and review

Actions → **Store Assets** → *Run workflow* with `action = render`, or:

```bash
gh workflow run store-assets.yml -f action=render
gh run download --name store-screenshots   # framed PNGs + contact-sheet.html
```

`scripts/frame_store_screenshots.py` renders each slide with its caption above
a phone frame at every size the stores need: Play 1080×1920, App Store 6.9"
1320×2868. Watch captures go up at their native sizes.

### Push

```bash
gh workflow run store-assets.yml -f action=push -f platforms=both -f dry_run=true
gh workflow run store-assets.yml -f action=push -f platforms=both -f dry_run=false
```

| Input | Meaning |
|---|---|
| `platforms` | `both`, `android`, `ios` |
| `ios_version` | App Store version to write to. Blank = the newest version still editable. Given and missing = created (text and screenshots then ride the next promotion). |
| `text_only` | Push the listing text only; screenshots, feature graphic and icon stay as they are on the store. |
| `ios_remove_from_review` | If `ios_version` is waiting for review, cancel that submission first (same as *Remove from Review* in App Store Connect; the build stays attached, the queue place is lost). Push, then run the promotion again to resubmit. |
| `dry_run` | Play: does every write in an edit and discards it. App Store: prints every write. |

- **Play** replaces the phone screenshots, Wear screenshots, feature graphic
  and icon wholesale, and sets title, short and full description, in one
  committed edit. Live immediately (or after review if the account uses
  managed publishing).
- **App Store** sets name and subtitle on the app record (only when it is not
  locked by a review), and promotional text, keywords, description and the
  iPhone + Apple Watch screenshot sets on the version. A version waiting for
  review cannot be edited: pull it from review, or target the next version.

### Pull

`action = pull` prints what each store currently has (text per language, image
counts) and saves it as the `store-listing-pull` artifact. Use it to seed
`listing.yaml` from the live listing or to check the two are in sync.

### What can go wrong

- *FAIL description: 4123 characters, both allows 4000* — the checker; fix the
  file.
- *store_03.png is not in store/screenshots/raw* — a slide in `listing.yaml`
  without a capture; run `make store-capture`.
- *No App Store version is editable right now* — every version is in review or
  live; pass `ios_version` for the next one.
- *App-level record (name, subtitle) is not editable right now* — Apple locks
  it during review; the rest still pushes.
- *You cannot create a new version of the App in the current state* — Apple
  will not open the next version while one is waiting for review. Either
  wait for that review to finish, or push onto the waiting version with
  `ios_version` set to it and `ios_remove_from_review` on, then promote again.
- *Play: The caller does not have permission* on commit — the service
  account can publish releases but not edit the store listing. In Play
  Console → Users and permissions → the service account → App permissions,
  grant **Manage store presence** (edit store listing, store settings).
  The dry run cannot catch this: Play only checks it at commit.
