import Foundation

/// Pure functions for day-streak logic (unit-testable).
enum StreakCalculator {

    struct StreakUpdate {
        let newStreak: Int
        let lastPlayedDate: Date
        let lastStreakDate: Date
    }

    /// Updates streak when the user completes a quest. `lastPlayed` is the last completion instant before this one.
    static func updateAfterQuestCompletion(
        now: Date,
        calendar: Calendar = .current,
        previousStreak: Int,
        lastPlayed: Date
    ) -> StreakUpdate {
        let todayStart = calendar.startOfDay(for: now)
        let lastStart = calendar.startOfDay(for: lastPlayed)

        if lastStart == todayStart {
            return StreakUpdate(
                newStreak: previousStreak,
                lastPlayedDate: now,
                lastStreakDate: now
            )
        }

        let newStreak: Int
        if lastPlayed == Date.distantPast {
            newStreak = 1
        } else {
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!
            if lastStart == yesterdayStart {
                newStreak = previousStreak + 1
            } else {
                newStreak = 1
            }
        }

        return StreakUpdate(newStreak: newStreak, lastPlayedDate: now, lastStreakDate: now)
    }
}
