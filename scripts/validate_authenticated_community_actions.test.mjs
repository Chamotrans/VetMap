import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const paths = {
  userProfile: new URL("../VetMap/Models/UserProfile.swift", import.meta.url),
  clinicViewModel: new URL(
    "../VetMap/ViewModels/ClinicDetailViewModel.swift",
    import.meta.url,
  ),
  quoteViewModel: new URL(
    "../VetMap/ViewModels/QuoteViewModel.swift",
    import.meta.url,
  ),
  clinicsViewModel: new URL(
    "../VetMap/ViewModels/ClinicsViewModel.swift",
    import.meta.url,
  ),
  addClinic: new URL(
    "../VetMap/Views/Community/AddClinicView.swift",
    import.meta.url,
  ),
  clinicList: new URL(
    "../VetMap/Views/Clinics/ClinicListView.swift",
    import.meta.url,
  ),
  addReview: new URL(
    "../VetMap/Views/ClinicDetail/AddReviewView.swift",
    import.meta.url,
  ),
  addQuote: new URL(
    "../VetMap/Views/Community/AddQuoteView.swift",
    import.meta.url,
  ),
  clinicDetail: new URL(
    "../VetMap/Views/ClinicDetail/ClinicDetailView.swift",
    import.meta.url,
  ),
  reviewList: new URL(
    "../VetMap/Views/Review/ReviewListView.swift",
    import.meta.url,
  ),
  quoteList: new URL(
    "../VetMap/Views/Community/QuoteListView.swift",
    import.meta.url,
  ),
  strings: new URL("../VetMap/Localizable.xcstrings", import.meta.url),
};

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

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

test("continuation consumes intent once and cancellation clears it", async () => {
  const source = await readFile(paths.userProfile, "utf8");
  const requestBody = declarationBody(source, "mutating func request(");
  const takeBody = declarationBody(source, "mutating func takeIfAuthenticated(");
  const cancelBody = declarationBody(source, "mutating func cancel()");

  assert.match(requestBody, /case \.loading:\s*pendingAction = action/);
  assert.match(requestBody, /case \.signedOut, \.signedIn:\s*pendingAction = action/);
  assert.match(
    requestBody,
    /case \.signedIn\(let userID\) where !userID\.isEmpty:[\s\S]*pendingAction = nil[\s\S]*return \.perform\(action\)/,
  );
  assert.match(takeBody, /pendingAction = nil\s*return action/);
  assert.match(cancelBody, /pendingAction = nil/);
  assert.match(source, /case authenticationRequired/);
  assert.match(source, /case failed\(message: String\)/);
});

test("review and quote forms preserve snapshots and retry only typed auth failures", async () => {
  const [review, quote] = await Promise.all([
    readFile(paths.addReview, "utf8"),
    readFile(paths.addQuote, "utf8"),
  ]);

  for (const [name, source, draftType] of [
    ["review", review, "ReviewDraft"],
    ["quote", quote, "QuoteDraft"],
  ]) {
    assert.match(source, new RegExp(`let draft = ${draftType}\\(`), `${name} lacks a snapshot`);
    assert.match(source, /AuthenticatedActionContinuation<[^>]+>/);
    assert.match(source, /\.fullScreenCover\(isPresented: \$showLogin, onDismiss: loginDidDismiss\)/);
    assert.match(source, /case \.authenticationRequired:\s*submissionContinuation\.deferUntilAuthenticated\(draft\)/);
    assert.match(source, /case \.failed\(let message\):\s*submissionContinuation\.cancel\(\)/);
    assert.match(source, /takeIfAuthenticated\(authenticationPhase\)/);
    const dismissBody = declarationBody(source, "private func loginDidDismiss()");
    assert.match(dismissBody, /guard didAuthenticateDuringLogin else \{/);
    assert.match(dismissBody, /submissionContinuation\.cancel\(\)/);
  }
});

test("clinic form preserves its reviewed draft across session recovery", async () => {
  const [form, list] = await Promise.all([
    readFile(paths.addClinic, "utf8"),
    readFile(paths.clinicList, "utf8"),
  ]);

  assert.match(form, /AuthenticatedActionContinuation<VetClinic>/);
  assert.match(form, /let clinic = viewModel\.makeClinic\(\)/);
  assert.match(form, /submissionContinuation\.request\(\s*clinic,/);
  assert.match(form, /case \.authenticationRequired:\s*duplicateGate\.finishSubmission\(clinic, succeeded: false\)/);
  assert.match(form, /submissionContinuation\.deferUntilAuthenticated\(clinic\)/);
  assert.match(form, /case \.failed\(let message\):[\s\S]*submissionContinuation\.cancel\(\)/);
  assert.match(form, /takeIfAuthenticated\(authenticationPhase\)/);
  assert.match(form, /await prepareSubmission\(clinic\)/);
  assert.match(form, /\.fullScreenCover\(isPresented: \$showLogin, onDismiss: loginDidDismiss\)/);
  assert.match(form, /guard didAuthenticateDuringLogin else \{/);
  assert.match(list, /await viewModel\.submitClinicForModeration\(clinic\)/);
  assert.doesNotMatch(list, /ClinicSubmissionError/);
  assert.match(
    list,
    /\.fullScreenCover\(\s*isPresented: \$showLogin,\s*onDismiss: addClinicLoginDidDismiss/,
  );
  assert.equal(
    list.match(/onDismiss: addClinicLoginDidDismiss/g)?.length,
    2,
    "both iPhone and iPad must wait for LoginView dismissal",
  );
  assert.equal(
    list.match(/addClinicAuthenticationDidChange\(\)/g)?.length,
    5,
    "both auth signals in both layouts must share the safe handoff helper",
  );
  const authChangeBody = declarationBody(
    list,
    "private func addClinicAuthenticationDidChange()",
  );
  const outerDismissBody = declarationBody(
    list,
    "private func addClinicLoginDidDismiss()",
  );
  assert.match(authChangeBody, /didAuthenticateForAddClinic = true/);
  assert.match(authChangeBody, /showLogin = false/);
  assert.doesNotMatch(authChangeBody, /isAddingClinic = true/);
  assert.match(outerDismissBody, /guard didAuthenticateForAddClinic,/);
  assert.match(outerDismissBody, /isAddingClinic = true/);
});

test("view models distinguish pre-write authentication from generic failures", async () => {
  const [clinic, quote, clinics] = await Promise.all([
    readFile(paths.clinicViewModel, "utf8"),
    readFile(paths.quoteViewModel, "utf8"),
    readFile(paths.clinicsViewModel, "utf8"),
  ]);

  for (const [name, source] of [
    ["clinic", clinic],
    ["quote", quote],
    ["clinics", clinics],
  ]) {
    assert.match(source, /catch FirebaseError\.authenticationRequired \{/);
    assert.match(source, /return \.authenticationRequired/);
    assert.match(source, /catch \{[\s\S]*return \.failed\(message: error\.localizedDescription\)/);
    assert.doesNotMatch(
      source,
      /catch \{\s*storageError = error\.localizedDescription\s*return \.authenticationRequired/,
      `${name} retries a generic backend error`,
    );
  }
});

test("every community entrance is auth-gated without being removed", async () => {
  const [clinic, reviews, quotes] = await Promise.all([
    readFile(paths.clinicDetail, "utf8"),
    readFile(paths.reviewList, "utf8"),
    readFile(paths.quoteList, "utf8"),
  ]);

  assert.match(clinic, /requestAuthenticatedAction\(\.addReview\)/);
  assert.match(clinic, /\.markHelpful\(reviewID: review\.id\)/);
  assert.match(clinic, /\.message\(/);
  assert.match(clinic, /\.confirm\(\.reportReview\(/);
  assert.match(clinic, /\.confirm\(\.blockUser\(/);
  assert.match(clinic, /\.reportQuote\(quote, reason:/);
  assert.match(clinic, /\.reportClinic\(/);
  assert.match(clinic, /String\(localized: "確認回報"\)/);
  assert.match(clinic, /String\(localized: "確認舉報"\)/);
  assert.match(clinic, /AddReviewView\(clinicName: clinic\.name\)/);
  assert.doesNotMatch(clinic, /onMarkHelpful:\s*\{\s*Task/);
  assert.doesNotMatch(clinic, /onReport:\s*\{\s*Task/);
  assert.doesNotMatch(clinic, /onBlockAuthor:\s*\{\s*Task/);
  assert.equal(clinic.match(/viewModel\.reportReview\(/g)?.length, 1);
  assert.equal(clinic.match(/viewModel\.reportQuote\(/g)?.length, 1);
  assert.equal(clinic.match(/viewModel\.blockUser\(/g)?.length, 1);
  assert.equal(clinic.match(/viewModel\.reportClinic\(/g)?.length, 1);
  assert.equal(clinic.match(/viewModel\.markHelpful\(/g)?.length, 1);

  assert.match(reviews, /\.markHelpful\(reviewID: review\.id\)/);
  assert.match(reviews, /\.confirm\(\.report\(/);
  assert.match(reviews, /\.confirm\(\.block\(/);
  assert.match(reviews, /\.message\(/);
  assert.doesNotMatch(reviews, /onMarkHelpful:\s*\{\s*Task/);
  assert.doesNotMatch(reviews, /onReport:\s*\{\s*Task/);
  assert.doesNotMatch(reviews, /onBlockAuthor:\s*\{\s*Task/);
  assert.equal(reviews.match(/viewModel\.report\(/g)?.length, 1);
  assert.equal(reviews.match(/viewModel\.blockAuthor\(/g)?.length, 1);
  assert.equal(reviews.match(/viewModel\.markHelpful\(/g)?.length, 1);

  assert.match(quotes, /requestAuthenticatedAction\(\.addQuote\)/);
  assert.match(quotes, /\.confirm\(\.report\(/);
  assert.match(quotes, /\.confirm\(\.block\(/);
  assert.match(quotes, /AddQuoteView\(viewModel: viewModel\)/);
  assert.equal(quotes.match(/viewModel\.report\(/g)?.length, 1);
  assert.equal(quotes.match(/viewModel\.blockAuthor\(/g)?.length, 1);
});

test("destructive actions resume to confirmation and confirmation rechecks auth", async () => {
  const sources = await Promise.all([
    ["clinic", paths.clinicDetail],
    ["reviews", paths.reviewList],
    ["quotes", paths.quoteList],
  ].map(async ([name, path]) => [name, await readFile(path, "utf8")]));

  for (const [name, source] of sources) {
    const performBody = declarationBody(source, "private func perform(_ action: PendingAction)");
    const executeBody = declarationBody(source, "private func executeConfirmed(");

    assert.match(source, /\.confirmationDialog\(/, `${name} has no confirmation`);
    assert.match(performBody, /case \.confirm\(let destructiveAction\):/);
    assert.match(performBody, /destructiveConfirmation = destructiveAction/);
    assert.doesNotMatch(
      performBody,
      /viewModel\.(report|block)/,
      `${name} writes directly after LoginView`,
    );
    assert.match(executeBody, /guard authenticationPhase\.authenticatedUserID != nil else \{/);
    assert.match(executeBody, /requestAuthenticatedAction\(\.confirm\(action\)\)/);
    assert.match(executeBody, /viewModel\.(report|block)|performClinicReport/);
    assert.match(source, /takeIfAuthenticated\(authenticationPhase\)/);
    const dismissBody = declarationBody(source, "private func loginDidDismiss()");
    assert.match(dismissBody, /guard didAuthenticateDuringLogin else \{/);
    assert.match(dismissBody, /actionContinuation\.cancel\(\)/);
  }
});

test("community authentication recovery is localized for every launch language", async () => {
  const [
    catalogSource,
    addClinic,
    addReview,
    addQuote,
    clinicsModel,
    clinicModel,
    quoteModel,
    clinic,
    reviews,
    quotes,
  ] =
    await Promise.all([
      readFile(paths.strings, "utf8"),
      readFile(paths.addClinic, "utf8"),
      readFile(paths.addReview, "utf8"),
      readFile(paths.addQuote, "utf8"),
      readFile(paths.clinicsViewModel, "utf8"),
      readFile(paths.clinicViewModel, "utf8"),
      readFile(paths.quoteViewModel, "utf8"),
      readFile(paths.clinicDetail, "utf8"),
      readFile(paths.reviewList, "utf8"),
      readFile(paths.quoteList, "utf8"),
    ]);
  const catalog = JSON.parse(catalogSource);
  const requiredKeys = [
    "暫時無法提交報價。",
    "暫時無法提交評價。",
    "正在確認登入狀態，草稿已保留。",
    "登入或註冊後會自動繼續提交，草稿不會遺失。",
    "草稿已保留；登入後可再次提交。",
    "請先登入後再提交報價。",
    "請先登入後再提交評價。",
    "請先登入後再提交診所資料。",
    "確認操作",
    "確認舉報",
    "確認封鎖",
    "確認回報",
    "確認舉報此評價？",
    "確認舉報此報價？",
    "確認舉報此診所？",
    "確認封鎖此作者？",
    "確認回報營業資料？",
  ];

  for (const key of requiredKeys) {
    const entry = catalog.strings[key];
    assert.ok(entry, `missing community localization key: ${key}`);
    for (const locale of ["en", "zh-Hans"]) {
      const unit = entry.localizations?.[locale]?.stringUnit;
      assert.equal(unit?.state, "translated", `${key} missing ${locale}`);
      assert.ok(unit?.value?.trim(), `${key} has an empty ${locale} value`);
    }
  }

  const runtimeKeysBySource = [
    [addClinic, requiredKeys.slice(2, 5)],
    [addReview, requiredKeys.slice(2, 5)],
    [addQuote, requiredKeys.slice(2, 5)],
    [clinicsModel, [requiredKeys[7]]],
    [clinicModel, [requiredKeys[0], requiredKeys[1], requiredKeys[5], requiredKeys[6]]],
    [quoteModel, [requiredKeys[0], requiredKeys[5]]],
    [clinic, requiredKeys.slice(8)],
    [reviews, [requiredKeys[8], requiredKeys[9], requiredKeys[10], requiredKeys[12], requiredKeys[15]]],
    [quotes, [requiredKeys[8], requiredKeys[9], requiredKeys[10], requiredKeys[13], requiredKeys[15]]],
  ];

  for (const [source, keys] of runtimeKeysBySource) {
    for (const key of keys) {
      assert.ok(source.includes(key), `source no longer exposes expected string: ${key}`);
      assert.match(
        source,
        new RegExp(`String\\(\\s*localized:\\s*"${escapeRegExp(key)}"\\s*\\)`),
        `runtime string bypasses localization: ${key}`,
      );
    }
  }
});
