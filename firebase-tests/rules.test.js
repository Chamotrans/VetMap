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
const catalogExpiry = new Date(Date.now() + 24 * 60 * 60 * 1000);
let testEnv;

function clinicSubmission({
  submissionId = "submission-clinic-1",
  authorId = "alice",
  clinicOverrides = {},
} = {}) {
  const now = new Date();
  return {
    id: submissionId,
    type: "clinic",
    authorId,
    authorName: "Alice",
    status: "pending",
    submittedAt: now,
    clinic: {
      id: "client-clinic-1",
      name: "香港社群投稿診所",
      address: "香港測試地址",
      coordinate: {latitude: 22.3193, longitude: 114.1694},
      phone: "21234567",
      openingHours: {},
      services: [],
      avgRating: 0,
      reviewCount: 0,
      priceLevel: 2,
      images: [],
      tags: [],
      createdAt: now,
      updatedAt: now,
      reportedBy: authorId,
      verified: false,
      ...clinicOverrides,
    },
  };
}

function publishedClinic({
  id = "ugc-submission-clinic-1",
  authorId = "alice",
  overrides = {},
} = {}) {
  const submitted = clinicSubmission({authorId}).clinic;
  return {
    id,
    name: submitted.name,
    address: submitted.address,
    coordinate: submitted.coordinate,
    phone: submitted.phone,
    website: "https://example.hk/clinic",
    openingHours: {},
    services: [],
    avgRating: 0,
    reviewCount: 0,
    priceLevel: 0,
    images: [],
    tags: [],
    createdAt: submitted.createdAt,
    updatedAt: submitted.createdAt,
    reportedBy: authorId,
    verified: false,
    authorId,
    status: "approved",
    approvedAt: new Date(),
    catalogRegion: "HK",
    ...overrides,
  };
}

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

function chatMessage({
  id = "message-1",
  conversationId = "alice--bob",
  senderId = "alice",
  body = "你好，想交流一下診所經驗。",
  sentAt = new Date(),
} = {}) {
  return {
    id,
    conversationId,
    senderId,
    body,
    sentAt,
    isDeleted: false,
  };
}

function conversation({
  id = "alice--bob",
  participants = ["alice", "bob"],
  lastMessageId = "message-1",
  lastMessage = "你好，想交流一下診所經驗。",
  lastSenderId = "alice",
  now = new Date(),
} = {}) {
  return {
    id,
    participantIds: participants,
    participantNames: {alice: "Alice", bob: "Bob"},
    lastMessageId,
    lastMessage,
    lastMessageAt: now,
    lastSenderId,
    createdAt: now,
    updatedAt: now,
  };
}

async function createConversation(db, options = {}) {
  const data = conversation(options);
  const message = chatMessage({
    id: data.lastMessageId,
    conversationId: data.id,
    senderId: data.lastSenderId,
    body: data.lastMessage,
    sentAt: data.lastMessageAt,
  });
  const reference = db.collection("conversations").doc(data.id);
  const batch = db.batch();
  batch.set(reference, data);
  batch.set(reference.collection("messages").doc(message.id), message);
  return batch.commit();
}

function catalogMetadata({
  status = "approved",
  catalogRegion = "HK",
  region = "HK",
  expiresAt = catalogExpiry,
} = {}) {
  return {
    status,
    catalogRegion,
    region,
    sourceName: "VetMap 測試目錄",
    sourceURL: "https://vetmap-app.web.app",
    rightsBasis: "existing VetMap operator-supplied catalog",
    verifiedAt: new Date(),
    expiresAt,
    migrationId: "hk-commercial-v1-2026-07-28",
  };
}

function catalogProduct(overrides = {}) {
  return {
    id: "hk-service-sup-001",
    name: "香港寵物用品測試商戶",
    description: "香港寵物用品商戶目錄資料。",
    category: "用品",
    price: 0,
    currency: "HKD",
    clinicId: null,
    affiliateURL: null,
    imageURL: null,
    tags: [],
    createdAt: new Date(),
    ...catalogMetadata(),
    ...overrides,
  };
}

function catalogInsurance(overrides = {}) {
  return {
    id: "insurance-hk-fwd",
    providerName: "FWD",
    planName: "毛孩寵物保",
    description: "香港寵物保險官方產品目錄。",
    monthlyPremium: 0,
    annualPremium: 0,
    coverage: [],
    exclusions: [],
    website: "https://www.fwd.com.hk/online-insurance/pets-insurance/",
    contactPhone: "",
    ...catalogMetadata({}),
    rightsBasis: "official provider website",
    ...overrides,
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
  await assertSucceeds(
    alice.collection("submissions").doc("submission-clinic-1").set(
      clinicSubmission(),
    ),
  );
  await assertFails(
    alice.collection("submissions").doc("submission-clinic-non-hk").set(
      clinicSubmission({
        submissionId: "submission-clinic-non-hk",
        clinicOverrides: {
          coordinate: {latitude: 25.033, longitude: 121.5654},
        },
      }),
    ),
  );
  await assertFails(
    alice.collection("submissions").doc("submission-clinic-curated").set(
      clinicSubmission({
        submissionId: "submission-clinic-curated",
        clinicOverrides: {
          catalogRegion: "HK",
          migrationId: "client-claimed-migration",
        },
      }),
    ),
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

test("診所批准只可建立安全投影；crafted claims 拒絕且 batch 保持 pending", async () => {
  await seedAdmin();
  const alice = testEnv.authenticatedContext("alice").firestore();
  const admin = testEnv.authenticatedContext("admin").firestore();
  const pendingRef = alice.collection("submissions").doc("submission-clinic-1");
  await pendingRef.set(clinicSubmission());

  const approval = admin.batch();
  approval.set(
    admin.collection("clinics").doc("ugc-submission-clinic-1"),
    publishedClinic(),
  );
  approval.update(admin.collection("submissions").doc("submission-clinic-1"), {
    status: "approved",
    reviewedAt: firebase.firestore.FieldValue.serverTimestamp(),
    reviewedBy: "admin",
  });
  await assertSucceeds(approval.commit());

  const publicClinic = await admin.collection("clinics")
    .doc("ugc-submission-clinic-1").get();
  const publicData = publicClinic.data();
  if (publicData.catalogRegion !== "HK"
      || publicData.verified !== false
      || Object.keys(publicData.openingHours).length !== 0
      || publicData.services.length !== 0
      || publicData.avgRating !== 0
      || publicData.reviewCount !== 0
      || publicData.priceLevel !== 0
      || publicData.images.length !== 0
      || publicData.tags.length !== 0
      || publicData.reportedBy !== "alice") {
    throw new Error("safe clinic projection was not preserved");
  }

  const craftedCases = [
    ["verified", {verified: true}],
    ["wrong-region", {catalogRegion: "TW"}],
    ["hours", {openingHours: {mon: "24 hours"}}],
    ["availability", {availability: {is24Hours: true}}],
    ["services", {services: ["24 hour emergency"]}],
    ["rating", {avgRating: 5}],
    ["reviews", {reviewCount: 99}],
    ["price", {priceLevel: 3}],
    ["images", {images: ["https://example.hk/untrusted.jpg"]}],
    ["tags", {tags: ["verified"]}],
    ["submitter", {reportedBy: "mallory"}],
    ["non-hk", {coordinate: {latitude: 25.033, longitude: 121.5654}}],
  ];
  for (const [suffix, overrides] of craftedCases) {
    const id = `crafted-${suffix}`;
    await assertFails(
      admin.collection("clinics").doc(id).set(publishedClinic({id, overrides})),
    );
  }
  const missingCoordinate = publishedClinic({id: "crafted-missing-coordinate"});
  delete missingCoordinate.coordinate;
  await assertFails(
    admin.collection("clinics").doc(missingCoordinate.id).set(missingCoordinate),
  );

  await alice.collection("submissions").doc("submission-clinic-crafted").set(
    clinicSubmission({submissionId: "submission-clinic-crafted"}),
  );
  const rejectedBatch = admin.batch();
  rejectedBatch.set(
    admin.collection("clinics").doc("ugc-submission-clinic-crafted"),
    publishedClinic({
      id: "ugc-submission-clinic-crafted",
      overrides: {services: ["crafted claim"]},
    }),
  );
  rejectedBatch.update(
    admin.collection("submissions").doc("submission-clinic-crafted"),
    {
      status: "approved",
      reviewedAt: firebase.firestore.FieldValue.serverTimestamp(),
      reviewedBy: "admin",
    },
  );
  await assertFails(rejectedBatch.commit());
  const stillPending = await admin.collection("submissions")
    .doc("submission-clinic-crafted").get();
  if (stillPending.data().status !== "pending") {
    throw new Error("rejected publication batch changed pending submission");
  }
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

test("聊天室只限兩名參與者，建立對話必須原子寫入第一則本人訊息", async () => {
  const anonymous = testEnv.unauthenticatedContext().firestore();
  const alice = testEnv.authenticatedContext("alice").firestore();
  const bob = testEnv.authenticatedContext("bob").firestore();
  const mallory = testEnv.authenticatedContext("mallory").firestore();

  await assertFails(
    alice.collection("conversations").doc("alice--bob").set(conversation()),
  );
  await assertFails(
    createConversation(alice, {participants: ["bob", "alice"]}),
  );
  await assertSucceeds(createConversation(alice));

  const conversationRef = alice.collection("conversations").doc("alice--bob");
  await assertFails(anonymous.collection("conversations").doc("alice--bob").get());
  await assertSucceeds(conversationRef.get());
  await assertSucceeds(bob.collection("conversations").doc("alice--bob").get());
  await assertFails(mallory.collection("conversations").doc("alice--bob").get());
  await assertSucceeds(
    alice.collection("conversations")
      .where("participantIds", "array-contains", "alice")
      .get(),
  );
  await assertFails(
    mallory.collection("conversations/alice--bob/messages").doc("message-1").get(),
  );
});

test("聊天室新訊息綁定本人及對話預覽，任一方封鎖後禁止再傳送", async () => {
  const alice = testEnv.authenticatedContext("alice").firestore();
  const bob = testEnv.authenticatedContext("bob").firestore();
  await createConversation(alice);

  const secondSentAt = new Date();
  const bobConversation = bob.collection("conversations").doc("alice--bob");
  const secondMessage = chatMessage({
    id: "message-2",
    senderId: "bob",
    body: "多謝分享。",
    sentAt: secondSentAt,
  });
  const reply = bob.batch();
  reply.update(bobConversation, {
    lastMessageId: secondMessage.id,
    lastMessage: secondMessage.body,
    lastMessageAt: secondSentAt,
    lastSenderId: "bob",
    updatedAt: secondSentAt,
  });
  reply.set(bobConversation.collection("messages").doc(secondMessage.id), secondMessage);
  await assertSucceeds(reply.commit());

  const forged = alice.batch();
  forged.update(alice.collection("conversations").doc("alice--bob"), {
    lastMessageId: "message-3",
    lastMessage: "冒認 Bob",
    lastMessageAt: new Date(),
    lastSenderId: "alice",
    updatedAt: new Date(),
  });
  forged.set(
    alice.collection("conversations/alice--bob/messages").doc("message-3"),
    chatMessage({id: "message-3", senderId: "bob", body: "冒認 Bob"}),
  );
  await assertFails(forged.commit());

  await bob.collection("users/bob/blockedUsers").doc("alice").set({
    blockedUserId: "alice",
    createdAt: firebase.firestore.FieldValue.serverTimestamp(),
  });
  const blockedSentAt = new Date();
  const blocked = alice.batch();
  blocked.update(alice.collection("conversations").doc("alice--bob"), {
    lastMessageId: "message-4",
    lastMessage: "不應送達",
    lastMessageAt: blockedSentAt,
    lastSenderId: "alice",
    updatedAt: blockedSentAt,
  });
  blocked.set(
    alice.collection("conversations/alice--bob/messages").doc("message-4"),
    chatMessage({id: "message-4", body: "不應送達", sentAt: blockedSentAt}),
  );
  await assertFails(blocked.commit());
});

test("訊息只可由作者軟刪除，參與者可舉報而外人不可", async () => {
  await seedAdmin();
  const alice = testEnv.authenticatedContext("alice").firestore();
  const bob = testEnv.authenticatedContext("bob").firestore();
  const mallory = testEnv.authenticatedContext("mallory").firestore();
  await createConversation(alice);

  const messageRef = alice.collection("conversations/alice--bob/messages").doc("message-1");
  await assertFails(
    bob.collection("conversations/alice--bob/messages").doc("message-1").update({
      body: "",
      isDeleted: true,
      deletedAt: firebase.firestore.FieldValue.serverTimestamp(),
      deletedBy: "bob",
    }),
  );

  const deletion = alice.batch();
  deletion.update(messageRef, {
    body: "",
    isDeleted: true,
    deletedAt: firebase.firestore.FieldValue.serverTimestamp(),
    deletedBy: "alice",
  });
  deletion.update(alice.collection("conversations").doc("alice--bob"), {
    lastMessage: "訊息已刪除",
  });
  await assertSucceeds(deletion.commit());

  const messageReport = {
    id: "message-message-1-bob",
    targetType: "message",
    targetId: "message-1",
    targetTitle: "聊天室訊息",
    conversationId: "alice--bob",
    reason: "騷擾或冒犯",
    reporterId: "bob",
    createdAt: new Date(),
    status: "pending",
  };
  await assertSucceeds(
    bob.collection("reports").doc(messageReport.id).set(messageReport),
  );
  await assertFails(
    mallory.collection("reports").doc("message-message-1-mallory").set({
      ...messageReport,
      id: "message-message-1-mallory",
      reporterId: "mallory",
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

test("已整理的香港診所可公開查詢，舊台灣目錄維持封鎖", async () => {
  await seedAdmin();
  const anonymous = testEnv.unauthenticatedContext().firestore();
  const alice = testEnv.authenticatedContext("alice").firestore();
  const admin = testEnv.authenticatedContext("admin").firestore();

  await assertSucceeds(
    admin.collection("clinics").doc("hk-curated-1").set({
      id: "hk-curated-1",
      name: "香港測試獸醫診所",
      address: "香港測試地址",
      coordinate: {latitude: 22.3193, longitude: 114.1694},
      phone: "21234567",
      openingHours: {},
      services: [],
      avgRating: 0,
      reviewCount: 0,
      priceLevel: 0,
      images: [],
      tags: [],
      createdAt: new Date(),
      updatedAt: new Date(),
      reportedBy: "vetmap-curation",
      verified: false,
      authorId: "vetmap-curation",
      status: "approved",
      approvedAt: new Date(),
      catalogRegion: "HK",
      migrationId: "hk-v1-normalize-2026-07-24",
    }),
  );
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore()
      .collection("officialClinicCatalog")
      .doc("tw-moa-078-manifest")
      .set({
        kind: "manifest",
        datasetId: "tw-moa-vet-license-078",
        status: "published",
      });
  });

  await assertSucceeds(
    anonymous.collection("clinics").doc("hk-curated-1").get(),
  );
  await assertSucceeds(
    anonymous.collection("clinics")
      .where("status", "==", "approved")
      .get(),
  );
  await assertFails(
    anonymous.collection("officialClinicCatalog").doc("tw-moa-078-manifest").get(),
  );
  await assertFails(
    alice.collection("officialClinicCatalog").doc("ordinary-write").set({
      kind: "manifest",
      datasetId: "tw-moa-vet-license-078",
      status: "published",
    }),
  );
});

test("只有已批准、香港及未過期的產品與保險目錄可公開讀取", async () => {
  await seedAdmin();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().collection("products").doc("legacy-product").set({
      name: "未授權舊產品",
    });
    await context.firestore().collection("products").doc("tw-product").set(
      catalogProduct({
        id: "tw-product",
        catalogRegion: "TW",
        region: "TW",
      }),
    );
    await context.firestore().collection("products").doc("region-mismatch").set(
      catalogProduct({
        id: "region-mismatch",
        region: "TW",
      }),
    );
    await context.firestore().collection("products").doc("pending-product").set(
      catalogProduct({
        id: "pending-product",
        status: "pending",
      }),
    );
    await context.firestore().collection("products").doc("expired-product").set(
      catalogProduct({
        id: "expired-product",
        expiresAt: new Date(Date.now() - 60 * 1000),
      }),
    );
    await context.firestore().collection("products").doc("hk-service-sup-001").set(
      catalogProduct(),
    );
    await context.firestore().collection("insurances").doc("legacy-plan").set({
      planName: "未授權舊保險",
    });
    await context.firestore().collection("insurances").doc("insurance-hk-fwd").set(
      catalogInsurance(),
    );
  });

  const anonymous = testEnv.unauthenticatedContext().firestore();
  const alice = testEnv.authenticatedContext("alice").firestore();
  const admin = testEnv.authenticatedContext("admin").firestore();

  await assertSucceeds(
    anonymous.collection("products").doc("hk-service-sup-001").get(),
  );
  await assertSucceeds(
    alice.collection("insurances").doc("insurance-hk-fwd").get(),
  );
  await assertFails(anonymous.collection("products").doc("legacy-product").get());
  await assertFails(anonymous.collection("products").doc("tw-product").get());
  await assertFails(anonymous.collection("products").doc("region-mismatch").get());
  await assertFails(anonymous.collection("products").doc("pending-product").get());
  await assertFails(anonymous.collection("products").doc("expired-product").get());
  await assertFails(alice.collection("insurances").doc("legacy-plan").get());

  // Firestore rules are not filters. A caller first reads one known current
  // catalog document, then uses its exact shared expiry in collection queries.
  // A moving `expiresAt > Date()` query cannot prove `expiresAt > request.time`
  // to the rules engine, while exact equality can.
  await assertFails(
    anonymous.collection("products")
      .where("status", "==", "approved")
      .where("catalogRegion", "==", "HK")
      .where("region", "==", "HK")
      .get(),
  );
  await assertSucceeds(
    anonymous.collection("products")
      .where("status", "==", "approved")
      .where("catalogRegion", "==", "HK")
      .where("region", "==", "HK")
      .where("expiresAt", "==", catalogExpiry)
      .get(),
  );
  await assertSucceeds(
    anonymous.collection("insurances")
      .where("status", "==", "approved")
      .where("catalogRegion", "==", "HK")
      .where("region", "==", "HK")
      .where("expiresAt", "==", catalogExpiry)
      .get(),
  );

  await assertSucceeds(admin.collection("products").doc("legacy-product").get());
  await assertSucceeds(admin.collection("insurances").doc("legacy-plan").get());
  await assertFails(
    alice.collection("products").doc("ordinary-write").set(catalogProduct()),
  );
  await assertSucceeds(
    admin.collection("products").doc("admin-write").set(
      catalogProduct({id: "admin-write"}),
    ),
  );
  await assertSucceeds(
    admin.collection("products").doc("admin-write").update({name: "管理員更新"}),
  );
  await assertSucceeds(
    admin.collection("products").doc("admin-write").delete(),
  );
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
