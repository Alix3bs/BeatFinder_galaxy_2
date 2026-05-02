import XCTest
import Foundation

final class BeatFinderProductionPassUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsRowsAndConfirmationsOnIPad() throws {
        let app = launchApp(deviceTab: "My Studio")

        app.buttons["profile.settingsButton"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))

        let destinationChecks: [(id: String, title: String)] = [
            ("settings.account", "Account"),
            ("settings.verification", "Verification"),
            ("settings.changepassword", "Change Password"),
            ("settings.likedposts", "Liked Posts"),
            ("settings.wallet", "Wallet"),
            ("settings.notifications", "Notifications"),
            ("settings.privacy", "Privacy"),
            ("settings.security", "Security"),
            ("settings.language", "Language"),
            ("settings.appearance", "Appearance"),
            ("settings.helpcenter", "Help Center"),
            ("settings.reportaproblem", "Report a Problem"),
            ("settings.termsofuse", "Terms of Use"),
            ("settings.privacypolicy", "Privacy Policy"),
            ("settings.joinbeatfinderaitesters", "Join BeatFinder AI Testers")
        ]

        for check in destinationChecks {
            tapSettingsRow(check.id, in: app)
            XCTAssertTrue(app.navigationBars[check.title].waitForExistence(timeout: 5) || app.staticTexts[check.title].waitForExistence(timeout: 5))
            app.swipeRight()
            XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        }

        tapSettingsRow("settings.clearappcache", in: app)
        XCTAssertTrue(app.sheets["Clear App Cache?"].waitForExistence(timeout: 5) || app.buttons["Clear Cache"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        scrollToBottom(in: app)
        XCTAssertTrue(app.buttons["Sign out"].waitForExistence(timeout: 5))
        app.buttons["Sign out"].tap()
        XCTAssertTrue(app.sheets["Sign out?"].waitForExistence(timeout: 5) || app.buttons["Sign Out"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testMessageThreadPersistsOnIPad() throws {
        let app = launchApp(deviceTab: "Explore")

        scrollUntilVisible(app.staticTexts["Trending Producers"], in: app)
        app.buttons["V, Velvet, R&B • Soul"].firstMatch.tap()

        XCTAssertTrue(app.buttons["userProfile.messageButton"].waitForExistence(timeout: 5))
        app.buttons["userProfile.messageButton"].tap()

        let composer = app.textFields["messages.composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("QA thread message")
        app.buttons["messages.sendButton"].tap()

        XCTAssertTrue(app.staticTexts["QA thread message"].waitForExistence(timeout: 5))

        app.buttons["messages.backButton"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        scrollUntilVisible(app.staticTexts["Trending Producers"], in: app)
        app.buttons["V, Velvet, R&B • Soul"].firstMatch.tap()
        app.buttons["userProfile.messageButton"].tap()

        XCTAssertTrue(app.staticTexts["QA thread message"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLyricPadPersistsPerBeatOnIPad() throws {
        let app = launchApp(deviceTab: "Explore")

        let heroCard = app.buttons["explore.heroCard.0"]
        XCTAssertTrue(heroCard.waitForExistence(timeout: 5))
        heroCard.tap()

        let lyricToggle = app.buttons["beat.lyricPad.toggle"]
        XCTAssertTrue(lyricToggle.waitForExistence(timeout: 5))
        lyricToggle.tap()

        let editor = app.textViews["beat.lyricPad.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("QA lyrics for beat one")

        XCTAssertEqual(editor.value as? String, "QA lyrics for beat one")

        app.buttons["beatDetail.closeButton"].tap()
        XCTAssertTrue(heroCard.waitForExistence(timeout: 5))

        heroCard.tap()
        XCTAssertTrue(lyricToggle.waitForExistence(timeout: 5))
        lyricToggle.tap()
        XCTAssertEqual(app.textViews["beat.lyricPad.editor"].value as? String, "QA lyrics for beat one")

        app.buttons["beatDetail.closeButton"].tap()

        let mondayCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "explore.mondayCard.")).firstMatch
        XCTAssertTrue(mondayCard.waitForExistence(timeout: 5))
        mondayCard.tap()
        XCTAssertTrue(lyricToggle.waitForExistence(timeout: 5))
        lyricToggle.tap()

        let secondEditor = app.textViews["beat.lyricPad.editor"]
        XCTAssertTrue(secondEditor.waitForExistence(timeout: 5))
        XCTAssertEqual(secondEditor.value as? String, "empty")
    }

    @MainActor
    func testPhoneSmokeStillLoadsCoreScreens() throws {
        let app = launchApp(deviceTab: "Explore")

        XCTAssertTrue(app.staticTexts["Beats"].waitForExistence(timeout: 5))

        app.buttons["My Studio"].firstMatch.tap()
        XCTAssertTrue(app.buttons["profile.settingsButton"].waitForExistence(timeout: 5))

        app.buttons["Explore"].firstMatch.tap()
        XCTAssertTrue(app.buttons["explore.heroCard.0"].waitForExistence(timeout: 5))
        app.buttons["explore.heroCard.0"].tap()
        XCTAssertTrue(app.buttons["beat.lyricPad.toggle"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExploreMessagingAndSubscriptionVisualPassOnIPad() throws {
        let app = launchApp(deviceTab: "Explore")

        scrollUntilVisible(app.staticTexts["Monday Releases"], in: app)
        let mondayCards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "explore.mondayCard."))
        XCTAssertGreaterThanOrEqual(mondayCards.count, 2)

        let firstCard = mondayCards.element(boundBy: 0)
        let secondCard = mondayCards.element(boundBy: 1)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(secondCard.waitForExistence(timeout: 5))
        saveScreenshot(named: "beatfinder-qa-explore-monday-releases")

        app.buttons["V, Velvet, R&B • Soul"].firstMatch.tap()
        let otherProfileMessageButton = app.buttons["userProfile.messageButton"]
        XCTAssertTrue(otherProfileMessageButton.waitForExistence(timeout: 5))
        saveScreenshot(named: "beatfinder-qa-other-profile")
        otherProfileMessageButton.tap()
        XCTAssertTrue(app.textFields["messages.composer"].waitForExistence(timeout: 5))
        saveScreenshot(named: "beatfinder-qa-direct-thread")
        app.buttons["messages.backButton"].tap()
        app.swipeRight()

        app.buttons["My Studio"].firstMatch.tap()
        let ownProfileMessageButton = app.buttons["profile.messageButton"]
        XCTAssertTrue(ownProfileMessageButton.waitForExistence(timeout: 5))
        saveScreenshot(named: "beatfinder-qa-own-profile")
        ownProfileMessageButton.tap()
        XCTAssertTrue(app.staticTexts["Messages"].waitForExistence(timeout: 5))
        saveScreenshot(named: "beatfinder-qa-inbox")
        app.buttons.matching(identifier: "chevron.left").firstMatch.tap()

        app.buttons["Explore"].firstMatch.tap()
        scrollToTopUntilVisible(app.buttons["explore.getButton"], in: app)
        XCTAssertTrue(app.buttons["explore.getButton"].waitForExistence(timeout: 5))
        app.buttons["explore.getButton"].tap()
        XCTAssertTrue(app.otherElements["subscriptionModal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pro Plan"].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["Pro Plan"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["BeatFinder Plus Membership"].waitForExistence(timeout: 5))
        saveScreenshot(named: "beatfinder-qa-subscription-detail")
    }

    @MainActor
    func testSubscriptionLogoVisualPassOnIPad() throws {
        let app = launchApp(deviceTab: "Explore")

        let getButton = app.buttons["explore.getButton"]
        XCTAssertTrue(getButton.waitForExistence(timeout: 5))
        saveScreenshot(named: "beatfinder-qa-explore-top")
        getButton.tap()

        XCTAssertTrue(app.staticTexts["Free Plan"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pro Plan"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Producer Plan"].firstMatch.waitForExistence(timeout: 5))
        saveScreenshot(named: "beatfinder-qa-subscription-chooser")

        app.staticTexts["Pro Plan"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["BeatFinder Plus Membership"].waitForExistence(timeout: 5))
        saveScreenshot(named: "beatfinder-qa-subscription-detail")
    }

    @MainActor
    private func launchApp(deviceTab: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting-authenticated")
        app.launch()
        let tabButton = app.buttons[deviceTab].firstMatch
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5))
        tabButton.tap()
        return app
    }

    private func tapSettingsRow(_ identifier: String, in app: XCUIApplication) {
        let row = app.buttons[identifier]
        scrollUntilVisible(row, in: app)
        row.tap()
    }

    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        var attempts = 0
        while !element.exists && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
        attempts = 0
        while !element.isHittable && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }

    private func scrollToBottom(in app: XCUIApplication, swipes: Int = 6) {
        for _ in 0..<swipes {
            app.swipeUp()
        }
    }

    private func scrollToTopUntilVisible(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        var attempts = 0
        while !element.exists && attempts < maxSwipes {
            app.swipeDown()
            attempts += 1
        }
        attempts = 0
        while !element.isHittable && attempts < maxSwipes {
            app.swipeDown()
            attempts += 1
        }
    }

    @discardableResult
    private func saveScreenshot(named name: String) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(name).png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        print("Saved screenshot to \(url.path)")
        return url
    }
}
