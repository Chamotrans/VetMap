import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const authPath = new URL("../VetMap/ViewModels/AuthViewModel.swift", import.meta.url);
const loginPath = new URL("../VetMap/Views/Profile/LoginView.swift", import.meta.url);
const stringsPath = new URL("../VetMap/Localizable.xcstrings", import.meta.url);

function declarationBody(source, signature) {
  const signatureIndex = source.indexOf(signature);
  assert.notEqual(signatureIndex, -1, `missing declaration: ${signature}`);

  const openingBrace = source.indexOf("{", signatureIndex);
  assert.notEqual(openingBrace, -1, `missing body: ${signature}`);

  let depth = 0;
  for (let index = openingBrace; index < source.length; index += 1) {
    if (source[index] === "{") depth += 1;
    if (source[index] === "}") depth -= 1;
    if (depth === 0) return source.slice(openingBrace + 1, index);
  }

  assert.fail(`unterminated body: ${signature}`);
}

test("password reset normalizes email and uses Firebase's async reset API", async () => {
  const source = await readFile(authPath, "utf8");
  const resetBody = declarationBody(source, "func sendPasswordReset(email:");

  assert.match(resetBody, /trimmingCharacters\(in: \.whitespacesAndNewlines\)/);
  assert.match(resetBody, /\.lowercased\(\)/);
  assert.match(resetBody, /let previousLanguageCode = auth\.languageCode/);
  assert.match(
    resetBody,
    /Self\.passwordResetLanguageCode\(\s*for: Bundle\.main\.preferredLocalizations\.first\s*\)/,
  );
  assert.match(resetBody, /defer \{ auth\.languageCode = previousLanguageCode \}/);
  assert.match(resetBody, /try await auth\.sendPasswordReset\(withEmail: normalizedEmail\)/);
  assert.doesNotMatch(resetBody, /authState\s*=/);
  assert.doesNotMatch(resetBody, /\buser\s*=/);
  assert.doesNotMatch(source, /fetchSignInMethods/);
});

test("password reset locale and privacy mappings are explicit", async () => {
  const source = await readFile(authPath, "utf8");
  const outcomeBody = declarationBody(source, "private func passwordResetOutcome(for error:");
  const localeBody = declarationBody(source, "private static func passwordResetLanguageCode(");

  assert.match(outcomeBody, /case \.userNotFound, \.userDisabled:\s*return \.accepted/);
  assert.match(outcomeBody, /case \.networkError:/);
  assert.match(outcomeBody, /case \.tooManyRequests:/);
  assert.match(outcomeBody, /default:\s*return \.failed\(String\(localized:/);
  assert.match(localeBody, /identifier\.contains\("hant"\)/);
  assert.match(localeBody, /return "zh-TW"/);
  assert.match(localeBody, /identifier\.contains\("hans"\)/);
  assert.match(localeBody, /return "zh-CN"/);
  assert.match(localeBody, /return "en"/);
});

test("login exposes an accessible one-shot password reset sheet", async () => {
  const source = await readFile(loginPath, "utf8");
  const sendBody = declarationBody(source, "private func sendResetEmail()");

  assert.match(source, /Button\("忘記密碼？"\)/);
  assert.match(source, /minHeight: 44/);
  assert.match(source, /\.accessibilityIdentifier\("login\.forgotPassword"\)/);
  assert.match(source, /PasswordResetView\(\s*authViewModel: authViewModel,\s*initialEmail: email/);
  assert.match(source, /\.interactiveDismissDisabled\(isSending\)/);
  assert.match(source, /\.accessibilityIdentifier\("passwordReset\.email"\)/);
  assert.match(source, /\.accessibilityIdentifier\("passwordReset\.send"\)/);
  assert.match(source, /\.accessibilityIdentifier\("passwordReset\.success"\)/);
  assert.match(source, /@AccessibilityFocusState/);
  assert.match(source, /\.accessibilityFocused\(\$accessibilityFocus, equals: \.success\)/);
  assert.match(source, /\.accessibilityFocused\(\$accessibilityFocus, equals: \.fieldError\)/);
  assert.match(source, /\.accessibilityFocused\(\$accessibilityFocus, equals: \.requestError\)/);
  assert.match(source, /isSending \? "正在傳送重設密碼電郵"/);
  assert.match(sendBody, /guard !isSending else \{ return \}/);
  assert.match(sendBody, /guard !trimmedEmail\.isEmpty/);
  assert.match(sendBody, /await authViewModel\.sendPasswordReset\(email: trimmedEmail\)/);
  assert.match(sendBody, /case \.accepted:\s*isAccepted = true/);
  assert.match(source, /如果此電子郵件已註冊/);
});

test("every password reset string has English and Simplified Chinese translations", async () => {
  const catalog = JSON.parse(await readFile(stringsPath, "utf8"));
  const keys = [
    "忘記密碼？",
    "開啟重設密碼頁面",
    "輸入你的帳戶電子郵件，我們會傳送重設密碼連結。",
    "重設密碼",
    "請輸入電子郵件。",
    "如果此電子郵件已註冊，你稍後會收到重設密碼電郵。請檢查收件箱及垃圾郵件。",
    "傳送重設密碼電郵",
    "電子郵件格式不正確。",
    "重設密碼服務暫時未能使用，請稍後再試。",
    "暫時未能傳送重設密碼電郵，請稍後再試。",
    "網絡錯誤，請檢查連線後再試。",
    "請求過於頻繁，請稍後再試。",
    "正在傳送重設密碼電郵",
  ];

  for (const key of keys) {
    const localizations = catalog.strings[key]?.localizations;
    assert.equal(localizations?.en?.stringUnit?.state, "translated", `missing en: ${key}`);
    assert.ok(localizations?.en?.stringUnit?.value, `empty en: ${key}`);
    assert.equal(localizations?.["zh-Hans"]?.stringUnit?.state, "translated", `missing zh-Hans: ${key}`);
    assert.ok(localizations?.["zh-Hans"]?.stringUnit?.value, `empty zh-Hans: ${key}`);
  }
});
