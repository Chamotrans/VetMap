"use strict";

const {onCall} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {
  authenticatedUserID,
  purgeUserDataForUID,
} = require("./purge-user-data");

initializeApp();

const REGION = "asia-east1";

exports.purgeUserData = onCall({region: REGION}, async (request) => {
  const uid = authenticatedUserID(request.auth);
  return purgeUserDataForUID({
    db: getFirestore(),
    bucket: getStorage().bucket(),
    uid,
  });
});
