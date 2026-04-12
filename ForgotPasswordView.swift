import SwiftUI
import FirebaseAuth

/// Collects the account email and sends Firebase password-reset mail.
struct ForgotPasswordView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var email: String
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertIsSuccess = false

    init(initialEmail: String = "") {
        _email = State(initialValue: initialEmail)
    }

    private var isWideLayout: Bool {
        horizontalSizeClass == .regular
    }

    private var horizontalPadding: CGFloat {
        isWideLayout ? 32 : 20
    }

    private var contentScale: CGFloat {
        isWideLayout ? 0.98 : 0.86
    }

    var body: some View {
        ZStack {
            QuestModeBackground(authFlow: true).ignoresSafeArea()

            GeometryReader { geo in
                let W = geo.size.width
                let columnMax = isWideLayout ? min(520, W) : W

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow
                            .padding(.top, 8)
                            .padding(.bottom, 22)

                        Text("Enter the email address associated with your Quest Mode account. We’ll send recovery instructions there.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.AuthFlow.textSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 20)

                        emailCard

                        sendButton
                            .padding(.top, 20)

                        Text("If you don’t see the message, check spam or try again in a few minutes.")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.88))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 14)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .frame(minWidth: 0, maxWidth: columnMax)
                    .frame(maxWidth: W, alignment: .center)
                    .scaleEffect(contentScale, anchor: .top)
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
                    QuestAlert(
                        title: alertIsSuccess ? "Email sent" : "Notice",
                        message: alertMessage,
                        maxWidth: min(340, geo.size.width - 32),
                        iconName: alertIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    ) {
                        withAnimation { showAlert = false }
                        if alertIsSuccess {
                            dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.AuthFlow.accent)
            }
            .buttonStyle(.plain)

            Text("Forgot password")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.AuthFlow.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emailCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Account email")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.AuthFlow.textPrimary)

                Text("Use the same address you signed up with.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.95))
            }

            labeledEmailField
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

    private var labeledEmailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.AuthFlow.textSecondary)

            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.AuthFlow.accent.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: "envelope.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.AuthFlow.accent)
                }

                TextField("", text: $email, prompt: Text("you@example.com").foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.55)))
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(AppTheme.AuthFlow.textPrimary)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
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

    private var sendButton: some View {
        Button(action: sendRecoveryEmail) {
            HStack(spacing: 10) {
                if isProcessing {
                    SwiftUI.ProgressView()
                        .tint(.white)
                        .scaleEffect(1.05)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.body.weight(.semibold))
                    Text("Send recovery email")
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
            )
            .foregroundStyle(.white)
            .shadow(color: AppTheme.AuthFlow.accent.opacity(0.42), radius: 16, y: 7)
        }
        .buttonStyle(ForgotPasswordPrimaryButtonStyle())
        .disabled(trimmedEmail.isEmpty || isProcessing)
        .opacity(trimmedEmail.isEmpty || isProcessing ? 0.5 : 1)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendRecoveryEmail() {
        let addr = trimmedEmail
        guard !addr.isEmpty else {
            alertIsSuccess = false
            alertMessage = "Enter the email address for your account."
            withAnimation { showAlert = true }
            return
        }

        isProcessing = true
        Auth.auth().sendPasswordReset(withEmail: addr) { error in
            DispatchQueue.main.async {
                isProcessing = false
                if let error = error as NSError? {
                    alertIsSuccess = false
                    alertMessage = forgotPasswordErrorMessage(error)
                    withAnimation { showAlert = true }
                } else {
                    alertIsSuccess = true
                    alertMessage = "If that email is registered, you’ll receive a link to reset your password shortly."
                    withAnimation { showAlert = true }
                }
            }
        }
    }

    private func forgotPasswordErrorMessage(_ error: NSError) -> String {
        if let code = AuthErrorCode(rawValue: error.code) {
            switch code {
            case .invalidEmail:
                return "That email address doesn’t look valid."
            case .userNotFound:
                return "No account found for that email. Double-check the address or sign up."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}

private struct ForgotPasswordPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ForgotPasswordView(initialEmail: "")
        }
        .environmentObject(ThemeManager.shared)
    }
}
