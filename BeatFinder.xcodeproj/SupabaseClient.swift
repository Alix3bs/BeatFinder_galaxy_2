import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://qsvhlpctkzbgznmxpoib.supabase.co")!
    static let anonKey = "PASTE_YOUR_IOS1_SB_PUBLISHABLE_KEY_HERE"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)
