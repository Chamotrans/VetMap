import XCTest

final class VetMapUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTabBarHasAllFourTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        XCTAssertTrue(tabBar.buttons["首頁"].exists, "首頁 tab should exist")
        XCTAssertTrue(tabBar.buttons["診所"].exists, "診所 tab should exist")
        XCTAssertTrue(tabBar.buttons["好物"].exists, "好物 tab should exist")
        XCTAssertTrue(tabBar.buttons["我的"].exists, "我的 tab should exist")
    }

    func testClinicsTabShowsClinicList() {
        app.tabBars.buttons["診所"].tap()

        let navBar = app.navigationBars["獸醫診所"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Clinic list navigation bar should exist")

        let clinicCell = app.buttons["安心動物醫院"]
        XCTAssertTrue(clinicCell.waitForExistence(timeout: 5), "安心動物醫院 should appear in clinic list")
    }

    func testMapTabLoads() {
        app.tabBars.buttons["首頁"].tap()

        let tab = app.tabBars.buttons["首頁"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        XCTAssertTrue(tab.isSelected, "Map tab should be selected after tapping")
    }

    func testProductsTabShowsProducts() {
        app.tabBars.buttons["好物"].tap()

        let navBar = app.navigationBars["毛孩好物"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Products navigation bar should exist")

        let goodiesButton = app.buttons["好物"]
        XCTAssertTrue(goodiesButton.waitForExistence(timeout: 5), "Products segment should be visible")
    }

    func testProfileTabShowsSignInPrompt() {
        app.tabBars.buttons["我的"].tap()

        let navBar = app.navigationBars["我的"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Profile navigation bar should exist")

        let signInButton = app.buttons["登入 / 註冊"]
        let loadingText = app.staticTexts["載入中…"]
        XCTAssertTrue(
            signInButton.waitForExistence(timeout: 5) || loadingText.waitForExistence(timeout: 5),
            "Profile should show sign-in prompt or loading state"
        )
    }

    func testClinicSearchFiltersResults() {
        app.tabBars.buttons["診所"].tap()

        let navBar = app.navigationBars["獸醫診所"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 5) else {
            XCTFail("Search field not found")
            return
        }

        searchField.tap()
        searchField.typeText("牙科")

        let result = app.buttons["安心動物醫院"]
        XCTAssertTrue(result.waitForExistence(timeout: 5), "安心動物醫院 should appear in filtered results")
    }

    func testAddClinicFormValidation() {
        app.tabBars.buttons["診所"].tap()

        let clinicNavBar = app.navigationBars["獸醫診所"]
        XCTAssertTrue(clinicNavBar.waitForExistence(timeout: 5))

        let addButton = clinicNavBar.buttons["新增診所"]
        guard addButton.waitForExistence(timeout: 5) else {
            XCTFail("Add clinic button not found")
            return
        }
        addButton.tap()

        let addNavBar = app.navigationBars["新增診所"]
        XCTAssertTrue(addNavBar.waitForExistence(timeout: 5), "Add clinic form should appear")

        let submitButton = addNavBar.buttons["提交"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 5))
        XCTAssertFalse(submitButton.isEnabled, "Submit should be disabled with empty form")

        let nameField = app.textFields["診所名稱"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("測試診所")
    }
}
