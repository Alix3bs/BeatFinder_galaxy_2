import Foundation


struct RhymeEngine {

    private let buckets: [String: [String]] = [

        "ime": ["time","rhyme","climb","prime","sublime","grime","slime"],

        "ove": ["love","above","dove","glove","shove","of"],

        "ow":  ["flow","go","glow","snow","slow","grow","show"],

        "ay":  ["day","play","stay","wave","way","spray","delay"],

        "ight": ["night","light","flight","fight","bright","insight","alight"],

        "eal": ["real","feel","deal","seal","appeal","steal","reveal"],

        "ore": ["more","score","core","shore","before","ignore"],

        "air": ["care","share","flare","snare","stare","aware"],

        "eep": ["deep","sleep","keep","creep","leap","cheap"],

        "eam": ["dream","beam","scheme","stream","theme","team"],

        "ine": ["line","shine","define","design","align","mine","sign"],

        "ound": ["sound","ground","found","bound","around","pound"]

    ]



    func rhymes(for word: String) -> [String] {

        let w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard w.count >= 3 else { return [] }

        let end3 = String(w.suffix(3))

        let end4 = w.count >= 4 ? String(w.suffix(4)) : nil

        if let e4 = end4, let list = buckets[e4] { return list.filter { $0 != w } }

        if let list = buckets[end3] { return list.filter { $0 != w } }

        let end2 = String(w.suffix(2))

        let flat = buckets.values.flatMap { $0 }

        return flat.filter { $0.hasSuffix(end2) && $0 != w }.prefix(12).map { $0 }

    }

}
