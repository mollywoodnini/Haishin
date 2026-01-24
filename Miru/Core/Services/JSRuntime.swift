//
//  JSRuntime.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation
import JavaScriptCore

/// Manages JavaScript execution for anime sources.
/// Uses JavaScriptCore to run source scripts in a sandboxed environment.
actor JSRuntime {

    //#################################################################################
    // MARK: - Types
    //#################################################################################

    /// Errors that can occur during JS execution.
    enum JSError: LocalizedError {
        case contextCreationFailed
        case scriptLoadFailed(String)
        case functionNotFound(String)
        case executionFailed(String)
        case invalidResult(String)

        var errorDescription: String? {
            switch self {
            case .contextCreationFailed:
                return "Failed to create JavaScript context."
            case .scriptLoadFailed(let message):
                return "Failed to load script: \(message)"
            case .functionNotFound(let name):
                return "Function '\(name)' not found in source."
            case .executionFailed(let message):
                return "JavaScript execution failed: \(message)"
            case .invalidResult(let message):
                return "Invalid result from JavaScript: \(message)"
            }
        }
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private nonisolated(unsafe) let context: JSContext
    private let networkClient: NetworkClient
    private var loadedSources: [String: JSValue] = [:]


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new JavaScript runtime.
    /// - Parameter networkClient: Network client for HTTP requests from JS.
    init(networkClient: NetworkClient = NetworkClient()) throws {
        guard let context = JSContext() else {
            throw JSError.contextCreationFailed
        }

        self.context = context
        self.networkClient = networkClient

        setupContext()
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads a source script into the runtime.
    /// - Parameters:
    ///   - script: The JavaScript source code.
    ///   - sourceId: Unique identifier for the source.
    func loadSource(script: String, sourceId: String) throws {
        context.evaluateScript(script)

        if let exception = context.exception {
            throw JSError.scriptLoadFailed(exception.toString() ?? "Unknown error")
        }

        guard let sourceObject = context.objectForKeyedSubscript("source"),
              !sourceObject.isUndefined else {
            throw JSError.scriptLoadFailed("No 'source' object exported from script")
        }

        loadedSources[sourceId] = sourceObject
    }

    /// Calls a function on a loaded source.
    /// - Parameters:
    ///   - sourceId: The source identifier.
    ///   - function: The function name to call.
    ///   - arguments: Arguments to pass to the function.
    /// - Returns: The result as a dictionary or array.
    func callFunction(sourceId: String,
                      function: String,
                      arguments: [Any] = []) async throws -> Any {
        guard let source = loadedSources[sourceId] else {
            throw JSError.functionNotFound("Source '\(sourceId)' not loaded")
        }

        guard let functionValue = source.objectForKeyedSubscript(function),
              !functionValue.isUndefined else {
            throw JSError.functionNotFound(function)
        }

        // Call the function
        let result = functionValue.call(withArguments: arguments)

        if let exception = context.exception {
            context.exception = nil
            throw JSError.executionFailed(exception.toString() ?? "Unknown error")
        }

        // Handle Promise results
        if let result = result, isPromise(result) {
            return try await resolvePromise(result)
        }

        guard let result = result, !result.isUndefined, !result.isNull else {
            throw JSError.invalidResult("Function returned undefined or null")
        }

        return result.toObject() ?? [:]
    }
    
    /// Calls an async function and returns JSON string result.
    /// - Parameters:
    ///   - sourceId: The source identifier.
    ///   - functionName: The function name (e.g., "search" or "source.search").
    ///   - arguments: Arguments to pass to the function.
    /// - Returns: JSON string of the result.
    func callAsyncFunction(sourceId: String,
                           functionName: String,
                           arguments: [Any] = []) async throws -> String {
        // Build the function call expression
        let argsJson = try JSONSerialization.data(withJSONObject: arguments)
        let argsString = String(data: argsJson, encoding: .utf8) ?? "[]"
        
        // Create a wrapper that calls the function and JSON.stringify the result
        let script = """
        (async function() {
            const args = \(argsString);
            const result = await \(functionName)(...args);
            return JSON.stringify(result);
        })();
        """
        
        // Evaluate the script
        guard let promiseValue = context.evaluateScript(script) else {
            throw JSError.executionFailed("Failed to evaluate async function")
        }
        
        if let exception = context.exception {
            context.exception = nil
            throw JSError.executionFailed(exception.toString() ?? "Unknown error")
        }
        
        // Resolve the promise
        let result = try await resolvePromise(promiseValue)
        
        guard let jsonString = result as? String else {
            throw JSError.invalidResult("Expected JSON string result")
        }
        
        return jsonString
    }

    /// Gets source info from a loaded source.
    /// - Parameter sourceId: The source identifier.
    /// - Returns: The source info.
    func getSourceInfo(sourceId: String) throws -> SourceInfo {
        guard let source = loadedSources[sourceId] else {
            throw JSError.functionNotFound("Source '\(sourceId)' not loaded")
        }

        guard let infoDict = source.toDictionary() as? [String: Any] else {
            throw JSError.invalidResult("Cannot read source properties")
        }

        return try parseSourceInfo(from: infoDict, sourceId: sourceId)
    }

    /// Unloads a source from the runtime.
    /// - Parameter sourceId: The source identifier to unload.
    func unloadSource(sourceId: String) {
        loadedSources.removeValue(forKey: sourceId)
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private nonisolated func setupContext() {
        // Set up exception handler
        context.exceptionHandler = { _, exception in
            print("[JSRuntime] Exception: \(exception?.toString() ?? "unknown")")
        }

        // Inject console.log
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("[JSRuntime] console.log: \(message)")
        }
        context.setObject(consoleLog,
                          forKeyedSubscript: "_consoleLog" as NSString)
        context.evaluateScript("var console = { log: _consoleLog, error: _consoleLog, warn: _consoleLog };")

        // Inject fetch function (will be handled via callbacks)
        setupFetchFunction()
    }

    private nonisolated func setupFetchFunction() {
        // Create a simplified fetch that stores requests for async handling
        // In a real implementation, this would bridge to the NetworkClient
        let fetchScript = """
        var _pendingFetches = {};
        var _fetchId = 0;

        function fetch(url, options) {
            return new Promise(function(resolve, reject) {
                var id = _fetchId++;
                _pendingFetches[id] = { resolve: resolve, reject: reject };
                _nativeFetch(id, url, JSON.stringify(options || {}));
            });
        }
        """
        context.evaluateScript(fetchScript)

        // Native fetch handler - this gets called from JS
        let nativeFetch: @convention(block) (Int, String, String) -> Void = { [weak self] id, urlString, optionsJson in
            Task {
                await self?.handleFetch(id: id, urlString: urlString, optionsJson: optionsJson)
            }
        }
        context.setObject(nativeFetch,
                          forKeyedSubscript: "_nativeFetch" as NSString)
    }

    private func handleFetch(id: Int, urlString: String, optionsJson: String) async {
        do {
            guard let url = URL(string: urlString) else {
                resolveFetch(id: id, error: "Invalid URL: \(urlString)")
                return
            }

            var headers: [String: String]?

            if let optionsData = optionsJson.data(using: .utf8),
               let options = try? JSONSerialization.jsonObject(with: optionsData) as? [String: Any],
               let headerDict = options["headers"] as? [String: String] {
                headers = headerDict
            }

            let data = try await networkClient.fetch(url: url, headers: headers)
            let text = String(data: data, encoding: .utf8) ?? ""

            resolveFetch(id: id, result: text)
        } catch {
            resolveFetch(id: id, error: error.localizedDescription)
        }
    }

    private nonisolated func resolveFetch(id: Int, result: String? = nil, error: String? = nil) {
        // This needs to run on the main thread to interact with JSContext
        DispatchQueue.main.async { [weak self] in
            Task { @MainActor in
                guard let context = self?.context else { return }

                if let error = error {
                    context.evaluateScript("""
                        if (_pendingFetches[\(id)]) {
                            _pendingFetches[\(id)].reject(new Error('\(error.replacingOccurrences(of: "'", with: "\\'"))'));
                            delete _pendingFetches[\(id)];
                        }
                    """)
                } else if let result = result {
                    let escapedResult = result
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "'", with: "\\'")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\r", with: "\\r")

                    context.evaluateScript("""
                        if (_pendingFetches[\(id)]) {
                            _pendingFetches[\(id)].resolve({
                                ok: true,
                                status: 200,
                                text: function() { return Promise.resolve('\(escapedResult)'); },
                                json: function() { return Promise.resolve(JSON.parse('\(escapedResult)')); }
                            });
                            delete _pendingFetches[\(id)];
                        }
                    """)
                }
            }
        }
    }

    private func isPromise(_ value: JSValue) -> Bool {
        guard let thenFunc = value.objectForKeyedSubscript("then"),
              !thenFunc.isUndefined else {
            return false
        }
        return true
    }

    private func resolvePromise(_ promise: JSValue) async throws -> Any {
        return try await withCheckedThrowingContinuation { continuation in
            let onFulfilled: @convention(block) (JSValue) -> Void = { result in
                continuation.resume(returning: result.toObject() ?? [:])
            }

            let onRejected: @convention(block) (JSValue) -> Void = { error in
                let message = error.toString() ?? "Promise rejected"
                continuation.resume(throwing: JSError.executionFailed(message))
            }

            promise.invokeMethod("then", withArguments: [
                unsafeBitCast(onFulfilled, to: JSValue.self),
                unsafeBitCast(onRejected, to: JSValue.self)
            ])
        }
    }

    private func parseSourceInfo(from dict: [String: Any], sourceId: String) throws -> SourceInfo {
        guard let name = dict["name"] as? String,
              let version = dict["version"] as? String,
              let baseURLString = dict["baseUrl"] as? String,
              let baseURL = URL(string: baseURLString) else {
            throw JSError.invalidResult("Missing required source properties (name, version, baseUrl)")
        }

        let iconURL: URL?
        if let iconString = dict["icon"] as? String {
            iconURL = URL(string: iconString)
        } else {
            iconURL = nil
        }

        return SourceInfo(id: sourceId,
                          name: name,
                          version: version,
                          language: dict["language"] as? String ?? "en",
                          baseURL: baseURL,
                          iconURL: iconURL,
                          isNSFW: dict["nsfw"] as? Bool ?? false,
                          description: dict["description"] as? String)
    }
}
