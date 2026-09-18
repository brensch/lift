#!/usr/bin/env python3
"""Promote an already-uploaded Google Play release to another track.

No build, no upload. The release workflow puts every `v*` build on the
testing tracks (`beta` for the phone, `wear:beta watch` for the watch) under a
release named `<tag>-<run>-<label>`. This script finds that release by version
on the source track, then writes its version codes to the target track with
release notes and (optionally) a staged rollout, in one edit.

    scripts/promote_google_play.py \
        --package-name com.brensch.schlift \
        --version 0.10.1 \
        --release-notes-file release-notes/0.10.1.md \
        --promote beta=production \
        --promote "wear:beta watch=wear:production"

`--dry-run` does every lookup and prints the plan, then deletes the edit
instead of committing it.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

import httplib2
from google.oauth2 import service_account
from googleapiclient.discovery import build

# Sibling script: shared auth + commit helpers.
from upload_google_play import (
    ANDROID_PUBLISHER_SCOPE,
    commit_edit,
    google_auth_httplib2_request,
    load_service_account_info,
)

# Play rejects release notes over this length.
PLAY_RELEASE_NOTES_LIMIT = 500
RELEASE_NOTES_LANGUAGE = "en-US"


@dataclass(frozen=True)
class Promotion:
    source_track: str
    target_track: str


@dataclass(frozen=True)
class FoundRelease:
    track: str
    name: str
    version_codes: list[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--package-name", required=True)
    parser.add_argument(
        "--version", required=True, help="Release version, e.g. 0.10.1 (the v* tag without the v)"
    )
    parser.add_argument("--release-notes-file", required=True, type=Path)
    parser.add_argument(
        "--promote",
        action="append",
        required=True,
        metavar="SOURCE=TARGET",
        help="Track to read the release from and track to write it to. Repeatable.",
    )
    parser.add_argument(
        "--user-fraction",
        type=float,
        default=1.0,
        help="Staged rollout fraction in (0, 1]. 1 = full rollout (status completed).",
    )
    parser.add_argument("--service-account-json", default=None)
    parser.add_argument("--service-account-json-file", default=None)
    parser.add_argument(
        "--dry-run", action="store_true", help="Look everything up, print the plan, do not commit"
    )
    return parser.parse_args()


def parse_promotions(specs: list[str]) -> list[Promotion]:
    promotions = []
    for spec in specs:
        if "=" not in spec:
            raise SystemExit(f"--promote expects SOURCE=TARGET, got {spec!r}")
        source, target = spec.split("=", 1)
        source, target = source.strip(), target.strip()
        if not source or not target or source == target:
            raise SystemExit(f"--promote needs two different tracks, got {spec!r}")
        promotions.append(Promotion(source, target))
    return promotions


def load_release_notes(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(
            f"Release notes not found: {path}\n"
            "Every production promotion needs release-notes/<version>.md."
        )
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        raise SystemExit(f"Release notes are empty: {path}")
    if len(text) > PLAY_RELEASE_NOTES_LIMIT:
        raise SystemExit(
            f"Release notes are {len(text)} characters; "
            f"Google Play allows {PLAY_RELEASE_NOTES_LIMIT}."
        )
    return text


def release_status(user_fraction: float) -> dict:
    if not 0 < user_fraction <= 1:
        raise SystemExit(f"--user-fraction must be in (0, 1], got {user_fraction}")
    if user_fraction == 1:
        return {"status": "completed"}
    return {"status": "inProgress", "userFraction": user_fraction}


def find_release(
    androidpublisher, package_name: str, edit_id: str, track: str, version: str
) -> FoundRelease:
    """The release on `track` whose name starts with `v<version>-`.

    The upload workflow names releases `<tag>-<run>-<label>`, so a rerun of
    the same tag leaves several candidates; the highest version code wins.
    """
    result = (
        androidpublisher.edits()
        .tracks()
        .get(packageName=package_name, editId=edit_id, track=track)
        .execute()
    )
    prefix = f"v{version}-"
    candidates = [
        release
        for release in result.get("releases", [])
        if release.get("name", "").startswith(prefix) and release.get("versionCodes")
    ]
    if not candidates:
        names = [r.get("name", "?") for r in result.get("releases", [])]
        raise SystemExit(
            f"No release named {prefix}* on track {track!r} of {package_name}. "
            f"Releases there: {names or 'none'}. Has the v{version} build finished uploading?"
        )
    best = max(candidates, key=lambda r: max(int(code) for code in r["versionCodes"]))
    return FoundRelease(track=track, name=best["name"], version_codes=list(best["versionCodes"]))


def list_tracks(androidpublisher, package_name: str, edit_id: str) -> list[str]:
    result = (
        androidpublisher.edits().tracks().list(packageName=package_name, editId=edit_id).execute()
    )
    return [track["track"] for track in result.get("tracks", [])]


def assign_release(
    androidpublisher,
    package_name: str,
    edit_id: str,
    target_track: str,
    found: FoundRelease,
    version: str,
    notes: str,
    status: dict,
) -> None:
    body = {
        "track": target_track,
        "releases": [
            {
                "name": f"v{version}",
                "versionCodes": found.version_codes,
                "releaseNotes": [{"language": RELEASE_NOTES_LANGUAGE, "text": notes}],
                **status,
            }
        ],
    }
    (
        androidpublisher.edits()
        .tracks()
        .update(packageName=package_name, editId=edit_id, track=target_track, body=body)
        .execute()
    )


def main() -> int:
    args = parse_args()
    promotions = parse_promotions(args.promote)
    notes = load_release_notes(args.release_notes_file)
    status = release_status(args.user_fraction)

    credentials = service_account.Credentials.from_service_account_info(
        load_service_account_info(args),
        scopes=[ANDROID_PUBLISHER_SCOPE],
    )
    http = google_auth_httplib2_request(credentials, httplib2.Http(timeout=120))
    androidpublisher = build("androidpublisher", "v3", http=http, cache_discovery=False)

    edit_id = (
        androidpublisher.edits().insert(packageName=args.package_name, body={}).execute()["id"]
    )
    print(f"Created Google Play edit {edit_id}")

    try:
        tracks = list_tracks(androidpublisher, args.package_name, edit_id)
        for promotion in promotions:
            for track in (promotion.source_track, promotion.target_track):
                if track not in tracks:
                    raise SystemExit(
                        f"Track {track!r} does not exist. Tracks on {args.package_name}: {tracks}"
                    )

        for promotion in promotions:
            found = find_release(
                androidpublisher, args.package_name, edit_id, promotion.source_track, args.version
            )
            print(
                f"{promotion.source_track!r} -> {promotion.target_track!r}: "
                f"release {found.name!r} version codes {found.version_codes} "
                f"({status['status']}"
                + (f", {status['userFraction']:.0%} of users" if "userFraction" in status else "")
                + ")"
            )
            assign_release(
                androidpublisher,
                args.package_name,
                edit_id,
                promotion.target_track,
                found,
                args.version,
                notes,
                status,
            )

        if args.dry_run:
            print("Dry run: plan validated by the Play API; deleting the edit without committing")
            androidpublisher.edits().delete(packageName=args.package_name, editId=edit_id).execute()
            return 0

        print("Committing Google Play edit")
        commit_edit(androidpublisher, args.package_name, edit_id)
        print(f"Promoted v{args.version} on {args.package_name}")
        return 0
    except Exception:
        print(f"Promotion failed before commit; deleting edit {edit_id}", file=sys.stderr)
        try:
            androidpublisher.edits().delete(packageName=args.package_name, editId=edit_id).execute()
        except Exception as delete_error:
            print(f"Failed to delete edit {edit_id}: {delete_error}", file=sys.stderr)
        raise


if __name__ == "__main__":
    raise SystemExit(main())
