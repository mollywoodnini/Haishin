//
//  Logger+Categories.swift
//  Haishin
//
//  Created by Haishin on 26.01.26.
//

import OSLog

extension Logger {

    //#################################################################################
    // MARK: - Subsystem
    //#################################################################################

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.haishin"


    //#################################################################################
    // MARK: - Categories
    //#################################################################################

    /// General app lifecycle and events.
    static let general = Logger(subsystem: subsystem, category: "general")

    /// Network requests and API calls.
    static let network = Logger(subsystem: subsystem, category: "network")

    /// JavaScript source loading, execution, and errors.
    static let sources = Logger(subsystem: subsystem, category: "sources")

    /// Download progress and file operations.
    static let downloads = Logger(subsystem: subsystem, category: "downloads")

    /// Video player events and streaming.
    static let playback = Logger(subsystem: subsystem, category: "playback")

    /// iCloud sync operations.
    static let sync = Logger(subsystem: subsystem, category: "sync")
}


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
    enum Category {
        case general
        case network
        case sources
        case downloads
        case playback
        case sync

        var logger: Logger {
            switch self {
            case .general: return .general
            case .network: return .network
            case .sources: return .sources
            case .downloads: return .downloads
            case .playback: return .playback
            case .sync: return .sync
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
    static func debug(_ category: Category,
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
    static func info(_ category: Category,
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
    static func notice(_ category: Category,
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
    static func warning(_ category: Category,
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
    static func error(_ category: Category,
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
    static func fault(_ category: Category,
                      _ message: String,
                      file: String = #file,
                      function: String = #function) {
        let context = formatContext(file: file, function: function)
        category.logger.fault("\(context): \(message)")
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private static func formatContext(file: String, function: String) -> String {
        let fileName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        // Remove parameter list from function name for cleaner output
        let cleanFunction = function.components(separatedBy: "(").first ?? function
        return "[\(fileName).\(cleanFunction)]"
    }
}
