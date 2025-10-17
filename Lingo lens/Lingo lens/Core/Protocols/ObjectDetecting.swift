//
//  ObjectDetecting.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation
import CoreVideo
import ImageIO

/// Protocol defining object detection capabilities
/// Enables dependency injection and testing with mock implementations
/// @MainActor ensures detection results are delivered on main thread (Swift 6 concurrency)
@MainActor
protocol ObjectDetecting {
    
    /// Detects objects in a specified region of a camera frame
    /// - Parameters:
    ///   - pixelBuffer: Raw camera frame from ARKit
    ///   - exifOrientation: Current orientation of device camera
    ///   - normalizedROI: Region of interest in normalized coordinates (0-1)
    ///   - completion: Callback with identified object name or nil if none found
    func detectObjectCropped(
        pixelBuffer: CVPixelBuffer,
        exifOrientation: CGImagePropertyOrientation,
        normalizedROI: CGRect,
        completion: @escaping (String?) -> Void
    )
}


