"use strict";

const assert = require("node:assert/strict");
const {env} = require("node:process");
const {after, before, test} = require("node:test");
const {Firestore} = require("@google-cloud/firestore");
const {
  authenticatedUserID,
  purgeUserDataForUID,
} = require("./purge-user-data");

const projectId = "demo-vetmap-rules";
const uid = "purge-test-user";
const otherUID = "purge-test-other";
const conversationID = "purge-test-other--purge-test-user";
let db;

function fakeBucket() {
  const deletions = [];
  return {
    deletions,
    async deleteFiles(options) {
      deletions.push(options);
    },
  };
}

async function set(path, data) {
  await db.doc(path).set(data);
}

async function exists(path) {
  return (await db.doc(path).get()).exists;
}

before(async () => {
  assert.ok(
      env.FIRESTORE_EMULATOR_HOST,
      "purge tests must run against the Firestore emulator",
  );
  db = new Firestore({projectId});

  await set(`users/${uid}`, {uid});
  await set(`users/${uid}/blockedUsers/local-block`, {
    blockedUserId: "local-block",
  });
  await set(`users/${otherUID}`, {uid: otherUID});
  await set(`users/${otherUID}/blockedUsers/${uid}`, {blockedUserId: uid});

  await set("submissions/delete-submission", {authorId: uid});
  await set("submissions/keep-submission", {authorId: otherUID});
  await set("quotes/delete-quote", {userId: uid});
  await set("quotes/keep-quote", {userId: otherUID});
  await set("clinics/delete-clinic", {reportedBy: uid});
  await set("clinics/keep-clinic", {reportedBy: otherUID});
  await set("reports/delete-owned-report", {reporterId: uid});
  await set("reports/delete-linked-report", {
    reporterId: otherUID,
    conversationId: conversationID,
  });
  await set("reports/keep-report", {reporterId: otherUID});

  await set(`conversations/${conversationID}`, {
    participantIds: [uid, otherUID],
  });
  await set(`conversations/${conversationID}/messages/message-1`, {
    senderId: uid,
  });
  await set(`chatModeration/${conversationID}`, {
    conversationId: conversationID,
  });
  await set(
      `chatModeration/${conversationID}/reportedMessages/message-1`,
      {messageId: "message-1"},
  );

  await set("reviews/delete-review", {userId: uid});
  await set("reviews/keep-review", {userId: otherUID});
  await set("reviewEngagement/delete-review", {reviewId: "delete-review"});
  await set("reviewEngagement/delete-review/voters/other-vote", {
    userId: otherUID,
  });
  await set("reviewEngagement/keep-review", {reviewId: "keep-review"});
  await set("reviewEngagement/keep-review/voters/delete-vote", {userId: uid});
  await set("reviewEngagement/keep-review/voters/keep-vote", {
    userId: otherUID,
  });
});

after(async () => {
  await db.terminate();
});

test("recent authentication is mandatory and bounded", () => {
  const now = 2_000_000_000;
  assert.throws(
      () => authenticatedUserID(undefined, now),
      (error) => error.code === "unauthenticated",
  );
  assert.throws(
      () => authenticatedUserID({uid, token: {}}, now),
      (error) => error.code === "failed-precondition",
  );
  assert.throws(
      () => authenticatedUserID({uid, token: {auth_time: now - 301}}, now),
      (error) => error.code === "failed-precondition",
  );
  assert.throws(
      () => authenticatedUserID({uid, token: {auth_time: now + 61}}, now),
      (error) => error.code === "failed-precondition",
  );
  assert.equal(
      authenticatedUserID({uid, token: {auth_time: now - 300}}, now),
      uid,
  );
});

test("purge removes the complete account graph and preserves unrelated data", async () => {
  const bucket = fakeBucket();
  const result = await purgeUserDataForUID({db, bucket, uid});

  assert.deepEqual(result, {
    deleted: true,
    deletionCounts: {
      submissions: 1,
      quotes: 1,
      clinics: 1,
      reports: 1,
      conversations: 1,
      linkedChatReports: 1,
      chatModeration: 1,
      reviews: 1,
      blockedReferences: 1,
      helpfulVotes: 1,
    },
  });

  const deletedPaths = [
    `users/${uid}`,
    `users/${uid}/blockedUsers/local-block`,
    `users/${otherUID}/blockedUsers/${uid}`,
    "submissions/delete-submission",
    "quotes/delete-quote",
    "clinics/delete-clinic",
    "reports/delete-owned-report",
    "reports/delete-linked-report",
    `conversations/${conversationID}`,
    `conversations/${conversationID}/messages/message-1`,
    `chatModeration/${conversationID}`,
    `chatModeration/${conversationID}/reportedMessages/message-1`,
    "reviews/delete-review",
    "reviewEngagement/delete-review",
    "reviewEngagement/delete-review/voters/other-vote",
    "reviewEngagement/keep-review/voters/delete-vote",
  ];
  for (const path of deletedPaths) {
    assert.equal(await exists(path), false, `${path} should be deleted`);
  }

  const retainedPaths = [
    `users/${otherUID}`,
    "submissions/keep-submission",
    "quotes/keep-quote",
    "clinics/keep-clinic",
    "reports/keep-report",
    "reviews/keep-review",
    "reviewEngagement/keep-review",
    "reviewEngagement/keep-review/voters/keep-vote",
  ];
  for (const path of retainedPaths) {
    assert.equal(await exists(path), true, `${path} should be retained`);
  }

  assert.deepEqual(bucket.deletions, [
    {prefix: `users/${uid}/`, force: true},
    {prefix: `review-images/${uid}/`, force: true},
    {prefix: `submissionUploads/${uid}/`, force: true},
    {prefix: `submission-images/${uid}/`, force: true},
  ]);

  const retry = await purgeUserDataForUID({db, bucket: fakeBucket(), uid});
  assert.deepEqual(retry.deletionCounts, {
    submissions: 0,
    quotes: 0,
    clinics: 0,
    reports: 0,
    conversations: 0,
    linkedChatReports: 0,
    chatModeration: 0,
    reviews: 0,
    blockedReferences: 0,
    helpfulVotes: 0,
  });
});
