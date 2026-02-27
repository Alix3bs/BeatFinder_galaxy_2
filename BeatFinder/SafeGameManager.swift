import Foundation
import SwiftUI
import Combine

enum LockState {
    case locked
    case unlocked
}

class SafeGameManager: ObservableObject {
    @Published var state: LockState = .locked
}
