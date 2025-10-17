//
//  LanguageSelectionView.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/21/25.
//

import SwiftUI
import Translation

/// View for selecting the target translation language
/// Displays a list of available languages and handles language downloads
struct LanguageSelectionView: View {
    
    // Dismisses the view when selection is complete
    @Environment(\.dismiss) private var dismiss
    
    // Access to the app's translation service
    @EnvironmentObject var translationService: TranslationService
    
    // The selected language binding passed from parent view
    @Binding var selectedLanguage: AvailableLanguage
    
    // Temporary storage for language selection before confirming
    @State private var tempSelectedLanguage: AvailableLanguage
    
    // MARK: - State Properties

    // Tracks if we're currently downloading language data
    @State private var isDownloading = false
    
    // Error state for download failures
    @State private var showDownloadError = false
    
    // Configuration for translation task
    @State private var downloadConfig: TranslationSession.Configuration? = nil
    
    /// Initialize with the currently selected language
    /// Sets up temp language for selection changes
    init(selectedLanguage: Binding<AvailableLanguage>) {
        self._selectedLanguage = selectedLanguage
        self._tempSelectedLanguage = State(initialValue: selectedLanguage.wrappedValue)
    }
    
    var body: some View {
        
        // List of available languages with checkmark for selected one
        List(translationService.availableLanguages, id: \.id) { language in
            HStack {
                Text(language.localizedName())
                Spacer()
                if language.shortName() == tempSelectedLanguage.shortName() {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(language.localizedName())")
            .accessibilityValue(language.shortName() == tempSelectedLanguage.shortName() ? "Selected" : "")
            .accessibilityAddTraits(language.shortName() == tempSelectedLanguage.shortName() ? .isSelected : [])
            .accessibilityAddTraits(.isButton)
            .contentShape(Rectangle())
            .onTapGesture {
                print("👆 Selected language: \(language.localizedName()) (\(language.shortName()))")
                tempSelectedLanguage = language
            }
        }
        
        // If languages change while view is open, update selection if needed
        .onChange(of: translationService.availableLanguages) {
            print("🔄 Available languages list updated, count: \(translationService.availableLanguages.count)")
            if !translationService.availableLanguages.contains(where: { $0.shortName() == tempSelectedLanguage.shortName() }) {
                print("⚠️ Previously selected language no longer available, updating selection")
                tempSelectedLanguage = translationService.availableLanguages.first ?? tempSelectedLanguage
            }
        }
        
        // Reset temp language to match current selection on appear
        .onAppear {
            print("📄 Language selection view appeared - current language: \(selectedLanguage.localizedName()) (\(selectedLanguage.shortName()))")
            tempSelectedLanguage = selectedLanguage
        }
        
        // Navigation bar setup
        .navigationTitle("Select Language")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    print("👆 Button pressed: Cancel language selection")
                    dismiss()
                }
                .accessibilityLabel("Cancel")
                .accessibilityHint("Discard changes and return to settings")
                .accessibilityAddTraits(.isButton)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    print("👆 Button pressed: Confirm language selection: \(tempSelectedLanguage.localizedName()) (\(tempSelectedLanguage.shortName()))")
                    isDownloading = true
                    downloadConfig = TranslationSession.Configuration(
                        source: translationService.sourceLanguage,
                        target: tempSelectedLanguage.locale
                    )
                }
                .accessibilityLabel("Done")
                .accessibilityHint("Confirm selection of \(tempSelectedLanguage.localizedName())")
                .accessibilityAddTraits(.isButton)
            }
        }
        
        // Loading overlay while preparing language
        .overlay(
            isDownloading ?
                VStack {
                    ProgressView("Preparing language...")
                        .accessibilityLabel("Preparing language")
                        .accessibilityAddTraits(.updatesFrequently)
                    Text("This might take a moment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .accessibilityLabel("This might take a moment")
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(10)
                : nil
        )
        .disabled(isDownloading)
        
        // Error alert if download fails
        .alert("Download Error", isPresented: $showDownloadError) {
            Button("OK") {
                selectedLanguage = tempSelectedLanguage
                dismiss()
            }
            .accessibilityLabel("OK")
            .accessibilityHint("Dismiss error and continue with selected language")
            .accessibilityAddTraits(.isButton)
        } message: {
            Text("Unable to download language data. Translations may not work properly.")
                .accessibilityLabel("Download error message")
        }
        
        // Hidden view that handles language download
        .translationTask(downloadConfig) { session in
            guard isDownloading else { return }
            
            print("🔄 Preparing translation with language: \(tempSelectedLanguage.shortName())")
            do {
                
                // Try to prepare translation with selected language
                try await session.prepareTranslation()
                print("✅ Successfully prepared language: \(tempSelectedLanguage.shortName())")
            
                await MainActor.run {
                    isDownloading = false
                    selectedLanguage = tempSelectedLanguage
                    print("👍 Language selection confirmed and view dismissed")
                    dismiss()
                    downloadConfig = nil
                }
            } catch {
                print("❌ Failed to prepare language \(tempSelectedLanguage.shortName()): \(error.localizedDescription)")

                // Handle download failure
                await MainActor.run {
                    isDownloading = false
                    showDownloadError = true
                    downloadConfig = nil
                    print("⚠️ Showing download error alert for language: \(tempSelectedLanguage.shortName())")
                }
            }
        }
    }
}


#Preview {
    createLanguageSelectionPreview()
}

private func createLanguageSelectionPreview() -> some View {
    let sampleLanguage = AvailableLanguage(locale: Locale.Language(languageCode: "es", region: "ES"))
    
    let translationService = TranslationService()
    translationService.availableLanguages = [
        AvailableLanguage(locale: Locale.Language(languageCode: "es", region: "ES")),
        AvailableLanguage(locale: Locale.Language(languageCode: "fr", region: "FR")),
        AvailableLanguage(locale: Locale.Language(languageCode: "de", region: "DE")),
        AvailableLanguage(locale: Locale.Language(languageCode: "it", region: "IT"))
    ]
    
    NavigationView {
        LanguageSelectionView(selectedLanguage: .constant(sampleLanguage))
            .environmentObject(translationService)
    }
}
