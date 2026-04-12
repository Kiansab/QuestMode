// APP ROOT: This file is the @main entry point for QuestMode. If you see this comment in Xcode, you opened the correct target root.

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseCrashlytics

@main
struct QuestModeApp: App {
    init() {
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        if let uid = Auth.auth().currentUser?.uid {
            Crashlytics.crashlytics().setUserID(uid)
        }
    }
    
    // 2. These MUST be here for the buttons and colors to work
    @StateObject var viewModel = QuestViewModel()
    @StateObject var theme = ThemeManager.shared
    
    /// Login & email verification stay dark + Sapphire accents. After sign-in, System/Light/Dark applies (including onboarding).
    private var usesFixedDarkAuthChrome: Bool {
        viewModel.currentUser == nil || viewModel.needsEmailVerification
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if viewModel.currentUser == nil {
                    LoginView()
                        .id(viewModel.authSessionID)
                        .transition(.opacity)
                } else if viewModel.needsEmailVerification {
                    EmailVerificationGateView()
                        .transition(.opacity)
                } else if !viewModel.hasCompletedOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    MainTabView()
                        .transition(.opacity)
                }
            }
            .environmentObject(viewModel)
            .environmentObject(theme)
            .preferredColorScheme(usesFixedDarkAuthChrome ? .dark : viewModel.appearance.colorScheme)
            .animation(.easeInOut, value: viewModel.currentUser)
            .animation(.easeInOut, value: viewModel.needsEmailVerification)
            .animation(.easeInOut, value: viewModel.hasCompletedOnboarding)
            .animation(.easeInOut, value: viewModel.appearance)
        }
    }
}
