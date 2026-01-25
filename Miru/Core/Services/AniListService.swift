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
    @MainActor
    init() {}


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Fetches the weekly airing schedule for the current week.
    /// - Parameter showNSFW: Whether to include NSFW (adult) content.
    /// - Returns: An array of recommending items for anime airing this week.
    func fetchThisWeek(showNSFW: Bool = false) async throws -> [RecommendingItem] {
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
            .filter { showNSFW || !$0.media.isAdult }
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
    /// - Parameters:
    ///   - page: The page number to fetch (1-indexed).
    ///   - showNSFW: Whether to include NSFW (adult) content.
    /// - Returns: A paginated response containing trending anime.
    func fetchTrending(page: Int = 1, showNSFW: Bool = false) async throws -> PaginatedResponse {
        let query = """
        query($page: Int, $perPage: Int, $isAdult: Boolean) {
            Page(page: $page, perPage: $perPage) {
                pageInfo {
                    hasNextPage
                    currentPage
                }
                media(type: ANIME, sort: [TRENDING_DESC, POPULARITY_DESC], isAdult: $isAdult) {
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
            "page": page,
            "perPage": Constants.pageSize,
            "isAdult": showNSFW
        ]

        let response: MediaPageResponse = try await executeQuery(query, variables: variables)

        let items = response.data.page.media.map { media in
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

        return PaginatedResponse(items: items,
                                 hasNextPage: response.data.page.pageInfo?.hasNextPage ?? false,
                                 currentPage: response.data.page.pageInfo?.currentPage ?? page)
    }

    /// Fetches seasonal anime for the current season.
    /// - Parameters:
    ///   - page: The page number to fetch (1-indexed).
    ///   - showNSFW: Whether to include NSFW (adult) content.
    /// - Returns: A paginated response containing seasonal anime.
    func fetchSeasonal(page: Int = 1, showNSFW: Bool = false) async throws -> PaginatedResponse {
        let (season, year) = currentSeason()

        let query = """
        query($page: Int, $perPage: Int, $season: MediaSeason, $seasonYear: Int, $isAdult: Boolean) {
            Page(page: $page, perPage: $perPage) {
                pageInfo {
                    hasNextPage
                    currentPage
                }
                media(type: ANIME, season: $season, seasonYear: $seasonYear, sort: [POPULARITY_DESC], isAdult: $isAdult) {
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
            "page": page,
            "perPage": Constants.pageSize,
            "season": season,
            "seasonYear": year,
            "isAdult": showNSFW
        ]

        let response: MediaPageResponse = try await executeQuery(query, variables: variables)

        let items = response.data.page.media.map { media in
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

        return PaginatedResponse(items: items,
                                 hasNextPage: response.data.page.pageInfo?.hasNextPage ?? false,
                                 currentPage: response.data.page.pageInfo?.currentPage ?? page)
    }

    /// Fetches detailed information for a specific anime.
    /// - Parameter id: The AniList ID of the anime.
    /// - Returns: Detailed anime information.
    func fetchAnimeDetails(id: Int) async throws -> AniListAnimeDetail {
        let query = """
        query($id: Int) {
            Media(id: $id, type: ANIME) {
                id
                title {
                    romaji
                    english
                    native
                }
                coverImage {
                    extraLarge
                    large
                }
                bannerImage
                description(asHtml: false)
                genres
                averageScore
                meanScore
                popularity
                favourites
                status
                format
                episodes
                duration
                season
                seasonYear
                startDate {
                    year
                    month
                    day
                }
                endDate {
                    year
                    month
                    day
                }
                source
                countryOfOrigin
                siteUrl
                trailer {
                    id
                    site
                    thumbnail
                }
                nextAiringEpisode {
                    episode
                    airingAt
                    timeUntilAiring
                }
                studios(isMain: true) {
                    nodes {
                        id
                        name
                        isAnimationStudio
                    }
                }
                characters(sort: [ROLE, FAVOURITES_DESC], perPage: 12) {
                    edges {
                        node {
                            id
                            name {
                                full
                            }
                            image {
                                medium
                            }
                        }
                        role
                        voiceActors(language: JAPANESE) {
                            id
                            name {
                                full
                            }
                            image {
                                medium
                            }
                        }
                    }
                }
                relations {
                    edges {
                        node {
                            id
                            title {
                                romaji
                                english
                            }
                            coverImage {
                                large
                            }
                            format
                            status
                            type
                        }
                        relationType
                    }
                }
                recommendations(sort: [RATING_DESC], perPage: 10) {
                    nodes {
                        mediaRecommendation {
                            id
                            title {
                                romaji
                                english
                            }
                            coverImage {
                                large
                            }
                        }
                        rating
                    }
                }
                externalLinks {
                    id
                    url
                    site
                    type
                    icon
                    color
                }
                tags {
                    id
                    name
                    rank
                    isMediaSpoiler
                }
            }
        }
        """

        let variables: [String: Any] = ["id": id]
        let response: AnimeDetailResponse = try await executeQuery(query, variables: variables)

        return mapToAnimeDetail(response.data.media)
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
        let pageInfo: PageInfo?
        let media: [Media]
    }

    struct PageInfo: Decodable {
        let hasNextPage: Bool
        let currentPage: Int
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
// MARK: - AnimeDetailResponse
//#################################################################################

private struct AnimeDetailResponse: Decodable {
    let data: DataContainer

    struct DataContainer: Decodable {
        let media: MediaDetail

        enum CodingKeys: String, CodingKey {
            case media = "Media"
        }
    }

    struct MediaDetail: Decodable {
        let id: Int
        let title: TitleInfo
        let coverImage: CoverImage
        let bannerImage: String?
        let description: String?
        let genres: [String]?
        let averageScore: Int?
        let meanScore: Int?
        let popularity: Int?
        let favourites: Int?
        let status: String?
        let format: String?
        let episodes: Int?
        let duration: Int?
        let season: String?
        let seasonYear: Int?
        let startDate: FuzzyDate?
        let endDate: FuzzyDate?
        let source: String?
        let countryOfOrigin: String?
        let siteUrl: String?
        let trailer: Trailer?
        let nextAiringEpisode: NextAiringEpisode?
        let studios: Studios?
        let characters: Characters?
        let relations: Relations?
        let recommendations: Recommendations?
        let externalLinks: [ExternalLink]?
        let tags: [Tag]?
    }

    struct TitleInfo: Decodable {
        let romaji: String
        let english: String?
        let native: String?
    }

    struct CoverImage: Decodable {
        let extraLarge: String?
        let large: String
    }

    struct FuzzyDate: Decodable {
        let year: Int?
        let month: Int?
        let day: Int?
    }

    struct Trailer: Decodable {
        let id: String?
        let site: String?
        let thumbnail: String?
    }

    struct NextAiringEpisode: Decodable {
        let episode: Int
        let airingAt: Int
        let timeUntilAiring: Int
    }

    struct Studios: Decodable {
        let nodes: [Studio]
    }

    struct Studio: Decodable {
        let id: Int
        let name: String
        let isAnimationStudio: Bool
    }

    struct Characters: Decodable {
        let edges: [CharacterEdge]
    }

    struct CharacterEdge: Decodable {
        let node: CharacterNode
        let role: String?
        let voiceActors: [VoiceActor]?
    }

    struct CharacterNode: Decodable {
        let id: Int
        let name: CharacterName
        let image: CharacterImage?
    }

    struct CharacterName: Decodable {
        let full: String?
    }

    struct CharacterImage: Decodable {
        let medium: String?
    }

    struct VoiceActor: Decodable {
        let id: Int
        let name: CharacterName
        let image: CharacterImage?
    }

    struct Relations: Decodable {
        let edges: [RelationEdge]
    }

    struct RelationEdge: Decodable {
        let node: RelationNode
        let relationType: String?
    }

    struct RelationNode: Decodable {
        let id: Int
        let title: TitleInfo
        let coverImage: CoverImage?
        let format: String?
        let status: String?
        let type: String?
    }

    struct Recommendations: Decodable {
        let nodes: [RecommendationNode]
    }

    struct RecommendationNode: Decodable {
        let mediaRecommendation: RecommendationMedia?
        let rating: Int?
    }

    struct RecommendationMedia: Decodable {
        let id: Int
        let title: TitleInfo
        let coverImage: CoverImage?
    }

    struct ExternalLink: Decodable {
        let id: Int
        let url: String
        let site: String
        let type: String?
        let icon: String?
        let color: String?
    }

    struct Tag: Decodable {
        let id: Int
        let name: String
        let rank: Int
        let isMediaSpoiler: Bool
    }
}


//#################################################################################
// MARK: - AniListService+Mapping
//#################################################################################

private extension AniListService {

    func mapToAnimeDetail(_ media: AnimeDetailResponse.MediaDetail) -> AniListAnimeDetail {
        let title = media.title.english ?? media.title.romaji
        let coverURL = URL(string: media.coverImage.extraLarge ?? media.coverImage.large)
        let bannerURL = media.bannerImage.flatMap { URL(string: $0) }

        let studios = media.studios?.nodes.map { studio in
            AniListStudio(id: studio.id,
                          name: studio.name,
                          isAnimationStudio: studio.isAnimationStudio)
        } ?? []

        let characters = media.characters?.edges.compactMap { edge -> AniListCharacter? in
            guard let name = edge.node.name.full else { return nil }
            let voiceActor = edge.voiceActors?.first
            let role: AniListCharacter.CharacterRole
            switch edge.role?.uppercased() {
            case "MAIN": role = .main
            case "SUPPORTING": role = .supporting
            default: role = .background
            }

            return AniListCharacter(id: edge.node.id,
                                    name: name,
                                    imageURL: edge.node.image?.medium.flatMap { URL(string: $0) },
                                    role: role,
                                    voiceActorName: voiceActor?.name.full,
                                    voiceActorImageURL: voiceActor?.image?.medium.flatMap { URL(string: $0) })
        } ?? []

        let relations = media.relations?.edges.compactMap { edge -> AniListRelation? in
            guard edge.node.type == "ANIME" else { return nil }
            let title = edge.node.title.english ?? edge.node.title.romaji
            let relationType = AniListRelation.RelationType(rawValue: edge.relationType ?? "") ?? .other
            let format = AniListFormat(rawValue: edge.node.format ?? "") ?? .unknown
            let status = AniListStatus(rawValue: edge.node.status ?? "") ?? .unknown

            return AniListRelation(id: edge.node.id,
                                   title: title,
                                   coverURL: edge.node.coverImage.flatMap { URL(string: $0.large) },
                                   relationType: relationType,
                                   format: format,
                                   status: status)
        } ?? []

        let recommendations = media.recommendations?.nodes.compactMap { node -> AniListRecommendation? in
            guard let rec = node.mediaRecommendation else { return nil }
            let title = rec.title.english ?? rec.title.romaji

            return AniListRecommendation(id: rec.id,
                                         title: title,
                                         coverURL: rec.coverImage.flatMap { URL(string: $0.large) },
                                         rating: node.rating ?? 0)
        } ?? []

        let externalLinks = media.externalLinks?.compactMap { link -> AniListExternalLink? in
            guard let url = URL(string: link.url) else { return nil }
            let linkType: AniListExternalLink.LinkType?
            switch link.type?.uppercased() {
            case "STREAMING": linkType = .streaming
            case "SOCIAL": linkType = .social
            case "INFO": linkType = .info
            default: linkType = nil
            }

            return AniListExternalLink(id: link.id,
                                       url: url,
                                       site: link.site,
                                       type: linkType,
                                       icon: link.icon.flatMap { URL(string: $0) },
                                       color: link.color)
        } ?? []

        let tags = media.tags?.map { tag in
            AniListTag(id: tag.id,
                       name: tag.name,
                       rank: tag.rank,
                       isMediaSpoiler: tag.isMediaSpoiler)
        } ?? []

        let trailer: AniListTrailer?
        if let t = media.trailer, let id = t.id, let site = t.site {
            trailer = AniListTrailer(id: id,
                                     site: site,
                                     thumbnail: t.thumbnail.flatMap { URL(string: $0) })
        } else {
            trailer = nil
        }

        let nextAiring: AniListAiringEpisode?
        if let na = media.nextAiringEpisode {
            nextAiring = AniListAiringEpisode(episode: na.episode,
                                              airingAt: Date(timeIntervalSince1970: TimeInterval(na.airingAt)),
                                              timeUntilAiring: TimeInterval(na.timeUntilAiring))
        } else {
            nextAiring = nil
        }

        let startDate: AniListDate?
        if let sd = media.startDate {
            startDate = AniListDate(year: sd.year, month: sd.month, day: sd.day)
        } else {
            startDate = nil
        }

        let endDate: AniListDate?
        if let ed = media.endDate {
            endDate = AniListDate(year: ed.year, month: ed.month, day: ed.day)
        } else {
            endDate = nil
        }

        return AniListAnimeDetail(id: media.id,
                                  title: title,
                                  romajiTitle: media.title.romaji,
                                  nativeTitle: media.title.native,
                                  englishTitle: media.title.english,
                                  coverURL: coverURL,
                                  bannerURL: bannerURL,
                                  synopsis: media.description?.strippingHTML(),
                                  genres: media.genres ?? [],
                                  averageScore: media.averageScore,
                                  meanScore: media.meanScore,
                                  popularity: media.popularity,
                                  favourites: media.favourites,
                                  status: AniListStatus(rawValue: media.status ?? "") ?? .unknown,
                                  format: AniListFormat(rawValue: media.format ?? ""),
                                  episodes: media.episodes,
                                  duration: media.duration,
                                  season: AniListSeason(rawValue: media.season ?? ""),
                                  seasonYear: media.seasonYear,
                                  startDate: startDate,
                                  endDate: endDate,
                                  source: media.source,
                                  countryOfOrigin: media.countryOfOrigin,
                                  studios: studios,
                                  characters: characters,
                                  relations: relations,
                                  recommendations: recommendations,
                                  externalLinks: externalLinks,
                                  trailer: trailer,
                                  tags: tags,
                                  nextAiringEpisode: nextAiring,
                                  siteUrl: media.siteUrl.flatMap { URL(string: $0) })
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
