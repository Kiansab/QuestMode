import SwiftUI

struct LegalDocumentView: View {
    enum Kind {
        case privacy
        case terms

        var title: String {
            switch self {
            case .privacy: return "Privacy Policy"
            case .terms: return "Terms of Use"
            }
        }

        var bodyText: String {
            switch self {
            case .privacy:
                return """
                Quest Mode collects the minimum data needed to run the app.

                • Account: email and authentication are handled by Firebase Auth.
                • Progress: gameplay data (XP, quests, streak, preferences) may sync to Firebase Firestore tied to your user ID.
                • Device: we may use analytics and crash reporting to improve stability.
                • Photos: images you attach stay on your device unless you enable cloud features that store them.

                You can export your data from Profile and delete your account at any time. Replace this text with your lawyer-reviewed policy before the App Store.
                """
            case .terms:
                return """
                Quest Mode is provided as-is for personal motivation and entertainment.

                You are responsible for your safety when completing real-world activities. The app does not provide medical or professional advice.

                Replace this text with your lawyer-reviewed terms before the App Store.
                """
            }
        }
    }

    let kind: Kind
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            Text(kind.bodyText)
                .font(.body)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(AppTheme.background(for: colorScheme))
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
