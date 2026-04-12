import SwiftUI
import Combine
import FirebaseAuth

struct LoginView: View {

    @EnvironmentObject var viewModel: QuestViewModel
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isSignUpMode: Bool = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""

    @State private var isProcessing: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var headerGlow = false
    @State private var showForgotPassword = false

    private var isWideLayout: Bool {
        horizontalSizeClass == .regular
    }

    /// Slightly “zooms out” the auth form so shadows/fields clear the screen edges on narrow phones.
    private var loginContentScale: CGFloat {
        isWideLayout ? 0.98 : 0.86
    }

    var body: some View {
        NavigationStack {
            loginContent
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showForgotPassword) {
                    ForgotPasswordView(initialEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
                }
        }
    }

    private var loginContent: some View {
        ZStack {
            QuestModeBackground(authFlow: true).ignoresSafeArea()

            // Pin scroll width to the container so nothing can lay out wider than the screen (blur/shadows included).
            GeometryReader { geo in
                let W = geo.size.width
                let columnMax = isWideLayout ? min(520, W) : W

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerBlock
                            .padding(.top, 8)
                            .padding(.bottom, 22)

                        authModePicker
                            .padding(.bottom, 20)

                        formCard

                        if !isSignUpMode {
                            Button(action: { showForgotPassword = true }) {
                                Text("Forgot password?")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.AuthFlow.accent)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 12)
                        }

                        primaryButton
                            .padding(.top, 20)

                        Text("By continuing you agree to responsible use of Quest Mode.")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 14)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .frame(minWidth: 0, maxWidth: columnMax)
                    .frame(maxWidth: W, alignment: .center)
                    .scaleEffect(loginContentScale, anchor: .top)
                }
                .frame(width: W, height: geo.size.height, alignment: .top)
                .scrollDismissesKeyboard(.interactively)
                .blur(radius: showAlert ? 5 : 0)
                .disabled(showAlert)
            }
            .clipped()

            if showAlert {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showAlert = false }
                    }

                GeometryReader { geo in
                    QuestAlert(message: alertMessage, maxWidth: min(340, geo.size.width - 32)) {
                        withAnimation { showAlert = false }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear {
            isProcessing = false
            email = ""
            password = ""
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                headerGlow = true
            }
        }
    }

    /// Keeps content inset on phones; centers a max-width column on iPad.
    private var horizontalPadding: CGFloat {
        isWideLayout ? 32 : 20
    }

    private var headerBlock: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppTheme.AuthFlow.accent.opacity(0.55),
                                AppTheme.AuthFlow.accent.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 118, height: 118)
                    .scaleEffect(headerGlow ? 1.03 : 1.0)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.AuthFlow.accent.opacity(0.42),
                                AppTheme.AuthFlow.accent.opacity(0.08),
                                AppTheme.AuthFlow.card.opacity(0.5)
                            ],
                            center: .init(x: 0.35, y: 0.3),
                            startRadius: 4,
                            endRadius: 56
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 0.5)

                ZStack {
                    Image(systemName: "map.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.AuthFlow.accent, AppTheme.AuthFlow.accent.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: AppTheme.AuthFlow.accent.opacity(0.45), radius: 10, y: 3)

                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .offset(x: 28, y: -26)
                        .shadow(color: AppTheme.AuthFlow.accent.opacity(0.6), radius: 4)
                }
            }

            VStack(spacing: 10) {
                Text("Quest Mode")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.AuthFlow.textPrimary, AppTheme.AuthFlow.textPrimary.opacity(0.88)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: AppTheme.AuthFlow.accent.opacity(0.22), radius: 16, y: 2)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)

                Text("Daily quests, streaks, and levels—your real life as the game.")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .lineLimit(4)
                    .minimumScaleFactor(0.88)
                    .foregroundStyle(AppTheme.AuthFlow.textSecondary)
                    .padding(.horizontal, 8)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.AuthFlow.accent.opacity(0.55),
                                AppTheme.AuthFlow.accent.opacity(0.15)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .frame(maxWidth: 100)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var authModePicker: some View {
        HStack(spacing: 0) {
            modeButton(title: "Sign in", selected: !isSignUpMode) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                    isSignUpMode = false
                }
            }
            modeButton(title: "Sign up", selected: isSignUpMode) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                    isSignUpMode = true
                }
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.AuthFlow.cardSecondary.opacity(0.92))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppTheme.AuthFlow.accent.opacity(0.35),
                            AppTheme.AuthFlow.accent.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 12, y: 5)
    }

    private func modeButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? AnyShapeStyle(AppTheme.AuthFlow.accentGradient) : AnyShapeStyle(Color.clear))
                )
                .foregroundStyle(selected ? Color.white : AppTheme.AuthFlow.textSecondary)
                .shadow(color: selected ? AppTheme.AuthFlow.accent.opacity(0.45) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isSignUpMode ? "Create your account" : "Welcome back")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.AuthFlow.textPrimary)

                Text(isSignUpMode ? "We’ll send a quick email to verify you." : "Sign in to pick up your streak.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.95))
            }

            VStack(spacing: 14) {
                if isSignUpMode {
                    Group {
                        if isWideLayout {
                            HStack(spacing: 12) {
                                labeledField("First name", systemImage: "person.fill", text: $firstName)
                                labeledField("Last name", systemImage: "person.fill", text: $lastName)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            VStack(spacing: 14) {
                                labeledField("First name", systemImage: "person.fill", text: $firstName)
                                labeledField("Last name", systemImage: "person.fill", text: $lastName)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                labeledField("Email", systemImage: "envelope.fill", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(isSignUpMode ? .emailAddress : .username)
                    .textInputAutocapitalization(.never)

                secureFieldBlock
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: isSignUpMode)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(AppTheme.AuthFlow.card)
                .shadow(color: Color.black.opacity(0.5), radius: 22, y: 10)
                .shadow(color: AppTheme.AuthFlow.accent.opacity(0.12), radius: 28, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppTheme.AuthFlow.accent.opacity(0.42),
                            AppTheme.AuthFlow.accent.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var primaryButton: some View {
        Button(action: handleAuth) {
            HStack(spacing: 10) {
                if isProcessing {
                    SwiftUI.ProgressView()
                        .tint(.white)
                        .scaleEffect(1.05)
                } else {
                    Image(systemName: isSignUpMode ? "sparkles" : "arrow.right.circle.fill")
                        .font(.body.weight(.semibold))
                    Text(isSignUpMode ? "Create account" : "Log in")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.AuthFlow.accentGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .allowsHitTesting(false)
                    )
            )
            .foregroundStyle(.white)
            .shadow(color: AppTheme.AuthFlow.accent.opacity(0.42), radius: 16, y: 7)
        }
        .buttonStyle(AuthPrimaryButtonStyle())
        .disabled(email.isEmpty || password.isEmpty || isProcessing)
        .opacity(email.isEmpty || password.isEmpty || isProcessing ? 0.5 : 1)
    }

    private func labeledField(_ label: String, systemImage: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.AuthFlow.textSecondary)

            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.AuthFlow.accent.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.AuthFlow.accent)
                }

                TextField("", text: text, prompt: Text(label).foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.55)))
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(AppTheme.AuthFlow.textPrimary)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(AppTheme.AuthFlow.cardSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppTheme.AuthFlow.accent.opacity(0.28),
                                AppTheme.AuthFlow.accent.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var secureFieldBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.AuthFlow.textSecondary)

            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.AuthFlow.accent.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: "lock.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.AuthFlow.accent)
                }

                SecureField("", text: $password, prompt: Text("Password").foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.55)))
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(AppTheme.AuthFlow.textPrimary)
                    .textContentType(isSignUpMode ? .newPassword : .password)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(AppTheme.AuthFlow.cardSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppTheme.AuthFlow.accent.opacity(0.28),
                                AppTheme.AuthFlow.accent.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleAuth() {
        isProcessing = true

        guard !email.isEmpty, !password.isEmpty else {
            isProcessing = false
            return
        }

        if isSignUpMode {
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let user = result?.user {
                    self.viewModel.resetOnboardingForNewAccount(uid: user.uid)
                }
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if let error = error as NSError? {
                        self.handleFirebaseError(error)
                    } else if let user = result?.user {
                        let name = "\(self.firstName) \(self.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            let change = user.createProfileChangeRequest()
                            change.displayName = name
                            change.commitChanges(completion: nil)
                        }
                        user.sendEmailVerification(completion: nil)
                    }
                }
            }
        } else {
            Auth.auth().signIn(withEmail: email, password: password) { _, error in
                DispatchQueue.main.async {
                    self.isProcessing = false

                    if let error = error as NSError? {
                        self.handleFirebaseError(error)
                    } else {
                        self.email = ""
                        self.password = ""
                    }
                }
            }
        }
    }

    private func handleFirebaseError(_ error: NSError) {
        if let errorCode = AuthErrorCode(rawValue: error.code) {
            switch errorCode {
            case .emailAlreadyInUse: alertMessage = "This email is already registered."
            case .invalidEmail: alertMessage = "That email address looks incorrect."
            case .wrongPassword, .userNotFound: alertMessage = "Invalid email or password."
            default: alertMessage = error.localizedDescription
            }
        } else {
            alertMessage = error.localizedDescription
        }
        withAnimation { showAlert = true }
    }
}

private struct AuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct QuestAlert: View {
    var title: String = "Notice"
    let message: String
    var maxWidth: CGFloat = 340
    var iconName: String = "exclamationmark.triangle.fill"
    var action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: iconName)
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.AuthFlow.accent)

            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.AuthFlow.textPrimary)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.AuthFlow.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text("OK")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.AuthFlow.accentGradient))
                    .foregroundStyle(.white)
            }
        }
        .padding(22)
        .frame(maxWidth: maxWidth)
        .background(AppTheme.AuthFlow.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.AuthFlow.cardBorder(accent: AppTheme.AuthFlow.accent), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 24, y: 12)
        .padding(.horizontal, 16)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(QuestViewModel())
            .environmentObject(ThemeManager.shared) // QuestModeBackground
    }
}
