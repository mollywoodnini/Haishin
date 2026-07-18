/**
 * Example Source for Haishin
 * 
 * This is a minimal example source that demonstrates the required API structure.
 * Use this as a template when creating your own sources.
 * 
 * @author Your Name
 * @version 1.0.0
 * @license MIT
 */

var source = {
    // ============================================
    // METADATA (Required)
    // ============================================
    
    /** Unique identifier for this source (must match filename without .js) */
    id: "example-source",
    
    /** Display name shown in the app */
    name: "Example Source",
    
    /** Version in semver format */
    version: "1.0.0",
    
    /** Brief description of the source */
    description: "A minimal example source for testing",
    
    /** Author name */
    author: "Haishin",
    
    /** Base URL of the website this source scrapes */
    baseUrl: "https://example.com",
    
    /** URL to the source icon/logo (optional) */
    icon: null,
    
    /** Language code (e.g., "en", "ja", "it") */
    language: "en",
    
    /** Whether this source provides NSFW content */
    nsfw: false,

    // ============================================
    // REQUIRED METHODS
    // ============================================

    /**
     * Search for videos by query.
     * 
     * @param {string} query - The search term
     * @param {number} page - Page number (1-indexed)
     * @returns {Object} Search results with format:
     *   {
     *     results: [{ id, title, englishTitle?, coverUrl, url }],
     *     hasNextPage: boolean
     *   }
     */
    search(query, page) {
        // Example: Return mock data
        // In a real source, you would fetch and parse HTML from the website
        return {
            results: [
                {
                    id: "video-1",
                    title: "Example Video 1",
                    englishTitle: null,
                    coverUrl: "https://via.placeholder.com/300x400",
                    url: "https://example.com/video/1"
                },
                {
                    id: "video-2",
                    title: "Example Video 2",
                    englishTitle: "Example Video 2 (English)",
                    coverUrl: "https://via.placeholder.com/300x400",
                    url: "https://example.com/video/2"
                }
            ],
            hasNextPage: false
        };
    },

    /**
     * Get detailed information about a video.
     * 
     * @param {string} url - The video page URL
     * @returns {Object} Video details with format:
     *   {
     *     id: string,
     *     title: string,
     *     englishTitle?: string,
     *     synopsis: string,
     *     coverUrl: string,
     *     rating?: number,
     *     releaseDate?: string (ISO 8601),
     *     status: "ongoing" | "completed" | "upcoming" | "unknown",
     *     genres: string[],
     *     servers: { [serverId]: serverName },
     *     episodes: { [serverId]: Episode[] },
     *     episodeRanges?: { [serverId]: EpisodeRange[] }
     *   }
     */
    getVideoDetails(url) {
        // Example: Return mock data
        return {
            id: "video-1",
            title: "Example Video",
            englishTitle: null,
            synopsis: "This is an example video description. In a real source, this would contain the actual synopsis from the website.",
            coverUrl: "https://via.placeholder.com/300x400",
            rating: 8.5,
            releaseDate: "2024-01-01",
            status: "completed",
            genres: ["Action", "Adventure", "Comedy"],
            servers: {
                "server1": "Main Server",
                "server2": "Backup Server"
            },
            episodes: {
                "server1": [
                    { id: "ep-1", number: 1, title: "Episode 1", url: "https://example.com/watch/1" },
                    { id: "ep-2", number: 2, title: "Episode 2", url: "https://example.com/watch/2" },
                    { id: "ep-3", number: 3, title: "Episode 3", url: "https://example.com/watch/3" }
                ],
                "server2": [
                    { id: "ep-1-backup", number: 1, title: "Episode 1", url: "https://example.com/backup/1" },
                    { id: "ep-2-backup", number: 2, title: "Episode 2", url: "https://example.com/backup/2" }
                ]
            }
        };
    },

    /**
     * Get streaming URLs for an episode.
     * 
     * @param {string} episodeId - The episode ID
     * @param {string} url - The episode page URL
     * @returns {Object} Streaming info with format:
     *   {
     *     streams: [{ quality, url, type, headers? }],
     *     subtitles?: [{ language, label?, url }]
     *   }
     */
    getVideoSources(episodeId, url) {
        // Example: Return mock data
        return {
            streams: [
                {
                    quality: "1080p",
                    url: "https://example.com/stream/1080.m3u8",
                    type: "m3u8",
                    headers: {
                        "Referer": "https://example.com"
                    }
                },
                {
                    quality: "720p",
                    url: "https://example.com/stream/720.m3u8",
                    type: "m3u8"
                },
                {
                    quality: "480p",
                    url: "https://example.com/stream/480.mp4",
                    type: "mp4"
                }
            ],
            subtitles: [
                {
                    language: "en",
                    label: "English",
                    url: "https://example.com/subs/en.vtt"
                },
                {
                    language: "es",
                    label: "Spanish",
                    url: "https://example.com/subs/es.vtt"
                }
            ]
        };
    },

    /**
     * Get entry videos (first glance of available content).
     * 
     * @returns {Promise<Array>} Array of video objects: [{ id, title, coverUrl, url }]
     */
    getEntryVideos() {
        return [
            {
                id: "popular-1",
                title: "Popular Video 1",
                coverUrl: "https://via.placeholder.com/300x400",
                url: "https://example.com/video/popular-1"
            },
            {
                id: "latest-1",
                title: "Latest Video 1",
                coverUrl: "https://via.placeholder.com/300x400",
                url: "https://example.com/video/latest-1"
            }
        ];
    }
};
