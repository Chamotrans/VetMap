import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const paths = {
  quote: new URL(
    "../VetMap/ViewModels/QuoteViewModel.swift",
    import.meta.url,
  ),
  review: new URL(
    "../VetMap/ViewModels/ReviewViewModel.swift",
    import.meta.url,
  ),
  clinicDetail: new URL(
    "../VetMap/ViewModels/ClinicDetailViewModel.swift",
    import.meta.url,
  ),
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

const assignmentPattern = /^\s*(?:self\.)?(reviews|quotes)\s*=/gmu;
const preClearPattern =
  /\b(?:self\.)?(?:reviews|quotes)\s*(?:=\s*\[\s*\]|\.removeAll\s*\()/u;

function assertResilientRefresh({
  name,
  body,
  fetchPatterns,
  expectedAssignments,
  errorDomain,
}) {
  const loadingIndex = body.indexOf("isLoading = true");
  const deferMatch = body.match(/defer \{\s*isLoading = false\s*\}/u);
  assert.notEqual(loadingIndex, -1, `${name} does not enter loading state`);
  assert.ok(deferMatch, `${name} does not restore loading state with defer`);
  assert.ok(
    loadingIndex < deferMatch.index,
    `${name} must set loading state before installing its deferred cleanup`,
  );

  const doIndex = body.indexOf("do {");
  const catchIndex = body.indexOf("catch {");
  assert.notEqual(doIndex, -1, `${name} has no guarded refresh transaction`);
  assert.notEqual(catchIndex, -1, `${name} has no visible failure path`);
  assert.ok(doIndex < catchIndex, `${name} catch appears before its fetch`);

  const fetchIndexes = fetchPatterns.map((pattern) => {
    const match = body.match(pattern);
    assert.ok(match, `${name} is missing fetch: ${pattern}`);
    return match.index;
  });
  const lastFetchIndex = Math.max(...fetchIndexes);
  const firstFetchIndex = Math.min(...fetchIndexes);
  assert.ok(
    deferMatch.index < firstFetchIndex,
    `${name} can fetch before loading cleanup is installed`,
  );
  assert.doesNotMatch(
    body.slice(0, firstFetchIndex),
    preClearPattern,
    `${name} clears last-known-good community data before fetching`,
  );

  const assignments = [...body.matchAll(assignmentPattern)].map((match) => ({
    field: match[1],
    index: match.index,
  }));
  assert.deepEqual(
    assignments.map(({field}) => field),
    expectedAssignments,
    `${name} must commit each refreshed array exactly once and never pre-clear it`,
  );
  for (const {field, index} of assignments) {
    assert.ok(
      index > lastFetchIndex && index < catchIndex,
      `${name} mutates ${field} before every fetch succeeds or from its catch path`,
    );
  }

  const catchBody = declarationBody(body.slice(catchIndex), "catch {");
  assert.doesNotMatch(
    catchBody,
    /\b(?:reviews|quotes)\b/u,
    `${name} touches last-known-good community data after a transient failure`,
  );
  assert.match(
    catchBody,
    /storageError = "[^"\n]*\\\(error\.localizedDescription\)"/u,
    `${name} does not expose the refresh error`,
  );
  assert.match(
    catchBody,
    new RegExp(
      `CrashReporting\\.recordError\\(error, domain: "${errorDomain}"\\)`,
      "u",
    ),
    `${name} does not record the refresh error`,
  );

  const successBody = body.slice(doIndex, catchIndex);
  const finalCommitIndex = Math.max(...assignments.map(({index}) => index));
  const clearErrorIndex = successBody.lastIndexOf("storageError = nil");
  assert.ok(
    clearErrorIndex > finalCommitIndex - doIndex,
    `${name} clears its error before committing refreshed data`,
  );
}

function assertHelpfulCountFallback(name, body) {
  assert.match(
    body,
    /let helpfulCounts = try\? await firebase\.fetchReviewHelpfulCounts\(\)/u,
    `${name} no longer treats helpful-count refresh as best effort`,
  );
  assert.doesNotMatch(
    body,
    /fetchReviewHelpfulCounts\(\)[^\n]*\?\? \[:\]/u,
    `${name} turns a helpful-count fetch failure into zero counts`,
  );
  assert.match(
    body,
    /let displayedHelpfulCounts = reviews\.reduce\(into: \[String: Int\]\(\)\) \{ counts, review in\s*counts\[review\.id\] = review\.helpfulCount\s*\}/u,
    `${name} does not snapshot currently displayed helpful counts`,
  );
  assert.match(
    body,
    /if let helpfulCounts \{\s*review\.helpfulCount \+= helpfulCounts\[review\.id, default: 0\]\s*\} else if let displayedHelpfulCount = displayedHelpfulCounts\[review\.id\] \{\s*review\.helpfulCount = displayedHelpfulCount\s*\}/u,
    `${name} can regress an existing review count when its secondary fetch fails`,
  );
}

test("quote refresh keeps last-known-good quotes on fetch failure", async () => {
  const source = await readFile(paths.quote, "utf8");
  const body = declarationBody(source, "func loadQuotes() async");

  assertResilientRefresh({
    name: "QuoteViewModel.loadQuotes",
    body,
    fetchPatterns: [/try await firebase\.fetchQuotes\(for: clinicId\)/u],
    expectedAssignments: ["quotes"],
    errorDomain: "QuoteViewModel.loadQuotes",
  });
});

test("review refresh keeps last-known-good reviews on fetch failure", async () => {
  const source = await readFile(paths.review, "utf8");
  const body = declarationBody(source, "func loadReviews() async");

  assertResilientRefresh({
    name: "ReviewViewModel.loadReviews",
    body,
    fetchPatterns: [/try await firebase\.fetchReviews\(for: clinicId\)/u],
    expectedAssignments: ["reviews"],
    errorDomain: "ReviewViewModel.loadReviews",
  });
  assertHelpfulCountFallback("ReviewViewModel.loadReviews", body);
});

test("clinic detail commits both community arrays after both fetches", async () => {
  const source = await readFile(paths.clinicDetail, "utf8");
  const body = declarationBody(source, "func loadCommunityData() async");

  assertResilientRefresh({
    name: "ClinicDetailViewModel.loadCommunityData",
    body,
    fetchPatterns: [
      /try await firebase\.fetchReviews\(for: clinic\.id\)/u,
      /try await firebase\.fetchQuotes\(for: clinic\.id\)/u,
    ],
    expectedAssignments: ["reviews", "quotes"],
    errorDomain: "ClinicDetail.loadCommunityData",
  });
  assertHelpfulCountFallback("ClinicDetailViewModel.loadCommunityData", body);
});
