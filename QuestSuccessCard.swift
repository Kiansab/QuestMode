import SwiftUI

struct QuestSuccessCard: View {
    let xpEarned: Int
    let streak: Int
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.18))
                    .frame(width: 72, height: 72)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(theme.accent)
            }
            
            VStack(spacing: 6) {
                Text("Quest Complete")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                
                Text("Nice work. That one counts.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            }
            
            VStack(spacing: 10) {
                rewardRow(
                    icon: "bolt.fill",
                    title: "XP Earned",
                    value: "+\(xpEarned)"
                )
                
                rewardRow(
                    icon: "flame.fill",
                    title: "Current Streak",
                    value: "\(streak) days"
                )
                
                rewardRow(
                    icon: "book.fill",
                    title: "Quest Log",
                    value: "Saved"
                )
            }
        }
        .padding(22)
        .frame(maxWidth: 320)
        .background(AppTheme.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12),
            radius: 20,
            y: 10
        )
    }
    
    private func rewardRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(theme.accent)
                .frame(width: 18)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.cardSecondary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
