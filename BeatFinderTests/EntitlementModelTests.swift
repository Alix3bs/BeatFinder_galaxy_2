import Foundation
import Testing
@testable import BeatFinder

@MainActor
struct EntitlementModelTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "beatfinder.tests.entitlements.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func tierMappingFollowsBillingState() {
        #expect(BeatFinderEntitlements.current(isPro: false) == .free)
        #expect(BeatFinderEntitlements.current(isPro: true) == .pro)
    }

    @Test func freeTierHasLimitsAndProDoesNot() {
        let free = BeatFinderEntitlements.free
        let pro = BeatFinderEntitlements.pro

        #expect(free.dailySearchLimit == 10)
        #expect(pro.dailySearchLimit == nil)
        #expect(free.maxUploadSeconds < pro.maxUploadSeconds)
        #expect(free.savedResultLimit == 25)
        #expect(pro.savedResultLimit == nil)
    }

    @Test func savedResultLimitGatesSaves() {
        let free = BeatFinderEntitlements.free
        #expect(free.canSave(currentSavedCount: 0))
        #expect(free.canSave(currentSavedCount: 24))
        #expect(!free.canSave(currentSavedCount: 25))
        #expect(BeatFinderEntitlements.pro.canSave(currentSavedCount: 10_000))
    }

    @Test func quotaTracksAndBlocksAtLimit() {
        let tracker = SearchQuotaTracker(defaults: makeDefaults())
        let free = BeatFinderEntitlements.free

        #expect(tracker.remainingSearches(for: free) == 10)
        for _ in 0..<10 {
            #expect(tracker.canSearch(with: free))
            tracker.recordSearch()
        }
        #expect(tracker.remainingSearches(for: free) == 0)
        #expect(!tracker.canSearch(with: free))
        #expect(tracker.canSearch(with: .pro))
        #expect(tracker.remainingSearches(for: .pro) == nil)
    }

    @Test func quotaResetsOnNewDay() {
        let defaults = makeDefaults()
        var currentDate = Date(timeIntervalSince1970: 1_760_000_000)
        let tracker = SearchQuotaTracker(defaults: defaults, now: { currentDate })

        tracker.recordSearch()
        tracker.recordSearch()
        #expect(tracker.remainingSearches(for: .free) == 8)

        currentDate = currentDate.addingTimeInterval(60 * 60 * 26)
        #expect(tracker.remainingSearches(for: .free) == 10)
        #expect(tracker.canSearch(with: .free))
    }

    @Test func quotaPersistsWithinTheSameDay() {
        let defaults = makeDefaults()
        let fixedDate = Date(timeIntervalSince1970: 1_760_000_000)
        let tracker = SearchQuotaTracker(defaults: defaults, now: { fixedDate })
        tracker.recordSearch()
        tracker.recordSearch()
        tracker.recordSearch()

        let reloaded = SearchQuotaTracker(defaults: defaults, now: { fixedDate })
        #expect(reloaded.remainingSearches(for: .free) == 7)
    }
}
