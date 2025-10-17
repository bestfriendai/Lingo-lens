//
//  AppLanguageSelectionView.swift
//  Lingo lens
//
//  Created by Localization Implementation on 10/17/25.
//

import SwiftUI

/// View for selecting the app's display language
struct AppLanguageSelectionView: View {
    
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(languageManager.supportedLanguages, id: \.code) { language in
                    Button(action: {
                        languageManager.currentLanguage = language.code
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                Text(languageManager.getLanguageDisplayName(for: language.code))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if languageManager.currentLanguage == language.code {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        languageManager.currentLanguage == language.code ?
                            Color.blue.opacity(0.08) :
                            Color(.systemBackground)
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(localized: "language.select_language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(localized: "action.done")
                    }
                }
            }
        }
        .withRTLSupport()
    }
}

#Preview {
    AppLanguageSelectionView()
        .environmentObject(AppLanguageManager.shared)
}