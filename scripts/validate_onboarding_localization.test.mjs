import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const onboardingPath = new URL(
  "../VetMap/Views/Shared/OnboardingView.swift",
  import.meta.url,
);
const stringsPath = new URL("../VetMap/Localizable.xcstrings", import.meta.url);

const pageKeys = [
  "歡迎來到 VetMap",
  "搵到最可靠嘅獸醫診所\n為毛孩揀最好嘅照顧",
  "地圖搜尋",
  "瀏覽附近診所、睇真實評價\n比較費用、一鍵導航",
  "社群分享",
  "寫評價、分享報價\n幫其他毛孩家長做明智選擇",
];

test("dynamic onboarding page copy uses typed localization keys", async () => {
  const source = await readFile(onboardingPath, "utf8");
  const resolvedSourceStrings = source.replaceAll("\\n", "\n");

  assert.match(source, /private struct OnboardingPage/);
  assert.match(source, /let title: LocalizedStringKey/);
  assert.match(source, /let subtitle: LocalizedStringKey/);
  assert.doesNotMatch(source, /title: String/);
  assert.doesNotMatch(source, /subtitle: String/);
  assert.equal(source.match(/OnboardingPage\(/g)?.length, 3);
  assert.match(source, /private func pageView\(_ page: OnboardingPage\)/);

  for (const key of pageKeys) {
    assert.ok(resolvedSourceStrings.includes(key), `onboarding source missing: ${key}`);
  }
});

test("every onboarding page has English and Simplified Chinese copy", async () => {
  const catalog = JSON.parse(await readFile(stringsPath, "utf8"));

  assert.equal(catalog.sourceLanguage, "zh-Hant");
  for (const key of pageKeys) {
    const localizations = catalog.strings[key]?.localizations;
    for (const locale of ["en", "zh-Hans"]) {
      const unit = localizations?.[locale]?.stringUnit;
      assert.equal(unit?.state, "translated", `${key} missing ${locale}`);
      assert.ok(unit?.value?.trim(), `${key} has empty ${locale} copy`);
    }
  }
});

test("onboarding completion and legal destinations remain intact", async () => {
  const source = await readFile(onboardingPath, "utf8");

  assert.match(source, /hasSeenOnboarding = true/);
  assert.match(source, /Text\("開始使用"\)/);
  assert.match(source, /https:\/\/vetmap-app\.web\.app\/tos/);
  assert.match(source, /https:\/\/vetmap-app\.web\.app"/);
  assert.match(source, /Link\("服務條款"/);
  assert.match(source, /Link\("私隱政策"/);
});
