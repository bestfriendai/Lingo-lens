//
//  ObjectDetectionManager.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 2/18/25.
//

import Foundation
import CoreML
import Vision
import CoreImage
import ImageIO

/// Handles object detection using Vision framework and FastViT model
/// Takes camera frames from AR session and identifies objects within user-defined regions
class ObjectDetectionManager: ObjectDetecting {
    
    // MARK: - Dependencies
    
    private let errorManager: ErrorManaging
    
    // ML model loaded from bundle for image classification
    private var visionModel: VNCoreMLModel?
    
    // CIContext for efficient image processing operations (reused across all detections)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Dedicated queue for background processing
    private let processingQueue = DispatchQueue(label: "com.lingolens.objectdetection", qos: .userInitiated)

    // Small margin to shrink the detection box slightly for better results
    private let insideMargin: CGFloat = 4

    // Image cache for improved performance on repeated detections
    private let imageCache = NSCache<NSString, CIImage>()
    private let detectionResultCache = NSCache<NSString, NSString>()

    // MARK: - Setup

    /// Sets up the ML model when manager is created
    /// IMPROVED: Graceful fallback when no ML model is available
    /// Object detection feature will be disabled but app will still work for text translation
    init(errorManager: ErrorManaging) {
        self.errorManager = errorManager
        // Configure image cache
        imageCache.countLimit = AppConstants.Performance.imageCacheSize
        imageCache.totalCostLimit = 50 * 1024 * 1024  // 50MB max

        // Configure result cache
        detectionResultCache.countLimit = AppConstants.Performance.imageCacheSize * 2

        // NOTE: ML model for object detection is not currently available
        // The app will still work for text translation (primary feature)
        // Object detection mode will show a message that the feature is unavailable
        visionModel = nil
    }
    
    // MARK: - ObjectDetecting Protocol
    
    /// Starts object detection
    func startDetection() {
        // Implementation would start detection process
    }
    
    /// Stops object detection
    func stopDetection() {
        // Implementation would stop detection process
    }
    
    /// Current detection state
    var isDetectionActive: Bool {
        // Implementation would return current detection state
        return false

        SecureLogger.log("ℹ️ Object detection model not available - text translation still works", level: .info)

        // TO ENABLE OBJECT DETECTION:
        // 1. Add a CoreML model file (.mlmodel or .mlpackage) to your project
        // 2. Uncomment and update the code below with your model name
        //
        // Example with FastViTMA36F16:
        // do {
        //     let config = MLModelConfiguration()
        //     config.computeUnits = .all  // Use Neural Engine if available
        //     let model = try FastViTMA36F16(configuration: config).model
        //     visionModel = try VNCoreMLModel(for: model)
        //     SecureLogger.log("✅ Object detection model loaded successfully", level: .info)
        // } catch {
        //     SecureLogger.logError("Failed to load object detection model", error: error)
        //     visionModel = nil
        // }
        //
        // Example with MobileNet (if you have it):
        // do {
        //     let config = MLModelConfiguration()
        //     config.computeUnits = .all
        //     let model = try MobileNet(configuration: config).model
        //     visionModel = try VNCoreMLModel(for: model)
        //     SecureLogger.log("✅ MobileNet model loaded", level: .info)
        // } catch {
        //     SecureLogger.logError("Failed to load MobileNet", error: error)
        //     visionModel = nil
        // }
    }
    
    // MARK: - Image Processing & Detection

    /// Detects objects in a specified region of a camera frame
    /// Only processes the part of the image that user has framed within the bounding box
    /// - Parameters:
    ///   - pixelBuffer: Raw camera frame from ARKit
    ///   - exifOrientation: Current orientation of device camera
    ///   - normalizedROI: Region of interest in normalized coordinates (0-1)
    ///   - completion: Callback with identified object name or nil if none found
    func detectObjectCropped(pixelBuffer: CVPixelBuffer,
                             exifOrientation: CGImagePropertyOrientation,
                             normalizedROI: CGRect,
                             completion: @escaping (String?) -> Void)
    {
        // Perform all heavy processing on background queue
        processingQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            #if DEBUG
            SecureLogger.log("Starting object detection", level: .info)
            #endif

            // Create cache key from ROI for detection result caching
            let cacheKey = String(format: "%.3f_%.3f_%.3f_%.3f",
                                normalizedROI.origin.x, normalizedROI.origin.y,
                                normalizedROI.width, normalizedROI.height) as NSString

            // Check detection result cache first
            if let cachedResult = self.detectionResultCache.object(forKey: cacheKey) {
                #if DEBUG
                SecureLogger.log("Using cached detection result", level: .info)
                #endif
                DispatchQueue.main.async {
                    completion(cachedResult as String)
                }
                return
            }

            // Make sure we have the ML model loaded
            guard let visionModel = self.visionModel else {
                SecureLogger.logError("Object detection model not available")
                DispatchQueue.main.async {
                    errorManager.showError(
                        message: "Object detection model is not available. Please restart the app.",
                        retryAction: nil
                    )
                    completion(nil)
                }
                return
            }

            // Check image cache first
            let imageCacheKey = String(format: "img_%.3f_%.3f_%.3f_%.3f",
                                      normalizedROI.origin.x, normalizedROI.origin.y,
                                      normalizedROI.width, normalizedROI.height) as NSString
            
            var ciImage: CIImage
            if let cachedImage = self.imageCache.object(forKey: imageCacheKey) {
                ciImage = cachedImage
                #if DEBUG
                SecureLogger.log("Using cached processed image", level: .info)
                #endif
            } else {
                // Convert pixel buffer to CIImage and fix orientation
                ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    .oriented(forExifOrientation: exifOrientation.numericValue)
            }
        
        // Convert normalized coordinates (0-1) to actual pixel coordinates
        let fullWidth = ciImage.extent.width
        let fullHeight = ciImage.extent.height
        
        #if DEBUG
        SecureLogger.log("Image dimensions: \(fullWidth) x \(fullHeight)", level: .info)
        #endif
        
        let cropX = normalizedROI.origin.x * fullWidth
        let cropY = normalizedROI.origin.y * fullHeight
        let cropW = normalizedROI.width  * fullWidth
        let cropH = normalizedROI.height * fullHeight
        
        var cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
        
        // Add a small margin inside the detection box for better results
        cropRect = cropRect.insetBy(dx: insideMargin, dy: insideMargin)
        
        // Skip processing for extremely small regions that would fail detection
        if cropRect.width < 10 || cropRect.height < 10 {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Make sure we're not trying to crop outside the image bounds
        cropRect = ciImage.extent.intersection(cropRect)
        if cropRect.isEmpty {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Crop the image to only the region inside the detection box
        ciImage = ciImage.cropped(to: cropRect)
        
        // Cache the processed image for future detections
        self.imageCache.setObject(ciImage, forKey: imageCacheKey)
        
        // Convert CIImage to CGImage for Vision framework
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            SecureLogger.logError("Failed to create CGImage from CIImage for object detection")
            DispatchQueue.main.async {
                errorManager.showError(
                    message: "Image processing failed. Please try again.",
                    retryAction: nil
                )
                completion(nil)
            }
            return
        }
        
        // Set up the ML request to detect objects in the image
        let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
            guard let self = self else { 
                DispatchQueue.main.async {
                    completion(nil)
                }
                return 
            }
            
            if let error = error {
                SecureLogger.logError("Vision request failed", error: error)
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // Extract the top classification result
            // Only return it if confidence is above 50%
            guard let results = request.results as? [VNClassificationObservation],
                  let best = results.first,
                  best.confidence > AppConstants.AR.confidenceThreshold else {
                SecureLogger.log("No object detected with sufficient confidence", level: .info)
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            #if DEBUG
            SecureLogger.log("Object detected with confidence: \(best.confidence)", level: .info)
            #endif
            
            // Cache the detection result
            self.detectionResultCache.setObject(best.identifier as NSString, forKey: cacheKey)
            
            DispatchQueue.main.async {
                completion(best.identifier)
            }
        }
        
        // Use center crop scaling to focus on the main object in the frame
        request.imageCropAndScaleOption = .centerCrop
        
            // Run the image through Vision framework
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                SecureLogger.logError("Vision request failed", error: error)
                DispatchQueue.main.async {
                    errorManager.showError(
                        message: "Vision processing failed. Please try again.",
                        retryAction: nil
                    )
                    completion(nil)
                }
            }
        } // End of processingQueue.async
    }
}
