import SwiftUI
import Combine
import FirebaseAuth

/// Full-screen wait after signup — quiet loader that unlocks the moment email is verified.
struct EmailVerificationGateView: View {
    @EnvironmentObject var viewModel: QuestViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isSending = false
    @State private var statusMessage: String?
    @State private var appear = false
    @State private var justResent = false
    @State private var didAttemptInitialSend = false
    @State private var resendCooldownEndsAt: Date?
    @State private var cooldownTick = Date()
    @State private var celebrating = false
    @State private var celebrationPhase = 0
    @State private var sealScale: CGFloat = 0.4
    @State private var sealOpacity: Double = 0
    @State private var ringExpand: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var headlineOpacity: Double = 0
    @State private var sparkle = false

    private let poll = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    private let cooldownClock = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private let resendCooldownSeconds: TimeInterval = 75
    private let minSecondsBetweenSends: TimeInterval = 70

    private var email: String {
        Auth.auth().currentUser?.email ?? "your email"
    }

    private var uid: String {
        Auth.auth().currentUser?.uid ?? "anon"
    }

    private var resendCooldownRemaining: Int {
        guard let ends = resendCooldownEndsAt else { return 0 }
        return max(0, Int(ceil(ends.timeIntervalSince(cooldownTick))))
    }

    private var canResend: Bool {
        !isSending && !celebrating && resendCooldownRemaining == 0
    }

    var body: some View {
        ZStack {
            QuestModeBackground(authFlow: true)
                .ignoresSafeArea()

            if celebrating {
                verifiedCelebration
                    .transition(.opacity)
            } else {
                waitingContent
                    .transition(.opacity)
            }
        }
        .animation(QuestMotion.content, value: celebrating)
        .onAppear {
            withAnimation(QuestMotion.appear) { appear = true }
            pollVerification()
            // Do not auto-resend here — Firebase rate-limits “unusual activity” when the gate
            // re-sends on every appear. Signup already triggers one send from LoginView.
            if !didAttemptInitialSend {
                didAttemptInitialSend = true
                startCooldownFromLastSend()
            }
        }
        .onReceive(poll) { _ in
            guard !celebrating else { return }
            pollVerification()
        }
        .onReceive(cooldownClock) { now in
            cooldownTick = now
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !celebrating {
                pollVerification()
            }
        }
    }

    private var waitingContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)

            QuestLoader(
                size: 78,
                label: justResent
                    ? "Email sent — waiting for the link…"
                    : "Waiting for you to verify…"
            )
            .padding(.bottom, 32)
            .opacity(appear ? 1 : 0)

            VStack(spacing: 12) {
                Text("Check your inbox")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.AuthFlow.textPrimary)

                Text(email)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(QuestChrome.softWhite.opacity(0.85))
                    .textSelection(.enabled)

                Text("Open the verification link from Quest Mode. We’ll bring you in the moment it’s done — check Junk/Spam if it’s not there.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.AuthFlow.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 28)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 10)

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.AuthFlow.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
                    .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 14) {
                Button {
                    resend(isAutomatic: false)
                } label: {
                    Group {
                        if isSending {
                            Text("Sending…")
                        } else if resendCooldownRemaining > 0 {
                            Text("Resend in \(resendCooldownRemaining)s")
                        } else {
                            Text(justResent ? "Send again" : "Resend email")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        canResend
                            ? QuestChrome.softWhite.opacity(0.75)
                            : QuestChrome.softWhite.opacity(0.35)
                    )
                }
                .disabled(!canResend)
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    viewModel.signOut()
                } label: {
                    Text("Sign out")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.AuthFlow.textSecondary.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 40)
        }
    }

    private var verifiedCelebration: some View {
        ZStack {
            // Soft brand wash
            RadialGradient(
                colors: [
                    Color(red: 0.35, green: 0.75, blue: 0.55).opacity(0.35),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            .opacity(headlineOpacity)

            // Expanding rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        QuestChrome.softWhite.opacity(0.22 - Double(i) * 0.05),
                        lineWidth: 1.5
                    )
                    .frame(width: 120 + CGFloat(i) * 56, height: 120 + CGFloat(i) * 56)
                    .scaleEffect(ringExpand + CGFloat(i) * 0.08)
                    .opacity(ringOpacity * (1 - Double(i) * 0.25))
            }

            // Spark dots
            if sparkle && !reduceMotion {
                ForEach(0..<12, id: \.self) { i in
                    Circle()
                        .fill(QuestChrome.softWhite.opacity(0.85))
                        .frame(width: 5, height: 5)
                        .offset(
                            x: cos(CGFloat(i) / 12 * 2 * .pi) * (70 + CGFloat(celebrationPhase) * 18),
                            y: sin(CGFloat(i) / 12 * 2 * .pi) * (70 + CGFloat(celebrationPhase) * 18)
                        )
                        .opacity(max(0, 1 - Double(celebrationPhase) * 0.35))
                }
            }

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.92, blue: 0.62),
                                    Color(red: 0.25, green: 0.72, blue: 0.55)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .shadow(color: Color(red: 0.3, green: 0.85, blue: 0.55).opacity(0.55), radius: 24, y: 8)

                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(QuestChrome.onSoft)
                }
                .scaleEffect(sealScale)
                .opacity(sealOpacity)

                Text("You’re in")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(QuestChrome.softWhite)
                    .opacity(headlineOpacity)

                Text("Email verified")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(QuestChrome.softWhite.opacity(0.65))
                    .opacity(headlineOpacity)
            }
        }
    }

    // MARK: - Send / cooldown

    private func lastSendKey() -> String { "questmode_verify_email_last_send_\(uid)" }

    private func shouldAttemptSend() -> Bool {
        let last = UserDefaults.standard.double(forKey: lastSendKey())
        guard last > 0 else { return true }
        return Date().timeIntervalSince1970 - last >= minSecondsBetweenSends
    }

    private func markSendAttempt() {
        let now = Date()
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastSendKey())
        resendCooldownEndsAt = now.addingTimeInterval(resendCooldownSeconds)
        cooldownTick = now
    }

    private func startCooldownFromLastSend() {
        let last = UserDefaults.standard.double(forKey: lastSendKey())
        guard last > 0 else { return }
        let elapsed = Date().timeIntervalSince1970 - last
        let remaining = minSecondsBetweenSends - elapsed
        if remaining > 0 {
            resendCooldownEndsAt = Date().addingTimeInterval(remaining)
            cooldownTick = Date()
        }
    }

    private func resend(isAutomatic: Bool) {
        guard !isSending, !celebrating else { return }
        if !isAutomatic && !canResend { return }
        if !shouldAttemptSend() {
            startCooldownFromLastSend()
            if !isAutomatic {
                statusMessage = "Hang tight — we just sent one. Check Junk/Spam, or wait a minute to resend."
            }
            return
        }

        isSending = true
        markSendAttempt()
        QuestModeAuthEmail.sendVerification { error in
            DispatchQueue.main.async {
                isSending = false
                if let error {
                    statusMessage = Self.friendlySendError(error, isAutomatic: isAutomatic)
                    justResent = false
                } else {
                    statusMessage = isAutomatic
                        ? nil
                        : "Sent — check inbox and Junk/Spam."
                    withAnimation(QuestMotion.content) { justResent = true }
                    if !isAutomatic {
                        HapticsManager.shared.success()
                    }
                }
            }
        }
    }

    private static func friendlySendError(_ error: Error, isAutomatic: Bool) -> String {
        let ns = error as NSError
        let text = (ns.localizedDescription + " " + (ns.userInfo["FIRAuthErrorUserInfoNameKey"] as? String ?? ""))
            .lowercased()
        if text.contains("unusual") || text.contains("blocked") || text.contains("too many")
            || text.contains("try again later") || ns.code == 17010 {
            return "Email sending was paused for a bit (too many tries). Wait a few minutes and check Junk/Spam for an earlier message."
        }
        if isAutomatic {
            return "Couldn’t send yet — wait for Resend, or check Junk/Spam."
        }
        return ns.localizedDescription
    }

    // MARK: - Poll → celebrate → enter app

    private func pollVerification() {
        guard Auth.auth().currentUser != nil, !celebrating else { return }
        Auth.auth().currentUser?.reload { _ in
            DispatchQueue.main.async {
                guard Auth.auth().currentUser?.isEmailVerified == true else { return }
                beginVerifiedCelebration()
            }
        }
    }

    private func beginVerifiedCelebration() {
        guard !celebrating else { return }
        celebrating = true
        statusMessage = nil
        HapticsManager.shared.notifySuccess()

        if reduceMotion {
            sealScale = 1
            sealOpacity = 1
            headlineOpacity = 1
            ringOpacity = 0.5
            ringExpand = 1
            finishCelebrationAndEnter()
            return
        }

        withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
            sealScale = 1
            sealOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.55)) {
            ringExpand = 1.35
            ringOpacity = 1
            headlineOpacity = 1
        }
        sparkle = true
        withAnimation(.easeOut(duration: 0.9)) {
            celebrationPhase = 3
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
            finishCelebrationAndEnter()
        }
    }

    private func finishCelebrationAndEnter() {
        // Release the gate so ContentView / App root advances.
        viewModel.currentUser = Auth.auth().currentUser
        viewModel.isCurrentUserEmailVerified = true
        viewModel.noteAuthStateChanged()
    }
}
