import SwiftUI

/// Large, readable title + plain-language subtitle for main screens (accessibility-friendly).
struct ScreenGuideHeader: View {
    let title: String
    let guide: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                .accessibilityAddTraits(.isHeader)

            Text(guide)
                .font(.title3)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
