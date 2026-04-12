import SwiftUI

struct DeleteAccountSheet: View {
    @ObservedObject var viewModel: QuestViewModel
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var password: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 20) {
                    Text("This permanently deletes your account and cloud progress. You’ll need your password to confirm.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(AppTheme.card(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(theme.accent.opacity(0.25), lineWidth: 1)
                        )

                    if viewModel.isProcessing {
                        HStack(spacing: 10) {
                            SwiftUI.ProgressView()
                                .tint(theme.accent)
                            Text("Deleting…")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                        }
                    }

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(AppTheme.danger)
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isProcessing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete") {
                        errorMessage = nil
                        viewModel.deleteAccount(password: password) { err in
                            if let err = err {
                                errorMessage = err
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .disabled(password.isEmpty || viewModel.isProcessing)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
