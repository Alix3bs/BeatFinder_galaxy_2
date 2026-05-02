import Foundation

enum AppTab: Hashable {
    case home
    case upload
    case profile
    case safe
}

enum HomeRoute: Hashable {}

enum UploadRoute: Hashable {
    case result(BeatResultModel)
}

enum ProfileRoute: Hashable {
    case settings
    case wallet
}

enum SafeRoute: Hashable {}

enum SubscriptionFlowStep: Hashable {
    case plans
    case membership
}
