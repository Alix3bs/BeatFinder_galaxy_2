import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://qsvhlpctkzbgznmxpoib.supabase.co")!
    static let anonKey = "sb_publishable_SYA1REfXZHKG_ZkH2Fy_FA_MSA5SlEh"

    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey
    )
}
