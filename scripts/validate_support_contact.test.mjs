import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const profilePath = new URL(
  "../VetMap/Views/TabViews/ProfileTab.swift",
  import.meta.url,
);
const supportPagePath = new URL("../public/support.html", import.meta.url);
const setupPath = new URL("../AppStoreSetup.md", import.meta.url);
const metadataPath = new URL("../AppStoreMetadata.md", import.meta.url);
const updaterPath = new URL("./update_asc_hk_metadata.py", import.meta.url);
const localizationPath = new URL(
  "../VetMap/Localizable.xcstrings",
  import.meta.url,
);

const supportURL = "https://vetmap-app.web.app/support";
const supportEmail = "vetmap.app@gmail.com";

test("signed-in and signed-out profiles expose actionable support contact paths", async () => {
  const source = await readFile(profilePath, "utf8");
  const supportEntryCount = source.match(/SupportContactView\(\)/g)?.length ?? 0;

  assert.equal(
    supportEntryCount,
    2,
    "Profile must expose support while signed in and signed out",
  );
  assert.ok(source.includes(supportURL), "Profile support URL must match ASC");
  assert.ok(
    source.includes(`mailto:${supportEmail}`),
    "Profile must provide an actionable support email",
  );
  assert.doesNotMatch(source, /高對比模式|isOn:\s*\.constant\(false\)/);
});

test("app, hosted support page, and release metadata use the same support identity", async () => {
  const [supportPage, setup, metadata, updater] = await Promise.all([
    readFile(supportPagePath, "utf8"),
    readFile(setupPath, "utf8"),
    readFile(metadataPath, "utf8"),
    readFile(updaterPath, "utf8"),
  ]);

  assert.ok(supportPage.includes(`mailto:${supportEmail}`));
  assert.ok(supportPage.includes(supportEmail));
  for (const [name, source] of [
    ["AppStoreSetup.md", setup],
    ["AppStoreMetadata.md", metadata],
    ["ASC metadata updater", updater],
  ]) {
    assert.ok(source.includes(supportURL), `${name} must retain ${supportURL}`);
  }
});

test("support contact UI is localized for every launch language", async () => {
  const catalog = JSON.parse(await readFile(localizationPath, "utf8"));
  const requiredKeys = [
    "支援與聯絡",
    "取得協助",
    "查看常見問題、帳戶支援及私隱資料要求的處理方法。",
    "開啟 VetMap 支援網頁",
    "在瀏覽器開啟 VetMap 支援網頁",
    "聯絡 VetMap",
    "電郵支援",
    "建立寄給 VetMap 支援團隊的電郵",
    "診所資料更正",
    "如發現診所地址、電話或營運狀態有誤，可在診所詳情頁舉報，或提交更新資料供審核。",
  ];

  for (const key of requiredKeys) {
    const entry = catalog.strings[key];
    assert.ok(entry, `missing support localization key: ${key}`);
    for (const locale of ["en", "zh-Hans"]) {
      const unit = entry.localizations?.[locale]?.stringUnit;
      assert.equal(unit?.state, "translated", `${key} missing ${locale}`);
      assert.ok(unit?.value?.trim(), `${key} has an empty ${locale} value`);
    }
  }
});
