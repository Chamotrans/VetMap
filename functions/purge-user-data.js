"use strict";

const {HttpsError} = require("firebase-functions/v2/https");

const OWNED_COLLECTIONS = [
  ["submissions", "authorId"],
  ["quotes", "userId"],
  ["clinics", "reportedBy"],
  ["reports", "reporterId"],
];

const STORAGE_PREFIXES = [
  "users",
  "review-images",
  "submissionUploads",
  "submission-images",
];

function authenticatedUserID(auth, nowSeconds = Math.floor(Date.now() / 1000)) {
  const uid = auth?.uid;
  if (!uid) {
    throw new HttpsError(
        "unauthenticated",
        "You must sign in again before deleting your account.",
    );
  }

  const authTime = Number(auth.token?.auth_time);
  if (!Number.isFinite(authTime) ||
      authTime > nowSeconds + 60 ||
      nowSeconds - authTime > 5 * 60) {
    throw new HttpsError(
        "failed-precondition",
        "Recent authentication is required before deleting an account.",
    );
  }

  return uid;
}

async function deleteSnapshotDocuments(db, snapshot) {
  for (const document of snapshot.docs) {
    await db.recursiveDelete(document.ref);
  }

  return snapshot.size;
}

async function deleteMatchingDocuments(db, collectionName, field, uid) {
  const snapshot = await db.collection(collectionName)
      .where(field, "==", uid)
      .get();

  return deleteSnapshotDocuments(db, snapshot);
}

async function purgeUserDataForUID({db, bucket, uid}) {
  const deletionCounts = {};

  for (const [collectionName, ownerField] of OWNED_COLLECTIONS) {
    const deletedCount = await deleteMatchingDocuments(
        db,
        collectionName,
        ownerField,
        uid,
    );
    deletionCounts[collectionName] =
      (deletionCounts[collectionName] || 0) + deletedCount;
  }

  const conversations = await db.collection("conversations")
      .where("participantIds", "array-contains", uid)
      .get();
  let linkedChatReports = 0;
  let linkedChatModeration = 0;
  for (const conversation of conversations.docs) {
    const reports = await db.collection("reports")
        .where("conversationId", "==", conversation.id)
        .get();
    linkedChatReports += await deleteSnapshotDocuments(db, reports);
    const moderationReference = db.collection("chatModeration")
        .doc(conversation.id);
    if ((await moderationReference.get()).exists) {
      linkedChatModeration += 1;
    }
    await db.recursiveDelete(moderationReference);
    await db.recursiveDelete(conversation.ref);
  }
  deletionCounts.conversations = conversations.size;
  deletionCounts.linkedChatReports = linkedChatReports;
  deletionCounts.chatModeration = linkedChatModeration;

  const ownedReviews = await db.collection("reviews")
      .where("userId", "==", uid)
      .get();
  deletionCounts.reviews = await deleteSnapshotDocuments(db, ownedReviews);
  for (const reviewDocument of ownedReviews.docs) {
    await db.recursiveDelete(
        db.collection("reviewEngagement").doc(reviewDocument.id),
    );
  }

  const blockedReferences = await db.collectionGroup("blockedUsers")
      .where("blockedUserId", "==", uid)
      .get();
  deletionCounts.blockedReferences = await deleteSnapshotDocuments(
      db,
      blockedReferences,
  );

  const helpfulVotes = await db.collectionGroup("voters")
      .where("userId", "==", uid)
      .get();
  deletionCounts.helpfulVotes = await deleteSnapshotDocuments(
      db,
      helpfulVotes,
  );

  await db.recursiveDelete(db.collection("users").doc(uid));

  await Promise.all(STORAGE_PREFIXES.map((prefix) =>
    bucket.deleteFiles({prefix: `${prefix}/${uid}/`, force: true}),
  ));

  return {
    deleted: true,
    deletionCounts,
  };
}

module.exports = {
  authenticatedUserID,
  purgeUserDataForUID,
};
