#!/usr/bin/env python3
"""Update VetMap's editable App Store metadata to the Hong Kong release copy.

Required environment variables:
  ASC_KEY_ID
  ASC_ISSUER_ID
  ASC_PRIVATE_KEY_PATH

The script never changes Content Rights and never submits the review draft.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import time
import urllib.parse
import urllib.request
import urllib.error

import jwt


API_ROOT = "https://api.appstoreconnect.apple.com/v1"
VERSION_ID = "583c6199-bf1e-42d9-8bd4-69c2e51f4d2c"

ZH_DESCRIPTION = """VetMap 係一個專為香港毛孩家長而設嘅獸醫診所地圖同社群 App。

搵診所
• 瀏覽經整理及審核後公開嘅香港獸醫診所
• 用關鍵字、地區及服務項目搜尋
• 查看地址、電話及地圖位置
• 營業時間、服務、評分及費用只會喺有可靠資料或經審核後顯示

睇評價
• 已審核嘅社群評價同評分
• 每個帳戶只可投一次嘅「有用」標記
• 舉報不當內容及封鎖相關用戶

費用透明
• 治療報價分享系統
• 預估費用 vs 實際費用
• 以 HKD 分享香港診療費用資料

社群貢獻
• 登入／註冊後可新增診所、評價及治療報價
• 所有投稿先進入人工審核，批准後先會公開
• 可直接喺 App 內刪除帳戶及相關用戶內容

VetMap 首版只顯示香港診所。診所目錄以名稱、地址、電話及地圖位置為主；未重新核實嘅星級、價錢、營業時間、服務及醫療聲稱不會公開。

診所、評價及費用資料只供一般參考，不構成獸醫診斷或治療建議；緊急情況請直接聯絡合資格獸醫診所。"""

EN_DESCRIPTION = """VetMap is a Hong Kong veterinary clinic map and moderated community for pet guardians.

Find clinics
• Browse Hong Kong veterinary clinics published after review
• Search by keyword, area and service
• View addresses, phone numbers and map locations
• Hours, services, ratings and costs are shown only when reliable or approved

Community reviews
• Read approved ratings and reviews
• Mark a review as helpful once per account
• Report inappropriate content and block its author

Treatment quotes
• Share treatment quote information
• Compare estimated and actual costs
• Share Hong Kong cost information in HKD

Contribute
• Sign in or create an account to submit clinics, reviews and treatment quotes
• Every submission remains pending until manually approved
• Delete your account and associated user content in the app

VetMap 1.0 displays Hong Kong clinics only. Directory entries focus on factual names, addresses, phone numbers and map locations. Unverified ratings, prices, opening hours, services and medical claims are not published.

Clinic, review and cost information is for general reference only and is not veterinary diagnosis or treatment advice. In an emergency, contact a qualified veterinary clinic directly."""

KEYWORDS = {
    "zh-Hant": "獸醫,診所,寵物,狗,貓,毛孩,動物醫院,vet,pet,clinic,review,報價,社群,香港,地圖",
    "en-GB": "vet,veterinary,clinic,pet,dog,cat,Hong Kong,map,review,quote,community",
}

DESCRIPTIONS = {
    "zh-Hant": ZH_DESCRIPTION,
    "en-GB": EN_DESCRIPTION,
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
    with open(private_key_path, "r", encoding="utf-8") as handle:
        private_key = handle.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer_id, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


TOKEN = make_token()


def request(
    method: str,
    path: str,
    *,
    query: dict[str, str] | None = None,
    payload: dict | None = None,
) -> tuple[int, dict | None]:
    url = f"{API_ROOT}{path}"
    if query:
        url = f"{url}?{urllib.parse.urlencode(query)}"
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Accept": "application/json",
    }
    if body is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, method=method, headers=headers, data=body)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"{method} {path}: HTTP {error.code} {details}",
        ) from error


_, localization_response = request(
    "GET",
    f"/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations",
    query={"limit": "200"},
)
localizations = {
    item["attributes"]["locale"]: item
    for item in (localization_response or {}).get("data", [])
}

updated_localizations: list[dict[str, str]] = []
for locale, description in DESCRIPTIONS.items():
    item = localizations.get(locale)
    if item is None:
        raise RuntimeError(f"Missing App Store localization: {locale}")
    status, _ = request(
        "PATCH",
        f"/appStoreVersionLocalizations/{item['id']}",
        payload={
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": item["id"],
                "attributes": {
                    "description": description,
                    "keywords": KEYWORDS[locale],
                },
            },
        },
    )
    updated_localizations.append({
        "locale": locale,
        "status": str(status),
        "descriptionSHA256": hashlib.sha256(
            description.encode("utf-8"),
        ).hexdigest(),
    })

_, review_response = request(
    "GET",
    f"/appStoreVersions/{VERSION_ID}/appStoreReviewDetail",
)
review_detail = (review_response or {}).get("data")
if not review_detail or not review_detail.get("id"):
    raise RuntimeError("App Store Review detail relationship is missing.")
review_detail_id = review_detail["id"]
current_notes = (
    review_detail.get("attributes", {}).get("notes")
    or ""
)
deletion_account_match = re.search(
    r"Disposable deletion-test account:\s*"
    r"Email:\s*[^\n]+\s*"
    r"Password:\s*[^\n]+",
    current_notes,
)
if deletion_account_match is None:
    raise RuntimeError(
        "Could not preserve the existing deletion-test account block.",
    )

review_notes = f"""VetMap is a Hong Kong veterinary clinic directory and moderated community platform. It does not diagnose, monitor, prevent, or treat medical conditions and is not a regulated medical device.

Use the credentials in Sign-In Information for the main test account.

Test paths:
1. My → Login / Sign Up.
2. Clinics → + to submit a clinic.
3. Open “VetMap 示範診所（非真實商戶）” → Add Review or Add Quote.
4. Open its approved demo review/quote → Helpful / Report / Block Author.
5. My → Account Settings → Delete Account.

All new clinic, review, and quote submissions remain Pending until manually reviewed by an administrator. No IAP or subscription UI is exposed in v1.0. Location permission is optional and precise location is processed on device only to center the map and calculate distance.

The directory contains ten reviewed Hong Kong entries normalized from the app's existing production Firestore catalog. Only clinic names, addresses, phone numbers and Hong Kong map coordinates are retained. Unverified ratings, prices, opening hours, services and medical claims are not published.

The single demo clinic, review, and quote are VetMap-owned test fixtures. Each is prominently labelled as non-real and contains no third-party business name, medical experience, or real price claim.

{deletion_account_match.group(0)}

Support: https://vetmap-app.web.app/support"""

review_status, _ = request(
    "PATCH",
    f"/appStoreReviewDetails/{review_detail_id}",
    payload={
        "data": {
            "type": "appStoreReviewDetails",
            "id": review_detail_id,
            "attributes": {"notes": review_notes},
        },
    },
)

print(json.dumps({
    "updatedLocalizations": updated_localizations,
    "reviewNotes": {
        "status": review_status,
        "sha256": hashlib.sha256(review_notes.encode("utf-8")).hexdigest(),
        "deletionAccountBlockPreserved": True,
    },
    "contentRightsChanged": False,
    "reviewSubmitted": False,
}, indent=2))
