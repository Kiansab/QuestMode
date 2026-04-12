import SwiftUI
import FirebaseAuth

struct EmailVerificationBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        Group {
            if let user = Auth.auth().currentUser, !user.isEmailVerified {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verify your email")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Check your inbox for the link so we can reach you if needed.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                    }
                    Spacer(minLength: 8)
                    Button("Resend") {
                        user.sendEmailVerification(completion: nil)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.accent)
                }
                .padding(12)
                .background(AppTheme.card(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.accent.opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
