//
//  AniListService.swift
//  Miru
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - AniListService
//#################################################################################

/// Service for fetching anime data from the AniList GraphQL API.
final class AniListService: AniListServicing {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let apiEndpoint = URL(string: "https://graphql.anilist.co")!
        static let pageSize = 25
    }


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new AniList service.
    init() {}


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Fetches the weekly airing schedule for the current week.
    /// - Returns: An array of recommending items for anime airing this week.
    func fetchThisWeek() async throws -> [RecommendingItem] {
        let calendar = Calendar.current
        let now = Date()

        // Get start of today and end of week (7 days from now)
        let startOfToday = calendar.startOfDay(for: now)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday)!

        let startTime = Int(startOfToday.timeIntervalSince1970)
        let endTime = Int(endOfWeek.timeIntervalSince1970)

        let query = """
        query($page: Int, $perPage: Int, $startTime: Int, $endTime: Int) {
            Page(page: $page, perPage: $perPage) {
                airingSchedules(sort: [TIME], airingAt_greater: $startTime, airingAt_lesser: $endTime) {
                    id
                    episode
                    airingAt
                    media {
                        id
                        isAdult
                        episodes
                        description(asHtml: false)
                        coverImage {
                            large
                        }
                        title {
                            romaji
                            english
                        }
                    }
                }
            }
        }
        """

        let variables: [String: Any] = [
            "page": 1,
            "perPage": 50,
            "startTime": startTime,
            "endTime": endTime
        ]

        let response: AiringScheduleResponse = try await executeQuery(query, variables: variables)

        return response.data.page.airingSchedules
            .filter { !$0.media.isAdult }
            .map { schedule in
                let title = schedule.media.title.english ?? schedule.media.title.romaji
                let airDate = Date(timeIntervalSince1970: TimeInterval(schedule.airingAt))

                return RecommendingItem(id: "\(schedule.id)",
                                        title: title,
                                        subtitle: formatAirDate(airDate),
                                        caption: "Ep. \(schedule.episode)",
                                        isCaptionHighlighted: isToday(airDate),
                                        synopsis: schedule.media.description?.strippingHTML(),
                                        coverURL: URL(string: schedule.media.coverImage.large),
                                        anilistId: schedule.media.id,
                                        airDate: airDate,
                                        episodeNumber: schedule.episode,
                                        totalEpisodes: schedule.media.episodes)
            }
    }

    /// Fetches trending anime.
    /// - Returns: An array of recommending items for trending anime.
    func fetchTrending() async throws -> [RecommendingItem] {
        let query = """
        query($page: Int, $perPage: Int) {
            Page(page: $page, perPage: $perPage) {
                media(type: ANIME, sort: [TRENDING_DESC], isAdult: false) {
                    id
                    episodes
                    description(asHtml: false)
                    coverImage {
                        large
                    }
                    title {
                        romaji
                        english
                    }
                    status
                    studios(isMain: true) {
                        nodes {
                            name
                        }
                    }
                }
            }
        }
        """

        let variables: [String: Any] = [
            "page": 1,
            "perPage": Constants.pageSize
        ]

        let response: MediaPageResponse = try await executeQuery(query, variables: variables)

        return response.data.page.media.map { media in
            let title = media.title.english ?? media.title.romaji
            let studio = media.studios?.nodes.first?.name

            return RecommendingItem(id: "\(media.id)",
                                    title: title,
                                    subtitle: studio,
                                    synopsis: media.description?.strippingHTML(),
                                    coverURL: URL(string: media.coverImage.large),
                                    anilistId: media.id,
                                    totalEpisodes: media.episodes)
        }
    }

    /// Fetches seasonal anime for the current season.
    /// - Returns: An array of recommending items for seasonal anime.
    func fetchSeasonal() async throws -> [RecommendingItem] {
        let (season, year) = currentSeason()

        let query = """
        query($page: Int, $perPage: Int, $season: MediaSeason, $seasonYear: Int) {
            Page(page: $page, perPage: $perPage) {
                media(type: ANIME, season: $season, seasonYear: $seasonYear, sort: [POPULARITY_DESC], isAdult: false) {
                    id
                    episodes
                    description(asHtml: false)
                    coverImage {
                        large
                    }
                    title {
                        romaji
                        english
                    }
                    status
                    studios(isMain: true) {
                        nodes {
                            name
                        }
                    }
                }
            }
        }
        """

        let variables: [String: Any] = [
            "page": 1,
            "perPage": Constants.pageSize,
            "season": season,
            "seasonYear": year
        ]

        let response: MediaPageResponse = try await executeQuery(query, variables: variables)

        return response.data.page.media.map { media in
            let title = media.title.english ?? media.title.romaji
            let studio = media.studios?.nodes.first?.name

            return RecommendingItem(id: "\(media.id)",
                                    title: title,
                                    subtitle: studio,
                                    synopsis: media.description?.strippingHTML(),
                                    coverURL: URL(string: media.coverImage.large),
                                    anilistId: media.id,
                                    totalEpisodes: media.episodes)
        }
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func executeQuery<T: Decodable>(_ query: String, variables: [String: Any]) async throws -> T {
        var request = URLRequest(url: Constants.apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AniListError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw AniListError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func formatAirDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func currentSeason() -> (season: String, year: Int) {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        let season: String
        switch month {
        case 1...3:
            season = "WINTER"
        case 4...6:
            season = "SPRING"
        case 7...9:
            season = "SUMMER"
        default:
            season = "FALL"
        }

        return (season, year)
    }
}


//#################################################################################
// MARK: - AniListError
//#################################################################################

/// Errors that can occur when communicating with AniList.
enum AniListError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AniList"
        case .httpError(let code):
            return "HTTP error \(code) from AniList"
        case .decodingError(let error):
            return "Failed to decode AniList response: \(error.localizedDescription)"
        }
    }
}


//#################################################################################
// MARK: - AniList Response Models
//#################################################################################

private struct AiringScheduleResponse: Decodable {
    let data: DataContainer

    struct DataContainer: Decodable {
        let page: Page

        enum CodingKeys: String, CodingKey {
            case page = "Page"
        }
    }

    struct Page: Decodable {
        let airingSchedules: [AiringSchedule]
    }

    struct AiringSchedule: Decodable {
        let id: Int
        let episode: Int
        let airingAt: Int
        let media: Media
    }

    struct Media: Decodable {
        let id: Int
        let isAdult: Bool
        let episodes: Int?
        let description: String?
        let coverImage: CoverImage
        let title: Title
    }

    struct CoverImage: Decodable {
        let large: String
    }

    struct Title: Decodable {
        let romaji: String
        let english: String?
    }
}


//#################################################################################
// MARK: - MediaPageResponse
//#################################################################################

private struct MediaPageResponse: Decodable {
    let data: DataContainer

    struct DataContainer: Decodable {
        let page: Page

        enum CodingKeys: String, CodingKey {
            case page = "Page"
        }
    }

    struct Page: Decodable {
        let media: [Media]
    }

    struct Media: Decodable {
        let id: Int
        let episodes: Int?
        let description: String?
        let coverImage: CoverImage
        let title: Title
        let status: String?
        let studios: Studios?
    }

    struct CoverImage: Decodable {
        let large: String
    }

    struct Title: Decodable {
        let romaji: String
        let english: String?
    }

    struct Studios: Decodable {
        let nodes: [Studio]
    }

    struct Studio: Decodable {
        let name: String
    }
}


//#################################################################################
// MARK: - String Extension
//#################################################################################

private extension String {
    /// Strips HTML tags from a string using regex.
    func strippingHTML() -> String {
        self.replacingOccurrences(of: "<[^>]+>",
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
