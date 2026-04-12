import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: QuestViewModel

    private var usesFixedDarkAuthChrome: Bool {
        viewModel.currentUser == nil || viewModel.needsEmailVerification
    }

    var body: some View {
        Group {
            if viewModel.currentUser == nil {
                LoginView()
                    .id(viewModel.authSessionID)
            } else if viewModel.needsEmailVerification {
                EmailVerificationGateView()
            } else if !viewModel.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(usesFixedDarkAuthChrome ? .dark : viewModel.appearance.colorScheme)
    }
}
