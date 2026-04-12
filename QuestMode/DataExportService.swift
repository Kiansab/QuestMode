import Foundation

enum DataExportService {

    struct FullExport: Codable {
        let exportedAt: Date
        let xp: Int
        let streak: Int
        let username: String
        let appearance: String
        let quests: [Quest]
        let questLog: [QuestLogEntry]
        let selectedCategories: [String]
        let hasCompletedOnboarding: Bool
        let onboardingProfile: OnboardingProfile?
    }

    static func makeExportFile(from viewModel: QuestViewModel) throws -> URL {
        let payload = FullExport(
            exportedAt: Date(),
            xp: viewModel.xp,
            streak: viewModel.streak,
            username: viewModel.username,
            appearance: viewModel.appearance.rawValue,
            quests: viewModel.quests,
            questLog: viewModel.questLog,
            selectedCategories: viewModel.selectedCategories,
            hasCompletedOnboarding: viewModel.hasCompletedOnboarding,
            onboardingProfile: viewModel.onboardingProfile
        )
        let data = try JSONEncoder().encode(payload)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("QuestMode-export-\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url)
        return url
    }
}
