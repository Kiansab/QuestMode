import SwiftUI
import Combine
import FirebaseAuth
import UIKit

struct LoginView: View {

    @EnvironmentObject var viewModel: QuestViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var focusedField: AuthField?

    @State private var isSignUpMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isProcessing = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showForgotPassword = false

    private enum AuthField: Hashable {
        case firstName, lastName, email, password
    }

    private var isWide: Bool { horizontalSizeClass == .regular }
    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
            && !isProcessing
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QuestModeBackground(authFlow: true)
                    .ignoresSafeArea()

                GeometryReader { geo in
                    let sidePad: CGFloat = isWide ? 48 : 32
                    let column = min(isWide ? 400 : geo.size.width - sidePad * 2, geo.size.width - sidePad * 2)

                    VStack(spacing: 0) {
                        Spacer(minLength: isSignUpMode ? 28 : 48)

                        titleBlock

                        Spacer(minLength: isSignUpMode ? 28 : 40)

                        formBlock
                            .frame(width: column)

                        Spacer(minLength: 20)

                        footerLegal
                            .frame(width: column)
                            .padding(.bottom, max(20, geo.safeAreaInsets.bottom + 8))
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .animation(QuestMotion.content, value: isSignUpMode)
                    .blur(radius: showAlert ? 4 : 0)
                    .disabled(showAlert)
                }

                if showAlert {
                    Color.black.opacity(0.58)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { showAlert = false } }

                    QuestAlert(message: alertMessage) {
                        withAnimation(.easeOut(duration: 0.2)) { showAlert = false }
                    }
                    .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showForgotPassword) {
                ForgotPasswordView(initialEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .onAppear { isProcessing = false }
            .onTapGesture { focusedField = nil }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Title (no icon)

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text("Quest Mode")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.AuthFlow.textPrimary)
                .tracking(-0.5)

            Text("Daily quests for your real goals.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.AuthFlow.textSecondary)
                .multilineTextAlignment(.center)

            Text(isSignUpMode ? "Create your account" : "Welcome back")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.8))
                .padding(.top, 4)
                .animation(.easeOut(duration: 0.2), value: isSignUpMode)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - Form

    private var formBlock: some View {
        VStack(spacing: 0) {
            modeSwitcher
                .padding(.bottom, 28)

            VStack(spacing: 14) {
                if isSignUpMode {
                    authField(
                        placeholder: "First name",
                        text: $firstName,
                        field: .firstName,
                        contentType: .givenName,
                        capitalization: .words,
                        submit: .next
                    ) { focusedField = .lastName }

                    authField(
                        placeholder: "Last name",
                        text: $lastName,
                        field: .lastName,
                        contentType: .familyName,
                        capitalization: .words,
                        submit: .next
                    ) { focusedField = .email }
                }

                authField(
                    placeholder: "Email",
                    text: $email,
                    field: .email,
                    contentType: isSignUpMode ? .emailAddress : .username,
                    keyboard: .emailAddress,
                    submit: .next
                ) { focusedField = .password }

                passwordField
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.9), value: isSignUpMode)

            if !isSignUpMode {
                Button { showForgotPassword = true } label: {
                    Text("Forgot password?")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.AuthFlow.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 14)
                .transition(.opacity)
            }

            primaryCTA
                .padding(.top, isSignUpMode ? 28 : 24)

            if !isSignUpMode {
                Button {
                    trySampleDay()
                } label: {
                    Text("Try a sample day without an account")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.AuthFlow.accent)
                }
                .padding(.top, 16)
                .disabled(isProcessing)
            }

            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                    isSignUpMode.toggle()
                }
            } label: {
                Text(isSignUpMode ? "Already have an account? Sign in" : "New here? Create an account")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.AuthFlow.textSecondary)
            }
            .padding(.top, 20)
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            modeChip("Sign in", selected: !isSignUpMode) {
                withAnimation(QuestMotion.content) {
                    isSignUpMode = false
                }
            }
            modeChip("Sign up", selected: isSignUpMode) {
                withAnimation(QuestMotion.content) { isSignUpMode = true }
            }
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func modeChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(selected ? QuestChrome.onSoft : AppTheme.AuthFlow.textSecondary)
                .background {
                    if selected {
                        Capsule(style: .continuous)
                            .fill(QuestChrome.softWhite)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var primaryCTA: some View {
        Button(action: handleAuth) {
            ZStack {
                if isProcessing {
                    QuestLoader(size: 26, compact: true)
                } else {
                    Text(isSignUpMode ? "Create account" : "Sign in")
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Capsule(style: .continuous)
                    .fill(canSubmit ? QuestChrome.softWhite : QuestChrome.softWhite.opacity(0.22))
            )
            .foregroundStyle(canSubmit ? QuestChrome.onSoft : QuestChrome.onSoft.opacity(0.4))
        }
        .buttonStyle(AuthPrimaryButtonStyle())
        .questPressable()
        .disabled(!canSubmit)
    }

    private var footerLegal: some View {
        Text("By continuing you agree to Terms & Privacy.")
            .font(.caption2)
            .foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.55))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Fields (full-width, stacked — no side-by-side squeeze)

    private func authField(
        placeholder: String,
        text: Binding<String>,
        field: AuthField,
        contentType: UITextContentType? = nil,
        keyboard: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .never,
        submit: SubmitLabel = .next,
        onSubmit: (() -> Void)? = nil
    ) -> some View {
        let focused = focusedField == field
        return TextField("", text: text, prompt: Text(placeholder).foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.45)))
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(AppTheme.AuthFlow.textPrimary)
            .keyboardType(keyboard)
            .textInputAutocapitalization(capitalization)
            .submitLabel(submit)
            .optionalTextContentType(contentType)
            .optionalOnSubmit(onSubmit)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(focused ? 0.09 : 0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focused ? AppTheme.AuthFlow.accent.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: focused)
    }

    private var passwordField: some View {
        let focused = focusedField == .password
        return SecureField("", text: $password, prompt: Text("Password").foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.45)))
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(AppTheme.AuthFlow.textPrimary)
            .textContentType(isSignUpMode ? .newPassword : .password)
            .submitLabel(.go)
            .onSubmit { handleAuth() }
            .focused($focusedField, equals: .password)
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(focused ? 0.09 : 0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focused ? AppTheme.AuthFlow.accent.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: focused)
    }

    // MARK: - Auth

    private func trySampleDay() {
        isProcessing = true
        Auth.auth().signInAnonymously { result, error in
            DispatchQueue.main.async {
                self.isProcessing = false
                if let error = error as NSError? {
                    self.handleFirebaseError(error)
                    return
                }
                guard let user = result?.user else { return }
                HapticsManager.shared.notifySuccess()
                self.viewModel.resetOnboardingForNewAccount(uid: user.uid)
            }
        }
    }

    private func handleAuth() {
        isProcessing = true
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            isProcessing = false
            return
        }

        if isSignUpMode {
            Auth.auth().createUser(withEmail: trimmedEmail, password: password) { result, error in
                if let user = result?.user {
                    self.viewModel.resetOnboardingForNewAccount(uid: user.uid)
                }
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if let error = error as NSError? {
                        self.handleFirebaseError(error)
                    } else if let user = result?.user {
                        HapticsManager.shared.notifySuccess()
                        let name = "\(self.firstName) \(self.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            let change = user.createProfileChangeRequest()
                            change.displayName = name
                            change.commitChanges(completion: nil)
                        }
                        // One verification send at signup (gate only polls — avoids Firebase rate limits).
                        QuestModeAuthEmail.sendVerification { _ in
                            let key = "questmode_verify_email_last_send_\(user.uid)"
                            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
                        }
                    }
                }
            }
        } else {
            Auth.auth().signIn(withEmail: trimmedEmail, password: password) { _, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if let error = error as NSError? {
                        self.handleFirebaseError(error)
                    } else {
                        HapticsManager.shared.notifySuccess()
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
            case .weakPassword: alertMessage = "Choose a stronger password (at least 6 characters)."
            default: alertMessage = error.localizedDescription
            }
        } else {
            alertMessage = error.localizedDescription
        }
        withAnimation { showAlert = true }
    }
}

private extension View {
    @ViewBuilder
    func optionalTextContentType(_ type: UITextContentType?) -> some View {
        if let type { self.textContentType(type) } else { self }
    }

    @ViewBuilder
    func optionalOnSubmit(_ action: (() -> Void)?) -> some View {
        if let action { self.onSubmit(action) } else { self }
    }
}

private struct AuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct QuestAlert: View {
    var title: String = "Notice"
    let message: String
    var maxWidth: CGFloat = 320
    var iconName: String = "exclamationmark.triangle.fill"
    var action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.AuthFlow.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.AuthFlow.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text("OK")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(AppTheme.AuthFlow.accent))
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(AuthPrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: maxWidth)
        .background(AppTheme.AuthFlow.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(QuestViewModel())
    }
}
