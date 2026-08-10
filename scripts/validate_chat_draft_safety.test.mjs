import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const chatModelPath = new URL("../VetMap/Models/Chat.swift", import.meta.url);
const chatThreadPath = new URL("../VetMap/Views/Chat/ChatThreadView.swift", import.meta.url);
const catalogPath = new URL("../VetMap/Localizable.xcstrings", import.meta.url);

test("failed sends preserve any newer composer draft", async () => {
  const [model, thread] = await Promise.all([
    readFile(chatModelPath, "utf8"),
    readFile(chatThreadPath, "utf8"),
  ]);

  assert.match(model, /struct ChatDraftFailureRecovery: Equatable/);
  assert.match(model, /guard !currentDraft\.isEmpty else/);
  assert.match(model, /composerDraft: currentDraft,[\s\S]*retryBody: failedBody/);
  assert.match(thread, /ChatDraftFailureRecovery\.recover\(/);
  assert.doesNotMatch(thread, /catch\s*\{\s*draft\s*=\s*body/);
});

test("failed messages remain independently retryable without replacing new text", async () => {
  const thread = await readFile(chatThreadPath, "utf8");

  assert.match(thread, /@State private var failedMessageBody: String\?/);
  assert.match(thread, /private func retryFailedMessage\(\)/);
  assert.match(thread, /send\(body: failedMessageBody, recoverIntoComposerOnFailure: false\)/);
  assert.match(thread, /Button\("重試"\)[\s\S]*retryFailedMessage\(\)/);
  assert.match(thread, /Button\("放棄"\)[\s\S]*failedMessageBody = nil/);
  assert.match(thread, /\.disabled\(chat\.isSending\)/);
  assert.match(
    thread,
    /draft\.count > 1_000[\s\S]*chat\.isSending[\s\S]*failedMessageBody != nil/,
    "a second composer send must wait until the failed retry slot is resolved",
  );
  assert.match(
    thread,
    /private func send\(\)\s*\{\s*guard failedMessageBody == nil else \{ return \}/,
    "the send action must also fail closed if invoked outside the disabled button",
  );
});

test("new chat failure affordances are localized for declared fallback languages", async () => {
  const catalog = JSON.parse(await readFile(catalogPath, "utf8"));
  const keys = [
    "上一則訊息未能送出",
    "放棄",
    "放棄上一則訊息",
    "重試上一則訊息",
  ];

  for (const key of keys) {
    const entry = catalog.strings[key];
    assert.ok(entry, `missing localization key: ${key}`);
    for (const locale of ["en", "zh-Hans"]) {
      const unit = entry.localizations?.[locale]?.stringUnit;
      assert.equal(unit?.state, "translated", `${key} ${locale} must be translated`);
      assert.ok(unit?.value?.trim(), `${key} ${locale} must not be empty`);
    }
  }
});
