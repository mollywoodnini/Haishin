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

First determine if the site is server-rendered (HTML contains content) or **client-side rendered (SPA)**.

#### For server-rendered sites
Use `webfetch` to parse HTML for:
- **Entry page pattern** — How are video cards structured? (article, div, li)
- **Search URL pattern** — `/?s=`, `/search?q=`, `/api/search?`
- **Video detail page** — Title, synopsis, cover, genres, episode list structure

#### For client-side rendered (SPA) sites
The HTML is a shell with loading skeletons. All content comes from JavaScript API calls.
- Fetch JS bundles (look for `/_next/static/chunks/*.js` in Next.js sites)
- Search for `fetch(`, `axios`, `https://` API patterns in bundle source to discover endpoints
- The API is often on a **separate domain** (e.g., `animedata.cfd`) — not the visible website
- Common SPA frameworks: Next.js, Nuxt, React SPA, Vue SPA

#### Stream extraction path
This is the hardest part. Identify the player chain:

**Common player architectures (from existing sources):**

| Pattern | Example | Extraction approach |
|---------|---------|-------------------|
| Direct `file:` URL in JWPlayer | Nested player page on same domain | Regex for `var fileUrl = "..."` or `sources: [{file:"..."}]` |
| Direct m3u8 API response | nasa-plus | Extract from JSON response meta |
| Direct download URL | archiveorg | Build from metadata identifier |
| Iframe to external provider | Player embed with URL params | Follow iframe recursively |
| Iframe on same domain (nested player) | Encrypted params pointing to self-hosted player | Generic iframe fallback |
| **Iframe to megaplay.su** | JWPlayer on megaplay.su with direct `file:` URL | Follow iframe → `extractVideoFromHtml` (regex `file:` pattern works) |
| Encrypted params in page HTML | Player with enc1/enc2/enc3 params | Base64 decode, XOR, or pass through to player page |
| Base64-encoded URL in attribute | Common | `atob()` decode |
| **XOR-encrypted `window.__P` blob** in player page | Third-party embed player | Extract `__P`, XOR-decode with known key, get `src` field (direct m3u8) |

The `window.__P` XOR pattern:
- Player page contains `<script>window.__P="BASE64BLOB"</script>`
- XOR key is embedded in the player JS (look for `OBF_KEY`, `deobfuscate`, `xor` functions)
- Decode: `atob(blob)` → XOR with key → `decodeURIComponent(escape(result))` → `JSON.parse` → get `src` (m3u8)
- Found by reading the player JS files (look for `OBF_KEY`, `deobfuscate`, `xor` functions)

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
- **Server-rendered**: Fetch search page: `` `${baseUrl}/?s=${encodeURIComponent(query)}` `` and parse HTML
- **API-based**: POST to `` `${apiBase}/search` `` with JSON body `{title: query}` (or GET with query params)
- Parse results — either from HTML cards or JSON array response
- Return `{ results: [{ id, title, englishTitle?, coverUrl, url }], hasNextPage: boolean }`
- Wrap in try/catch, return empty on error (app must not crash)
- **Edge case**: API may be unreliable (522/timeout) — implement retry or return gracefully

**`getVideoDetails(videoId, videoUrl)`**
- **Server-rendered**: Fetch the video/series page; extract title, synopsis, cover, status, genres from HTML
- **API-based**: Fetch `` `${apiBase}/anime/{slug}` `` endpoint (slug = videoId or extracted from videoUrl)
- Episodes are often in the same response (no pagination needed for API-based sources)
- Store stream links from API response in a cache (`this.streamCache`) for later use in `getEpisodeStreams`
- Return `{ id, title, englishTitle?, synopsis, coverUrl, status, genres, servers: {...}, episodes: {...} }`
- If episodes span multiple pages, implement `episodeRanges` for pagination
- **Edge case**: API items may have multiple slug fields — try `slugs[]`, `slug`, `id` in order

**`getEpisodeStreams(episodeId, episodeUrl, server)`** — Most complex method
- Fetch the episode page
- Locate the player/server section for the requested server type (sub/dub)
- Extract encrypted params or player URLs from HTML attributes
- Build the player URL and fetch it
- **Follow iframes recursively** — the video URL is often 2-3 hops deep
- Use a **generic iframe fallback** when specific patterns don't match
- Extract video URL from JWPlayer config (`file:` key, `sources[]` array, `var fileUrl`)
- Return `{ streams: [{ quality, url, type, headers? }], subtitles: [...] }`

**Common video extraction sub-pipeline:**

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
// XOR-encrypted window.__P blob in player page
/window\.__P\s*=\s*"([^"]+)"/
// XOR key in player JS (e.g., OBF_KEY = '...')
/OBF_KEY\s*=\s*['"]([^'"]+)['"]/
```

XOR decode implementation:
```javascript
_decodeEncryptedBlob(blob) {
    const key = "example-key";           // XOR key found in player JS
    let xored = "";
    const raw = atob(blob);
    for (let i = 0; i < raw.length; i++) {
        xored += String.fromCharCode(raw.charCodeAt(i) ^ key.charCodeAt(i % key.length));
    }
    return JSON.parse(decodeURIComponent(escape(xored)));
}


**`getEntryVideos()`**
- **Server-rendered**: Fetch homepage or browse page; parse video cards from HTML
- **API-based**: Fetch `` `${apiBase}/home` `` — iterate known sections (`featured`, `trending`, `popular`, `latestAnime`)
- Use `Array.isArray()` to guard against mixed-type responses (some sections may be objects, not arrays)
- Handle nested wrappers: item may be `{anime: {title, slug, image}}` or a flat object
- Return `[{ id, title, coverUrl, url }]` — up to 20 items
- Wrap in try/catch, return `[]` on error

### 4. Coding Guidelines

- **No DOM API** — JavaScriptCore has no `document`, `DOMParser`, or `URL`. Use regex for all HTML parsing.
- **No ES modules** — Use `var source = { ... };` pattern. No `import`/`export`.
- **Async/await** — All methods must be `async`; use `await fetch(...)`.
- **Error handling** — Wrap each method in try/catch. Never throw from the top level — return empty results or `{ streams: [], subtitles: [] }` so the app shows "no streams" gracefully instead of crashing.
- **Headers** — Include `User-Agent` on all requests. Add `Referer`, `Origin`, `Accept` as needed.
- **Stream Referer** — HLS streams often require a specific `Referer` header to avoid 403 errors. Set `Referer` to the embed / player page domain in stream headers.
- **Console logging** — Use `console.log` extensively; prefix logs with the source name for clarity.
- **No external dependencies** — All logic in a single `.js` file.
- **Iframe traversal** — After checking known iframe patterns, add a generic fallback that follows any iframe on the same domain (common for nested player pages). Also add fallbacks for common external embed domains like `megaplay.su` — the player chain often goes: episode page → player.php → external embed (megaplay.su, embtaku.pro, etc.) → JWPlayer with direct `file:` URL.
- **Generic iframe fallback for external domains** — When the player page contains an iframe to an unknown external domain, follow it and try `extractVideoFromHtml`. Many external embed pages (like megaplay.su) serve a simple JWPlayer setup with a direct `file:` URL that the standard regex patterns can extract.
- **`embed` parameter type** — Player URLs may use `embed=` as the parameter name (not just `double_player`, `Blogger`, `hianime`). The generic parameter check loop (checking all keys except `ref`, `url2`, `url3`) handles this, but be aware that `embed` is a common parameter type for encrypted player data.
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
| `examples/example-source.js` | Minimal template with method shapes and JSDoc |
| `examples/nasa-plus.js` | REST API-based source (WordPress JSON API) |
| `examples/archiveorg-cartoons.js` | API-based with pagination and grouping |
| `examples/test-script.mjs` | How sources are validated at runtime |
| `examples/player-extraction-patterns.js` | Iframe traversal, external embed (megaplay.su), encrypted player params, JWPlayer extraction |
| `examples/test-script.mjs` | How sources are validated at runtime |

### 7. Output

After generating the source file:
1. Inform the user of the file path
2. Remind them that `id` must match the filename
3. Run the test script to verify
