# Haishin External Sources Architecture

## Overview

Haishin supports user-installable external sources through **JavaScript-based plugins**. This allows users to add their own anime sources without needing to modify the app code.

## Architecture

```
Haishin App (Swift)
    ↓
JavaScript Runtime (JSRuntime actor)
    ↓
User-Installed Source Scripts (.js files)
    ↓
Anime Websites (HTTP requests via bridged fetch)
```

## Source Plugin Structure

### 1. JavaScript Plugin Format

Each source is a JavaScript file with this structure:

```javascript
// source.js
const source = {
    // ============================================
    // METADATA
    // ============================================
    id: "anime-example",
    name: "anime-exampleeExample",
    version: "1.0.0",
    language: "en",
    baseURL: "https://www.anime-example.tv",
    iconURL: "https://www.anime-example.tv/favicon.ico", // Optional
    isNSFW: false,
    description: "Anime Example", // Optional
    
    // ============================================
    // REQUIRED METHODS
    // ============================================
    
    /**
     * Search for anime
     * @param {string} query - Search query
     * @param {number} page - Page number (1-indexed)
     * @returns {Promise<JSSearchResult>}
     */
    async search(query, page = 1) {
        const url = `${this.baseURL}/search?keyword=${encodeURIComponent(query)}`;
        const response = await fetch(url);
        const html = await response.text();
        
        // Parse HTML and extract anime links
        return {
            results: [
                {
                    id: "unique-anime-id",
                    title: "Anime Title",
                    englishTitle: "English Title", // Optional
                    coverUrl: "https://...",
                    url: "https://..."
                }
            ],
            hasNextPage: false
        };
    },
    
    /**
     * Get anime details and episodes
     * @param {string} animeId - Anime identifier
     * @param {string} animeUrl - Full URL to anime page
     * @returns {Promise<JSAnimeDetails>}
     */
    async getAnimeDetails(animeId, animeUrl) {
        const response = await fetch(animeUrl);
        const html = await response.text();
        
        return {
            id: animeId,
            title: "Anime Title",
            englishTitle: "English Title", // Optional
            synopsis: "Description...",
            coverUrl: "https://...",
            rating: 8.5, // Optional
            releaseDate: "2024-01-01", // Optional, ISO 8601
            status: "ongoing", // "ongoing", "completed", "upcoming", "unknown"
            genres: ["Action", "Adventure"],
            
            // Available servers/sources
            servers: {
                "server1": "ExampleAnime",
                "server2": "StreamTape"
            },
            
            // Episodes organized by server
            episodes: {
                "server1": [
                    {
                        id: "episode-1-id",
                        number: 1,
                        title: "Episode 1",
                        url: "https://..."
                    }
                ]
            },
            
            // Optional: Episode ranges for anime with many episodes
            episodeRanges: {
                "server1": [
                    {
                        id: "range-0",
                        title: "1 - 50",
                        episodes: [/* episodes 1-50 */]
                    },
                    {
                        id: "range-1",
                        title: "51 - 100",
                        episodes: [/* episodes 51-100 */]
                    }
                ]
            }
        };
    },
    
    /**
     * Get streaming link for an episode
     * @param {string} episodeId - Episode identifier
     * @param {string} episodeUrl - Episode URL
     * @param {string} server - Server/source name
     * @returns {Promise<JSEpisodeStream>}
     */
    async getEpisodeStreams(episodeId, episodeUrl, server) {
        const response = await fetch(episodeUrl);
        const data = await response.json();
        
        return {
            streams: [
                {
                    quality: "1080p",
                    url: "https://...",
                    type: "m3u8", // "m3u8", "mp4", or "dash"
                    headers: { // Optional
                        "Referer": "https://example.com"
                    }
                }
            ],
            subtitles: [ // Optional
                {
                    language: "en",
                    label: "English",
                    url: "https://..."
                }
            ]
        };
    },
    
    /**
     * Get featured/popular anime (optional)
     * @returns {Promise<JSAnimePreview[]>}
     */
    async getFeatured() {
        // Optional: Return featured/trending anime
        return [];
    }
};

// Export the source
source;
```

### 2. Type Definitions

```typescript
interface JSSearchResult {
    results: JSAnimePreview[];
    hasNextPage: boolean;
}

interface JSAnimePreview {
    id: string;
    title: string;
    englishTitle?: string;
    coverUrl: string;
    url: string;
    sourceId?: string;
}

interface JSAnimeDetails {
    id: string;
    title: string;
    englishTitle?: string;
    synopsis: string;
    coverUrl: string;
    rating?: number;
    releaseDate?: string;
    status: "ongoing" | "completed" | "upcoming" | "unknown";
    genres: string[];
    servers: { [serverId: string]: string };
    episodes: { [serverId: string]: SourceEpisode[] };
    episodeRanges?: { [serverId: string]: SourceEpisodeRange[] };
}

interface SourceEpisode {
    id: string;
    number: number;
    title: string;
    url: string;
}

interface SourceEpisodeRange {
    id: string;
    title: string;
    episodes: SourceEpisode[];
}

interface JSEpisodeStream {
    streams: Stream[];
    subtitles?: SourceSubtitle[];
}

interface Stream {
    quality: string;
    url: string;
    type: "m3u8" | "mp4" | "dash";
    headers?: { [key: string]: string };
}

interface SourceSubtitle {
    language: string;
    label?: string;
    url: string;
}
```

## Swift Implementation

### Core Components

| File | Purpose |
|------|---------|
| `Core/Services/JSRuntime.swift` | JavaScript execution engine using JavaScriptCore |
| `Core/Services/JavaScriptSource.swift` | Actor wrapping a JS source with Swift async methods |
| `Core/Services/SourceManager.swift` | Manages source installation, loading, and queries |
| `Core/Protocols/SourceManaging.swift` | Protocol for dependency injection and testing |
| `Core/Models/Source.swift` | `SourceInfo`, `SourceRepository`, `InstalledSource` |
| `Core/Models/SourceModels.swift` | JS type definitions (`JSAnimePreview`, `JSSearchResult`, etc.) |

### SourceManaging Protocol

```swift
protocol SourceManaging: AnyObject {
    var installedSources: [InstalledSource] { get }
    var repositories: [SourceRepository] { get }
    var isLoading: Bool { get }
    var lastError: Error? { get }
    
    func loadInstalledSources() async
    func addRepository(url: URL) async throws
    func installSource(_ source: SourceInfo, from repository: SourceRepository) async throws
    func installSource(fromURL urlString: String) async throws
    func uninstallSource(sourceId: String) throws
    func selectSource(sourceId: String)
    func getPopular(sourceId: String, page: Int) async throws -> [AnimePreview]
    func getLatest(sourceId: String, page: Int) async throws -> [AnimePreview]
    func search(sourceId: String, query: String, page: Int) async throws -> [AnimePreview]
    func getAnimeDetails(sourceId: String, url: String) async throws -> Anime
    func getVideoSources(sourceId: String, episodeId: String, url: String) async throws -> PlaybackInfo
}
```

### SourceInfo

```swift
struct SourceInfo: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let version: String
    let language: String
    let baseURL: URL
    let iconURL: URL?
    let isNSFW: Bool
    let description: String?
}
```

## User Flow

### Installing a Source

1. **From Sources Tab**:
   ```
   Sources Tab → Add Repository → Enter URL
   ```

2. **Installation Methods**:
   - **Repository**: Add a repository URL, then install sources from it
   - **Direct URL**: Install from a direct `.js` file URL (HTTP/HTTPS or file://)

3. **Installation Process**:
   ```
   1. User provides source URL or selects from repository
   2. App downloads/reads JavaScript
   3. JSRuntime validates and extracts metadata
   4. Source is saved to app's Application Support directory
   5. Source appears in installed sources list
   6. First installed source is auto-selected
   ```

### Using a Source

1. **Search Tab**: Searches across selected source
2. **Sources Tab**: Manage installed sources (select/uninstall)
3. **Episode List**: Stream episodes using selected source

## File Storage

Sources are stored in:
```
~/Library/Application Support/Haishin/Sources/<source-id>.js
```

## Security Considerations

1. **Sandboxing**: JavaScript runs in isolated JSContext
2. **Network Restrictions**: 
   - Only HTTP/HTTPS allowed via bridged fetch
   - Timeout enforcement
3. **No File Access**: JS sources cannot access the filesystem
4. **Code Review**: Users should review source code before installation
