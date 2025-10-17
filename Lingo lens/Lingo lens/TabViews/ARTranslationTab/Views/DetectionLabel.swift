//
//  DetectionLabel.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/22/25.
//

import SwiftUI

/// Displays the currently detected object name or guidance text
/// Matches Google Translate's clean and professional design
struct DetectionLabel: View {
    
    let detectedObjectName: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: detectedObjectName.isEmpty ? "viewfinder.circle" : "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(detectedObjectName.isEmpty ? .orange : .white)
            
            Text(detectedObjectName.isEmpty ? "Fit object in box" : detectedObjectName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(detectedObjectName.isEmpty ? 
                    Color.black.opacity(0.75) : 
                    Color.green.opacity(0.85))
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 2)
        )
        .accessibilityLabel("Detection Status")
        .accessibilityValue(detectedObjectName.isEmpty ?
            "No object detected" :
            "Detected object: \(detectedObjectName)")
    }
}

#Preview {
    VStack(spacing: 20) {
        DetectionLabel(detectedObjectName: "")
        
        DetectionLabel(detectedObjectName: "Coffee Cup")
        
        DetectionLabel(detectedObjectName: "Large Professional Camera with Telephoto Lens")
    }
    .padding()
}
