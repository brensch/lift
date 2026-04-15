#!/usr/bin/env python3
"""Upload Android App Bundles to Google Play tracks deterministically.

The script creates one Android Publisher edit, uploads each AAB once, assigns
the returned version code to all requested tracks, then commits the edit.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

import httplib2

ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"

# Upload timeout: large AABs (~60MB+) can take a while to upload and process.
UPLOAD_TIMEOUT_SECONDS = 300
MAX_UPLOAD_RETRIES = 3
RETRY_DELAY_SECONDS = 10


@dataclass(frozen=True)
class Artifact:
    label: str
    path: Path
    tracks: list[str]
    release_name: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upload phone and Wear OS AABs to Google Play testing tracks."
    )
    parser.add_argument("--package-name", required=True)
    parser.add_argument("--status", default="completed")
    parser.add_argument("--service-account-json", default=None)
    parser.add_argument("--service-account-json-file", default=None)
    parser.add_argument("--phone-aab", required=True, type=Path)
    parser.add_argument("--phone-release-name", required=True)
    parser.add_argument("--phone-tracks", required=True, nargs="+")
    parser.add_argument("--wear-aab", required=True, type=Path)
    parser.add_argument("--wear-release-name", required=True)
    parser.add_argument("--wear-tracks", required=True, nargs="+")
    parser.add_argument(
        "--changes-not-sent-for-review",
        action="store_true",
        help="Commit the edit without sending changes for review.",
    )
    return parser.parse_args()


def load_service_account_info(args: argparse.Namespace) -> dict:
    service_account_json = (
        args.service_account_json or os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")
    )
    if service_account_json:
        return json.loads(service_account_json)

    service_account_json_file = args.service_account_json_file or os.environ.get(
        "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_FILE"
    )
    if service_account_json_file:
        with open(service_account_json_file, "r", encoding="utf-8") as handle:
            return json.load(handle)

    raise SystemExit(
        "Missing Google Play credentials. Set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON "
        "or pass --service-account-json-file."
    )


def validate_artifacts(artifacts: Iterable[Artifact]) -> None:
    for artifact in artifacts:
        if not artifact.path.is_file():
            raise SystemExit(f"{artifact.label} AAB not found: {artifact.path}")
        if not artifact.tracks:
            raise SystemExit(f"{artifact.label} has no tracks configured")


def upload_artifact(androidpublisher, package_name: str, edit_id: str, artifact: Artifact) -> str:
    print(f"Uploading {artifact.label} AAB once: {artifact.path}")
    media = MediaFileUpload(
        str(artifact.path),
        mimetype="application/octet-stream",
        resumable=True,
    )

    for attempt in range(1, MAX_UPLOAD_RETRIES + 1):
        try:
            bundle = (
                androidpublisher.edits()
                .bundles()
                .upload(packageName=package_name, editId=edit_id, media_body=media)
                .execute(num_retries=2)
            )
            version_code = str(bundle["versionCode"])
            print(f"{artifact.label} upload returned version code {version_code}")
            return version_code
        except Exception as e:
            if attempt < MAX_UPLOAD_RETRIES:
                print(
                    f"{artifact.label} upload attempt {attempt}/{MAX_UPLOAD_RETRIES} "
                    f"failed: {e}. Retrying in {RETRY_DELAY_SECONDS}s..."
                )
                time.sleep(RETRY_DELAY_SECONDS)
                # Reset media stream position for retry
                media = MediaFileUpload(
                    str(artifact.path),
                    mimetype="application/octet-stream",
                    resumable=True,
                )
            else:
                raise


def update_tracks(
    androidpublisher,
    package_name: str,
    edit_id: str,
    artifact: Artifact,
    version_code: str,
    status: str,
) -> None:
    for track in artifact.tracks:
        print(
            f"Assigning {artifact.label} version code {version_code} "
            f"to track {track!r}"
        )
        body = {
            "track": track,
            "releases": [
                {
                    "name": artifact.release_name,
                    "status": status,
                    "versionCodes": [version_code],
                }
            ],
        }
        (
            androidpublisher.edits()
            .tracks()
            .update(
                packageName=package_name,
                editId=edit_id,
                track=track,
                body=body,
            )
            .execute()
        )


def main() -> int:
    args = parse_args()
    artifacts = [
        Artifact(
            label="phone",
            path=args.phone_aab,
            tracks=args.phone_tracks,
            release_name=args.phone_release_name,
        ),
        Artifact(
            label="wear",
            path=args.wear_aab,
            tracks=args.wear_tracks,
            release_name=args.wear_release_name,
        ),
    ]
    validate_artifacts(artifacts)

    service_account_info = load_service_account_info(args)
    credentials = service_account.Credentials.from_service_account_info(
        service_account_info,
        scopes=[ANDROID_PUBLISHER_SCOPE],
    )

    # Use a longer timeout for large AAB uploads
    http = httplib2.Http(timeout=UPLOAD_TIMEOUT_SECONDS)
    http = google_auth_httplib2_request(credentials, http)

    androidpublisher = build(
        "androidpublisher",
        "v3",
        http=http,
        cache_discovery=False,
    )

    edit = (
        androidpublisher.edits()
        .insert(packageName=args.package_name, body={})
        .execute()
    )
    edit_id = edit["id"]
    print(f"Created Google Play edit {edit_id}")

    try:
        for artifact in artifacts:
            version_code = upload_artifact(
                androidpublisher,
                args.package_name,
                edit_id,
                artifact,
            )
            update_tracks(
                androidpublisher,
                args.package_name,
                edit_id,
                artifact,
                version_code,
                args.status,
            )

        print("Committing Google Play edit")
        (
            androidpublisher.edits()
            .commit(
                packageName=args.package_name,
                editId=edit_id,
                changesNotSentForReview=args.changes_not_sent_for_review,
            )
            .execute()
        )
        print("Google Play edit committed")
    except Exception:
        print(f"Upload failed before commit; deleting edit {edit_id}", file=sys.stderr)
        try:
            (
                androidpublisher.edits()
                .delete(packageName=args.package_name, editId=edit_id)
                .execute()
            )
        except Exception as delete_error:
            print(f"Failed to delete edit {edit_id}: {delete_error}", file=sys.stderr)
        raise

    return 0


def google_auth_httplib2_request(credentials, http):
    """Wrap an httplib2.Http with google-auth credentials."""
    import google_auth_httplib2
    return google_auth_httplib2.AuthorizedHttp(credentials, http=http)


if __name__ == "__main__":
    raise SystemExit(main())
