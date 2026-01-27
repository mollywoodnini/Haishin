//
//  JSRuntime.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation
import JavaScriptCore
import WebKit

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

    private let context: JSContext
    private let networkClient: NetworkClient
    private let cookieStorage: HTTPCookieStorage
    private var loadedSources: [String: JSValue] = [:]
    private var resolvedHosts: Set<String> = []


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new JavaScript runtime.
    /// - Parameters:
    ///   - networkClient: Network client for HTTP requests from JS.
    ///   - cookieStorage: Cookie storage shared with NetworkClient and ChallengeResolver.
    init(networkClient: NetworkClient,
         cookieStorage: HTTPCookieStorage = .shared) throws {
        guard let context = JSContext() else {
            throw JSError.contextCreationFailed
        }

        self.context = context
        self.networkClient = networkClient
        self.cookieStorage = cookieStorage

        // We pass 'self' and 'context' to a helper.
        // Swift 6 is happy because we are explicitly defining how the bridge works.
        Self.configure(context, for: self)
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads a source script into the runtime.
    /// - Parameters:
    ///   - script: The JavaScript source code.
    ///   - sourceId: Unique identifier for the source.
    func loadSource(script: String, sourceId: String) throws {
        Log.debug(.sources, "Loading source with ID: \(sourceId)")
        Log.debug(.sources, "Script length: \(script.count) characters")
        
        context.evaluateScript(script)
        
        Log.debug(.sources, "Script evaluated")

        if let exception = context.exception {
            Log.error(.sources, "JavaScript exception: \(exception.toString() ?? "unknown")")
            throw JSError.scriptLoadFailed(exception.toString() ?? "Unknown error")
        }

        Log.debug(.sources, "Checking for 'source' object in global context")
        guard let sourceObject = context.objectForKeyedSubscript("source"),
              !sourceObject.isUndefined else {
            Log.error(.sources, "No 'source' object found!")
            throw JSError.scriptLoadFailed("No 'source' object exported from script")
        }
        
        Log.debug(.sources, "Found source object: \(sourceObject)")
        loadedSources[sourceId] = sourceObject
        Log.info(.sources, "Source loaded successfully")
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
        Log.debug(.sources, "Getting source info for: \(sourceId)")
        
        guard let source = loadedSources[sourceId] else {
            Log.error(.sources, "Source not found in loadedSources")
            throw JSError.functionNotFound("Source '\(sourceId)' not loaded")
        }

        Log.debug(.sources, "Converting source to dictionary")
        guard let infoDict = source.toDictionary() as? [String: Any] else {
            Log.error(.sources, "Cannot convert source to dictionary")
            throw JSError.invalidResult("Cannot read source properties")
        }

        Log.debug(.sources, "Dictionary keys: \(infoDict.keys.joined(separator: ", "))")
        let info = try parseSourceInfo(from: infoDict, sourceId: sourceId)
        Log.info(.sources, "Successfully parsed source info: \(info.name) v\(info.version)")
        return info
    }

    /// Unloads a source from the runtime.
    /// - Parameter sourceId: The source identifier to unload.
    func unloadSource(sourceId: String) {
        loadedSources.removeValue(forKey: sourceId)
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    nonisolated private static func configure(_ context: JSContext, for runtime: JSRuntime) {        // Set up exception handler
        context.exceptionHandler = { _, exception in
            Log.error(.sources, "Exception: \(exception?.toString() ?? "unknown")")
        }

        // Inject console.log
        let consoleLog: @convention(block) (String) -> Void = { message in
            Log.debug(.sources, "console.log: \(message)")
        }
        context.setObject(consoleLog,
                          forKeyedSubscript: "_consoleLog" as NSString)
        context.evaluateScript("var console = { log: _consoleLog, error: _consoleLog, warn: _consoleLog };")

        // Inject fetch function (will be handled via callbacks)
        setupFetch(context, runtime: runtime)
    }

    nonisolated private static func setupFetch(_ context: JSContext, runtime: JSRuntime) {
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
        let nativeFetch: @convention(block) (Int, String, String) -> Void = { [weak runtime] id, url, options in
            Task {
                await runtime?.handleFetch(id: id, urlString: url, optionsJson: options)
            }
        }
        context.setObject(nativeFetch,
                          forKeyedSubscript: "_nativeFetch" as NSString)
    }

    private func handleFetch(id: Int, urlString: String, optionsJson: String) async {
        Log.debug(.sources, "========================================")
        Log.debug(.sources, "handleFetch called")
        Log.debug(.sources, "URL: \(urlString)")
        Log.debug(.sources, "Options: \(optionsJson)")
        
        do {
            guard let url = URL(string: urlString) else {
                Log.error(.sources, "Invalid URL")
                resolveFetch(id: id, error: "Invalid URL: \(urlString)")
                return
            }

            var headers: [String: String]?

            if let optionsData = optionsJson.data(using: .utf8),
               let options = try? JSONSerialization.jsonObject(with: optionsData) as? [String: Any],
               let headerDict = options["headers"] as? [String: String] {
                headers = headerDict
                Log.debug(.sources, "Parsed headers: \(headerDict)")
            }
            
            // Log cookies currently in storage for this host
            if let host = url.host {
                let hostCookies = cookieStorage.cookies?.filter { 
                    $0.domain.contains(host) || host.contains($0.domain.replacingOccurrences(of: ".", with: "")) 
                } ?? []
                Log.debug(.sources, "Cookies in storage for \(host): \(hostCookies.count)")
                for cookie in hostCookies {
                    Log.debug(.sources, "  \(cookie.name)=\(cookie.value)")
                }
            }

            // Check if we need to resolve a challenge for this host first
            if let host = url.host, !resolvedHosts.contains(host) {
                Log.debug(.sources, "Host '\(host)' not yet resolved, making initial request...")
                
                // Try the request first - use fetchWithStatus to get body even on 403
                let (data, statusCode) = try await networkClient.fetchWithStatus(url: url, headers: headers)
                let text = String(data: data, encoding: .utf8) ?? ""
                
                Log.debug(.sources, "Response status: \(statusCode)")
                Log.debug(.sources, "Response length: \(text.count) chars")
                Log.debug(.sources, "Response preview: \(String(text.prefix(300)))...")

                // Check if the response is a challenge page (typically 403 with challenge HTML)
                if statusCode == 403 || ChallengeResolver.isChallengePage(text) {
                    Log.notice(.sources, "*** CHALLENGE PAGE DETECTED for \(host) (status: \(statusCode)) ***")
                    Log.debug(.sources, "Starting challenge resolution...")

                    // Resolve the challenge using WebView (must be on MainActor)
                    try await resolveChallengeOnMainActor(for: url)

                    // Mark host as resolved
                    resolvedHosts.insert(host)
                    Log.info(.sources, "Host '\(host)' marked as resolved")
                    
                    // Log cookies after resolution
                    let hostCookies = cookieStorage.cookies?.filter { 
                        $0.domain.contains(host) || host.contains($0.domain.replacingOccurrences(of: ".", with: "")) 
                    } ?? []
                    Log.debug(.sources, "Cookies after resolution for \(host): \(hostCookies.count)")
                    for cookie in hostCookies {
                        Log.debug(.sources, "  \(cookie.name)=\(cookie.value)")
                    }

                    // Retry the original request with the new cookies
                    Log.debug(.sources, "Retrying original request...")
                    let (retryData, retryStatus) = try await networkClient.fetchWithStatus(url: url, headers: headers)
                    let retryText = String(data: retryData, encoding: .utf8) ?? ""
                    Log.debug(.sources, "Retry response status: \(retryStatus)")
                    Log.debug(.sources, "Retry response length: \(retryText.count) chars")
                    Log.debug(.sources, "Retry response preview: \(String(retryText.prefix(300)))...")
                    
                    // Check if retry also got a challenge
                    if retryStatus == 403 || ChallengeResolver.isChallengePage(retryText) {
                        Log.warning(.sources, "Retry still got challenge page!")
                    }
                    
                    resolveFetch(id: id, result: retryText)
                } else if statusCode >= 200 && statusCode < 300 {
                    // Success, not a challenge page
                    Log.debug(.sources, "Not a challenge page, returning result")
                    resolveFetch(id: id, result: text)
                } else {
                    // Other error
                    Log.error(.sources, "HTTP error: \(statusCode)")
                    resolveFetch(id: id, error: "HTTP error with status code: \(statusCode)")
                }
            } else {
                // Host already resolved or no host, just fetch
                Log.debug(.sources, "Host already resolved or no host, fetching directly...")
                let (data, statusCode) = try await networkClient.fetchWithStatus(url: url, headers: headers)
                let text = String(data: data, encoding: .utf8) ?? ""
                Log.debug(.sources, "Response status: \(statusCode)")
                Log.debug(.sources, "Response length: \(text.count) chars")
                
                if statusCode >= 200 && statusCode < 300 {
                    resolveFetch(id: id, result: text)
                } else {
                    resolveFetch(id: id, error: "HTTP error with status code: \(statusCode)")
                }
            }
        } catch {
            Log.error(.sources, "Error: \(error.localizedDescription)")
            resolveFetch(id: id, error: error.localizedDescription)
        }
        Log.debug(.sources, "========================================")
    }
    
    private func resolveFetch(id: Int, result: String? = nil, error: String? = nil) {
        // We use Task { @MainActor } to ensure we are on the thread where JSContext lives.
        // In many apps, JSContext must be managed on a single consistent thread (usually Main).
        Task { @MainActor in
            guard !Task.isCancelled else { return }
            
            // Inside this block, we are on the MainActor.
            // If JSContext was created on the Main Thread, this is safe.
            if let error {
                let escapedError = error.replacingOccurrences(of: "'", with: "\\'")
                context.evaluateScript("""
                    if (_pendingFetches[\(id)]) {
                        _pendingFetches[\(id)].reject(new Error('\(escapedError)'));
                        delete _pendingFetches[\(id)];
                    }
                """)
            } else if let result {
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

        // Use the 'id' from the JavaScript source, fallback to sourceId parameter if not present
        let actualId = dict["id"] as? String ?? sourceId

        return SourceInfo(id: actualId,
                          name: name,
                          version: version,
                          language: dict["language"] as? String ?? "en",
                          baseURL: baseURL,
                          iconURL: iconURL,
                          isNSFW: dict["nsfw"] as? Bool ?? false,
                          description: dict["description"] as? String)
    }

    @MainActor
    private func resolveChallengeOnMainActor(for url: URL) async throws {
        let resolver = ChallengeResolver(cookieStorage: cookieStorage)
        _ = try await resolver.resolveChallenge(for: url)
    }
}
