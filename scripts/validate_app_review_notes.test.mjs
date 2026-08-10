import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const setupPath = new URL("../AppStoreSetup.md", import.meta.url);
const metadataPath = new URL("../AppStoreMetadata.md", import.meta.url);
const updaterPath = new URL("./update_asc_hk_metadata.py", import.meta.url);

function extractSetupNotes(source) {
  const match = source.match(/Review Notes：\s*```text\n([\s\S]*?)\n```/);
  assert.ok(match, "AppStoreSetup.md must contain one fenced Review Notes block");
  return match[1];
}

function extractUpdaterNotes(source) {
  const match = source.match(/review_notes = f"""([\s\S]*?)"""\n\nreview_status/);
  assert.ok(match, "metadata updater must contain the review_notes payload");
  return match[1];
}

const requiredReviewFacts = [
  "Send Message",
  "Tap the heart in the demo clinic header",
  "My → Saved Clinics",
  "account-synchronised",
  "Messages tab",
  "Long-press it to Report",
  "Block User",
  "Long-press a message you sent to Delete Message",
  "My → Account Settings → Delete Account",
  "Private one-to-one messages are visible only to their two participants",
  "reported messages are available to administrators for review and soft removal",
  "demo clinic, review, quote, and chat message are VetMap-owned test fixtures",
  "No IAP or subscription UI is exposed in v1.0",
  "https://vetmap-app.web.app/support",
];

test("manual and automated App Review notes retain every 1.0 review path", async () => {
  const [setupSource, updaterSource] = await Promise.all([
    readFile(setupPath, "utf8"),
    readFile(updaterPath, "utf8"),
  ]);
  const setupNotes = extractSetupNotes(setupSource).replaceAll(/\s+/g, " ");
  const updaterNotes = extractUpdaterNotes(updaterSource).replaceAll(/\s+/g, " ");

  for (const fact of requiredReviewFacts) {
    assert.ok(setupNotes.includes(fact), `manual Review Notes missing: ${fact}`);
    assert.ok(updaterNotes.includes(fact), `ASC updater Review Notes missing: ${fact}`);
  }
});

test("manual and automated descriptions retain account-synchronised favourites", async () => {
  const [metadataSource, updaterSource] = await Promise.all([
    readFile(metadataPath, "utf8"),
    readFile(updaterPath, "utf8"),
  ]);
  for (const fact of [
    "收藏常用診所並同步到 VetMap 帳戶",
    "Save favourite clinics and sync them to your VetMap account",
  ]) {
    assert.ok(metadataSource.includes(fact), `manual description missing: ${fact}`);
    assert.ok(updaterSource.includes(fact), `ASC updater description missing: ${fact}`);
  }
});
