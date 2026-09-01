import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("drink support is a single StoreKit consumable, not a premium entitlement", async () => {
  const [iap, storekit, storekitJSON, profile, view, viewModel] = await Promise.all([
    read("VetMap/Services/IAPService.swift"), read("VetMap/Resources/Products.storekit"), read("VetMap/Resources/Products.storekit.json"), read("VetMap/Views/TabViews/ProfileTab.swift"), read("VetMap/Views/Profile/SupportDeveloperView.swift"), read("VetMap/ViewModels/SupportDeveloperViewModel.swift"),
  ]);
  const config = JSON.parse(storekit); const compatibility = JSON.parse(storekitJSON);
  assert.equal(config.products.filter((product) => product.productID === "com.vetmap.app.support.drink").length, 1);
  assert.equal(config.products.find((product) => product.productID === "com.vetmap.app.support.drink").type, "Consumable");
  assert.equal(compatibility.products.find((product) => product.id === "com.vetmap.app.support.drink").type, "consumable");
  assert.match(iap, /static let supportDrinkProductID = "com\.vetmap\.app\.support\.drink"/);
  assert.match(iap, /func purchaseSupport\(_ product: Product\) async throws/);
  assert.match(iap, /guard product\.id == Self\.supportDrinkProductID/);
  assert.doesNotMatch(iap, /supportDrinkProductID\).*isPremium/);
  assert.equal((profile.match(/SupportDeveloperView\(\)/g) ?? []).length, 2);
  assert.match(view, /displayPrice/); assert.doesNotMatch(view, /HK\$|\$18|18\.00/);
  assert.match(view, /不是訂閱，沒有自動續期/); assert.match(viewModel, /testingDisplayPrice/);
  assert.match(viewModel, /init\(service: IAPService\? = nil\)/);
  assert.match(viewModel, /let service = service \?\? IAPService\(\)/);
  assert.doesNotMatch(viewModel, /IAPService = IAPService\(\)/);
});
