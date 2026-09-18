#!/usr/bin/env python3
"""Submit an already-uploaded TestFlight build to the App Store for review.

No build, no upload. The iOS release workflow uploads every `v*` build to
App Store Connect. This script finds the processed build for a version,
creates (or reuses) the App Store version record, attaches the build, writes
"What's New", optionally turns on phased release, and submits it for review.
Apple's review is still Apple's; "promote" here means "submit".

    scripts/promote_app_store.py \
        --bundle-id com.brensch.schlift \
        --version 0.10.1 \
        --release-notes-file release-notes/0.10.1.md

Auth is an App Store Connect API key: APP_STORE_CONNECT_KEY_ID,
APP_STORE_CONNECT_ISSUER_ID and APP_STORE_CONNECT_PRIVATE_KEY_BASE64 (the .p8
contents), the same secrets the upload uses.

`--dry-run` does every lookup and prints the plan without writing anything.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import jwt  # pyjwt[crypto]

API = "https://api.appstoreconnect.apple.com/v1"
WHATS_NEW_LIMIT = 4000
DEFAULT_LOCALE = "en-US"

# appStoreVersion states we can still attach a build to and submit.
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}
# States that mean a submission for this version is already in flight.
IN_FLIGHT_STATES = {
    "WAITING_FOR_REVIEW",
    "IN_REVIEW",
    "PENDING_DEVELOPER_RELEASE",
    "PENDING_APPLE_RELEASE",
    "PROCESSING_FOR_DISTRIBUTION",
}
LIVE_STATES = {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION"}


@dataclass(frozen=True)
class Credentials:
    key_id: str
    issuer_id: str
    private_key: str


class AppStoreConnect:
    def __init__(self, creds: Credentials, dry_run: bool):
        self.creds = creds
        self.dry_run = dry_run
        self._token: str | None = None
        self._token_expires = 0.0

    def token(self) -> str:
        now = time.time()
        if self._token is None or now > self._token_expires - 60:
            expires = now + 15 * 60  # Apple caps tokens at 20 minutes
            self._token = jwt.encode(
                {"iss": self.creds.issuer_id, "iat": int(now), "exp": int(expires), "aud": "appstoreconnect-v1"},
                self.creds.private_key,
                algorithm="ES256",
                headers={"kid": self.creds.key_id, "typ": "JWT"},
            )
            self._token_expires = expires
        return self._token

    def request(self, method: str, path: str, params: dict | None = None, body: dict | None = None) -> dict:
        url = path if path.startswith("http") else f"{API}{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        if method != "GET" and self.dry_run:
            print(f"  dry-run: would {method} {url} {json.dumps(body) if body else ''}")
            return {}
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self.token()}")
        req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")
            raise SystemExit(f"{method} {url} -> HTTP {error.code}\n{detail}") from error

    def get(self, path: str, params: dict | None = None) -> dict:
        return self.request("GET", path, params=params)

    def post(self, path: str, body: dict) -> dict:
        return self.request("POST", path, body=body)

    def patch(self, path: str, body: dict) -> dict:
        return self.request("PATCH", path, body=body)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--version", required=True, help="Marketing version, e.g. 0.10.1 (the v* tag without the v)")
    parser.add_argument("--release-notes-file", required=True, type=Path)
    parser.add_argument("--phased-release", action="store_true", help="Roll out over 7 days after approval")
    parser.add_argument(
        "--wait-minutes",
        type=int,
        default=30,
        help="How long to wait for App Store Connect to finish processing the build",
    )
    parser.add_argument("--dry-run", action="store_true", help="Look everything up, print the plan, write nothing")
    return parser.parse_args()


def load_credentials() -> Credentials:
    missing = [
        name
        for name in ("APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_PRIVATE_KEY_BASE64")
        if not os.environ.get(name)
    ]
    if missing:
        raise SystemExit(f"Missing App Store Connect secrets: {', '.join(missing)}")
    private_key = base64.b64decode(os.environ["APP_STORE_CONNECT_PRIVATE_KEY_BASE64"]).decode()
    return Credentials(
        key_id=os.environ["APP_STORE_CONNECT_KEY_ID"],
        issuer_id=os.environ["APP_STORE_CONNECT_ISSUER_ID"],
        private_key=private_key,
    )


def load_release_notes(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(
            f"Release notes not found: {path}\nEvery production promotion needs release-notes/<version>.md."
        )
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        raise SystemExit(f"Release notes are empty: {path}")
    if len(text) > WHATS_NEW_LIMIT:
        raise SystemExit(f"Release notes are {len(text)} characters; App Store allows {WHATS_NEW_LIMIT}.")
    return text


def find_app(asc: AppStoreConnect, bundle_id: str) -> str:
    apps = asc.get("/apps", {"filter[bundleId]": bundle_id, "fields[apps]": "bundleId,name"}).get("data", [])
    if len(apps) != 1:
        raise SystemExit(f"Expected one app with bundle id {bundle_id}, found {len(apps)}")
    print(f"App {apps[0]['attributes']['name']} ({apps[0]['id']})")
    return apps[0]["id"]


def find_build(asc: AppStoreConnect, app_id: str, version: str, wait_minutes: int) -> dict:
    """The newest non-expired build for `version`, waited on until processed."""
    deadline = time.time() + wait_minutes * 60
    while True:
        builds = asc.get(
            "/builds",
            {
                "filter[app]": app_id,
                "filter[preReleaseVersion.version]": version,
                "sort": "-uploadedDate",
                "limit": 20,
                "fields[builds]": "version,processingState,expired,uploadedDate",
            },
        ).get("data", [])
        builds = [b for b in builds if not b["attributes"].get("expired")]
        if not builds:
            raise SystemExit(f"No build for version {version} in App Store Connect. Has the v{version} upload finished?")
        build = max(builds, key=lambda b: int(b["attributes"]["version"]))
        state = build["attributes"]["processingState"]
        label = f"build {build['attributes']['version']} ({build['id']}, uploaded {build['attributes']['uploadedDate']})"
        if state == "VALID":
            print(f"Using {label}")
            return build
        if state in {"FAILED", "INVALID"}:
            raise SystemExit(f"{label} is {state}; Apple rejected it during processing")
        if time.time() > deadline:
            raise SystemExit(f"{label} still {state} after {wait_minutes} minutes")
        print(f"{label} is {state}; waiting")
        time.sleep(60)


def version_state(record: dict) -> str:
    attrs = record["attributes"]
    return attrs.get("appVersionState") or attrs.get("appStoreState") or "UNKNOWN"


def find_or_create_version(asc: AppStoreConnect, app_id: str, version: str) -> dict:
    existing = asc.get(
        f"/apps/{app_id}/appStoreVersions",
        {"filter[platform]": "IOS", "filter[versionString]": version, "limit": 5},
    ).get("data", [])
    for record in existing:
        state = version_state(record)
        if state in EDITABLE_STATES:
            print(f"Reusing App Store version {version} ({record['id']}, {state})")
            return record
        if state in IN_FLIGHT_STATES:
            raise SystemExit(f"App Store version {version} is already {state}; nothing to do")
        if state in LIVE_STATES:
            raise SystemExit(f"App Store version {version} is already {state}")
        print(f"Ignoring App Store version record {record['id']} in state {state}")

    # Apple allows one unreleased version at a time: a leftover editable one
    # (say 0.10.1 pulled from review) makes creating 0.10.2 fail with "cannot
    # create a new version in the current state". Its version string can be
    # changed though, so take it over.
    leftovers = asc.get(
        f"/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS", "limit": 20}
    ).get("data", [])
    for record in leftovers:
        state = version_state(record)
        current = record["attributes"].get("versionString")
        if state in EDITABLE_STATES and current != version:
            print(f"Renaming editable App Store version {current} ({record['id']}, {state}) to {version}")
            asc.patch(
                f"/appStoreVersions/{record['id']}",
                {"data": {"type": "appStoreVersions", "id": record["id"], "attributes": {"versionString": version}}},
            )
            record["attributes"]["versionString"] = version
            return record

    print(f"Creating App Store version {version}")
    created = asc.post(
        "/appStoreVersions",
        {
            "data": {
                "type": "appStoreVersions",
                "attributes": {"platform": "IOS", "versionString": version, "releaseType": "AFTER_APPROVAL"},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        },
    )
    if asc.dry_run:
        return {"id": "<new>", "attributes": {"appVersionState": "PREPARE_FOR_SUBMISSION"}}
    return created["data"]


def attach_build(asc: AppStoreConnect, version_id: str, build_id: str) -> None:
    print(f"Attaching build {build_id} to version {version_id}")
    asc.patch(
        f"/appStoreVersions/{version_id}/relationships/build",
        {"data": {"type": "builds", "id": build_id}},
    )


def set_whats_new(asc: AppStoreConnect, version_id: str, notes: str) -> None:
    localizations = []
    if version_id != "<new>":
        localizations = asc.get(
            f"/appStoreVersions/{version_id}/appStoreVersionLocalizations",
            {"fields[appStoreVersionLocalizations]": "locale", "limit": 50},
        ).get("data", [])
    if not localizations:
        print(f"Creating {DEFAULT_LOCALE} localization with What's New")
        asc.post(
            "/appStoreVersionLocalizations",
            {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "attributes": {"locale": DEFAULT_LOCALE, "whatsNew": notes},
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
                }
            },
        )
        return
    for localization in localizations:
        locale = localization["attributes"]["locale"]
        print(f"Setting What's New for {locale}")
        asc.patch(
            f"/appStoreVersionLocalizations/{localization['id']}",
            {"data": {"type": "appStoreVersionLocalizations", "id": localization["id"], "attributes": {"whatsNew": notes}}},
        )


def enable_phased_release(asc: AppStoreConnect, version_id: str) -> None:
    if version_id != "<new>":
        current = asc.get(f"/appStoreVersions/{version_id}/appStoreVersionPhasedRelease").get("data")
        if current:
            print(f"Phased release already configured ({current['attributes'].get('phasedReleaseState')})")
            return
    print("Enabling phased release (7 days after approval)")
    asc.post(
        "/appStoreVersionPhasedReleases",
        {
            "data": {
                "type": "appStoreVersionPhasedReleases",
                "attributes": {"phasedReleaseState": "INACTIVE"},
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
            }
        },
    )


def submit_for_review(asc: AppStoreConnect, app_id: str, version_id: str) -> None:
    open_submissions = asc.get(
        f"/apps/{app_id}/reviewSubmissions",
        {"filter[platform]": "IOS", "filter[state]": "READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES", "limit": 10},
    ).get("data", [])
    submission = None
    for record in open_submissions:
        state = record["attributes"]["state"]
        if state == "READY_FOR_REVIEW":
            print(f"Reusing draft review submission {record['id']}")
            submission = record
            break
        raise SystemExit(f"A review submission is already {state} ({record['id']}); resolve it in App Store Connect first")

    if submission is None:
        print("Creating review submission")
        submission = asc.post(
            "/reviewSubmissions",
            {
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": "IOS"},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        ).get("data", {"id": "<new-submission>"})

    submission_id = submission["id"]
    already_attached = False
    if submission_id != "<new-submission>":
        items = asc.get(
            f"/reviewSubmissions/{submission_id}/items",
            {"limit": 10, "fields[reviewSubmissionItems]": "appStoreVersion", "include": "appStoreVersion"},
        ).get("data", [])
        already_attached = any(
            (item.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id") == version_id
            for item in items
        )
    if not already_attached:
        print(f"Adding version {version_id} to submission {submission_id}")
        asc.post(
            "/reviewSubmissionItems",
            {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                    },
                }
            },
        )

    print(f"Submitting {submission_id} for review")
    asc.patch(
        f"/reviewSubmissions/{submission_id}",
        {"data": {"type": "reviewSubmissions", "id": submission_id, "attributes": {"submitted": True}}},
    )


def main() -> int:
    args = parse_args()
    notes = load_release_notes(args.release_notes_file)
    asc = AppStoreConnect(load_credentials(), dry_run=args.dry_run)

    app_id = find_app(asc, args.bundle_id)
    build = find_build(asc, app_id, args.version, args.wait_minutes)
    version = find_or_create_version(asc, app_id, args.version)
    version_id = version["id"]

    attach_build(asc, version_id, build["id"])
    set_whats_new(asc, version_id, notes)
    if args.phased_release:
        enable_phased_release(asc, version_id)
    submit_for_review(asc, app_id, version_id)

    if args.dry_run:
        print("Dry run: nothing was written")
    else:
        print(f"Submitted {args.version} (build {build['attributes']['version']}) for App Store review")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        sys.exit(130)
