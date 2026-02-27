import Foundation
import Combine

/// Compatibility stub kept only to avoid reintroducing a second auth system.
@available(*, unavailable, message: "Use AuthStore + AuthGateView. AppSession is not supported.")
@MainActor
final class AppSession: ObservableObject {}
