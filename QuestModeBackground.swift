import SwiftUI

struct QuestModeBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var theme: ThemeManager

    /// When `true`, uses dark auth surfaces + Sapphire blobs (login); ignores saved accent theme.
    var authFlow: Bool = false

    var body: some View {
        ZStack {
            (authFlow ? AppTheme.AuthFlow.background : AppTheme.background(for: colorScheme))

            // Blobs stay purely decorative: blur can inflate layout width/height if left in an unconstrained ZStack.
            ZStack {
                Circle()
                    .fill(blobAccent.opacity(authFlow ? 0.12 : (colorScheme == .dark ? 0.10 : 0.15)))
                    .frame(width: 400)
                    .blur(radius: 120)
                    .offset(x: -180, y: -250)

                Circle()
                    .fill(blobSoft.opacity(authFlow ? 0.10 : (colorScheme == .dark ? 0.08 : 0.12)))
                    .frame(width: 450)
                    .blur(radius: 150)
                    .offset(x: 200, y: 300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
    }

    private var blobAccent: Color {
        if authFlow {
            return ThemeColor.neonBlue.accent
        }
        return theme.accent
    }

    private var blobSoft: Color {
        if authFlow {
            return ThemeColor.neonBlue.accentSoft
        }
        return theme.accentSoft
    }
}
