//
//  Result+Extensions.swift
//  Lingo lens
//
//  Created by Code Improvement on 10/14/25.
//

import Foundation

extension Result {
    
    /// Returns the success value or nil if failure
    var value: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    /// Returns the error or nil if success
    var error: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
    
    /// Maps a Result to another Result with a different Success type
    func flatMapError<NewFailure: Error>(
        _ transform: (Failure) -> NewFailure
    ) -> Result<Success, NewFailure> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(transform(error))
        }
    }
}

// MARK: - Async Result Helpers

extension Result where Failure == Error {
    
    /// Creates a Result from an async throwing function
    /// - Parameter operation: Async throwing operation to execute
    /// - Returns: Result with success value or error
    static func asyncCatching(
        _ operation: () async throws -> Success
    ) async -> Result<Success, Failure> {
        do {
            let value = try await operation()
            return .success(value)
        } catch {
            return .failure(error)
        }
    }
}
