//
//  Logger+Categories.swift
//  Haishin
//
//  Created by Haishin on 26.01.26.
//

import OSLog

//#################################################################################
// MARK: - Log
//#################################################################################

/// A convenience wrapper for OSLog that automatically includes file and function context.
///
/// Usage:
/// ```swift
/// Log.debug(.playback, "Loading video")
/// Log.error(.network, "Request failed: \(error)")
/// ```
enum Log {

    //#################################################################################
    // MARK: - Category
    //#################################################################################

    /// Available logging categories.
    enum Category: Sendable {
        case general
        case network
        case sources
        case downloads
        case playback
        case sync

        nonisolated var logger: Logger {
            let subsystem = Bundle.main.bundleIdentifier ?? "com.haishin"
            
            switch self {
            case .general: return Logger(subsystem: subsystem, category: "general")
            case .network: return Logger(subsystem: subsystem, category: "network")
            case .sources: return Logger(subsystem: subsystem, category: "sources")
            case .downloads: return Logger(subsystem: subsystem, category: "downloads")
            case .playback: return Logger(subsystem: subsystem, category: "playback")
            case .sync: return Logger(subsystem: subsystem, category: "sync")
            }
        }
    }


    //#################################################################################
    // MARK: - Logging Methods
    //#################################################################################

    /// Logs a debug message with file and function context.
    /// - Parameters:
    ///   - category: The logging category.
    ///   - message: The message to log.
    ///   - file: The file name (automatically captured).
    ///   - function: The function name (automatically captured).
    nonisolated static func debug(_ category: Category,
                                  _ message: String,
                                  file: String = #file,
                                  function: String = #function) {
        let context = formatContext(file: file, function: function)
        category.logger.debug("\(context): \(message)")
    }

    /// Logs an info message with file and function context.
    /// - Parameters:
    ///   - category: The logging category.
    ///   - message: The message to log.
    ///   - file: The file name (automatically captured).
    ///   - function: The function name (automatically captured).
    nonisolated static func info(_ category: Category,
                                 _ message: String,
                                 file: String = #file,
                                 function: String = #function) {
        let context = formatContext(file: file, function: function)
        category.logger.info("\(context): \(message)")
    }

    /// Logs a notice message with file and function context.
    /// - Parameters:
    ///   - category: The logging category.
    ///   - message: The message to log.
    ///   - file: The file name (automatically captured).
    ///   - function: The function name (automatically captured).
    nonisolated static func notice(_ category: Category,
                                   _ message: String,
                                   file: String = #file,
                                   function: String = #function) {
        let context = formatContext(file: file, function: function)
        category.logger.notice("\(context): \(message)")
    }

    /// Logs a warning message with file and function context.
    /// - Parameters:
    ///   - category: The logging category.
    ///   - message: The message to log.
    ///   - file: The file name (automatically captured).
    ///   - function: The function name (automatically captured).
    nonisolated static func warning(_ category: Category,
                                    _ message: String,
                                    file: String = #file,
                                    function: String = #function) {
        let context = formatContext(file: file, function: function)
        category.logger.warning("\(context): \(message)")
    }

    /// Logs an error message with file and function context.
    /// - Parameters:
    ///   - category: The logging category.
    ///   - message: The message to log.
    ///   - file: The file name (automatically captured).
    ///   - function: The function name (automatically captured).
    nonisolated static func error(_ category: Category,
                                  _ message: String,
                                  file: String = #file,
                                  function: String = #function) {
        let context = formatContext(file: file, function: function)
        category.logger.error("\(context): \(message)")
    }

    /// Logs a fault message with file and function context.
    /// - Parameters:
    ///   - category: The logging category.
    ///   - message: The message to log.
    ///   - file: The file name (automatically captured).
    ///   - function: The function name (automatically captured).
    nonisolated static func fault(_ category: Category,
                                  _ message: String,
                                  file: String = #file,
                                  function: String = #function) {
        let context = formatContext(file: file, function: function)
        category.logger.fault("\(context): \(message)")
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    nonisolated private static func formatContext(file: String, function: String) -> String {
        let fileName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        // Remove parameter list from function name for cleaner output
        let cleanFunction = function.components(separatedBy: "(").first ?? function
        return "[\(fileName).\(cleanFunction)]"
    }
}
