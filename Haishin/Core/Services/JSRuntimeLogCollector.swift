import Foundation
import Observation


//#################################################################################
// MARK: - JSRuntimeLogCollector
//#################################################################################

/// Collects JSRuntime log messages for in-app display (e.g., video loading overlay).
@MainActor
@Observable
final class JSRuntimeLogCollector {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private enum Constants {
        static let maxMessages: Int = 100
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    static let shared = JSRuntimeLogCollector()
    private init() {}

    var messages: [String] = []


    //#################################################################################
    // MARK: - Methods
    //#################################################################################

    func append(_ message: String) {
        if messages.count >= Constants.maxMessages {
            messages.removeFirst(messages.count - Constants.maxMessages + 1)
        }
        messages.append(message)
    }

    /// Appends a message with a bracketed category prefix, e.g. `[handleFetch] message`.
    func append(category: String, message: String) {
        append("[\(category)] \(message)")
    }

    func clear() {
        messages.removeAll()
    }
}
