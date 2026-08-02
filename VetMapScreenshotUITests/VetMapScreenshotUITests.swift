import XCTest

final class VetMapScreenshotUITests: XCTestCase {
    func testCaptureReleaseScreenshots() {
        let app = XCUIApplication()
        let screens = [
            "01-Map",
            "02-Clinics",
            "03-ClinicDetail",
            "04-Products",
            "05-Messages",
            "06-Profile",
        ]

        for screen in screens {
            app.terminate()
            app.launchArguments = [
                "-hasSeenOnboarding", "YES",
                "-UITestSuppressPrompts",
                "-screenshotScreen", screen == "06-Profile" ? "05-Profile" : screen,
            ]
            app.launch()

            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: 10),
                "\(screen) did not reach the foreground"
            )
            sleep(screen == "01-Map" ? 8 : 5)

            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = screen
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
