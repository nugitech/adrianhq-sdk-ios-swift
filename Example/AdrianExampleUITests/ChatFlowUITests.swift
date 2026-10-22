import XCTest

/// Walks the chat flow end to end against a running Adrian. Skipped unless ADRIAN_WORKSPACE_ID is set.
/// With SCREENSHOT_DIR set it saves a screenshot of each step there, and leaves `<step>.done` marker files
/// so a script playing the support team knows when to reply. TARGET_BUNDLE_ID runs the same flow against
/// another installed app with the same labels, such as the Flutter example (which bakes in its workspace at build time).
final class ChatFlowUITests: XCTestCase {
    private var env: [String: String] { ProcessInfo.processInfo.environment }

    func testChatFlow() throws {
        let workspace = try XCTUnwrap(env["ADRIAN_WORKSPACE_ID"], "Set ADRIAN_WORKSPACE_ID to run against a workspace")
        let app = env["TARGET_BUNDLE_ID"].map { XCUIApplication(bundleIdentifier: $0) } ?? XCUIApplication()
        app.launchEnvironment["ADRIAN_WORKSPACE_ID"] = workspace
        app.launchEnvironment["ADRIAN_WIDGET_URL"] = env["ADRIAN_WIDGET_URL"]
        app.launch()

        let launcher = app.buttons["Open chat"]
        XCTAssertTrue(launcher.waitForExistence(timeout: 10))
        sleep(5)
        snap("01-home")

        app.buttons["Sign in as Ada"].tap()
        sleep(2)
        launcher.tap()
        let composer = app.webViews.textViews.firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 20))
        sleep(3)
        snap("02-messenger")

        composer.tap()
        composer.typeText("Hi, I paid my tax this morning but the receipt isn't showing in the app")
        app.webViews.buttons["Send"].tap()
        mark("sent")
        let reply = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "receipt number")).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 90), "No reply from the team")
        if app.keyboards.count > 0 { app.webViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap() }
        sleep(2)
        snap("03-conversation")

        app.webViews.buttons["Close chat"].tap()
        mark("closed")
        // The team sends a message and a form after the chat closes.
        let badge = NSPredicate(format: "value CONTAINS %@", "2 unread")
        expectation(for: badge, evaluatedWith: launcher)
        waitForExpectations(timeout: 90)
        sleep(2)
        snap("04-unread")

        launcher.tap()
        sleep(3)
        app.webViews.firstMatch.swipeUp()
        sleep(1)
        snap("05-form")
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = env["SCREENSHOT_DIR"] else { return }
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    private func mark(_ step: String) {
        guard let dir = env["SCREENSHOT_DIR"] else { return }
        FileManager.default.createFile(atPath: URL(fileURLWithPath: dir).appendingPathComponent("\(step).done").path, contents: Data())
    }
}
