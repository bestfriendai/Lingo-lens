//
//  ErrorAlertModifier.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import SwiftUI

/// View modifier for displaying app errors in a consistent way
struct ErrorAlertModifier: ViewModifier {
    
    @Binding var error: AppError?
    
    func body(content: Content) -> some View {
        content
            .alert(
                error?.title ?? "Error",
                isPresented: Binding(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    error = nil
                }
                
                if let retryAction = error?.retryAction {
                    Button("Try Again") {
                        retryAction()
                        error = nil
                    }
                }
            } message: {
                if let error = error {
                    Text(error.message)
                }
            }
    }
}

extension View {
    /// Presents an alert when an AppError occurs
    /// - Parameter error: Binding to optional AppError
    func errorAlert(_ error: Binding<AppError?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}

#Preview("Error Alert") {
    ErrorAlertModifier_PreviewWrapper()
}

struct ErrorAlertModifier_PreviewWrapper: View {
        @State private var error: AppError? = nil
        
        var body: some View {
            VStack(spacing: 20) {
                Button("Show Network Error") {
                    error = TranslationError.networkError
                }
                
                Button("Show Timeout Error") {
                    error = TranslationError.timeout
                }
                
                Button("Show AR Error") {
                    error = ARError.trackingLost
                }
            }
            .errorAlert($error)
        }
}
