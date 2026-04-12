import Foundation

/// Deterministic daily quest picks from a pool (same user + same calendar day → same quests).
enum DailyQuestSelector {

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func seed(userId: String, dayKey: String) -> String {
        "\(userId)|\(dayKey)"
    }

    /// Stable 64-bit mix of string (FNV-1a style).
    static func hash64(_ string: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    static func pickQuests(from pool: [Quest], count: Int, seed: String, weights: [Double]? = nil) -> [Quest] {
        guard !pool.isEmpty, count > 0 else { return [] }
        let n = min(count, pool.count)
        if let w = weights, w.count == pool.count {
            let picked = pickWeightedWithoutReplacement(pool: pool, weights: w, count: n, seed: seed)
            if picked.count == n { return picked }
        }
        let indices = Array(0..<pool.count).sorted {
            hash64("\(seed)|\($0)") < hash64("\(seed)|\($1)")
        }
        return indices.prefix(n).map { pool[$0] }
    }

    /// Deterministic weighted sampling without replacement (`weights[i]` ≥ 0).
    private static func pickWeightedWithoutReplacement(pool: [Quest], weights: [Double], count: Int, seed: String) -> [Quest] {
        var remaining = Set(0..<pool.count)
        var result: [Quest] = []
        for slot in 0..<count where !remaining.isEmpty {
            let ordered = remaining.sorted()
            let total = ordered.map { max(0, weights[$0]) }.reduce(0, +)
            guard total > 0 else { break }
            let thresh = Double(hash64("\(seed)|w|\(slot)|\(result.count)")) / Double(UInt64.max) * total
            var cumulative: Double = 0
            var chosen = ordered[0]
            for idx in ordered {
                cumulative += max(0, weights[idx])
                if thresh < cumulative {
                    chosen = idx
                    break
                }
            }
            result.append(pool[chosen])
            remaining.remove(chosen)
        }
        return result
    }
}
