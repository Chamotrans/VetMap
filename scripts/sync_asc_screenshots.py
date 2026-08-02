#!/usr/bin/env python3
"""Safely replace VetMap 1.0 screenshots in App Store Connect.

The command is a dry run unless ``--apply`` is supplied. During an apply it
uploads and validates every replacement before deleting any existing image.
It never changes a build, submits a review, or publishes a release.

Required environment variables:
  ASC_KEY_ID
  ASC_ISSUER_ID
  ASC_PRIVATE_KEY_PATH
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt


API_ROOT = "https://api.appstoreconnect.apple.com/v1"
REPO_ROOT = Path(__file__).resolve().parent.parent
SCREENSHOT_ROOT = REPO_ROOT / "build" / "app-store-screenshots"

TARGETS = (
    {
        "locale": "en-GB",
        "device": "iPhone",
        "set_id": "91989dad-df1b-40e5-ae1a-ff5b3670d630",
        "directory": "iphone",
        # 01-Map is intentionally excluded: the Cloud capture contains a
        # simulator system notification and is not release quality.
        "files": (
            "02-Clinics.png",
            "03-ClinicDetail.png",
            "04-Products.png",
            "05-Messages.png",
            "06-Profile.png",
        ),
    },
    {
        "locale": "en-GB",
        "device": "iPad",
        "set_id": "a2c781cb-215b-4cc7-b3fd-337469c7f480",
        "directory": "ipad",
        "files": (
            "01-Map.png",
            "02-Clinics.png",
            "03-ClinicDetail.png",
            "04-Products.png",
            "05-Messages.png",
            "06-Profile.png",
        ),
    },
    {
        "locale": "zh-Hant",
        "device": "iPhone",
        "set_id": "bc8c7cf2-4147-46e5-ab54-c9112103f8f9",
        "directory": "iphone",
        "files": (
            "02-Clinics.png",
            "03-ClinicDetail.png",
            "04-Products.png",
            "05-Messages.png",
            "06-Profile.png",
        ),
    },
    {
        "locale": "zh-Hant",
        "device": "iPad",
        "set_id": "11b55a1c-5b57-4bf7-9a75-f884efcfd15b",
        "directory": "ipad",
        "files": (
            "01-Map.png",
            "02-Clinics.png",
            "03-ClinicDetail.png",
            "04-Products.png",
            "05-Messages.png",
            "06-Profile.png",
        ),
    },
)

EXPECTED_SIZES = {
    "iphone": (1320, 2868),
    "ipad": (2064, 2752),
}


def require_environment(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def make_token() -> str:
    key_id = require_environment("ASC_KEY_ID")
    issuer_id = require_environment("ASC_ISSUER_ID")
    private_key_path = require_environment("ASC_PRIVATE_KEY_PATH")
    private_key = Path(private_key_path).read_text(encoding="utf-8")
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer_id, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


class ASCClient:
    def __init__(self) -> None:
        self.token = make_token()

    def request(
        self,
        method: str,
        path: str,
        *,
        payload: dict | None = None,
    ) -> tuple[int, dict | None]:
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/json",
        }
        if body is not None:
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(
            f"{API_ROOT}{path}", method=method, headers=headers, data=body
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                raw = response.read()
                return response.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            details = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{method} {path}: HTTP {error.code} {details}") from error

    def list_screenshots(self, set_id: str) -> list[dict]:
        _, response = self.request(
            "GET",
            f"/appScreenshotSets/{set_id}/appScreenshots?limit=10",
        )
        return (response or {}).get("data", [])

    def delete_screenshot(self, screenshot_id: str) -> None:
        self.request("DELETE", f"/appScreenshots/{screenshot_id}")


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError(f"Not a valid PNG: {path}")
    return struct.unpack(">II", header[16:24])


def validate_local_files() -> None:
    for target in TARGETS:
        directory = target["directory"]
        for filename in target["files"]:
            path = SCREENSHOT_ROOT / directory / filename
            if not path.is_file():
                raise RuntimeError(f"Missing screenshot: {path}")
            actual = png_size(path)
            expected = EXPECTED_SIZES[directory]
            if actual != expected:
                raise RuntimeError(
                    f"Unexpected screenshot dimensions for {path}: {actual}, expected {expected}"
                )


def delivery_state(item: dict) -> str:
    state = item.get("attributes", {}).get("assetDeliveryState") or {}
    return state.get("state", "UNKNOWN")


def remote_name(target: dict, order: int, filename: str) -> str:
    slug = filename.removesuffix(".png").lower()
    return (
        f"vetmap-1.0-{target['locale'].lower()}-"
        f"{target['device'].lower()}-{order:02d}-{slug}.png"
    )


def reserve_and_upload(
    client: ASCClient,
    *,
    set_id: str,
    path: Path,
    remote_name: str,
) -> dict:
    data = path.read_bytes()
    _, response = client.request(
        "POST",
        "/appScreenshots",
        payload={
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": remote_name, "fileSize": len(data)},
                "relationships": {
                    "appScreenshotSet": {
                        "data": {"type": "appScreenshotSets", "id": set_id}
                    }
                },
            }
        },
    )
    item = (response or {})["data"]
    screenshot_id = item["id"]

    for operation in item["attributes"]["uploadOperations"]:
        offset = operation["offset"]
        length = operation["length"]
        chunk = data[offset : offset + length]
        if len(chunk) != length:
            raise RuntimeError(f"Invalid upload range for {remote_name}")
        headers = {
            header["name"]: header["value"]
            for header in operation.get("requestHeaders", [])
        }
        request = urllib.request.Request(
            operation["url"],
            method=operation["method"],
            headers=headers,
            data=chunk,
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as upload_response:
                upload_response.read()
                if not 200 <= upload_response.status < 300:
                    raise RuntimeError(
                        f"Upload operation failed for {remote_name}: {upload_response.status}"
                    )
        except urllib.error.HTTPError as error:
            details = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Upload operation failed for {remote_name}: HTTP {error.code} {details}"
            ) from error

    checksum = hashlib.md5(data, usedforsecurity=False).hexdigest()
    _, committed = client.request(
        "PATCH",
        f"/appScreenshots/{screenshot_id}",
        payload={
            "data": {
                "type": "appScreenshots",
                "id": screenshot_id,
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": checksum,
                },
            }
        },
    )
    return (committed or {})["data"]


def wait_until_complete(client: ASCClient, screenshot_id: str, timeout: int = 180) -> dict:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        _, response = client.request("GET", f"/appScreenshots/{screenshot_id}")
        item = (response or {})["data"]
        state = delivery_state(item)
        if state == "COMPLETE":
            return item
        if state == "FAILED":
            errors = item.get("attributes", {}).get("assetDeliveryState", {}).get("errors")
            raise RuntimeError(f"Screenshot {screenshot_id} failed processing: {errors}")
        time.sleep(3)
    raise RuntimeError(f"Timed out waiting for screenshot {screenshot_id}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Upload validated replacements and remove the previous screenshots",
    )
    args = parser.parse_args()

    validate_local_files()
    client = ASCClient()
    baseline: dict[str, list[dict]] = {}
    already_current: set[str] = set()

    for target in TARGETS:
        existing = client.list_screenshots(target["set_id"])
        baseline[target["set_id"]] = existing
        desired_names = [
            remote_name(target, order, filename)
            for order, filename in enumerate(target["files"], start=1)
        ]
        existing_names = [
            item.get("attributes", {}).get("fileName") for item in existing
        ]
        is_current = existing_names == desired_names and all(
            delivery_state(item) == "COMPLETE" for item in existing
        )
        if is_current:
            already_current.add(target["set_id"])
        elif len(existing) + len(target["files"]) > 10:
            raise RuntimeError(
                f"{target['locale']} {target['device']} would exceed the 10 screenshot limit "
                f"({len(existing)} existing + {len(target['files'])} new)"
            )
        summary = [
            {
                "id": item["id"],
                "fileName": item.get("attributes", {}).get("fileName"),
                "state": delivery_state(item),
            }
            for item in existing
        ]
        print(
            json.dumps(
                {
                    "locale": target["locale"],
                    "device": target["device"],
                    "existing": summary,
                    "replacementFiles": list(target["files"]),
                    "alreadyCurrent": is_current,
                },
                ensure_ascii=False,
            )
        )

    if not args.apply:
        print("DRY_RUN: no App Store Connect data changed")
        return 0

    created: list[tuple[str, str]] = []
    try:
        for target in TARGETS:
            if target["set_id"] in already_current:
                print(
                    json.dumps(
                        {"unchanged": f"{target['locale']} {target['device']}"}
                    )
                )
                continue
            for order, filename in enumerate(target["files"], start=1):
                path = SCREENSHOT_ROOT / target["directory"] / filename
                upload_name = remote_name(target, order, filename)
                item = reserve_and_upload(
                    client,
                    set_id=target["set_id"],
                    path=path,
                    remote_name=upload_name,
                )
                created.append((target["set_id"], item["id"]))
                complete = wait_until_complete(client, item["id"])
                print(
                    json.dumps(
                        {
                            "uploaded": upload_name,
                            "id": complete["id"],
                            "state": delivery_state(complete),
                        }
                    )
                )

        # The full replacement portfolio is now processed. Only at this point
        # remove screenshots that existed before this run.
        for target in TARGETS:
            if target["set_id"] in already_current:
                continue
            for item in baseline[target["set_id"]]:
                client.delete_screenshot(item["id"])
                print(json.dumps({"deletedOldScreenshot": item["id"]}))

        for target in TARGETS:
            final = client.list_screenshots(target["set_id"])
            if target["set_id"] in already_current:
                expected_ids = [item["id"] for item in baseline[target["set_id"]]]
            else:
                expected_ids = [
                    screenshot_id
                    for set_id, screenshot_id in created
                    if set_id == target["set_id"]
                ]
            actual_ids = [item["id"] for item in final]
            if actual_ids != expected_ids:
                raise RuntimeError(
                    f"Unexpected final order for {target['locale']} {target['device']}: "
                    f"{actual_ids} != {expected_ids}"
                )
            if any(delivery_state(item) != "COMPLETE" for item in final):
                raise RuntimeError(
                    f"Non-COMPLETE screenshot remains in {target['locale']} {target['device']}"
                )
            print(
                json.dumps(
                    {
                        "verified": f"{target['locale']} {target['device']}",
                        "count": len(final),
                        "states": [delivery_state(item) for item in final],
                    }
                )
            )
    except Exception:
        # If no baseline screenshot was deleted, this restores the exact initial
        # state. If deletion had already begun, leave the COMPLETE replacements
        # present and report the error instead of risking an empty set.
        baseline_still_intact = all(
            {item["id"] for item in client.list_screenshots(set_id)}
            >= {item["id"] for item in items}
            for set_id, items in baseline.items()
        )
        if baseline_still_intact:
            for _, screenshot_id in reversed(created):
                try:
                    client.delete_screenshot(screenshot_id)
                except Exception as cleanup_error:  # noqa: BLE001
                    print(f"Cleanup warning for {screenshot_id}: {cleanup_error}", file=sys.stderr)
        raise

    if len(already_current) == len(TARGETS):
        print("NO_OP: App Store Connect screenshots already match the verified replacements")
    else:
        print("APPLIED: replacement screenshots verified; previous screenshots removed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
