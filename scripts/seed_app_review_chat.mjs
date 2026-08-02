#!/usr/bin/env node

import {execFileSync} from "node:child_process";
import {resolve} from "node:path";

const repoRoot = resolve(import.meta.dirname, "..");
const firebasePlist = resolve(repoRoot, "VetMap", "GoogleService-Info.plist");

function plistValue(key) {
  return execFileSync(
      "/usr/bin/plutil",
      ["-extract", key, "raw", firebasePlist],
      {encoding: "utf8"},
  ).trim();
}

function keychainPassword(service, account) {
  return execFileSync(
      "/usr/bin/security",
      ["find-generic-password", "-s", service, "-a", account, "-w"],
      {encoding: "utf8"},
  ).trim();
}

const apiKey = plistValue("API_KEY");
const projectId = plistValue("PROJECT_ID");
const reviewEmail = "appreview@vetmap.app";
const fixtureEmail = "appreview-fixture@vetmap.app";

async function requestJson(url, options = {}, allowedStatuses = [200]) {
  const response = await fetch(url, options);
  const body = await response.json().catch(() => ({}));
  if (!allowedStatuses.includes(response.status)) {
    const message = body?.error?.message ?? body?.error?.status ?? `HTTP ${response.status}`;
    throw new Error(message);
  }
  return {status: response.status, body};
}

async function signIn(email, password) {
  const {body} = await requestJson(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({email, password, returnSecureToken: true}),
      },
  );
  if (!body.idToken || !body.localId) {
    throw new Error(`Firebase sign-in did not return an identity for ${email}`);
  }
  return {idToken: body.idToken, uid: body.localId};
}

const reviewIdentity = await signIn(
    reviewEmail,
    keychainPassword("VetMap App Review", reviewEmail),
);
const fixtureIdentity = await signIn(
    fixtureEmail,
    keychainPassword("VetMap App Review Fixture", fixtureEmail),
);

const participants = [reviewIdentity.uid, fixtureIdentity.uid].sort();
const conversationId = participants.join("--");
const messageId = "vetmap-demo-chat-message";
const documentRoot =
  `projects/${projectId}/databases/(default)/documents`;
const firestoreBase =
  `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
  "/databases/(default)/documents";

function headers(idToken) {
  return {
    authorization: `Bearer ${idToken}`,
    "content-type": "application/json",
  };
}

const stringValue = (value) => ({stringValue: value});
const boolValue = (value) => ({booleanValue: value});
const timestampValue = (value) => ({timestampValue: value});
const arrayValue = (values) => ({
  arrayValue: {values: values.map(stringValue)},
});
const mapValue = (fields) => ({mapValue: {fields}});

async function listReviewConversations() {
  const {body} = await requestJson(
      `${firestoreBase}:runQuery`,
      {
        method: "POST",
        headers: headers(reviewIdentity.idToken),
        body: JSON.stringify({
          structuredQuery: {
            from: [{collectionId: "conversations"}],
            where: {
              fieldFilter: {
                field: {fieldPath: "participantIds"},
                op: "ARRAY_CONTAINS",
                value: stringValue(reviewIdentity.uid),
              },
            },
          },
        }),
      },
  );
  return Array.isArray(body) ? body : [];
}

const existing = (await listReviewConversations()).find(
    (item) => item?.document?.name?.endsWith(`/conversations/${conversationId}`),
);
let result = "existing";

if (!existing) {
  const now = new Date().toISOString();
  const messageBody =
    "呢係 VetMap 聊天室功能示範訊息，並非真實診所或醫療建議。";
  const conversationName = `${documentRoot}/conversations/${conversationId}`;
  const messageName = `${conversationName}/messages/${messageId}`;
  const participantNames = {};
  participantNames[reviewIdentity.uid] = stringValue("App Review 用戶");
  participantNames[fixtureIdentity.uid] = stringValue("VetMap 示範用戶");

  await requestJson(
      `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
        "/databases/(default)/documents:commit",
      {
        method: "POST",
        headers: headers(fixtureIdentity.idToken),
        body: JSON.stringify({
          writes: [
            {
              update: {
                name: conversationName,
                fields: {
                  id: stringValue(conversationId),
                  participantIds: arrayValue(participants),
                  participantNames: mapValue(participantNames),
                  lastMessageId: stringValue(messageId),
                  lastMessage: stringValue(messageBody),
                  lastMessageAt: timestampValue(now),
                  lastSenderId: stringValue(fixtureIdentity.uid),
                  createdAt: timestampValue(now),
                  updatedAt: timestampValue(now),
                },
              },
              currentDocument: {exists: false},
            },
            {
              update: {
                name: messageName,
                fields: {
                  id: stringValue(messageId),
                  conversationId: stringValue(conversationId),
                  senderId: stringValue(fixtureIdentity.uid),
                  body: stringValue(messageBody),
                  sentAt: timestampValue(now),
                  isDeleted: boolValue(false),
                },
              },
              currentDocument: {exists: false},
            },
          ],
        }),
      },
  );
  result = "created";
}

const verifiedConversation = (await listReviewConversations()).find(
    (item) => item?.document?.name?.endsWith(`/conversations/${conversationId}`),
);
if (!verifiedConversation) {
  throw new Error("App Review conversation is not readable by the review account");
}

const messageURL = `${firestoreBase}/conversations/${encodeURIComponent(conversationId)}` +
  `/messages/${encodeURIComponent(messageId)}`;
const verifiedMessage = await requestJson(messageURL, {
  headers: headers(reviewIdentity.idToken),
});
if (
  verifiedMessage.body?.fields?.senderId?.stringValue !== fixtureIdentity.uid ||
  verifiedMessage.body?.fields?.isDeleted?.booleanValue !== false
) {
  throw new Error("App Review message has unexpected ownership or state");
}

console.log(JSON.stringify({
  conversation: result,
  reviewParticipantVerified: true,
  fixtureSenderVerified: true,
  incomingMessageReadable: true,
}, null, 2));
