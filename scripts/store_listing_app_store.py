#!/usr/bin/env python3
"""Pull or push the App Store listing: text and screenshots.

    push: store/listing.yaml + store/screenshots/out/appstore/** -> every locale
          on the app. Name and subtitle go on the app-level record (only when it
          is editable); promotional text, keywords, description and the iPhone
          + Apple Watch screenshot sets go on one App Store version.
    pull: print the current text for every locale as YAML.

    scripts/store_listing_app_store.py push --bundle-id com.brensch.schlift [--version 0.10.2] \
[--dry-run]
    scripts/store_listing_app_store.py pull --bundle-id com.brensch.schlift

Which version: `--version X.Y.Z` picks (or creates) that version; without it
the newest version still in an editable state is used, and the script stops
if there is none (a version waiting for review cannot be changed — pull it
from review or wait for the next one).

Same API key secrets as the upload/promote scripts. `--dry-run` prints every
write instead of sending it.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
import time
import urllib.request
from pathlib import Path

import yaml
from check_store_text import (
    check,
    compose_description,
    load_listing,
)
from promote_app_store import (
    EDITABLE_STATES,
    IN_FLIGHT_STATES,
    AppStoreConnect,
    load_credentials,
    version_state,
)

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "store" / "screenshots" / "out" / "appstore"

# Display type -> (folder, pixel size the files must be)
SCREENSHOT_SETS = {
    "APP_IPHONE_67": ("iphone", (1320, 2868)),
    "APP_WATCH_SERIES_7": ("watch", (396, 484)),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("action", choices=["pull", "push", "inspect"])
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--listing", type=Path, default=ROOT / "store" / "listing.yaml")
    parser.add_argument(
        "--version", default=None, help="App Store version to write to (created if missing)"
    )
    parser.add_argument("--skip-images", action="store_true", help="Text only")
    parser.add_argument(
        "--remove-from-review",
        action="store_true",
        help="If --version is waiting for review, cancel that submission first so it can be edited",
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path} is not a PNG")
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def find_app(asc: AppStoreConnect, bundle_id: str) -> str:
    apps = asc.get("/apps", {"filter[bundleId]": bundle_id, "fields[apps]": "bundleId,name"}).get(
        "data", []
    )
    if len(apps) != 1:
        raise SystemExit(f"Expected one app with bundle id {bundle_id}, found {len(apps)}")
    return apps[0]["id"]


def editable_app_info(asc: AppStoreConnect, app_id: str) -> dict | None:
    infos = asc.get(
        f"/apps/{app_id}/appInfos", {"fields[appInfos]": "state,appStoreState", "limit": 10}
    ).get("data", [])
    for info in infos:
        state = info["attributes"].get("state") or info["attributes"].get("appStoreState")
        if state in EDITABLE_STATES:
            return info
    return None


def list_versions(asc: AppStoreConnect, app_id: str, wanted: str | None) -> list[dict]:
    # This endpoint rejects `sort`; order newest-first here instead.
    params = {
        "filter[platform]": "IOS",
        "limit": 20,
        "fields[appStoreVersions]": "versionString,appVersionState,appStoreState,createdDate",
    }
    if wanted:
        params["filter[versionString]"] = wanted
    versions = asc.get(f"/apps/{app_id}/appStoreVersions", params).get("data", [])
    versions.sort(key=lambda v: v["attributes"].get("createdDate") or "", reverse=True)
    return versions


def remove_from_review(asc: AppStoreConnect, app_id: str, version: dict) -> None:
    """Cancel the review submission holding `version`, then wait for the
    version to become editable again. Same as "Remove from Review" in App
    Store Connect: the build stays attached, the queue place is lost."""
    submissions = asc.get(
        f"/apps/{app_id}/reviewSubmissions",
        {
            "filter[platform]": "IOS",
            "filter[state]": "WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES",
            "limit": 10,
        },
    ).get("data", [])
    for submission in submissions:
        # The relationship's data only comes back when asked for explicitly.
        items = asc.get(
            f"/reviewSubmissions/{submission['id']}/items",
            {
                "limit": 10,
                "fields[reviewSubmissionItems]": "appStoreVersion",
                "include": "appStoreVersion",
            },
        ).get("data", [])
        ids = [
            (item.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id")
            for item in items
        ]
        holds_version = version["id"] in ids
        if not holds_version and any(ids):
            continue
        if not holds_version:
            # Apple allows one in-flight submission per platform, so with no
            # item data to go on, the open one is the one holding this version.
            print(
                f"Submission {submission['id']} has no item detail; "
                f"assuming it holds {version['attributes']['versionString']}"
            )
        print(
            f"Removing {version['attributes']['versionString']} from review "
            f"(submission {submission['id']}, {submission['attributes']['state']})"
        )
        asc.patch(
            f"/reviewSubmissions/{submission['id']}",
            {
                "data": {
                    "type": "reviewSubmissions",
                    "id": submission["id"],
                    "attributes": {"canceled": True},
                }
            },
        )
        if asc.dry_run:
            return
        for _ in range(12):
            time.sleep(5)
            fresh = asc.get(
                f"/appStoreVersions/{version['id']}",
                {"fields[appStoreVersions]": "versionString,appVersionState,appStoreState"},
            ).get("data")
            if fresh and version_state(fresh) in EDITABLE_STATES:
                print(f"Version is now {version_state(fresh)}")
                return
        raise SystemExit(
            "Cancelled the review submission "
            "but the version did not become editable within a minute"
        )
    raise SystemExit(
        f"No open review submission holds version {version['attributes']['versionString']}"
    )


def pick_version(
    asc: AppStoreConnect, app_id: str, wanted: str | None, remove: bool = False
) -> dict:
    versions = list_versions(asc, app_id, wanted)
    if wanted and remove:
        for v in versions:
            if version_state(v) in IN_FLIGHT_STATES:
                remove_from_review(asc, app_id, v)
                versions = list_versions(asc, app_id, wanted)
                break
    for v in versions:
        if version_state(v) in EDITABLE_STATES:
            print(
                f"Using App Store version {v['attributes']['versionString']} "
                f"({v['id']}, {version_state(v)})"
            )
            return v
    if wanted:
        print(f"Creating App Store version {wanted}")
        created = asc.post(
            "/appStoreVersions",
            {
                "data": {
                    "type": "appStoreVersions",
                    "attributes": {
                        "platform": "IOS",
                        "versionString": wanted,
                        "releaseType": "AFTER_APPROVAL",
                    },
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )
        return created.get("data") or {"id": "<new>", "attributes": {"versionString": wanted}}
    states = ", ".join(
        f"{v['attributes']['versionString']}={version_state(v)}" for v in versions[:5]
    )
    raise SystemExit(
        "No App Store version is editable right now "
        f"({states or 'none'}). Pass --version X.Y.Z to create the next one, "
        "or pull the current one from review."
    )


def pull(asc: AppStoreConnect, app_id: str, version: dict | None) -> None:
    out: dict = {}
    info = editable_app_info(asc, app_id)
    infos = (
        [info] if info else asc.get(f"/apps/{app_id}/appInfos", {"limit": 10}).get("data", [])[:1]
    )
    for info in infos:
        for loc in asc.get(f"/appInfos/{info['id']}/appInfoLocalizations", {"limit": 50}).get(
            "data", []
        ):
            a = loc["attributes"]
            out.setdefault(a["locale"], {}).update(
                {"name": a.get("name", ""), "subtitle": a.get("subtitle") or ""}
            )
    if version and version["id"] != "<new>":
        for loc in asc.get(
            f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations", {"limit": 50}
        ).get("data", []):
            a = loc["attributes"]
            out.setdefault(a["locale"], {}).update(
                {
                    "promotional_text": a.get("promotionalText") or "",
                    "keywords": a.get("keywords") or "",
                    "description": a.get("description") or "",
                    "whats_new": a.get("whatsNew") or "",
                }
            )
            sets = asc.get(
                f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets", {"limit": 50}
            ).get("data", [])
            out[a["locale"]]["screenshot_sets"] = {
                s["attributes"]["screenshotDisplayType"]: len(
                    asc.get(f"/appScreenshotSets/{s['id']}/appScreenshots", {"limit": 50}).get(
                        "data", []
                    )
                )
                for s in sets
            }
    print(yaml.safe_dump(out, allow_unicode=True, sort_keys=False, width=100))


def inspect(asc: AppStoreConnect, app_id: str, wanted: str | None) -> None:
    """Read-only: every version and its state, then every screenshot set on one
    version (any state) with each image's file name, size and processing state.

    The store shows a device the set for its own display size, falling back to a
    larger one. A set this script does not manage (SCREENSHOT_SETS) keeps
    whatever was uploaded by hand, so stale images hide there.
    """
    versions = list_versions(asc, app_id, None)
    print("versions:")
    for v in versions:
        print(f"  {v['attributes']['versionString']}: {version_state(v)}")
    target = next(
        (v for v in versions if not wanted or v["attributes"]["versionString"] == wanted), None
    )
    if target is None:
        raise SystemExit(f"no App Store version {wanted}")
    print(f"\nscreenshots on {target['attributes']['versionString']} ({version_state(target)}):")
    for loc in asc.get(
        f"/appStoreVersions/{target['id']}/appStoreVersionLocalizations", {"limit": 50}
    ).get("data", []):
        locale = loc["attributes"]["locale"]
        sets = asc.get(
            f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets", {"limit": 50}
        ).get("data", [])
        if not sets:
            print(f"  [{locale}] no screenshot sets")
        for s in sets:
            display_type = s["attributes"]["screenshotDisplayType"]
            managed = "managed" if display_type in SCREENSHOT_SETS else "NOT MANAGED by this script"
            shots = asc.get(f"/appScreenshotSets/{s['id']}/appScreenshots", {"limit": 50}).get(
                "data", []
            )
            print(f"  [{locale}] {display_type} ({managed}): {len(shots)} image(s)")
            for shot in shots:
                a = shot["attributes"]
                asset = a.get("imageAsset") or {}
                state = (a.get("assetDeliveryState") or {}).get("state", "?")
                print(
                    f"      {a.get('fileName')}  {asset.get('width')}x{asset.get('height')}  "
                    f"{a.get('fileSize')} bytes  {state}"
                )


def push_text(asc: AppStoreConnect, app_id: str, version: dict, listing: dict) -> list[dict]:
    info = editable_app_info(asc, app_id)
    if info is None:
        print("App-level record (name, subtitle) is not editable right now; leaving it")
    else:
        for loc in asc.get(f"/appInfos/{info['id']}/appInfoLocalizations", {"limit": 50}).get(
            "data", []
        ):
            print(f"[{loc['attributes']['locale']}] name / subtitle")
            asc.patch(
                f"/appInfoLocalizations/{loc['id']}",
                {
                    "data": {
                        "type": "appInfoLocalizations",
                        "id": loc["id"],
                        "attributes": {
                            "name": listing["name"].strip(),
                            "subtitle": listing["tagline"].strip(),
                        },
                    }
                },
            )
    localizations = []
    if version["id"] != "<new>":
        localizations = asc.get(
            f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations", {"limit": 50}
        ).get("data", [])
    if not localizations:
        print("Version has no localizations yet; creating en-US")
        created = asc.post(
            "/appStoreVersionLocalizations",
            {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "attributes": {"locale": "en-US"},
                    "relationships": {
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": version["id"]}
                        }
                    },
                }
            },
        )
        localizations = [
            created.get("data") or {"id": "<new-loc>", "attributes": {"locale": "en-US"}}
        ]
    for loc in localizations:
        print(f"[{loc['attributes']['locale']}] promotional text / keywords / description")
        asc.patch(
            f"/appStoreVersionLocalizations/{loc['id']}",
            {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc["id"],
                    "attributes": {
                        "promotionalText": listing["promotional_text"].strip(),
                        "keywords": listing["keywords"].strip(),
                        "description": compose_description(listing),
                    },
                }
            },
        )
    return localizations


def upload_screenshot(asc: AppStoreConnect, set_id: str, path: Path) -> str | None:
    data = path.read_bytes()
    reserved = asc.post(
        "/appScreenshots",
        {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": path.name, "fileSize": len(data)},
                "relationships": {
                    "appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}
                },
            }
        },
    ).get("data")
    if not reserved:  # dry run
        return None
    for op in reserved["attributes"]["uploadOperations"]:
        chunk = data[op["offset"] : op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for header in op.get("requestHeaders", []):
            req.add_header(header["name"], header["value"])
        with urllib.request.urlopen(req, timeout=120) as resp:
            resp.read()
    asc.patch(
        f"/appScreenshots/{reserved['id']}",
        {
            "data": {
                "type": "appScreenshots",
                "id": reserved["id"],
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": hashlib.md5(data).hexdigest(),
                },
            }
        },
    )
    return reserved["id"]


def push_images(asc: AppStoreConnect, localizations: list[dict]) -> None:
    for display_type, (folder, expected) in SCREENSHOT_SETS.items():
        files = sorted((IMAGES / folder).glob("*.png"))
        if not files:
            print(f"{display_type}: no files in {IMAGES / folder}, leaving the store's as is")
            continue
        for f in files:
            size = png_size(f)
            if size != expected:
                raise SystemExit(
                    f"{f.relative_to(ROOT)} is {size[0]}x{size[1]}; "
                    f"{display_type} needs {expected[0]}x{expected[1]}"
                )
        for loc in localizations:
            locale = loc["attributes"]["locale"]
            sets = []
            if loc["id"] not in ("<new-loc>",):
                sets = asc.get(
                    f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets", {"limit": 50}
                ).get("data", [])
            existing = next(
                (s for s in sets if s["attributes"]["screenshotDisplayType"] == display_type), None
            )
            if existing is None:
                print(f"[{locale}] {display_type}: creating screenshot set")
                existing = asc.post(
                    "/appScreenshotSets",
                    {
                        "data": {
                            "type": "appScreenshotSets",
                            "attributes": {"screenshotDisplayType": display_type},
                            "relationships": {
                                "appStoreVersionLocalization": {
                                    "data": {
                                        "type": "appStoreVersionLocalizations",
                                        "id": loc["id"],
                                    }
                                }
                            },
                        }
                    },
                ).get("data") or {"id": "<new-set>"}
            else:
                for shot in asc.get(
                    f"/appScreenshotSets/{existing['id']}/appScreenshots", {"limit": 50}
                ).get("data", []):
                    asc.request("DELETE", f"/appScreenshots/{shot['id']}")
            ids = []
            for f in files:
                print(f"[{locale}] {display_type}: uploading {f.relative_to(ROOT)}")
                shot_id = upload_screenshot(asc, existing["id"], f)
                if shot_id:
                    ids.append(shot_id)
            if ids:
                asc.patch(
                    f"/appScreenshotSets/{existing['id']}/relationships/appScreenshots",
                    {"data": [{"type": "appScreenshots", "id": i} for i in ids]},
                )


def main() -> int:
    args = parse_args()
    listing = load_listing(args.listing)
    if args.action == "push":
        problems = check(listing)
        if problems:
            for p in problems:
                print(f"FAIL {p}")
            return 1
    asc = AppStoreConnect(load_credentials(), dry_run=args.dry_run)
    app_id = find_app(asc, args.bundle_id)
    if args.action == "inspect":
        inspect(asc, app_id, args.version)
        return 0
    if args.action == "pull":
        # Read-only: look the version up in whatever state it is in. (This
        # used to go through pick_version, which creates a missing version.)
        versions = list_versions(asc, app_id, args.version)
        version = versions[0] if versions else None
        if version is None:
            print(f"(no App Store version {args.version or ''} to read)")
        pull(asc, app_id, version)
        return 0
    version = pick_version(asc, app_id, args.version, remove=args.remove_from_review)
    localizations = push_text(asc, app_id, version, listing)
    if not args.skip_images:
        push_images(asc, localizations)
    print("Dry run: nothing was written" if args.dry_run else "App Store listing updated")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        sys.exit(130)
