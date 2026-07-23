import { readFileSync } from "node:fs";
import { after, before, beforeEach, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import firebase from "firebase/compat/app";
import "firebase/compat/firestore";
import "firebase/compat/storage";

const projectId = "demo-vetmap-rules";
const bucket = `gs://${projectId}.appspot.com`;
let testEnv;

function quoteSubmission({
  submissionId = "submission-quote-1",
  quoteId = "quote-1",
  authorId = "alice",
  submittedAt = new Date(),
} = {}) {
  return {
    id: submissionId,
    type: "quote",
    authorId,
    authorName: "Alice",
    status: "pending",
    submittedAt,
    clinicName: "安全動物診所",
    quote: {
      id: quoteId,
      clinicId: "clinic-1",
      userId: authorId,
      treatmentType: "一般診症",
      estimatedCost: 500,
      currency: "HKD",
      notes: "普通門診費用",
      createdAt: new Date(),
    },
  };
}

function report({
  reporterId = "alice",
  targetType = "quote",
} = {}) {
  const id = `${targetType}-quote-1-${reporterId}`;
  return {
    id,
    targetType,
    targetId: "quote-1",
    targetTitle: "一般診症",
    clinicId: "clinic-1",
    reason: "資料可能不準確",
    reporterId,
    createdAt: new Date(),
    status: "pending",
  };
}

async function seedAdmin() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("users").doc("admin").set({
      role: "admin",
    });
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(new URL("../FirestoreRules.rules", import.meta.url), "utf8"),
    },
    storage: {
      rules: readFileSync(new URL("../StorageRules.rules", import.meta.url), "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

after(async () => {
  await testEnv.cleanup();
});

test("投稿必須登入、綁定本人 UID、pending 並使用近期時間", async () => {
  const anonymous = testEnv.unauthenticatedContext().firestore();
  const alice = testEnv.authenticatedContext("alice").firestore();

  await assertFails(
    anonymous.collection("submissions").doc("submission-quote-1").set(quoteSubmission()),
  );
  await assertFails(
    alice.collection("submissions").doc("submission-quote-1").set(
      quoteSubmission({ authorId: "mallory" }),
    ),
  );
  await assertFails(
    alice.collection("submissions").doc("submission-quote-1").set(
      quoteSubmission({ submittedAt: new Date("2020-01-01T00:00:00Z") }),
    ),
  );
  await assertSucceeds(
    alice.collection("submissions").doc("submission-quote-1").set(quoteSubmission()),
  );
});

test("作者只能讀自己的待審投稿，普通用戶不能直接公開或自批", async () => {
  const alice = testEnv.authenticatedContext("alice").firestore();
  const bob = testEnv.authenticatedContext("bob").firestore();
  const submissionRef = alice.collection("submissions").doc("submission-quote-1");
  await submissionRef.set(quoteSubmission());

  await assertSucceeds(submissionRef.get());
  await assertFails(bob.collection("submissions").doc("submission-quote-1").get());
  await assertFails(
    submissionRef.update({
      status: "approved",
      reviewedAt: new Date(),
      reviewedBy: "alice",
    }),
  );
  await assertFails(
    alice.collection("quotes").doc("quote-1").set({
      ...quoteSubmission().quote,
      authorId: "alice",
      status: "approved",
      approvedAt: new Date(),
    }),
  );
});

test("管理員批准 batch 及 create-only 公開規則", async () => {
  await seedAdmin();
  const alice = testEnv.authenticatedContext("alice").firestore();
  const admin = testEnv.authenticatedContext("admin").firestore();
  await alice.collection("submissions").doc("submission-quote-1").set(quoteSubmission());

  const batch = admin.batch();
  batch.set(admin.collection("quotes").doc("quote-1"), {
    ...quoteSubmission().quote,
    authorId: "alice",
    status: "approved",
    approvedAt: new Date(),
  });
  batch.update(admin.collection("submissions").doc("submission-quote-1"), {
    status: "approved",
    reviewedAt: firebase.firestore.FieldValue.serverTimestamp(),
    reviewedBy: "admin",
  });
  await assertSucceeds(batch.commit());
  await assertSucceeds(
    testEnv.unauthenticatedContext().firestore()
      .collection("quotes").doc("quote-1").get(),
  );

  await assertFails(
    admin.collection("quotes").doc("quote-1").set({
      ...quoteSubmission({ quoteId: "quote-1" }).quote,
      notes: "嘗試覆寫",
      authorId: "alice",
      status: "approved",
      approvedAt: new Date(),
    }),
  );
});

test("舊有無 approved 狀態的公開文件不再對外可見", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("quotes").doc("legacy-quote").set({
      ...quoteSubmission({ quoteId: "legacy-quote" }).quote,
    });
  });
  await assertFails(
    testEnv.unauthenticatedContext().firestore()
      .collection("quotes").doc("legacy-quote").get(),
  );
});

test("舉報綁定 reporter；管理員可駁回無效 target，普通用戶不可處理", async () => {
  await seedAdmin();
  const alice = testEnv.authenticatedContext("alice").firestore();
  const admin = testEnv.authenticatedContext("admin").firestore();

  await assertFails(
    alice.collection("reports").doc("quote-quote-1-mallory").set(
      report({ reporterId: "mallory" }),
    ),
  );
  await assertSucceeds(
    alice.collection("reports").doc("quote-quote-1-alice").set(report()),
  );
  await assertFails(
    alice.collection("reports").doc("quote-quote-1-alice").update({
      status: "rejected",
      resolvedAt: new Date(),
      resolvedBy: "alice",
    }),
  );

  await assertSucceeds(
    admin.collection("reports").doc("quote-quote-1-alice").update({
      status: "rejected",
      resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      resolvedBy: "admin",
    }),
  );
});

test("封鎖清單只可由本人管理，亦不可封鎖自己", async () => {
  const alice = testEnv.authenticatedContext("alice").firestore();
  const bob = testEnv.authenticatedContext("bob").firestore();
  await assertSucceeds(
    alice.collection("users/alice/blockedUsers").doc("bob").set({
      blockedUserId: "bob",
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    }),
  );
  await assertFails(
    bob.collection("users/alice/blockedUsers").doc("mallory").set({
      blockedUserId: "mallory",
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    }),
  );
  await assertFails(
    alice.collection("users/alice/blockedUsers").doc("alice").set({
      blockedUserId: "alice",
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    }),
  );
});

test("每個 Firebase UID 對同一評價只能標記一次有用", async () => {
  const alice = testEnv.authenticatedContext("alice").firestore();
  const bob = testEnv.authenticatedContext("bob").firestore();
  const engagement = alice.collection("reviewEngagement").doc("review-seed-1");
  const aliceVote = engagement.collection("voters").doc("alice");

  const firstVote = alice.batch();
  firstVote.set(engagement, {
    reviewId: "review-seed-1",
    helpfulCount: 1,
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
  });
  firstVote.set(aliceVote, {
    userId: "alice",
    createdAt: firebase.firestore.FieldValue.serverTimestamp(),
  });
  await assertSucceeds(firstVote.commit());

  const duplicateVote = alice.batch();
  duplicateVote.update(engagement, {
    helpfulCount: 2,
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
  });
  duplicateVote.set(aliceVote, {
    userId: "alice",
    createdAt: firebase.firestore.FieldValue.serverTimestamp(),
  });
  await assertFails(duplicateVote.commit());

  const bobVote = bob.batch();
  bobVote.update(bob.collection("reviewEngagement").doc("review-seed-1"), {
    helpfulCount: 2,
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
  });
  bobVote.set(
    bob.collection("reviewEngagement/review-seed-1/voters").doc("bob"),
    {
      userId: "bob",
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    },
  );
  await assertSucceeds(bobVote.commit());
});

test("用戶 profile 私隱及防止自行提升 admin / premium", async () => {
  const alice = testEnv.authenticatedContext("alice").firestore();
  const bob = testEnv.authenticatedContext("bob").firestore();
  const profile = {
    uid: "alice",
    displayName: "Alice",
    email: "alice@example.com",
    providerIDs: ["password"],
    createdAt: new Date(),
    updatedAt: new Date(),
    isPremium: false,
    favoriteClinics: [],
    savedProducts: [],
  };

  await assertSucceeds(alice.collection("users").doc("alice").set(profile));
  await assertFails(bob.collection("users").doc("alice").get());
  await assertFails(alice.collection("users").doc("alice").update({ role: "admin" }));
  await assertFails(alice.collection("users").doc("alice").update({ isPremium: true }));
});

test("Storage 待審圖片只限本人及圖片 MIME/大小", async () => {
  await seedAdmin();
  const aliceStorage = testEnv.authenticatedContext("alice").storage(bucket);
  const bobStorage = testEnv.authenticatedContext("bob").storage(bucket);
  const anonymousStorage = testEnv.unauthenticatedContext().storage(bucket);
  const path = "submissionUploads/alice/submission-1/photo.jpg";
  const image = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);

  await assertFails(
    anonymousStorage.ref(path).put(image, { contentType: "image/jpeg" }),
  );
  await assertFails(
    bobStorage.ref(path).put(image, { contentType: "image/jpeg" }),
  );
  await assertFails(
    aliceStorage.ref(path).put(image, { contentType: "text/plain" }),
  );
  await assertSucceeds(
    aliceStorage.ref(path).put(image, { contentType: "image/jpeg" }),
  );
  await assertFails(bobStorage.ref(path).getDownloadURL());
  await assertSucceeds(aliceStorage.ref(path).getDownloadURL());
});
