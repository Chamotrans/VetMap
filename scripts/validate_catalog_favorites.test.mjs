import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

const interpolationTokens = (value) =>
  value.match(/%(?:\d+\$)?(?:@|lld)/gu) ?? [];

const rangeIDs = (prefix, start, end, excluded = new Set()) =>
  Array.from({length: end - start + 1}, (_, index) => start + index)
    .filter((number) => !excluded.has(number))
    .map((number) =>
      `hk-service-${prefix}-${String(number).padStart(3, "0")}`,
    );

const swiftIntegerExpression = (source, variableName, nextVariableName) => {
  const terminator = nextVariableName.startsWith("return ")
    ? nextVariableName
    : `let ${nextVariableName}`;
  const body = source.match(
    new RegExp(
      `let ${variableName} = ([\\s\\S]*?)\\n\\s*${terminator}`,
      "u",
    ),
  )?.[1];
  assert.ok(body, `missing Swift integer expression: ${variableName}`);

  const tokenPattern = /Array\((\d+)\.\.\.(\d+)\)|\[([\d,\s]+)\]/gu;
  const numbers = [];
  for (const match of body.matchAll(tokenPattern)) {
    if (match[1] !== undefined) {
      const start = Number(match[1]);
      const end = Number(match[2]);
      numbers.push(...Array.from({length: end - start + 1}, (_, index) => start + index));
    } else {
      numbers.push(...match[3].split(",").map(Number));
    }
  }
  assert.equal(
    body.replace(tokenPattern, "").replace(/[+\s]/gu, ""),
    "",
    `unparsed Swift allowlist syntax: ${variableName}`,
  );
  return numbers;
};

test("service and insurance favourites replace the profile placeholder", async () => {
  const [profile, productDetail, insuranceDetail, store] = await Promise.all([
    read("VetMap/Views/TabViews/ProfileTab.swift"),
    read("VetMap/Views/Products/ProductDetailView.swift"),
    read("VetMap/Views/Insurance/InsuranceDetailView.swift"),
    read("VetMap/Utilities/FavoriteButton.swift"),
  ]);
  const catalogStore = store.match(
    /final class CatalogFavoritesStore[\s\S]*?\n\}\n\nstruct FavoriteButton/u,
  )?.[0];
  const clinicStore = store.match(
    /final class ClinicFavoritesStore[\s\S]*?\n\}\n\n@MainActor\nfinal class CatalogFavoritesStore/u,
  )?.[0];
  assert.ok(catalogStore, "CatalogFavoritesStore source block is missing");
  assert.ok(clinicStore, "ClinicFavoritesStore source block is missing");

  assert.doesNotMatch(profile, /ComingSoonView/);
  assert.match(profile, /CatalogFavoritesView\(\)/);
  assert.match(profile, /Section\("寵物服務/);
  assert.match(profile, /Section\("保險官方入口/);
  assert.match(profile, /移除無法顯示的收藏/);
  assert.match(productDetail, /CatalogFavoriteButton\(itemID: product\.id, kind: \.service\)/);
  assert.match(insuranceDetail, /CatalogFavoriteButton\(itemID: plan\.id, kind: \.insurance\)/);
  assert.match(store, /CatalogFavoriteButton[\s\S]*?\.frame\(width: 44, height: 44\)/u);
  assert.match(catalogStore, /sessionGeneration/);
  assert.match(catalogStore, /generation == sessionGeneration/);
  assert.doesNotMatch(catalogStore, /itemIDs = previousIDs/);
  assert.match(
    catalogStore,
    /itemIDs = SavedCatalogItems\.rollingBack\([\s\S]*?previousItemIDs: previousIDs,[\s\S]*?currentItemIDs: itemIDs/,
  );
  assert.match(catalogStore, /prepareLocalSession\(for userID: String\)/);
  assert.match(catalogStore, /guard preparedUserID != userID else \{ return \}/);
  assert.match(catalogStore, /preparedUserID = userID/);
  assert.match(catalogStore, /cacheOwnerUserID = userID\s+loadedUserID = userID/u);
  assert.doesNotMatch(catalogStore, /await refresh\(force: force\)/);
  for (const [name, source] of [
    ["clinic", clinicStore],
    ["catalog", catalogStore],
  ]) {
    assert.match(
      source,
      /if loadedUserID != userID \{\s*await refresh\(\)\s*\}\s*guard AuthViewModel\.shared\.user\?\.uid == userID else \{\s*return\s*\}/u,
      `${name} stale mutation must not clear a newly prepared account session`,
    );
  }
});

test("saved catalog IDs are account scoped, canonical and privacy declared", async () => {
  const [model, firebase, auth, privacy, setup, rules] = await Promise.all([
    read("VetMap/Models/UserProfile.swift"),
    read("VetMap/Services/FirebaseService.swift"),
    read("VetMap/ViewModels/AuthViewModel.swift"),
    read("VetMap/PrivacyInfo.xcprivacy"),
    read("AppStoreSetup.md"),
    read("FirestoreRules.rules"),
  ]);

  assert.match(model, /enum SavedCatalogItems/);
  assert.match(model, /static let maximumCount = 200/);
  assert.match(model, /static let allowedItemIDs: \[String\]/);
  assert.match(model, /guard allowedItemIDSet\.contains\(value\) else/);
  assert.match(model, /\^hk-service-\[a-z\]\{3\}-\[0-9\]\{3\}\$/);
  assert.match(model, /\^insurance-hk-/);
  assert.match(firebase, /fetchSavedCatalogItemIDs\(expectedUserID:/);
  assert.match(firebase, /setCatalogItemSaved/);
  assert.match(firebase, /fetchFavoriteClinicIDs\(expectedUserID:/);
  assert.match(
    firebase,
    /setClinicFavorite\([\s\S]*?expectedUserID: String[\s\S]*?identity\.uid == expectedUserID/u,
  );
  assert.match(firebase, /identity\.uid == expectedUserID/);
  assert.match(firebase, /"savedProducts": isSaved/);
  assert.match(firebase, /catalogDocumentIdentityMismatch/);
  assert.match(firebase, /rawValues\.compactMap \{ \$0 as\? String \}/);
  assert.match(auth, /CatalogFavoritesStore\.shared\.clearLocalSession\(\)/);
  assert.match(auth, /CatalogFavoritesStore\.shared\.prepareLocalSession/);
  assert.match(auth, /private func commitSignedInUser/);
  assert.equal(
    (auth.match(/authState = \.signedIn/gu) ?? []).length,
    1,
    "all direct authentication paths must use commitSignedInUser",
  );
  assert.match(auth, /rawSavedValues\.compactMap \{ \$0 as\? String \}/);
  assert.match(auth, /SavedCatalogItems\.normalized/);
  assert.match(auth, /database\.runTransaction/);

  const privacyDictionaries = privacy.match(/<dict>[\s\S]*?<\/dict>/gu) ?? [];
  const productInteractionBlocks = privacyDictionaries.filter((block) =>
    block.includes("NSPrivacyCollectedDataTypeProductInteraction"),
  );
  assert.equal(productInteractionBlocks.length, 1);
  const productInteraction = productInteractionBlocks[0];
  assert.match(
    productInteraction,
    /NSPrivacyCollectedDataTypeLinked<\/key>\s*<true\/>/u,
  );
  assert.match(
    productInteraction,
    /NSPrivacyCollectedDataTypeTracking<\/key>\s*<false\/>/u,
  );
  assert.match(
    productInteraction,
    /NSPrivacyCollectedDataTypePurposes<\/key>[\s\S]*NSPrivacyCollectedDataTypePurposeAppFunctionality/u,
  );
  assert.match(setup, /Product Interaction[^\n]*Yes[^\n]*No[^\n]*App Functionality/);

  const allowlistBody = rules.match(
    /function allowedSavedCatalogItemIDs\(\) \{[\s\S]*?return \[([\s\S]*?)\];/u,
  )?.[1];
  assert.ok(allowlistBody, "saved catalog allowlist is missing from rules");
  const allowedIDs = [...allowlistBody.matchAll(/'([^']+)'/gu)]
    .map((match) => match[1]);
  const expectedIDs = [
    ...rangeIDs(
      "sup",
      1,
      62,
      new Set([13, 14, 15, 16, 18, 34, 35, 36, 37, 38, 39, 40]),
    ),
    ...rangeIDs("grm", 1, 56, new Set([29, 30, 31, 32, 33, 34])),
    ...rangeIDs("fun", 1, 24),
    "insurance-hk-fwd",
    "insurance-hk-onedegree",
    "insurance-hk-bluecross",
  ];
  assert.deepEqual(allowedIDs, expectedIDs);
  assert.equal(new Set(allowedIDs).size, 127);
  const swiftAllowedIDs = [
    ...swiftIntegerExpression(model, "supplyNumbers", "groomingNumbers")
      .map((number) => `hk-service-sup-${String(number).padStart(3, "0")}`),
    ...swiftIntegerExpression(model, "groomingNumbers", "funeralNumbers")
      .map((number) => `hk-service-grm-${String(number).padStart(3, "0")}`),
    ...swiftIntegerExpression(model, "funeralNumbers", "return serviceIDs")
      .map((number) => `hk-service-fun-${String(number).padStart(3, "0")}`),
    "insurance-hk-fwd",
    "insurance-hk-onedegree",
    "insurance-hk-bluecross",
  ];
  assert.deepEqual(swiftAllowedIDs, expectedIDs);
  assert.match(rules, /data\.savedProducts\.hasOnly\(allowedSavedCatalogItemIDs\(\)\)/u);
  assert.match(
    rules,
    /data\.savedProducts\.toSet\(\)\.size\(\) == data\.savedProducts\.size\(\)/u,
  );
  assert.match(rules, /function validUserSavedListsUpdate\(after, before\)/u);
  assert.match(rules, /after\.get\('savedProducts', null\)/u);
  assert.match(rules, /before\.get\('savedProducts', null\)/u);
  assert.match(rules, /let afterHasSaved = 'savedProducts' in after;/u);
  assert.match(rules, /afterHasSaved == beforeHasSaved/u);
  assert.match(rules, /afterHasSaved[\s\S]*?afterSaved is list/u);
  assert.match(
    rules,
    /afterSaved\.size\(\) - afterSaved\.toSet\(\)\.size\(\)[\s\S]*?<= beforeSaved\.size\(\) - beforeSaved\.toSet\(\)\.size\(\)/u,
  );
  assert.match(
    rules,
    /afterSaved\.toSet\(\)[\s\S]*?\.difference\(beforeSaved\.toSet\(\)\)[\s\S]*?\.hasOnly\(allowedSavedCatalogItemIDs\(\)\)/u,
  );
  assert.match(
    rules,
    /validUserSavedListsUpdate\(request\.resource\.data, resource\.data\)/u,
  );
});

test("catalog favourites are translated with matching placeholders", async () => {
  const catalog = JSON.parse(await read("VetMap/Localizable.xcstrings"));
  const requiredKeys = [
    "收藏診所同服務、投稿評論、分享報價",
    "收藏服務",
    "寵物服務（%lld）",
    "開啟收藏服務詳情",
    "保險官方入口（%lld）",
    "開啟收藏保險入口詳情",
    "另有 %lld 項收藏目前未在公開目錄顯示。",
    "移除無法顯示的收藏",
    "目錄項目可能因資料到期、下架或識別碼更新而暫時不可用。",
    "重新同步",
    "重新載入服務",
    "重新載入保險入口",
    "正在同步收藏服務…",
    "尚未收藏服務",
    "在服務或保險詳情按心形按鈕，收藏會同步到你的 VetMap 帳戶。",
    "未能顯示收藏",
    "請使用上方重試按鈕重新載入香港服務及保險目錄。",
    "服務收藏",
    "保險入口收藏",
    "將服務加入收藏",
    "從收藏移除服務",
    "將保險入口加入收藏",
    "從收藏移除保險入口",
    "同步到你的 VetMap 帳戶",
    "登入後同步到你的 VetMap 帳戶",
    "無法同步服務收藏：%@",
    "最多可收藏 %lld 項服務或保險。",
    "無法更新服務收藏：%@",
    "服務或保險識別碼無效，未能更新收藏。",
    "登入帳戶已變更，請重新操作。",
    "目錄文件識別碼不一致：%@",
    "暫時無法載入香港寵物服務目錄，請稍後再試。",
    "暫時無法載入香港寵物保險目錄，請稍後再試。",
  ];

  for (const key of requiredKeys) {
    const entry = catalog.strings[key];
    assert.ok(entry, `missing localization key: ${key}`);
    for (const locale of ["en", "zh-Hans"]) {
      const unit = entry.localizations?.[locale]?.stringUnit;
      assert.equal(unit?.state, "translated", `${locale} is not translated: ${key}`);
      assert.deepEqual(
        interpolationTokens(unit.value),
        interpolationTokens(key),
        `${locale} placeholder mismatch: ${key}`,
      );
    }
  }
});
