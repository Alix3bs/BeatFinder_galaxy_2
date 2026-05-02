import XCTest

final class BeatFinderExploreUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExploreGetButtonOpensSubscription() throws {
        let app = launchExplore()
        app.buttons["explore.getButton"].tap()
        XCTAssertTrue(app.otherElements["subscriptionModal"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExploreGiftButtonResponds() throws {
        let app = launchExplore()
        app.buttons["explore.giftButton"].tap()
        XCTAssertTrue(app.staticTexts["Gift / Redeem Membership"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExploreFilterButtonResponds() throws {
        let app = launchExplore()
        app.buttons["explore.filterButton"].tap()
        XCTAssertTrue(app.staticTexts["Explore Filters"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExploreSearchButtonResponds() throws {
        let app = launchExplore()
        app.buttons["explore.searchButton"].tap()
        XCTAssertTrue(app.staticTexts["Search Beats"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExploreHeroTapOpensBeatDetail() throws {
        let app = launchExplore()
        app.buttons["explore.heroCard.0"].tap()
        XCTAssertTrue(app.buttons["uploadResult.watchOnYouTube"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExploreFeaturedRowOpensBeatDetail() throws {
        let app = launchExplore()
        app.buttons["explore.featuredRow"].tap()
        XCTAssertTrue(app.buttons["uploadResult.watchOnYouTube"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExploreMondayReleaseOpensBeatDetail() throws {
        let app = launchExplore()
        let mondayCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "explore.mondayCard.")).firstMatch
        XCTAssertTrue(mondayCard.waitForExistence(timeout: 5))
        mondayCard.tap()
        XCTAssertTrue(app.buttons["uploadResult.watchOnYouTube"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchExplore() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting-authenticated")
        app.launch()
        XCTAssertTrue(app.staticTexts["Beats"].waitForExistence(timeout: 5))
        return app
    }
}
