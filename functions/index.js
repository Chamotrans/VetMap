"use strict";

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");

initializeApp();

const REGION = "asia-east1";

async function deleteMatchingDocuments(db, collectionName, field, uid) {
  const snapshot = await db.collection(collectionName)
      .where(field, "==", uid)
      .get();

  return deleteSnapshotDocuments(db, snapshot);
}

async function deleteSnapshotDocuments(db, snapshot) {
  for (const document of snapshot.docs) {
    await db.recursiveDelete(document.ref);
  }

  return snapshot.size;
}

exports.purgeUserData = onCall({region: REGION}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
        "unauthenticated",
        "You must sign in again before deleting your account.",
    );
  }

  const authTime = Number(request.auth.token.auth_time);
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (!Number.isFinite(authTime) ||
      authTime > nowSeconds + 60 ||
      nowSeconds - authTime > 5 * 60) {
    throw new HttpsError(
        "failed-precondition",
        "Recent authentication is required before deleting an account.",
    );
  }

  const db = getFirestore();
  const deletionCounts = {};

  const ownedCollections = [
    ["submissions", "authorId"],
    ["quotes", "userId"],
    ["clinics", "reportedBy"],
    ["reports", "reporterId"],
  ];

  for (const [collectionName, ownerField] of ownedCollections) {
    const deletedCount = await deleteMatchingDocuments(
        db,
        collectionName,
        ownerField,
        uid,
    );
    deletionCounts[collectionName] =
      (deletionCounts[collectionName] || 0) + deletedCount;
  }

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

  const bucket = getStorage().bucket();
  await Promise.all([
    bucket.deleteFiles({prefix: `users/${uid}/`, force: true}),
    bucket.deleteFiles({prefix: `review-images/${uid}/`, force: true}),
    bucket.deleteFiles({prefix: `submissionUploads/${uid}/`, force: true}),
    bucket.deleteFiles({prefix: `submission-images/${uid}/`, force: true}),
  ]);

  return {
    deleted: true,
    deletionCounts,
  };
});
