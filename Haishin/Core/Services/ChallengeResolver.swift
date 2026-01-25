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
        print("[ChallengeResolver] Initialized with cookie storage: \(cookieStorage)")
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
            print("[ChallengeResolver] ERROR: Invalid URL - no host: \(url)")
            throw ChallengeError.navigationFailed("Invalid URL: no host")
        }

        targetHost = host
        checkCount = 0
        
        print("[ChallengeResolver] ========================================")
        print("[ChallengeResolver] Starting challenge resolution")
        print("[ChallengeResolver] URL: \(url.absoluteString)")
        print("[ChallengeResolver] Host: \(host)")
        print("[ChallengeResolver] Timeout: \(timeout)s")
        print("[ChallengeResolver] ========================================")

        // Create WebView configuration
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        print("[ChallengeResolver] Created WebView configuration")
        print("[ChallengeResolver] Using default data store (persistent)")

        // Create WebView
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844),
                                configuration: configuration)
        webView.navigationDelegate = self
        webView.customUserAgent = Constants.userAgent
        self.webView = webView

        print("[ChallengeResolver] Created WebView with user agent: \(Constants.userAgent)")

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
            print("[ChallengeResolver] Loading request...")
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
                    print("[ChallengeResolver] Detected challenge indicator: '\(indicator)'")
                }
            }
        }
        
        return isChallenge
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func handleTimeout() {
        print("[ChallengeResolver] ========================================")
        print("[ChallengeResolver] TIMEOUT after \(Constants.defaultTimeout)s")
        print("[ChallengeResolver] Check count was: \(checkCount)")
        print("[ChallengeResolver] ========================================")
        
        // Before timing out, let's try to get whatever cookies we have
        Task { @MainActor in
            await self.extractAndSyncCookies(forceComplete: true)
        }
    }

    private func cleanup() {
        print("[ChallengeResolver] Cleaning up...")
        timeoutTask?.cancel()
        timeoutTask = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
    }

    private func extractAndSyncCookies(forceComplete: Bool = false) async {
        guard let webView = webView else {
            print("[ChallengeResolver] ERROR: WebView is nil during cookie extraction")
            if forceComplete {
                cleanup()
                continuation?.resume(throwing: ChallengeError.timeout)
                continuation = nil
            }
            return
        }

        print("[ChallengeResolver] ----------------------------------------")
        print("[ChallengeResolver] Extracting cookies...")
        
        let dataStore = webView.configuration.websiteDataStore
        let cookies = await dataStore.httpCookieStore.allCookies()
        
        print("[ChallengeResolver] Total cookies in WebView: \(cookies.count)")
        
        // Log all cookies
        for cookie in cookies {
            print("[ChallengeResolver]   Cookie: \(cookie.name)=\(cookie.value.prefix(30))... (domain: \(cookie.domain), path: \(cookie.path))")
        }

        // Filter cookies for our target host and sync to HTTPCookieStorage
        let relevantCookies = cookies.filter { cookie in
            let domainMatch = cookie.domain.contains(targetHost) || 
                              targetHost.contains(cookie.domain.replacingOccurrences(of: ".", with: ""))
            return domainMatch
        }

        print("[ChallengeResolver] Relevant cookies for '\(targetHost)': \(relevantCookies.count)")

        for cookie in relevantCookies {
            cookieStorage.setCookie(cookie)
            print("[ChallengeResolver] SYNCED: \(cookie.name)=\(cookie.value)")
        }
        
        // Also check existing cookies in storage
        if let existingCookies = cookieStorage.cookies {
            print("[ChallengeResolver] HTTPCookieStorage now has \(existingCookies.count) total cookies")
            let hostCookies = existingCookies.filter { $0.domain.contains(targetHost) || targetHost.contains($0.domain.replacingOccurrences(of: ".", with: "")) }
            print("[ChallengeResolver] Cookies for \(targetHost) in storage: \(hostCookies.count)")
            for cookie in hostCookies {
                print("[ChallengeResolver]   Storage: \(cookie.name)=\(cookie.value)")
            }
        }
        
        print("[ChallengeResolver] ----------------------------------------")

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
            print("[ChallengeResolver] ERROR: WebView is nil during challenge check")
            return
        }
        
        checkCount += 1
        print("[ChallengeResolver] Challenge check #\(checkCount)")

        // Check if we're still on a challenge page
        webView.evaluateJavaScript("document.title") { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                print("[ChallengeResolver] Error getting title: \(error.localizedDescription)")
            }
            
            let title = result as? String ?? ""
            print("[ChallengeResolver] Current page title: '\(title)'")

            // If the title is still "DDoS-Guard" or similar, we're still solving
            if title.lowercased().contains("ddos") || title.lowercased().contains("checking") {
                print("[ChallengeResolver] Still on challenge page, scheduling next check...")
                // Schedule another check
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(Constants.challengeCheckInterval * 1_000_000_000))
                    self.checkForChallengeCompletion()
                }
            } else {
                // Challenge appears to be solved, extract cookies
                print("[ChallengeResolver] Title changed - challenge may be solved!")
                Task { @MainActor in
                    await self.extractAndSyncCookies()
                }
            }
        }
    }
    
    private func logCurrentURL() {
        guard let webView = webView else { return }
        print("[ChallengeResolver] Current WebView URL: \(webView.url?.absoluteString ?? "nil")")
    }
}


//#################################################################################
// MARK: - WKNavigationDelegate
//#################################################################################

extension ChallengeResolver: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("[ChallengeResolver] Started provisional navigation to: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("[ChallengeResolver] Navigation committed: \(webView.url?.absoluteString ?? "unknown")")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[ChallengeResolver] ========================================")
        print("[ChallengeResolver] Navigation FINISHED")
        print("[ChallengeResolver] Final URL: \(webView.url?.absoluteString ?? "unknown")")
        logCurrentURL()

        // Check the page content to see if we're past the challenge
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            guard let self = self else { return }

            if let html = result as? String {
                let previewLength = min(500, html.count)
                let preview = String(html.prefix(previewLength))
                print("[ChallengeResolver] Page HTML preview: \(preview)...")
                print("[ChallengeResolver] Total HTML length: \(html.count) chars")
                
                if ChallengeResolver.isChallengePage(html) {
                    print("[ChallengeResolver] Still on challenge page, waiting for JS to complete...")
                    // Continue checking periodically
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(Constants.challengeCheckInterval * 1_000_000_000))
                        self.checkForChallengeCompletion()
                    }
                } else {
                    // Challenge solved!
                    print("[ChallengeResolver] SUCCESS: Challenge appears solved!")
                    Task { @MainActor in
                        await self.extractAndSyncCookies()
                    }
                }
            } else if let error = error {
                print("[ChallengeResolver] ERROR getting page content: \(error)")
                self.cleanup()
                self.continuation?.resume(throwing: ChallengeError.navigationFailed(error.localizedDescription))
                self.continuation = nil
            }
        }
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        print("[ChallengeResolver] ERROR: Navigation failed: \(error.localizedDescription)")
        print("[ChallengeResolver] Error details: \(error)")
        cleanup()
        continuation?.resume(throwing: ChallengeError.navigationFailed(error.localizedDescription))
        continuation = nil
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        print("[ChallengeResolver] ERROR: Provisional navigation failed: \(error.localizedDescription)")
        print("[ChallengeResolver] Error details: \(error)")
        cleanup()
        continuation?.resume(throwing: ChallengeError.navigationFailed(error.localizedDescription))
        continuation = nil
    }
    
    func webView(_ webView: WKWebView,
                 didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("[ChallengeResolver] Server redirect to: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let httpResponse = navigationResponse.response as? HTTPURLResponse {
            print("[ChallengeResolver] Response status: \(httpResponse.statusCode)")
            print("[ChallengeResolver] Response URL: \(httpResponse.url?.absoluteString ?? "unknown")")
            
            // Log response headers
            for (key, value) in httpResponse.allHeaderFields {
                if let keyString = key as? String {
                    print("[ChallengeResolver]   Header: \(keyString): \(value)")
                }
            }
        }
        decisionHandler(.allow)
    }
}
