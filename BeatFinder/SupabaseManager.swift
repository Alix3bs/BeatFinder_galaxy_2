import Foundation
import Supabase

enum SupabaseManager {
    // ✅ use your Project URL
    static let url = URL(string: "https://qsvhlpctkzbgznmxpoib.supabase.co")!

    // ✅ use your PUBLISHABLE key (ios1 is fine)
    static let anonKey = "sb_publishable_SYA1REfXZHKG_ZkH2Fy_FA_MSA5SlEh"

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey,
        options: .init(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
