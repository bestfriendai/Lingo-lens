//
//  PerformanceMonitor.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/15/25.
//

import Foundation
import os.log

/// Monitors app performance metrics and provides insights
/// Helps identify performance bottlenecks and optimization opportunities
final class PerformanceMonitor {

    // MARK: - Shared Instance

    static let shared = PerformanceMonitor()

    // MARK: - Properties

    private var timers: [String: CFAbsoluteTime] = [:]
    private var metrics: [String: [TimeInterval]] = [:]
    private let queue = DispatchQueue(label: "com.lingolens.performancemonitor", qos: .utility)
    private let logger = OSLog(subsystem: "com.lingolens", category: "Performance")

    // MARK: - Initialization

    private init() {}

    // MARK: - Timing Methods

    /// Starts timing an operation
    /// - Parameter identifier: Unique identifier for the operation
    func startTimer(_ identifier: String) {
        queue.async {
            self.timers[identifier] = CFAbsoluteTimeGetCurrent()
        }
    }

    /// Ends timing for an operation and records the duration
    /// - Parameter identifier: Unique identifier for the operation
    /// - Returns: Duration in seconds
    @discardableResult
    func endTimer(_ identifier: String) -> TimeInterval? {
        let endTime = CFAbsoluteTimeGetCurrent()

        return queue.sync {
            guard let startTime = timers[identifier] else {
                SecureLogger.log("⚠️ No start time found for identifier: \(identifier)", level: .warning)
                return nil
            }

            let duration = endTime - startTime
            timers.removeValue(forKey: identifier)

            // Store metric
            if metrics[identifier] == nil {
                metrics[identifier] = []
            }
            metrics[identifier]?.append(duration)

            // Log performance
            #if DEBUG
            os_log(.info, log: logger, "⏱️ %{public}@ completed in %.3f seconds", identifier, duration)
            #endif

            return duration
        }
    }

    /// Measures the time taken to execute a synchronous block
    /// - Parameters:
    ///   - identifier: Unique identifier for the operation
    ///   - block: The code to measure
    /// - Returns: Result of the block execution
    func measure<T>(_ identifier: String, block: () throws -> T) rethrows -> T {
        startTimer(identifier)
        defer { endTimer(identifier) }
        return try block()
    }

    /// Measures the time taken to execute an async block
    /// - Parameters:
    ///   - identifier: Unique identifier for the operation
    ///   - block: The async code to measure
    /// - Returns: Result of the block execution
    func measure<T>(_ identifier: String, block: () async throws -> T) async rethrows -> T {
        startTimer(identifier)
        defer { endTimer(identifier) }
        return try await block()
    }

    // MARK: - Metrics

    /// Gets average duration for an operation
    /// - Parameter identifier: Unique identifier for the operation
    /// - Returns: Average duration in seconds, or nil if no data
    func getAverageDuration(for identifier: String) -> TimeInterval? {
        queue.sync {
            guard let durations = metrics[identifier], !durations.isEmpty else {
                return nil
            }
            return durations.reduce(0, +) / Double(durations.count)
        }
    }

    /// Gets all recorded durations for an operation
    /// - Parameter identifier: Unique identifier for the operation
    /// - Returns: Array of durations
    func getDurations(for identifier: String) -> [TimeInterval] {
        queue.sync {
            metrics[identifier] ?? []
        }
    }

    /// Clears metrics for a specific operation
    /// - Parameter identifier: Unique identifier for the operation
    func clearMetrics(for identifier: String) {
        queue.async {
            self.metrics.removeValue(forKey: identifier)
        }
    }

    /// Clears all metrics
    func clearAllMetrics() {
        queue.async {
            self.metrics.removeAll()
            self.timers.removeAll()
        }
    }

    /// Prints a summary of all collected metrics
    func printSummary() {
        queue.sync {
            #if DEBUG
            print("\n📊 Performance Summary")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            for (identifier, durations) in metrics.sorted(by: { $0.key < $1.key }) {
                guard !durations.isEmpty else { continue }

                let avg = durations.reduce(0, +) / Double(durations.count)
                let min = durations.min() ?? 0
                let max = durations.max() ?? 0
                let count = durations.count

                print(String(format: "%-30s | Count: %4d | Avg: %.3fs | Min: %.3fs | Max: %.3fs",
                             identifier, count, avg, min, max))
            }

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            #endif
        }
    }

    // MARK: - Memory Monitoring

    /// Gets current memory usage in MB
    /// - Returns: Memory usage in megabytes
    static func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        guard kerr == KERN_SUCCESS else {
            return 0
        }

        return Double(info.resident_size) / 1024.0 / 1024.0
    }

    /// Logs current memory usage
    static func logMemoryUsage(_ context: String = "") {
        let usage = getMemoryUsage()
        SecureLogger.log("💾 Memory Usage\(context.isEmpty ? "" : " (\(context))"): \(String(format: "%.2f MB", usage))", level: .info)
    }
}
