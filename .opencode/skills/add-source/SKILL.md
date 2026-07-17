---
name: add-source
description: "Use when the user asks to create, generate, scaffold, or write a new Haishin JavaScript source that scrapes a website. This skill live-fetches the target website, analyzes its HTML structure, and generates a complete source.js file following the Haishin JS source contract."
---

# Adding a New Haishin Source

## Workflow

### 1. Gather Requirements

Ask the user for:
- **Website URL** — The site to scrape
- **Author** (optional) — Default to the user's name

After getting the URL, fetch the website and infer metadata from meta tags:
- **Source ID** — kebab-case slug from the domain name
- **Source name** — From `<title>`, `og:site_name`, or `og:title`
- **Language code** — From `<html lang="...">` or `og:locale`

**NSFW is always `true`** — do not ask the user.

### 2. Analyze the Website

Use `webfetch` to identify:

- **Entry page pattern** — How are video cards structured? (article, div, li)
- **Search URL pattern** — `/?s=`, `/search?q=`, `/api/search?`
- **Video detail page** — Title, synopsis, cover, genres, episode list structure
- **Stream extraction path** — This is the hardest part. Identify the player chain:

  **Common player architectures (from existing sources):**

  | Pattern | Example | Extraction approach |
  |---------|---------|-------------------|
  | Direct `file:` URL in JWPlayer | gogoanime (n-bg/player.php) | Regex for `var fileUrl = "..."` or `sources: [{file:"..."}]` |
  | Direct m3u8 API response | nasa-plus | Extract from JSON response meta |
  | Direct download URL | archiveorg | Build from metadata identifier |
  | Iframe to external provider | gogoanime (double_player → embtaku) | Follow iframe recursively |
  | Iframe on same domain (nested player) | gogoanime (Blogger → n-bg/player.php) | Generic iframe fallback |
  | Encrypted params in page HTML | gogoanime (enc1/enc2/enc3) | Base64 decode, XOR, or pass through to player page |
  | Base64-encoded URL in attribute | Common | `atob()` decode |

### 3. Generate the Source File

#### Required Metadata

```javascript
id: "<source-id>",
name: "<Source Name>",
version: "1.0.0",
description: "<description>",
author: "<author>",
baseUrl: "<https://website.com>",
language: "<lang-code>",
nsfw: true,
```

Optional: `icon`, `apiUrl`, `collection` (for site-specific config).

#### Required Methods

All four methods are `async` and take specific parameters:

```
search(query, page)
getVideoDetails(videoId, videoUrl)
getEpisodeStreams(episodeId, episodeUrl, server)
getEntryVideos()
```

#### Common Implementation Patterns (from 4 existing sources)

**`search(query, page)`**
- Fetch search page: `` `${baseUrl}/?s=${encodeURIComponent(query)}` ``
- Parse results with regex matching the site's card structure
- Return `{ results: [{ id, title, englishTitle?, coverUrl, url }], hasNextPage: boolean }`
- Wrap in try/catch, return empty on error (app must not crash)

**`getVideoDetails(videoId, videoUrl)`**
- Fetch the video/series page
- Extract: title (`<h1 class="entry-title">`), synopsis, cover, status, genres
- Parse episode list from HTML (look for episode links in a list/grid)
- Return `{ id, title, englishTitle?, synopsis, coverUrl, status, genres, servers: {...}, episodes: {...} }`
- If episodes span multiple pages, implement `episodeRanges` for pagination

**`getEpisodeStreams(episodeId, episodeUrl, server)`** — Most complex method
- Fetch the episode page
- Locate the player/server section for the requested server type (sub/dub)
- Extract encrypted params or player URLs from HTML attributes
- Build the player URL and fetch it
- **Follow iframes recursively** — the video URL is often 2-3 hops deep
- Use a **generic iframe fallback** when specific patterns don't match
- Extract video URL from JWPlayer config (`file:` key, `sources[]` array, `var fileUrl`)
- Return `{ streams: [{ quality, url, type, headers? }], subtitles: [...] }`

**Common video extraction sub-pipeline (from gogoanime):**

```
1. Check URL params for direct base64-encoded video URLs
2. Fetch player page → look for known iframe patterns
3. Generic iframe fallback: follow any <iframe src="..."> on same domain
4. Extract from HTML: file: "URL", sources: [{file:"URL"}]
5. Scan for base64-encoded strings → tryDecodeBase64Url
6. Try AJAX API endpoints as fallback (encrypt-ajax.php, etc.)
7. If all fail, return { streams: [], subtitles: [] }
```

Key extraction regex patterns:
```javascript
// JWPlayer file URL
/file:\s*"([^"]+)"/
// JWPlayer sources array
/sources:\s*\[([\s\S]*?)\]/
// Direct var fileUrl
/var\s+fileUrl\s*=\s*"([^"]+)"/
// Generic iframe
/<iframe[^>]*src="([^"]+)"/
// m3u8 URL
/(https?:[^"'\s]*\.m3u8[^"'\s]*)/
// Encrypted data
/data-value\s*=\s*"([^"]+)"/
// atob-encoded source
/source\s*[=:]\s*atob\s*\(\s*'([^']+)'/
```

**`getEntryVideos()`**
- Fetch homepage or browse page
- Parse the first page of content (recently added, popular, etc.)
- Return `[{ id, title, coverUrl, url }]` — up to 20 items
- Wrap in try/catch, return `[]` on error

### 4. Coding Guidelines

- **No DOM API** — JavaScriptCore has no `document`, `DOMParser`, or `URL`. Use regex for all HTML parsing.
- **No ES modules** — Use `var source = { ... };` pattern. No `import`/`export`.
- **Async/await** — All methods must be `async`; use `await fetch(...)`.
- **Error handling** — Wrap each method in try/catch. Never throw from the top level — return empty results or `{ streams: [], subtitles: [] }` so the app shows "no streams" gracefully instead of crashing.
- **Headers** — Include `User-Agent` on all requests. Add `Referer`, `Origin`, `Accept` as needed.
- **Console logging** — Use `console.log` extensively; prefix logs with the source name for clarity.
- **No external dependencies** — All logic in a single `.js` file.
- **Iframe traversal** — After checking known iframe patterns, add a generic fallback that follows any iframe on the same domain (common for nested player pages).
- **Quality extraction** — When extracting player data from `<li>` elements, use `(group5 + group6).trim()` for text content to handle regex group greediness.
- **fetch** — Use the standard `fetch(url, { headers: { ... } })` pattern.

### 5. Testing

Before finishing, run the test script against the new source:

```
node examples/test-script.mjs examples/new-source.js
```

The test chains: `getEntryVideos` → first result → `getVideoDetails` → first episode → `getEpisodeStreams`. All steps must return valid data. If `getEpisodeStreams` returns 0 streams, the test exits non-zero.

### 6. Reference Files

Study these files for real-world patterns:

| File | Best for |
|------|----------|
| `examples/example-source.js` | Minimal template with method shapes and JSDoc |
| `examples/nasa-plus.js` | REST API-based source (WordPress JSON API) |
| `examples/archiveorg-cartoons.js` | API-based with pagination and grouping |
| `examples/gogoanime-source.js` | Complex HTML scraping with iframe traversal, encrypted params, nested players, and multi-server support |
| `examples/test-script.mjs` | How sources are validated at runtime |

### 7. Output

After generating the source file:
1. Inform the user of the file path
2. Remind them that `id` must match the filename
3. Run the test script to verify
