//
//  LoadingOverlay.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import SwiftUI

/// Reusable loading overlay component
struct LoadingOverlay: View {
    
    let message: String
    let isPresented: Bool
    
    init(
        message: String = "Loading...",
        isPresented: Bool = true
    ) {
        self.message = message
        self.isPresented = isPresented
    }
    
    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text(message)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground).opacity(0.9))
                )
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()
        
        LoadingOverlay(message: "Processing...")
    }
}
