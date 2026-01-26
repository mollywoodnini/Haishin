//
//  ChallengeResolver.swift
//  Haishin
//
//  Created by Haishin on 25.01.26.
//

import Foundation
import WebKit

/// Resolves JavaScript-based challenges (like DDoS-Guard) by loading pages in a WKWebView.
/// This allows the WebView to execute JavaScript challenges and capture the resulting cookies.
@MainActor
final class ChallengeResolver: NSObject {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let defaultTimeout: TimeInterval = 30
        static let challengeCheckInterval: TimeInterval = 0.5
        static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }


    //#################################################################################
    // MARK: - Types
    //#################################################################################

    /// Errors that can occur during challenge resolution.
    enum ChallengeError: LocalizedError {
        case timeout
        case navigationFailed(String)
        case challengeNotSolved

        var errorDescription: String? {
            switch self {
            case .timeout:
                return "Challenge resolution timed out."
            case .navigationFailed(let message):
                return "Navigation failed: \(message)"
            case .challengeNotSolved:
                return "Failed to solve the JavaScript challenge."
            }
        }
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<[HTTPCookie], Error>?
    private var targetHost: String = ""
    private var timeoutTask: Task<Void, Never>?
    private let cookieStorage: HTTPCookieStorage
    private var checkCount: Int = 0


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new challenge resolver.
    /// - Parameter cookieStorage: Cookie storage to sync cookies to. Defaults to `.shared`.
    init(cookieStorage: HTTPCookieStorage = .shared) {
        self.cookieStorage = cookieStorage
        super.init()
        Log.debug(.network, "ChallengeResolver initialized with cookie storage: \(String(describing: cookieStorage))")
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Resolves a JavaScript challenge by loading the URL in a WebView.
    /// - Parameters:
    ///   - url: The URL that triggered the challenge.
    ///   - timeout: Maximum time to wait for the challenge to be solved.
    /// - Returns: The cookies obtained after solving the challenge.
    func resolveChallenge(for url: URL, timeout: TimeInterval = Constants.defaultTimeout) async throws -> [HTTPCookie] {
        guard let host = url.host else {
            Log.error(.network, "ChallengeResolver: Invalid URL - no host: \(url)")
            throw ChallengeError.navigationFailed("Invalid URL: no host")
        }

        targetHost = host
        checkCount = 0
        
        Log.info(.network, "ChallengeResolver: Starting challenge resolution for \(url.absoluteString)")
        Log.debug(.network, "ChallengeResolver: Host: \(host), Timeout: \(timeout)s")

        // Create WebView configuration
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        Log.debug(.network, "ChallengeResolver: Created WebView configuration with default data store")

        // Create WebView
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                configuration: configuration)
        webView.navigationDelegate = self
        webView.customUserAgent = Constants.userAgent
        self.webView = webView

        Log.debug(.network, "ChallengeResolver: Created WebView with user agent")

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            // Start timeout timer
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if self.continuation != nil {
                    self.handleTimeout()
                }
            }

            // Load the URL
            let request = URLRequest(url: url)
            Log.debug(.network, "ChallengeResolver: Loading request...")
            webView.load(request)
        }
    }

    /// Checks if a response appears to be a DDoS-Guard or similar challenge.
    /// - Parameter html: The HTML content of the response.
    /// - Returns: True if the response is a challenge page.
    nonisolated static func isChallengePage(_ html: String) -> Bool {
        let challengeIndicators = [
            "DDoS-Guard",
            "ddos-guard",
            "js-challenge",
            "checking your browser",
            "Please wait while we verify",
            "Just a moment...",
            "Cloudflare",
            "challenge-platform"
        ]

        let lowercased = html.lowercased()
        let isChallenge = challengeIndicators.contains { indicator in
            lowercased.contains(indicator.lowercased())
        }
        
        if isChallenge {
            for indicator in challengeIndicators {
                if lowercased.contains(indicator.lowercased()) {
                    Log.debug(.network, "ChallengeResolver: Detected challenge indicator: '\(indicator)'")
                }
            }
        }
        
        return isChallenge
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func handleTimeout() {
        Log.warning(.network, "ChallengeResolver: TIMEOUT after \(Constants.defaultTimeout)s, check count was: \(self.checkCount)")
        
        // Before timing out, let's try to get whatever cookies we have
        Task { @MainActor in
            await self.extractAndSyncCookies(forceComplete: true)
        }
    }

    private func cleanup() {
        Log.debug(.network, "ChallengeResolver: Cleaning up...")
        timeoutTask?.cancel()
        timeoutTask = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
    }

    private func extractAndSyncCookies(forceComplete: Bool = false) async {
        guard let webView = webView else {
            Log.error(.network, "ChallengeResolver: WebView is nil during cookie extraction")
            if forceComplete {
                cleanup()
                continuation?.resume(throwing: ChallengeError.timeout)
                continuation = nil
            }
            return
        }

        Log.debug(.network, "ChallengeResolver: Extracting cookies...")
        
        let dataStore = webView.configuration.websiteDataStore
        let cookies = await dataStore.httpCookieStore.allCookies()
        
        Log.debug(.network, "ChallengeResolver: Total cookies in WebView: \(cookies.count)")

        // Filter cookies for our target host and sync to HTTPCookieStorage
        let relevantCookies = cookies.filter { cookie in
            let domainMatch = cookie.domain.contains(targetHost) || 
                              targetHost.contains(cookie.domain.replacingOccurrences(of: ".", with: ""))
            return domainMatch
        }

        Log.info(.network, "ChallengeResolver: Found \(relevantCookies.count) relevant cookies for '\(self.targetHost)'")

        for cookie in relevantCookies {
            cookieStorage.setCookie(cookie)
            Log.debug(.network, "ChallengeResolver: SYNCED: \(cookie.name)=\(cookie.value)")
        }
        
        // Also check existing cookies in storage
        if let existingCookies = cookieStorage.cookies {
            let hostCookies = existingCookies.filter { $0.domain.contains(targetHost) || targetHost.contains($0.domain.replacingOccurrences(of: ".", with: "")) }
            Log.debug(.network, "ChallengeResolver: HTTPCookieStorage now has \(existingCookies.count) total, \(hostCookies.count) for \(self.targetHost)")
        }

        cleanup()
        
        if forceComplete && relevantCookies.isEmpty {
            continuation?.resume(throwing: ChallengeError.timeout)
        } else {
            continuation?.resume(returning: relevantCookies)
        }
        continuation = nil
    }

    private func checkForChallengeCompletion() {
        guard let webView = webView else {
            Log.error(.network, "ChallengeResolver: WebView is nil during challenge check")
            return
        }
        
        checkCount += 1
        Log.debug(.network, "ChallengeResolver: Challenge check #\(self.checkCount)")

        // Check if we're still on a challenge page
        webView.evaluateJavaScript("document.title") { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                Log.debug(.network, "ChallengeResolver: Error getting title: \(error.localizedDescription)")
            }
            
            let title = result as? String ?? ""
            Log.debug(.network, "ChallengeResolver: Current page title: '\(title)'")

            // If the title is still "DDoS-Guard" or similar, we're still solving
            if title.lowercased().contains("ddos") || title.lowercased().contains("checking") {
                Log.debug(.network, "ChallengeResolver: Still on challenge page, scheduling next check...")
                // Schedule another check
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(Constants.challengeCheckInterval * 1_000_000_000))
                    self.checkForChallengeCompletion()
                }
            } else {
                // Challenge appears to be solved, extract cookies
                Log.info(.network, "ChallengeResolver: Title changed - challenge may be solved!")
                Task { @MainActor in
                    await self.extractAndSyncCookies()
                }
            }
        }
    }
    
    private func logCurrentURL() {
        guard let webView = webView else { return }
        Log.debug(.network, "ChallengeResolver: Current WebView URL: \(webView.url?.absoluteString ?? "nil")")
    }
}


//#################################################################################
// MARK: - WKNavigationDelegate
//#################################################################################

extension ChallengeResolver: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Log.debug(.network, "ChallengeResolver: Started provisional navigation to: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        Log.debug(.network, "ChallengeResolver: Navigation committed: \(webView.url?.absoluteString ?? "unknown")")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Log.info(.network, "ChallengeResolver: Navigation FINISHED - URL: \(webView.url?.absoluteString ?? "unknown")")
        logCurrentURL()

        // Check the page content to see if we're past the challenge
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            guard let self = self else { return }

            if let html = result as? String {
                Log.debug(.network, "ChallengeResolver: Page HTML length: \(html.count) chars")
                
                if ChallengeResolver.isChallengePage(html) {
                    Log.debug(.network, "ChallengeResolver: Still on challenge page, waiting for JS to complete...")
                    // Continue checking periodically
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(Constants.challengeCheckInterval * 1_000_000_000))
                        self.checkForChallengeCompletion()
                    }
                } else {
                    // Challenge solved!
                    Log.notice(.network, "ChallengeResolver: SUCCESS - Challenge appears solved!")
                    Task { @MainActor in
                        await self.extractAndSyncCookies()
                    }
                }
            } else if let error = error {
                Log.error(.network, "ChallengeResolver: Error getting page content: \(error)")
                self.cleanup()
                self.continuation?.resume(throwing: ChallengeError.navigationFailed(error.localizedDescription))
                self.continuation = nil
            }
        }
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        Log.error(.network, "ChallengeResolver: Navigation failed: \(error.localizedDescription)")
        cleanup()
        continuation?.resume(throwing: ChallengeError.navigationFailed(error.localizedDescription))
        continuation = nil
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        Log.error(.network, "ChallengeResolver: Provisional navigation failed: \(error.localizedDescription)")
        cleanup()
        continuation?.resume(throwing: ChallengeError.navigationFailed(error.localizedDescription))
        continuation = nil
    }
    
    func webView(_ webView: WKWebView,
                 didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        Log.debug(.network, "ChallengeResolver: Server redirect to: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let httpResponse = navigationResponse.response as? HTTPURLResponse {
            Log.debug(.network, "ChallengeResolver: Response status: \(httpResponse.statusCode) for \(httpResponse.url?.absoluteString ?? "unknown")")
        }
        decisionHandler(.allow)
    }
}
