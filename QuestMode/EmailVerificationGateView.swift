import SwiftUI
import Combine
import FirebaseAuth

/// Full-screen gate: user must verify email before onboarding or home. Dark UI + Sapphire accents (same as login).
struct EmailVerificationGateView: View {
    @EnvironmentObject var viewModel: QuestViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var isChecking = false
    @State private var isSending = false
    @State private var statusMessage: String?
    @State private var didAutoSend = false

    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private var email: String {
        Auth.auth().currentUser?.email ?? "your email"
    }

    var body: some View {
        ZStack {
            AppTheme.AuthFlow.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.AuthFlow.accent.opacity(0.18))
                                .frame(width: 96, height: 96)
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(AppTheme.AuthFlow.accent)
                        }

                        Text("Verify your email")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppTheme.AuthFlow.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("We sent a secure link to unlock your account. Tap the link in that email, then return here. Check Junk/Spam if you don’t see it (common on Hotmail/Outlook).")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.AuthFlow.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sent to")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.AuthFlow.textSecondary)
                        Text(email)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.AuthFlow.textPrimary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AppTheme.AuthFlow.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(AppTheme.AuthFlow.accent.opacity(0.35), lineWidth: 1)
                    )

                    if let statusMessage = statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.danger)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: { checkVerification(manual: true) }) {
                        HStack {
                            if isChecking {
                                SwiftUI.ProgressView()
                                    .tint(.white)
                            } else {
                                Text("I've verified — continue")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.AuthFlow.accentGradient)
                        )
                        .foregroundStyle(.white)
                    }
                    .disabled(isChecking)
                    .accessibilityLabel("Continue after verifying email")

                    Button {
                        resend(isAutomatic: false)
                    } label: {
                        Text(isSending ? "Sending…" : "Resend verification email")
                            .fontWeight(.semibold)
                    }
                    .disabled(isSending)
                    .foregroundStyle(AppTheme.AuthFlow.accent)

                    Button(role: .destructive) {
                        viewModel.signOut()
                    } label: {
                        Text("Sign out")
                            .fontWeight(.medium)
                    }
                    .padding(.top, 8)
                    .foregroundStyle(AppTheme.AuthFlow.textSecondary)

                    #if DEBUG
                    Button {
                        viewModel.debugSkipEmailVerificationGate()
                    } label: {
                        Text("Skip verification (DEBUG only)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.top, 16)
                    .foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.85))
                    #endif
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onReceive(timer) { _ in
            checkVerification(manual: false)
        }
        .onAppear {
            checkVerification(manual: false)
            // Sign-in of an unverified account used to show this gate with no new email.
            if !didAutoSend {
                didAutoSend = true
                resend(isAutomatic: true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                checkVerification(manual: false)
            }
        }
    }

    private func resend(isAutomatic: Bool = false) {
        guard !isSending else { return }
        isSending = true
        QuestModeAuthEmail.sendVerification { error in
            DispatchQueue.main.async {
                isSending = false
                if let error {
                    statusMessage = isAutomatic
                        ? "Couldn’t send yet — tap Resend verification email. Also check Junk/Spam."
                        : error.localizedDescription
                } else {
                    statusMessage = nil
                }
            }
        }
    }

    private func checkVerification(manual: Bool) {
        guard Auth.auth().currentUser != nil else { return }
        if manual { isChecking = true }
        viewModel.refreshAuthUser {
            isChecking = false
            let verified = viewModel.isCurrentUserEmailVerified
            if manual && !verified {
                statusMessage = "Not verified yet — tap the link in your inbox (check Junk/Spam)."
            } else if verified {
                statusMessage = nil
            }
        }
    }
}
