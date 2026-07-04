import Foundation

/// Subscription tiers recognized by the app. Billing state (StoreKit) is
/// owned by SubscriptionManager; this model only describes what each tier is
/// allowed to do, so UI and view models never touch StoreKit directly.
enum SubscriptionTier: String, Codable, Equatable {
    case free
    case pro
}

struct BeatFinderEntitlements: Equatable {
    let tier: SubscriptionTier
    /// nil means unlimited.
    let dailySearchLimit: Int?
    let maxUploadSeconds: Double
    /// nil means unlimited.
    let savedResultLimit: Int?
    let producerDiscoveryEnabled: Bool

    static let free = BeatFinderEntitlements(
        tier: .free,
        dailySearchLimit: 10,
        maxUploadSeconds: 30,
        savedResultLimit: 25,
        producerDiscoveryEnabled: true
    )

    static let pro = BeatFinderEntitlements(
        tier: .pro,
        dailySearchLimit: nil,
        maxUploadSeconds: UploadAudioPreprocessor.maxUploadSeconds,
        savedResultLimit: nil,
        producerDiscoveryEnabled: true
    )

    static func current(isPro: Bool) -> BeatFinderEntitlements {
        isPro ? .pro : .free
    }

    func canSave(currentSavedCount: Int) -> Bool {
        guard let savedResultLimit else { return true }
        return currentSavedCount < savedResultLimit
    }
}

/// Tracks how many searches ran today, locally and anonymously. Resets at
/// local midnight; stores only a day stamp and a counter.
@MainActor
final class SearchQuotaTracker: ObservableObject {
    @Published private(set) var searchesToday: Int = 0

    private let defaults: UserDefaults
    private let countKey: String
    private let dayKey: String
    private let calendar: Calendar
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "beatfinder.quota.search",
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.countKey = "\(keyPrefix).count"
        self.dayKey = "\(keyPrefix).day"
        self.calendar = calendar
        self.now = now
        rolloverIfNeeded()
        searchesToday = defaults.integer(forKey: countKey)
    }

    func remainingSearches(for entitlements: BeatFinderEntitlements) -> Int? {
        rolloverIfNeeded()
        guard let limit = entitlements.dailySearchLimit else { return nil }
        return max(0, limit - searchesToday)
    }

    func canSearch(with entitlements: BeatFinderEntitlements) -> Bool {
        guard let remaining = remainingSearches(for: entitlements) else { return true }
        return remaining > 0
    }

    func recordSearch() {
        rolloverIfNeeded()
        searchesToday += 1
        defaults.set(searchesToday, forKey: countKey)
    }

    private func rolloverIfNeeded() {
        let today = dayStamp(for: now())
        let storedDay = defaults.string(forKey: dayKey)
        if storedDay != today {
            defaults.set(today, forKey: dayKey)
            defaults.set(0, forKey: countKey)
            searchesToday = 0
        }
    }

    private func dayStamp(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
