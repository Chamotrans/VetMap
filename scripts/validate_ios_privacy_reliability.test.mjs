import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("launch remains free of unsolicited notification and location permission prompts", async () => {
  const [content, app, map, location] = await Promise.all([
    read("VetMap/ContentView.swift"),
    read("VetMap/VetMapApp.swift"),
    read("VetMap/Views/Map/ClinicMapView.swift"),
    read("VetMap/Services/LocationService.swift"),
  ]);

  for (const source of [content, app, map]) {
    assert.doesNotMatch(source, /UNUserNotificationCenter|registerForRemoteNotifications/);
    assert.doesNotMatch(source, /requestWhenInUseAuthorization|requestAlwaysAuthorization/);
  }
  assert.doesNotMatch(content, /UserNotifications|requestLocationFromButton/);
  assert.match(location, /func requestLocationFromButton\(\)/);
  assert.match(location, /LocationButtonPolicy\.outcome/);
  assert.match(location, /if !canUseLocation \{\s*currentLocation = nil/);
  assert.equal((map.match(/requestLocationFromButton\(\)/g) ?? []).length, 1);
  assert.match(map, /Button\("開啟設定"\)/);
  assert.match(map, /UIApplication\.openSettingsURLString/);
});

test("chat fails closed across accounts and retains the newest message window", async () => {
  const [model, store, auth, list, thread] = await Promise.all([
    read("VetMap/Models/Chat.swift"),
    read("VetMap/Services/ChatStore.swift"),
    read("VetMap/ViewModels/AuthViewModel.swift"),
    read("VetMap/Views/Chat/ChatListView.swift"),
    read("VetMap/Views/Chat/ChatThreadView.swift"),
  ]);

  assert.match(model, /participantIds\.contains\(currentID\)/);
  assert.match(model, /static let maximumCount = 200/);
  assert.match(model, /static let fetchesNewestFirst = true/);
  assert.match(store, /order\(by: "sentAt", descending: ChatMessageWindow\.fetchesNewestFirst\)/);
  assert.match(store, /limit\(to: ChatMessageWindow\.maximumCount\)/);
  assert.match(store, /messages = ChatMessageWindow\.chronological\(decoded\)/);
  assert.match(store, /currentUser\?\.uid == uid/);
  assert.match(store, /conversationsObservationGeneration == observationGeneration/);
  assert.match(store, /messagesObservationGeneration == observationGeneration/);
  assert.match(store, /conversationsAreLoading/);
  assert.match(store, /messagesAreLoading/);
  assert.match(store, /func resetSession\(\)/);
  assert.match(auth, /ChatStore\.shared\.resetSession\(\)/);
  assert.match(list, /conversationLoadError/);
  assert.match(thread, /messageLoadError/);
  assert.match(thread, /onChange\(of: chat\.messages\.last\?\.id\)/);
  assert.match(thread, /\.frame\(width: 44, height: 44\)/);
});
