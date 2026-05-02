import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    func verificationTitle(for session: SessionState) -> String {
        session.isVerified ? "Verified creator" : "Verification pending"
    }

    func verificationDetail(for session: SessionState) -> String {
        session.isVerified
            ? "Your identity badge is active across profile and upload results."
            : "Submit creator details to unlock the verification badge across profile and upload surfaces."
    }
}
