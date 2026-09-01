import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("support tiers are three StoreKit consumables, not premium entitlements", async () => {
  const [iap, storekit, storekitJSON, profile, view, viewModel] = await Promise.all([
    read("VetMap/Services/IAPService.swift"), read("VetMap/Resources/Products.storekit"), read("VetMap/Resources/Products.storekit.json"), read("VetMap/Views/TabViews/ProfileTab.swift"), read("VetMap/Views/Profile/SupportDeveloperView.swift"), read("VetMap/ViewModels/SupportDeveloperViewModel.swift"),
  ]);
  const config = JSON.parse(storekit); const compatibility = JSON.parse(storekitJSON);
  const supportIDs = ["com.vetmap.app.support.drink", "com.vetmap.app.support.handcrafted_drink", "com.vetmap.app.support.meal"];
  assert.deepEqual(config.products.map((product) => product.productID), supportIDs);
  assert.deepEqual(config.products.map((product) => product.displayPrice), ["18.00", "28.00", "58.00"]);
  assert.ok(config.products.every((product) => product.type === "Consumable"));
  assert.ok(supportIDs.every((id) => compatibility.products.find((product) => product.id === id)?.type === "consumable"));
  assert.match(iap, /static let supportDrinkProductID = "com\.vetmap\.app\.support\.drink"/);
  assert.match(iap, /static let supportHandcraftedDrinkProductID = "com\.vetmap\.app\.support\.handcrafted_drink"/);
  assert.match(iap, /static let supportMealProductID = "com\.vetmap\.app\.support\.meal"/);
  assert.match(iap, /func purchaseSupport\(_ product: Product\) async throws/);
  assert.match(iap, /guard Self\.supportProductIDs\.contains\(product\.id\)/);
  assert.doesNotMatch(iap, /supportProductIDs.*isPremium/);
  assert.equal((profile.match(/SupportDeveloperView\(\)/g) ?? []).length, 2);
  assert.match(view, /option\.displayPrice/); assert.doesNotMatch(view, /HK\$|\$18|18\.00|28\.00|58\.00/);
  assert.match(view, /不是訂閱，沒有自動續期/); assert.match(viewModel, /testingDisplayPrice/);
  assert.match(viewModel, /轉凍飲/); assert.match(viewModel, /手搖飲品/); assert.match(viewModel, /肚餓都只食良/);
  assert.match(viewModel, /init\(service: IAPService\? = nil\)/);
  assert.match(viewModel, /let service = service \?\? IAPService\(\)/);
  assert.doesNotMatch(viewModel, /IAPService = IAPService\(\)/);
});
