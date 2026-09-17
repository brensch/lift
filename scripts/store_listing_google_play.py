#!/usr/bin/env python3
"""Pull or push the Google Play store listing: text and images.

    push: store/listing.yaml + store/screenshots/out/play/** + marketing/ -> every
          language on the Play listing, in one edit. Text: title, short and full
          description. Images: phone screenshots, Wear OS screenshots, feature
          graphic, icon (each type replaced wholesale, so the store matches the
          repo exactly).
    pull: print the current listing text for every language as YAML, to seed or
          compare with store/listing.yaml.

    scripts/store_listing_google_play.py push --package-name com.brensch.schlift [--dry-run]
    scripts/store_listing_google_play.py pull --package-name com.brensch.schlift

Same service account as the upload/promote scripts. `--dry-run` does every
write inside the edit and then deletes the edit instead of committing it, so
the Play API validates everything without anything going live.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

import httplib2

from check_store_text import LIMITS, check, load_listing  # noqa: E402  (sibling script)
from upload_google_play import (  # noqa: E402
    ANDROID_PUBLISHER_SCOPE,
    commit_edit,
    google_auth_httplib2_request,
    load_service_account_info,
)

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "store" / "screenshots" / "out" / "play"
MARKETING = ROOT / "marketing"

# Play image types -> where the repo keeps them. Each type is replaced wholesale.
IMAGE_SOURCES = {
    "phoneScreenshots": lambda: sorted((IMAGES / "phone").glob("*.png")),
    "wearScreenshots": lambda: sorted((IMAGES / "wear").glob("*.png")),
    "featureGraphic": lambda: [MARKETING / "feature_graphic.png"],
    "icon": lambda: [MARKETING / "schlift-square-512.png"],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=["pull", "push"])
    parser.add_argument("--package-name", required=True)
    parser.add_argument("--listing", type=Path, default=ROOT / "store" / "listing.yaml")
    parser.add_argument("--skip-images", action="store_true", help="Text only")
    parser.add_argument("--service-account-json", default=None)
    parser.add_argument("--service-account-json-file", default=None)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def connect(args: argparse.Namespace):
    credentials = service_account.Credentials.from_service_account_info(
        load_service_account_info(args), scopes=[ANDROID_PUBLISHER_SCOPE]
    )
    http = google_auth_httplib2_request(credentials, httplib2.Http(timeout=300))
    return build("androidpublisher", "v3", http=http, cache_discovery=False)


def pull(publisher, package: str, edit_id: str) -> None:
    listings = publisher.edits().listings().list(packageName=package, editId=edit_id).execute()
    out = {}
    for listing in listings.get("listings", []):
        out[listing["language"]] = {
            "name": listing.get("title", ""),
            "short_description": listing.get("shortDescription", ""),
            "description": listing.get("fullDescription", ""),
        }
        images = {}
        for image_type in IMAGE_SOURCES:
            result = (
                publisher.edits()
                .images()
                .list(packageName=package, editId=edit_id, language=listing["language"], imageType=image_type)
                .execute()
            )
            images[image_type] = len(result.get("images", []))
        out[listing["language"]]["images"] = images
    print(yaml.safe_dump(out, allow_unicode=True, sort_keys=False, width=100))


def push(publisher, package: str, edit_id: str, listing: dict, skip_images: bool) -> None:
    languages = [l["language"] for l in publisher.edits().listings().list(packageName=package, editId=edit_id).execute().get("listings", [])]
    if not languages:
        raise SystemExit("The Play listing has no languages yet; create the default one in Play Console first")
    for language in languages:
        print(f"[{language}] title / short / full description")
        publisher.edits().listings().update(
            packageName=package,
            editId=edit_id,
            language=language,
            body={
                "language": language,
                "title": listing["name"].strip(),
                "shortDescription": listing["short_description"].strip(),
                "fullDescription": listing["description"].strip(),
            },
        ).execute()
        if skip_images:
            continue
        for image_type, source in IMAGE_SOURCES.items():
            files = [f for f in source() if f.is_file()]
            if not files:
                print(f"[{language}] {image_type}: no files in repo, leaving the store's as is")
                continue
            publisher.edits().images().deleteall(
                packageName=package, editId=edit_id, language=language, imageType=image_type
            ).execute()
            for f in files:
                publisher.edits().images().upload(
                    packageName=package,
                    editId=edit_id,
                    language=language,
                    imageType=image_type,
                    media_body=MediaFileUpload(str(f), mimetype="image/png"),
                ).execute()
                print(f"[{language}] {image_type}: uploaded {f.relative_to(ROOT)}")


def main() -> int:
    args = parse_args()
    listing = load_listing(args.listing)
    if args.action == "push":
        problems = check(listing)
        if problems:
            for p in problems:
                print(f"FAIL {p}")
            return 1

    publisher = connect(args)
    edit_id = publisher.edits().insert(packageName=args.package_name, body={}).execute()["id"]
    print(f"Created Google Play edit {edit_id}")
    try:
        if args.action == "pull":
            pull(publisher, args.package_name, edit_id)
            publisher.edits().delete(packageName=args.package_name, editId=edit_id).execute()
            return 0
        push(publisher, args.package_name, edit_id, listing, args.skip_images)
        if args.dry_run:
            print("Dry run: listing accepted by the Play API; deleting the edit without committing")
            publisher.edits().delete(packageName=args.package_name, editId=edit_id).execute()
            return 0
        print("Committing Google Play edit")
        commit_edit(publisher, args.package_name, edit_id)
        print("Play listing updated")
        return 0
    except Exception:
        print(f"Failed before commit; deleting edit {edit_id}", file=sys.stderr)
        try:
            publisher.edits().delete(packageName=args.package_name, editId=edit_id).execute()
        except Exception as delete_error:  # noqa: BLE001
            print(f"Failed to delete edit {edit_id}: {delete_error}", file=sys.stderr)
        raise


if __name__ == "__main__":
    _ = LIMITS  # imported for the reader: the limits live in check_store_text
    raise SystemExit(main())
