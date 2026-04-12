import SwiftUI

struct QuestCardModifier: ViewModifier {

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var theme: ThemeManager

    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                theme.accent.opacity(colorScheme == .dark ? 0.55 : 0.4),
                                theme.accent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.1),
                radius: 14,
                y: 5
            )
            .shadow(color: theme.accent.opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 18, y: 4)
    }
}

extension View {
    func questCardStyle(cornerRadius: CGFloat = 24) -> some View {
        modifier(QuestCardModifier(cornerRadius: cornerRadius))
    }
}
