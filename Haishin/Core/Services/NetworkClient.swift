//
//  NetworkClient.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - NetworkClientProtocol
//#################################################################################

/// Protocol for network operations, enabling dependency injection and testing.
protocol NetworkClientProtocol: Sendable {
    
    /// Fetches data from a URL.
    /// - Parameters:
    ///   - url: The URL to fetch.
    ///   - headers: Optional HTTP headers.
    /// - Returns: The raw data from the response.
    func fetch(url: URL, headers: [String: String]?) async throws -> Data
    
    /// Fetches and decodes JSON from a URL.
    /// - Parameters:
    ///   - url: The URL to fetch.
    ///   - type: The type to decode.
    ///   - headers: Optional HTTP headers.
    /// - Returns: The decoded object.
    func fetchJSON<T: Decodable & Sendable>(url: URL, type: T.Type, headers: [String: String]?) async throws -> T
    
    /// Fetches HTML content from a URL as a string.
    /// - Parameters:
    ///   - url: The URL to fetch.
    ///   - headers: Optional HTTP headers.
    /// - Returns: The HTML content as a string.
    func fetchHTML(url: URL, headers: [String: String]?) async throws -> String
    
    /// Posts data to a URL.
    /// - Parameters:
    ///   - url: The URL to post to.
    ///   - body: The request body data.
    ///   - headers: Optional HTTP headers.
    /// - Returns: The raw data from the response.
    func post(url: URL, body: Data?, headers: [String: String]?) async throws -> Data
}


//#################################################################################
// MARK: - NetworkClient
//#################################################################################

/// A simple async/await network client for making HTTP requests.
actor NetworkClient: NetworkClientProtocol {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let defaultTimeout: TimeInterval = 30
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let session: URLSession
    private let decoder: JSONDecoder
    private let cookieStorage: HTTPCookieStorage


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new network client.
    /// - Parameters:
    ///   - configuration: URL session configuration. Defaults to `.default`.
    ///   - cookieStorage: Cookie storage for persisting cookies. Defaults to `.shared`.
    init(configuration: URLSessionConfiguration = .default,
         cookieStorage: HTTPCookieStorage = .shared) {
        configuration.timeoutIntervalForRequest = Constants.defaultTimeout
        configuration.httpCookieStorage = cookieStorage
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        self.session = URLSession(configuration: configuration)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.cookieStorage = cookieStorage
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    func fetch(url: URL, headers: [String: String]? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    /// Fetches data from a URL, returning both data and status code.
    /// This method does NOT throw on non-2xx status codes, allowing caller to handle challenge pages.
    /// - Parameters:
    ///   - url: The URL to fetch.
    ///   - headers: Optional HTTP headers.
    /// - Returns: A tuple containing the raw data and HTTP status code.
    func fetchWithStatus(url: URL, headers: [String: String]? = nil) async throws -> (data: Data, statusCode: Int) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        return (data, httpResponse.statusCode)
    }

    func fetchJSON<T: Decodable & Sendable>(url: URL,
                                            type: T.Type,
                                            headers: [String: String]? = nil) async throws -> T {
        let data = try await fetch(url: url, headers: headers)
        return try decoder.decode(T.self, from: data)
    }

    func fetchHTML(url: URL, headers: [String: String]? = nil) async throws -> String {
        let data = try await fetch(url: url, headers: headers)

        guard let html = String(data: data, encoding: .utf8) else {
            throw NetworkError.decodingFailed
        }

        return html
    }

    func post(url: URL, body: Data?, headers: [String: String]? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }
}


//#################################################################################
// MARK: - NetworkError
//#################################################################################

/// Errors that can occur during network operations.
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        case .decodingFailed:
            return "Failed to decode the response."
        case .noData:
            return "No data was received."
        }
    }
}
