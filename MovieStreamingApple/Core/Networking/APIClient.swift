//
//  APIClient.swift
//  MovieStreamingApple
//
//  Protocol-based networking layer using URLSession + async/await.
//  Mirrors the website's fetch helpers in useHomeContents.ts.
//

import Foundation

// MARK: - API Response Wrappers

/// Generic paginated response from the API.
nonisolated struct APIListResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: [T]?
    let meta: APIMeta?
}

nonisolated struct APIMeta: Codable, Sendable {
    let pagination: APIPagination?
}

nonisolated struct APIPagination: Codable, Sendable {
    let totalCount: Int?
    let page: Int?
    let pageSize: Int?
    let totalPages: Int?
    let hasMore: Bool?
    let nextCursor: String?
}

// MARK: - Network Error

nonisolated enum NetworkError: LocalizedError, Sendable {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingError(Error)
    case noConnection
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .invalidResponse: return String(localized: "Phản hồi không hợp lệ")
        case .httpError(let code, _): return "HTTP Error \(code)"
        case .decodingError(let error): return "Decoding: \(error.localizedDescription)"
        case .noConnection: return String(localized: "Không có kết nối mạng")
        case .timeout: return String(localized: "Hết thời gian chờ")
        }
    }
}

// MARK: - API Client Protocol

nonisolated protocol APIClientProtocol: Sendable {
    func fetchContents(params: String) async throws -> (data: [Content], totalCount: Int)
    func fetchContentsPaginated(params: String) async throws -> (data: [Content], pagination: APIPagination?)
    func fetchGenres() async throws -> [Genre]
    func fetchRegions() async throws -> [Region]
    func fetchCollections() async throws -> [ContentCollection]
    func fetchBlogPosts() async throws -> [BlogPost]

    // Content Detail endpoints
    func fetchContentDetail(slug: String, type: ContentType) async throws -> Content
    func fetchSeasons(slug: String) async throws -> [Season]
    func fetchEpisodes(slug: String, seasonNumber: Int) async throws -> [Episode]
    func fetchCredits(slug: String, type: ContentType) async throws -> CreditsResponse
    func fetchRelatedContents(slug: String, type: ContentType) async throws -> [Content]
    func fetchMedia(slug: String, type: ContentType) async throws -> [MediaItem]

    // Watch page endpoints
    func fetchWatchDetail(slug: String, type: ContentType) async throws -> WatchDetailResponse
    func fetchSeriesEpisodes(slug: String, seasonNumber: Int) async throws -> [Episode]
    func trackView(contentId: String) async

    // People directory
    func fetchPeople(pageSize: Int, sortBy: String, sortOrder: String, search: String, gender: String, cursor: String?) async throws -> (data: [PersonListItem], pagination: APIPagination?)
    func fetchPersonDetail(slug: String) async throws -> PersonDetail
}

// MARK: - API Client Implementation

nonisolated final class APIClient: APIClientProtocol, Sendable {
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: String = "https://ms-api-gateway.d9042n.online/api/v1",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    // MARK: - Content Fetching

    /// Fetch contents with query string (mirrors `fetchContents` in useHomeContents.ts).
    func fetchContents(params: String) async throws -> (data: [Content], totalCount: Int) {
        let urlString = "\(baseURL)/contents?\(params)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            let result = try decoder.decode(APIListResponse<Content>.self, from: data)
            return (
                data: result.data ?? [],
                totalCount: result.meta?.pagination?.totalCount ?? 0
            )
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    // MARK: - Genres

    func fetchGenres() async throws -> [Genre] {
        let urlString = "\(baseURL)/genres"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIListResponse<Genre>.self, from: data)
        return result.data ?? []
    }

    // MARK: - Regions

    func fetchRegions() async throws -> [Region] {
        let urlString = "\(baseURL)/regions"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIListResponse<Region>.self, from: data)
        return result.data ?? []
    }

    // MARK: - Contents Paginated (Browse)

    func fetchContentsPaginated(params: String) async throws -> (data: [Content], pagination: APIPagination?) {
        let urlString = "\(baseURL)/contents?\(params)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        do {
            let result = try decoder.decode(APIListResponse<Content>.self, from: data)
            return (data: result.data ?? [], pagination: result.meta?.pagination)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    // MARK: - Collections

    func fetchCollections() async throws -> [ContentCollection] {
        let urlString = "\(baseURL)/collections"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIListResponse<ContentCollection>.self, from: data)
        return result.data ?? []
    }

    // MARK: - Blog Posts

    func fetchBlogPosts() async throws -> [BlogPost] {
        let urlString = "\(baseURL)/blog/posts?page_size=4&sort_by=published_at&sort_order=desc"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIListResponse<BlogPost>.self, from: data)
        return result.data ?? []
    }

    // MARK: - Content Detail

    /// Fetch a single content detail by slug.
    func fetchContentDetail(slug: String, type: ContentType) async throws -> Content {
        let typePrefix = type == .series ? "tv" : "movie"
        let urlString = "\(baseURL)/\(typePrefix)/\(slug)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                data: data
            )
        }

        do {
            let result = try decoder.decode(APIDataResponse<Content>.self, from: data)
            guard let content = result.data else {
                throw NetworkError.invalidResponse
            }
            return content
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    // MARK: - Seasons

    func fetchSeasons(slug: String) async throws -> [Season] {
        let urlString = "\(baseURL)/tv/\(slug)/seasons"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIListResponse<Season>.self, from: data)
        return result.data ?? []
    }

    // MARK: - Episodes

    func fetchEpisodes(slug: String, seasonNumber: Int) async throws -> [Episode] {
        let urlString = "\(baseURL)/tv/\(slug)/episodes?season_number=\(seasonNumber)&page_size=100"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIListResponse<Episode>.self, from: data)
        return result.data ?? []
    }

    // MARK: - Credits

    func fetchCredits(slug: String, type: ContentType) async throws -> CreditsResponse {
        let typePrefix = type == .series ? "tv" : "movie"
        let urlString = "\(baseURL)/\(typePrefix)/\(slug)/credits"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIDataResponse<CreditsResponse>.self, from: data)
        return result.data ?? CreditsResponse(cast: [], crew: nil)
    }

    // MARK: - Related Content

    func fetchRelatedContents(slug: String, type: ContentType) async throws -> [Content] {
        let typePrefix = type == .series ? "tv" : "movie"
        let urlString = "\(baseURL)/\(typePrefix)/\(slug)/related"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIListResponse<Content>.self, from: data)
        return result.data ?? []
    }

    // MARK: - Media Gallery

    func fetchMedia(slug: String, type: ContentType) async throws -> [MediaItem] {
        let typePrefix = type == .series ? "tv" : "movie"
        let urlString = "\(baseURL)/\(typePrefix)/\(slug)/media"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIListResponse<MediaItem>.self, from: data)
        return (result.data ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Watch Detail (content + streaming links)

    /// Fetch content detail including streaming links for movies.
    func fetchWatchDetail(slug: String, type: ContentType) async throws -> WatchDetailResponse {
        let typePrefix = type == .series ? "tv" : "movie"
        let urlString = "\(baseURL)/\(typePrefix)/\(slug)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                data: data
            )
        }

        let result = try decoder.decode(APIDataResponse<WatchDetailResponse>.self, from: data)
        guard let detail = result.data else {
            throw NetworkError.invalidResponse
        }
        return detail
    }

    // MARK: - Series Episodes (with servers embedded)

    /// Fetch episodes for a season — episodes include servers and subtitles for playback.
    func fetchSeriesEpisodes(slug: String, seasonNumber: Int) async throws -> [Episode] {
        let urlString = "\(baseURL)/tv/\(slug)/episodes?season_number=\(seasonNumber)&page_size=100"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIListResponse<Episode>.self, from: data)
        return (result.data ?? []).sorted { ($0.episodeNumber ?? 0) < ($1.episodeNumber ?? 0) }
    }

    // MARK: - Track View

    /// POST view tracking (fire-and-forget).
    func trackView(contentId: String) async {
        let urlString = "\(baseURL)/views/\(contentId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("0", forHTTPHeaderField: "Content-Length")

        _ = try? await session.data(for: request)
    }

    // MARK: - People Directory

    func fetchPeople(
        pageSize: Int = 24,
        sortBy: String = "name",
        sortOrder: String = "asc",
        search: String = "",
        gender: String = "",
        cursor: String? = nil
    ) async throws -> (data: [PersonListItem], pagination: APIPagination?) {
        var urlString = "\(baseURL)/people?page_size=\(pageSize)&sort_by=\(sortBy)&sort_order=\(sortOrder)"
        if !search.isEmpty {
            urlString += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
        }
        if !gender.isEmpty {
            urlString += "&gender=\(gender)"
        }
        if let cursor, !cursor.isEmpty {
            urlString += "&cursor=\(cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor)"
        }

        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let result = try decoder.decode(APIListResponse<PersonListItem>.self, from: data)
        return (data: result.data ?? [], pagination: result.meta?.pagination)
    }

    // MARK: - Person Detail

    func fetchPersonDetail(slug: String) async throws -> PersonDetail {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let urlString = "\(baseURL)/people/\(encoded)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                data: data
            )
        }

        let result = try decoder.decode(APIDataResponse<PersonDetail>.self, from: data)
        guard let person = result.data else {
            throw NetworkError.invalidResponse
        }
        return person
    }
}

// MARK: - Single Object Response Wrapper

/// API wrapper for single-object responses: `{ "data": T }`.
nonisolated struct APIDataResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: T?
}

// MARK: - Watch Detail Response

/// Response from content detail that includes streaming links for movies.
nonisolated struct WatchDetailResponse: Codable, Sendable {
    let id: String
    let tmdbId: Int?
    let imdbId: String?
    let title: String
    let slug: String?
    let originalTitle: String?
    let description: String?
    let posterUrl: String?
    let backdropUrl: String?
    let trailerUrl: String?
    let releaseDate: String?
    let durationMinutes: Int?
    let seasonCount: Int?
    let episodeCount: Int?
    let contentRating: String?
    let averageRating: Double?
    let ratingCount: Int?
    let totalViews: Int?
    let status: String?
    let network: String?
    let type: ContentType?
    let genres: [GenreRef]?
    let streamingMeta: StreamingMeta?
    let stats: ContentStats?
    let regions: [Region]?
    let studios: [Studio]?
    let directors: [Person]?
    let topCast: [CastMember]?

    // Movie streaming links (inline in movie detail)
    let streamingLinks: [StreamingLink]?
    let subtitles: [SubtitleTrack]?

    // Series seasons (inline in TV detail)
    let seasons: [Season]?

    /// Convert to Content for reuse in UI.
    var asContent: Content {
        Content(
            id: id, tmdbId: tmdbId, imdbId: imdbId, title: title,
            slug: slug, originalTitle: originalTitle, description: description,
            posterUrl: posterUrl, backdropUrl: backdropUrl, trailerUrl: trailerUrl,
            releaseDate: releaseDate, durationMinutes: durationMinutes,
            seasonCount: seasonCount, episodeCount: episodeCount,
            latestEpisodeAt: nil, contentRating: contentRating,
            averageRating: averageRating, ratingCount: ratingCount,
            totalViews: totalViews, status: status, network: network,
            isFeatured: nil, isPublished: nil, type: type,
            genres: genres, streamingMeta: streamingMeta,
            stats: stats, regions: regions, studios: studios,
            directors: directors, writers: nil, topCast: topCast,
            createdAt: nil, updatedAt: nil
        )
    }
}
