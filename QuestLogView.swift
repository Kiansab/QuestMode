import SwiftUI

struct QuestLogView: View {
    @ObservedObject var viewModel: QuestViewModel
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ScreenGuideHeader(
                            title: "Quest log",
                            guide: "A simple history of quests you completed. Open any card to see your notes or proof."
                        )

                        if viewModel.questLog.isEmpty {
                            emptyState
                        } else {
                            ForEach(viewModel.questLog) { entry in
                                questLogCard(for: entry)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(theme.accent)

            Text("Nothing here yet")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

            Text("Finish a quest from the Home or Quests tab. Your completed quests and notes will show up in this list.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func questLogCard(for entry: QuestLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.category)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.accent.opacity(0.14))
                        .foregroundStyle(theme.accent)
                        .clipShape(Capsule())

                    Text(formattedDate(entry.completedAt))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                }

                Spacer()

                Label("\(entry.xp) XP", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            }

            Text(entry.title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))

            if !entry.reflection.isEmpty {
                Text(entry.reflection)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            }

            HStack(spacing: 8) {
                proofTypeBadge(for: entry.proofType)
                proofStatusBadge(for: entry.proofStatus)
                Spacer()
            }
        }
        .padding()
        .questCardStyle()
    }

    private func proofTypeBadge(for proofType: ProofType) -> some View {
        HStack(spacing: 6) {
            Image(systemName: proofTypeIcon(for: proofType))
                .font(.caption2)

            Text(proofTypeLabel(for: proofType))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.cardSecondary(for: colorScheme))
        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
        .clipShape(Capsule())
    }

    private func proofStatusBadge(for proofStatus: ProofStatus) -> some View {
        HStack(spacing: 6) {
            Image(systemName: proofStatusIcon(for: proofStatus))
                .font(.caption2)

            Text(proofStatusLabel(for: proofStatus))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.accent.opacity(0.16))
        .foregroundStyle(theme.accent)
        .clipShape(Capsule())
    }

    private func proofTypeLabel(for proofType: ProofType) -> String {
        switch proofType {
        case .photo:
            return "Photo Ready"
        case .reflection:
            return "Reflection"
        case .selfCheck:
            return "Self Check In"
        }
    }

    private func proofTypeIcon(for proofType: ProofType) -> String {
        switch proofType {
        case .photo:
            return "camera.fill"
        case .reflection:
            return "text.bubble.fill"
        case .selfCheck:
            return "checkmark.seal.fill"
        }
    }

    private func proofStatusLabel(for proofStatus: ProofStatus) -> String {
        switch proofStatus {
        case .photoPending:
            return "Photo Pending"
        case .reflectionSubmitted:
            return "Reflection Saved"
        case .selfCheckCompleted:
            return "Check In Complete"
        }
    }

    private func proofStatusIcon(for proofStatus: ProofStatus) -> String {
        switch proofStatus {
        case .photoPending:
            return "clock.fill"
        case .reflectionSubmitted:
            return "checkmark.bubble.fill"
        case .selfCheckCompleted:
            return "checkmark.circle.fill"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
