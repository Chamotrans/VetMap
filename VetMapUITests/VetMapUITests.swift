import XCTest

final class VetMapUITests: XCTestCase {
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssert(app.staticTexts["VetMap"].exists)
    }
}
