import SwiftUI
import UIKit

struct QuestCompletionSheet: View {
    @ObservedObject var viewModel: QuestViewModel
    let quest: Quest
    let onSubmitted: (Quest) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var theme: ThemeManager
    
    @State private var reflectionText: String = ""
    @State private var showSuccessCard = false
    @State private var isSubmitting = false
    @State private var inputImage: UIImage?
    @State private var showCamera = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background(for: colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        questInfoCard
                        proofTypeCard
                        reflectionSection
                        
                        if proofType == .photo {
                            photoProofSection
                        }
                        
                        submitButton
                    }
                    .padding()
                    .blur(radius: showSuccessCard ? 6 : 0)
                    .disabled(showSuccessCard)
                }
                
                if showSuccessCard {
                    Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    QuestSuccessCard(
                        xpEarned: quest.xp,
                        streak: viewModel.streak
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSuccessCard)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Complete this quest")
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                .multilineTextAlignment(.center)

            Text(quest.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                .multilineTextAlignment(.center)

            Text("Answer the prompts below, then tap Submit at the bottom.")
                .font(.body)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var questInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(categoryDisplayName)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.accent.opacity(0.14))
                    .foregroundStyle(theme.accent)
                    .clipShape(Capsule())
                
                Spacer()
                
                Label("\(quest.xp) XP", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
            }
            
            Text(promptTitle)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
            
            Text(promptSubtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .questCardStyle()
    }
    
    private var proofTypeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proof Type")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
            
            HStack(spacing: 12) {
                Image(systemName: proofTypeIcon)
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(theme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(proofTypeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                    
                    Text(proofTypeDescription)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .questCardStyle()
    }
    
    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(inputLabel)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
            
            ZStack(alignment: .topLeading) {
                if reflectionText.isEmpty {
                    Text(textPlaceholder)
                        .foregroundStyle(AppTheme.textSecondary(for: colorScheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                }
                
                TextEditor(text: $reflectionText)
                    .frame(height: 150)
                    .padding(8)
                    .background(AppTheme.card(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(AppTheme.textPrimary(for: colorScheme))
                    .scrollContentBackground(.hidden)
            }
        }
    }
    
    private var photoProofSection: some View {
        VStack(spacing: 12) {
            if let image = inputImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.accent.opacity(0.5), lineWidth: 2)
                    )
                
                Button("Retake Photo") {
                    showCamera = true
                }
                .font(.caption)
                .foregroundStyle(theme.accent)
            } else {
                Button {
                    showCamera = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 40))
                        Text("Capture Photo Proof")
                            .fontWeight(.bold)
                        Text(proofPlaceholderText)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .background(theme.accent.opacity(0.1))
                    .foregroundStyle(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showCamera) {
            ImagePicker(image: $inputImage)
        }
    }
    
    private var submitButton: some View {
        Button(action: submitQuest) {
            HStack {
                if isSubmitting {
                    SwiftUI.ProgressView()
                        .tint(.white)
                } else {
                    Text(submitButtonTitle)
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        canSubmit && !isSubmitting
                        ? AnyShapeStyle(theme.vividAccentGradient)
                        : AnyShapeStyle(AppTheme.cardSecondary(for: colorScheme))
                    )
            )
            .foregroundStyle(.white)
        }
        .disabled(!canSubmit || isSubmitting)
    }
    
    private func submitQuest() {
        guard canSubmit, !isSubmitting else { return }
        
        isSubmitting = true
        
        let cleanedReflection = reflectionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageData = inputImage?.jpegData(compressionQuality: 0.7)
        viewModel.completeQuest(quest, reflection: cleanedReflection, imageData: imageData)
        onSubmitted(quest)
        
        HapticsManager.shared.notifySuccess()
        
        withAnimation {
            showSuccessCard = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            dismiss()
        }
    }
    
    private var categoryDisplayName: String {
        quest.category
    }
    
    private var resolvedCategory: QuestCategory? {
        QuestCategory(rawValue: quest.category)
    }
    
    private var proofType: ProofType {
        resolvedCategory?.proofType ?? .reflection
    }
    
    private var canSubmit: Bool {
        let hasText = !reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if proofType == .photo {
            return hasText && inputImage != nil
        }
        return hasText
    }
    
    private var promptTitle: String {
        switch resolvedCategory {
        case .social: return "Tell us about the interaction"
        case .mindfulness: return "Reflect on what you noticed"
        case .productivity: return "Capture what you finished"
        case .confidence: return "Describe the stretch moment"
        case .adventure: return "Tell us about where you went"
        case .health: return "Record what you did"
        case .creativity: return "Describe what you created"
        case nil: return "Reflect on the quest"
        }
    }
    
    private var promptSubtitle: String {
        switch resolvedCategory {
        case .social: return "A short honest reflection makes it real."
        case .mindfulness: return "A few words about what you noticed."
        case .productivity: return "Write what task you moved forward."
        case .confidence: return "How did you handle the stretch?"
        case .adventure: return "What did you notice outside?"
        case .health: return "Briefly log your healthy action."
        case .creativity: return "What did you capture or create?"
        case nil: return "Add a quick reflection."
        }
    }
    
    private var inputLabel: String {
        switch resolvedCategory {
        case .social: return "What did you say?"
        case .mindfulness: return "What did you notice?"
        case .productivity: return "What did you finish?"
        case .confidence: return "How did it go?"
        case .adventure: return "Where did you go?"
        case .health: return "What did you do?"
        case .creativity: return "What did you make?"
        case nil: return "How did it go?"
        }
    }
    
    private var textPlaceholder: String {
        "Write a quick reflection..."
    }
    
    private var submitButtonTitle: String {
        proofType == .photo ? "Verify and Submit" : "Submit Quest"
    }
    
    private var proofTypeIcon: String {
        switch proofType {
        case .photo: return "camera.fill"
        case .reflection: return "text.bubble.fill"
        case .selfCheck: return "checkmark.seal.fill"
        }
    }
    
    private var proofTypeTitle: String {
        switch proofType {
        case .photo: return "Photo Ready"
        case .reflection: return "Reflection"
        case .selfCheck: return "Self Check In"
        }
    }
    
    private var proofTypeDescription: String {
        switch proofType {
        case .photo: return "Capture photo proof for your quest."
        case .reflection: return "Completed through a short written reflection."
        case .selfCheck: return "Personal completion check in."
        }
    }
    
    private var proofPlaceholderText: String {
        switch resolvedCategory {
        case .adventure: return "Attach a photo of your exploration."
        case .health: return "Attach wellness or activity proof."
        case .creativity: return "Attach your creative output."
        default: return "Attach your proof."
        }
    }
}
