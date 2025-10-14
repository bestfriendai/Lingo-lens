//
//  SecureLogger.swift
//  Lingo lens
//
//  Created by Code Review on 10/14/25.
//

import Foundation

/// Log levels for categorizing log messages
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

/// Secure logging utility that prevents sensitive user data from being logged in production
/// 
/// Usage:
/// ```
/// SecureLogger.log("Translation started", level: .info)
/// SecureLogger.log("Translation failed", level: .error)
/// SecureLogger.logDebugWithData("User input", userData: text) // Only logs in DEBUG
/// ```
struct SecureLogger {
    
    /// Logs a message with appropriate privacy controls
    /// - Parameters:
    ///   - message: The message to log (should NOT contain user data)
    ///   - level: The log level (debug, info, warning, error)
    ///   - file: Source file (auto-populated)
    ///   - function: Source function (auto-populated)
    ///   - line: Source line (auto-populated)
    static func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
            let fileName = (file as NSString).lastPathComponent
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)")
        #else
            // In production, only log errors without detailed context
            if level == .error {
                print("[\(level.rawValue)] \(message)")
            }
        #endif
    }
    
    /// Log with user data - ONLY use in DEBUG builds
    /// This method will never log user data in production builds
    /// - Parameters:
    ///   - message: Description of what is being logged
    ///   - userData: The actual user data (will be redacted in production)
    ///   - file: Source file (auto-populated)
    ///   - function: Source function (auto-populated)
    ///   - line: Source line (auto-populated)
    static func logDebugWithData(
        _ message: String,
        userData: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
            let fileName = (file as NSString).lastPathComponent
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] [DEBUG] [\(fileName):\(line)] \(function) - \(message): \(userData)")
        #else
            // Never log user data in production
            print("[DEBUG] \(message): [REDACTED]")
        #endif
    }
    
    /// Log an error with optional error object
    /// - Parameters:
    ///   - message: Error description
    ///   - error: Optional Error object
    ///   - file: Source file (auto-populated)
    ///   - function: Source function (auto-populated)
    ///   - line: Source line (auto-populated)
    static func logError(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
            let fileName = (file as NSString).lastPathComponent
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            if let error = error {
                print("[\(timestamp)] [ERROR] [\(fileName):\(line)] \(function) - \(message): \(error.localizedDescription)")
            } else {
                print("[\(timestamp)] [ERROR] [\(fileName):\(line)] \(function) - \(message)")
            }
        #else
            // In production, log errors without detailed context
            print("[ERROR] \(message)")
        #endif
    }
}

