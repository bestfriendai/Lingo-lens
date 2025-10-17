//
//  AdjustableBoundingBox.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import SwiftUI

/// Interactive bounding box for selecting objects to detect/translate
/// User can move, resize, and adjust this box to frame objects in the camera view
struct AdjustableBoundingBox: View {
    
    // Binding to the region of interest - allows parent view to access changes
    @Binding var roi: CGRect
    
    // Tracks initial box position during drag operations
    @State private var initialBoxROI: CGRect? = nil
    
    // Current drag offset while moving the box
    @State private var boxDragOffset: CGSize = .zero
    
    // Tracks initial handle position during resize operations
    @State private var initialHandleROI: CGRect? = nil
    
    // Spacing between box edge and screen edge
    private let margin: CGFloat = 16
    
    // Minimum size of the box to ensure usable detection area
    private let minBoxSize: CGFloat = 100
    
    /// Defines the four edge positions for drag handles
    private enum EdgePosition: String {
        case top = "Top"
        case bottom = "Bottom"
        case leading = "Left"
        case trailing = "Right"
    }
    
    /// Defines the four corner positions for resize handles
    enum HandlePosition: String {
        case topLeft = "Top left"
        case topRight = "Top right"
        case bottomLeft = "Bottom left"
        case bottomRight = "Bottom right"
    }
    
    // Size of the camera view for constraining the box's position
    var containerSize: CGSize
    
    // MARK: - Main Box Layout

    var body: some View {
        ZStack {
            
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: roi.width, height: roi.height)
                
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: roi.width, height: roi.height)
                
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .accessibilityHidden(true)
                        Text("Frame object here")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                    .padding(.top, 12)
                    .accessibilityLabel("Frame object here")
                    .accessibilityHint("Position this box around the object you want to translate")
                    
                    Spacer()
                }
                .frame(width: roi.width, height: roi.height)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Detection box")
            .accessibilityHint("Area where objects will be detected")
            .position(
                x: roi.midX + boxDragOffset.width,
                y: roi.midY + boxDragOffset.height
            )
            .gesture(mainDragGesture)
            .animation(.easeOut(duration: 0.2), value: boxDragOffset)
            
            handleView(for: .topLeft)
            handleView(for: .topRight)
            handleView(for: .bottomLeft)
            handleView(for: .bottomRight)
            
            edgeHandleView(for: .top)
            edgeHandleView(for: .bottom)
            edgeHandleView(for: .leading)
            edgeHandleView(for: .trailing)
        }
        // Custom hit testing to improve touch targets
        .contentShape(CombinedContentShape(roi: roi, containerSize: containerSize, boxDragOffset: boxDragOffset))
        .allowsHitTesting(true)
    }
    
    // MARK: - Edge Handle Controls

    /// Creates a draggable icon on the edges for moving the box
    /// Uses the square.arrowtriangle.4.outward SF Symbol to indicate draggability
    private func edgeHandleView(for position: EdgePosition) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 40, height: 40)
                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
            
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black.opacity(0.7))
        }
        .position(edgePosition(for: position))
        .gesture(mainDragGesture)
        .accessibilityLabel("\(position.rawValue) edge")
        .accessibilityHint("Drag to move the detection box")
        .accessibilityAddTraits(.isButton)
    }
    
    /// Calculates the position for edge handles based on the box position
    /// Accounts for any active drag operation offset
    private func edgePosition(for position: EdgePosition) -> CGPoint {
        switch position {
        case .top:
            return CGPoint(x: roi.midX + boxDragOffset.width, y: roi.minY + boxDragOffset.height)
        case .bottom:
            return CGPoint(x: roi.midX + boxDragOffset.width, y: roi.maxY + boxDragOffset.height)
        case .leading:
            return CGPoint(x: roi.minX + boxDragOffset.width, y: roi.midY + boxDragOffset.height)
        case .trailing:
            return CGPoint(x: roi.maxX + boxDragOffset.width, y: roi.midY + boxDragOffset.height)
        }
    }
    
    // MARK: - Box Movement
    
    /// Main gesture for dragging the entire box around
    /// Constrains movement to stay within screen bounds
    private var mainDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                
                // Store initial position on first drag event
                if initialBoxROI == nil {
                    initialBoxROI = roi
                }
                var translation = value.translation
                if let initial = initialBoxROI {
                    
                    // Constrain right movement
                    if translation.width > 0 {
                        let containerWidth = containerSize.width
                        let maxRightTranslation = containerWidth - margin - (initial.origin.x + initial.width)
                        translation.width = min(translation.width, maxRightTranslation)
                    }
                    
                    // Constrain left movement
                    if translation.width < 0 {
                        let maxLeftTranslation = margin - initial.origin.x
                        translation.width = max(translation.width, maxLeftTranslation)
                    }
                    
                    // Constrain upward movement
                    if translation.height < 0 {
                        let maxUpTranslation = margin - initial.origin.y
                        translation.height = max(translation.height, maxUpTranslation)
                    }
                    
                    // Constrain downward movement
                    if translation.height > 0 {
                        let containerHeight = containerSize.height
                        let maxDownTranslation = containerHeight - margin - (initial.origin.y + initial.height)
                        translation.height = min(translation.height, maxDownTranslation)
                    }
                }
                
                // Apply the constrained translation
                boxDragOffset = translation
            }
            .onEnded { value in
                if let initial = initialBoxROI {
                    var translation = value.translation
                    
                    // Apply the same constraints on drag end
                    // Constrain right movement
                    if translation.width > 0 {
                        let containerWidth = containerSize.width
                        let maxRightTranslation = containerWidth - margin - (initial.origin.x + initial.width)
                        translation.width = min(translation.width, maxRightTranslation)
                    }
                    
                    // Constrain left movement
                    if translation.width < 0 {
                        let maxLeftTranslation = margin - initial.origin.x
                        translation.width = max(translation.width, maxLeftTranslation)
                    }
                    
                    // Constrain upward movement
                    if translation.height < 0 {
                        let maxUpTranslation = margin - initial.origin.y
                        translation.height = max(translation.height, maxUpTranslation)
                    }
                    
                    // Constrain downward movement
                    if translation.height > 0 {
                        let containerHeight = containerSize.height
                        let maxDownTranslation = containerHeight - margin - (initial.origin.y + initial.height)
                        translation.height = min(translation.height, maxDownTranslation)
                    }
                    
                    // Create final box position and update the binding
                    let newROI = CGRect(
                        x: initial.origin.x + translation.width,
                        y: initial.origin.y + translation.height,
                        width: initial.width,
                        height: initial.height
                    )
                    roi = clampROI(newROI)
                }
                
                // Reset drag state
                initialBoxROI = nil
                boxDragOffset = .zero
            }
    }
    
    // MARK: - Corner Resizing

    /// Creates circular resize handles at the corners
    /// Allows user to resize the box by dragging corners
    @ViewBuilder
    private func handleView(for position: HandlePosition) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 36, height: 36)
                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
            
            Circle()
                .fill(Color.blue.opacity(0.9))
                .frame(width: 26, height: 26)
            
            Image(systemName: resizeIconForHandle(position))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .position(
            x: handlePosition(for: position).x + boxDragOffset.width,
            y: handlePosition(for: position).y + boxDragOffset.height
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    
                    if initialHandleROI == nil {
                        initialHandleROI = roi
                    }
                    let initial = initialHandleROI!
                    
                    var newROI = initial
                        
                        switch position {
                            
                        // Calculate maximum possible movement based on minimum size
                        case .topLeft:
                            let maxDeltaX = initial.width - minBoxSize
                            let maxDeltaY = initial.height - minBoxSize
                            
                            // Calculate proposed deltas
                            var deltaX = min(value.translation.width, maxDeltaX)
                            var deltaY = min(value.translation.height, maxDeltaY)
                            
                            // Apply margin constraints
                            if initial.origin.x + deltaX < margin {
                                deltaX = margin - initial.origin.x
                            }
                            if initial.origin.y + deltaY < margin {
                                deltaY = margin - initial.origin.y
                            }
                            
                            // Update origin and size
                            newROI.origin.x = initial.origin.x + deltaX
                            newROI.origin.y = initial.origin.y + deltaY
                            newROI.size.width = initial.width - deltaX
                            newROI.size.height = initial.height - deltaY
                            
                        case .topRight:
                            
                            // Calculate maximum possible movement based on minimum size
                            let maxNegativeDeltaX = minBoxSize - initial.width
                            let maxDeltaY = initial.height - minBoxSize
                            
                            // Calculate proposed deltas
                            var deltaX = max(value.translation.width, maxNegativeDeltaX)
                            var deltaY = min(value.translation.height, maxDeltaY)
                            
                            // Apply margin constraints
                            if initial.origin.x + initial.width + deltaX > containerSize.width - margin {
                                deltaX = containerSize.width - margin - (initial.origin.x + initial.width)
                            }
                            if initial.origin.y + deltaY < margin {
                                deltaY = margin - initial.origin.y
                            }
                            
                            // Update origin and size
                            newROI.origin.y = initial.origin.y + deltaY
                            newROI.size.width = initial.width + deltaX
                            newROI.size.height = initial.height - deltaY
                            
                        case .bottomLeft:
                            
                            // Calculate maximum possible movement based on minimum size
                            let maxDeltaX = initial.width - minBoxSize
                            let maxNegativeDeltaY = minBoxSize - initial.height
                            
                            // Calculate proposed deltas
                            var deltaX = min(value.translation.width, maxDeltaX)
                            var deltaY = max(value.translation.height, maxNegativeDeltaY)
                            
                            // Apply margin constraints
                            if initial.origin.x + deltaX < margin {
                                deltaX = margin - initial.origin.x
                            }
                            if initial.origin.y + initial.height + deltaY > containerSize.height - margin {
                                deltaY = containerSize.height - margin - (initial.origin.y + initial.height)
                            }
                            
                            // Update origin and size
                            newROI.origin.x = initial.origin.x + deltaX
                            newROI.size.width = initial.width - deltaX
                            newROI.size.height = initial.height + deltaY
                            
                        case .bottomRight:
                            
                            // Calculate maximum possible movement based on minimum size
                            let maxNegativeDeltaX = minBoxSize - initial.width
                            let maxNegativeDeltaY = minBoxSize - initial.height
                            
                            // Calculate proposed deltas
                            var deltaX = max(value.translation.width, maxNegativeDeltaX)
                            var deltaY = max(value.translation.height, maxNegativeDeltaY)
                            
                            // Apply margin constraints
                            if initial.origin.x + initial.width + deltaX > containerSize.width - margin {
                                deltaX = containerSize.width - margin - (initial.origin.x + initial.width)
                            }
                            if initial.origin.y + initial.height + deltaY > containerSize.height - margin {
                                deltaY = containerSize.height - margin - (initial.origin.y + initial.height)
                            }
                            
                            // Update size (origin stays the same)
                            newROI.size.width = initial.width + deltaX
                            newROI.size.height = initial.height + deltaY
                        }
                        
                        // Apply changes to the binding
                        roi = newROI
                    }
                    .onEnded { _ in
                        
                        // Final cleanup to ensure constraints are met
                        roi = clampROI(roi)
                        initialHandleROI = nil
                    }
            )
            .accessibilityLabel("\(position.rawValue) resize handle")
            .accessibilityHint("Drag to resize the detection box")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Custom shape that creates larger touch targets around the box edges and corners
    /// Improves usability by making it easier to grab the handles
    private struct CombinedContentShape: Shape {
        let roi: CGRect
        let containerSize: CGSize
        let boxDragOffset: CGSize
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let adjustedROI = roi.offsetBy(dx: boxDragOffset.width, dy: boxDragOffset.height)
            
            // Add circular hit areas for each corner and edge midpoint
            let positions = [
                
                // Corners
                CGPoint(x: adjustedROI.minX, y: adjustedROI.minY),
                CGPoint(x: adjustedROI.maxX, y: adjustedROI.minY),
                CGPoint(x: adjustedROI.minX, y: adjustedROI.maxY),
                CGPoint(x: adjustedROI.maxX, y: adjustedROI.maxY),
                
                // Edge midpoints
                CGPoint(x: adjustedROI.midX, y: adjustedROI.minY),
                CGPoint(x: adjustedROI.midX, y: adjustedROI.maxY),
                CGPoint(x: adjustedROI.minX, y: adjustedROI.midY),
                CGPoint(x: adjustedROI.maxX, y: adjustedROI.midY)
            ]
            
            // Add 30-point touch targets at each position
            for position in positions {
                path.addEllipse(in: CGRect(
                    x: position.x - 15,
                    y: position.y - 15,
                    width: 30,
                    height: 30
                ))
            }
            
            // Add hit areas along the edges
            let edgeThickness: CGFloat = 20

            // Top edge
            path.addRect(CGRect(
                x: adjustedROI.minX,
                y: adjustedROI.minY - edgeThickness/2,
                width: adjustedROI.width,
                height: edgeThickness
            ))

            // Bottom edge
            path.addRect(CGRect(
                x: adjustedROI.minX,
                y: adjustedROI.maxY - edgeThickness/2,
                width: adjustedROI.width,
                height: edgeThickness
            ))
            
            // Left edge
            path.addRect(CGRect(
                x: adjustedROI.minX - edgeThickness/2,
                y: adjustedROI.minY,
                width: edgeThickness,
                height: adjustedROI.height
            ))
            
            // Right edge
            path.addRect(CGRect(
                x: adjustedROI.maxX - edgeThickness/2,
                y: adjustedROI.minY,
                width: edgeThickness,
                height: adjustedROI.height
            ))
            
            return path
        }
    }
    
    /// Gets position for corner handles based on the box's dimensions
    private func handlePosition(for position: HandlePosition) -> CGPoint {
        switch position {
        case .topLeft: return CGPoint(x: roi.minX, y: roi.minY)
        case .topRight: return CGPoint(x: roi.maxX, y: roi.minY)
        case .bottomLeft: return CGPoint(x: roi.minX, y: roi.maxY)
        case .bottomRight: return CGPoint(x: roi.maxX, y: roi.maxY)
        }
    }
    
    /// Ensures the box stays within screen bounds and maintains minimum size
    /// Applied after any drag or resize operation to enforce constraints
    private func clampROI(_ rect: CGRect) -> CGRect {
        var newRect = rect
        
        newRect.size.width = max(newRect.size.width, minBoxSize)
        newRect.size.height = max(newRect.size.height, minBoxSize)
        
        newRect.origin.x = max(margin, newRect.origin.x)
        newRect.origin.y = max(margin, newRect.origin.y)
        
        if newRect.maxX > containerSize.width - margin {
            newRect.origin.x = containerSize.width - margin - newRect.size.width
        }
        
        if newRect.maxY > containerSize.height - margin {
            newRect.origin.y = containerSize.height - margin - newRect.size.height
        }
        
        if newRect.origin.x < margin {
            newRect.origin.x = margin
        }
        
        if newRect.origin.y < margin {
            newRect.origin.y = margin
        }
        
        return newRect
    }
    
    private func resizeIconForHandle(_ position: HandlePosition) -> String {
        switch position {
        case .topLeft: return "arrow.up.left"
        case .topRight: return "arrow.up.right"
        case .bottomLeft: return "arrow.down.left"
        case .bottomRight: return "arrow.down.right"
        }
    }
}

#Preview("Adjustable Bounding Box Preview") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        AdjustableBoundingBox(
            roi: .constant(CGRect(x: 100, y: 100, width: 200, height: 200)),
            containerSize: CGSize(width: 400, height: 800)
        )
    }
}
