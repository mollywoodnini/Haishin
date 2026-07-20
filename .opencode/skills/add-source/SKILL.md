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
- **Lazy-loaded images** — Many sites use `data-src` instead of `src` for image tags to lazy-load. Always check both attributes.
- **Embedded JSON data** — Look for `<script>` blocks containing `syncData`, `__NEXT_DATA__`, or inline JSON objects that store IDs (e.g., `"anime_id"`, `"episode_id"`) needed for subsequent AJAX API calls.

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
| **AJAX API returning JSON (link + type)** | an-example-anime-site | Fetch `/ajax/v2/episode/sources?id=`, JSON has `{link, type}` → player URL → iframe follow |
| **histream player** | an-example-site iframe target | Fetch `histream/play.php`, extract `const encodedUrl = "..."`, `atob()` decode |
| **player.php with multiple param types** | an-example-site | `/player.php?Blogger=` or `?embed=` or `?hianime=` — params hold encrypted ep data |

The `window.__P` XOR pattern:
- Player page contains `<script>window.__P="BASE64BLOB"</script>`
- XOR key is embedded in the player JS (look for `OBF_KEY`, `deobfuscate`, `xor` functions)
- Decode: `atob(blob)` → XOR with key → `decodeURIComponent(escape(result))` → `JSON.parse` → get `src` (m3u8)
- Found by reading the player JS files (look for `OBF_KEY`, `deobfuscate`, `xor` functions)

#### AJAX / API endpoints
Many sites use AJAX endpoints that return data in different formats:

- **JSON with HTML fragment**: `{ status: true, html: "<div>..." }` — episodes are HTML embedded inside JSON. Parse the `html` field with regex.
- **JSON with link + type**: `{ link: "player-url", type: "iframe" }` — the link is a player page URL, not a direct video URL.
- **JSON with direct video URL**: `{ url: "https://...m3u8", type: "hls" }` — direct stream URL, no player needed.
- **XHR header requirement**: AJAX endpoints often require `X-Requested-With: XMLHttpRequest` header.

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

#### Common Implementation Patterns (from 5 existing sources)

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
- **AJAX episode list**: Many sites (e.g., an-example-site) fetch episodes via AJAX from `/ajax/v2/episode/list/{anime_id}`. The response is `{ status: true, html: "<div>..." }` — parse the HTML for episode items with `data-number`, `data-id`, and `href` attributes. Extract the `anime_id` from inline `syncData` JSON in the detail page HTML.
- **Fallback episode range**: When the AJAX endpoint fails or returns empty, generate a default episode range by checking the episode count badge on the page (e.g., `<div class="tick-item tick-eps">N</div>`) and create numbered episodes with default URLs like `/watch/{anime_id}?ep={ep_id}`.

**`getEpisodeStreams(episodeId, episodeUrl, server)`** — Most complex method
- Fetch the episode page
- Locate the player/server section for the requested server type (sub/dub)
- Extract encrypted params or player URLs from HTML attributes
- Build the player URL and fetch it
- **Follow iframes recursively** — the video URL is often 2-3 hops deep
- Use a **generic iframe fallback** when specific patterns don't match
- Extract video URL from JWPlayer config (`file:` key, `sources[]` array, `var fileUrl`)
- Return `{ streams: [{ quality, url, type, headers? }], subtitles: [...] }`
- **AJAX sources endpoint**: Try `/ajax/v2/episode/sources?id={ep_id}` which returns `{ link, type }`. If `type` is `"iframe"`, fetch the link and follow the iframe chain. If `link` is empty, fall back to `player.php` URL variants.
- **player.php fallback**: Sites like an-example-site have a `player.php` endpoint that accepts different parameter names (`Blogger`, `embed`, `hianime`) to route to different player instances. Try multiple variants sequentially: `player.php?Blogger={epId}`, `player.php?embed={epId}`, `player.php?hianime={epId}`.
- **Site protection / anti-scraping**: Some sites heavily obfuscate their video delivery pipeline. The stream API endpoint may require a valid client-side session/context that simple HTTP requests can't replicate. In such cases, `getEpisodeStreams` will legitimately return 0 streams. This is a known limitation — document it and still return `{ streams: [], subtitles: [] }` gracefully.

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
// histream encodedUrl in player page
/const\s+encodedUrl\s*=\s*"([^"]+)"/
// JavaScript window.location redirect
/window\.location\.(?:replace|href)\s*[=(]\s*['"]([^'"]+)['"]/
// anime_id from inline syncData
/"anime_id"\s*:\s*"([^"]+)"/
// data-number and data-id on episode items
/data-number="(\d+)"[^>]*data-id="([^"]+)"[^>]*href="([^"]+)"/
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
- **flw-item card parsing**: Some sites (e.g., an-example-site) use a card class like `flw-item`. Parse minified HTML by splitting on `'<div class="flw-item'` and extracting `alt` (title), `href` (url), and `data-src` (cover) from each fragment. Deduplicate by ID with a `Set`.

### 4. Coding Guidelines

- **No DOM API** — JavaScriptCore has no `document`, `DOMParser`, or `URL`. Use regex for all HTML parsing.
- **No ES modules** — Use `var source = { ... };` pattern. No `import`/`export`.
- **Async/await** — All methods must be `async`; use `await fetch(...)`.
- **Error handling** — Wrap each method in try/catch. Never throw from the top level — return empty results or `{ streams: [], subtitles: [] }` so the app shows "no streams" gracefully instead of crashing.
- **Headers** — Include `User-Agent` on all requests. Add `Referer`, `Origin`, `Accept` as needed. AJAX endpoints often require `X-Requested-With: XMLHttpRequest`.
- **Stream Referer** — HLS streams often require a specific `Referer` header to avoid 403 errors. Set `Referer` to the embed / player page domain in stream headers.
- **Console logging** — Use `console.log` extensively; prefix logs with the source name for clarity.
- **No external dependencies** — All logic in a single `.js` file.
- **Iframe traversal** — After checking known iframe patterns, add a generic fallback that follows any iframe on the same domain (common for nested player pages). Also add fallbacks for common external embed domains like `megaplay.su` — the player chain often goes: episode page → player.php → external embed (megaplay.su, embtaku.pro, etc.) → JWPlayer with direct `file:` URL.
- **Generic iframe fallback for external domains** — When the player page contains an iframe to an unknown external domain, follow it and try `extractVideoFromHtml`. Many external embed pages (like megaplay.su) serve a simple JWPlayer setup with a direct `file:` URL that the standard regex patterns can extract.
- **`embed` parameter type** — Player URLs may use `embed=` as the parameter name (not just `double_player`, `Blogger`, `hianime`). The generic parameter check loop (checking all keys except `ref`, `url2`, `url3`) handles this, but be aware that `embed` is a common parameter type for encrypted player data.
- **Quality extraction** — When extracting player data from `<li>` elements, use `(group5 + group6).trim()` for text content to handle regex group greediness.
- **fetch** — Use the standard `fetch(url, { headers: { ... } })` pattern.
- **Split-on-class parsing for minified HTML** — When HTML is minified without line breaks, split by class name (e.g., `html.split('<div class="flw-item')`) to isolate card fragments, then regex each fragment individually. Deduplicate results by ID with a `Set`.
- **player.php URL variants** — When the primary AJAX sources endpoint fails, try constructing player URLs with different parameter names: `player.php?Blogger=`, `player.php?embed=`, `player.php?hianime=`. The parameter value is usually the episode ID. Append `&url2=&url3=&ref=<domain>` for compatibility.
- **AJAX HTML fragment parsing** — When an API returns episodes as HTML inside JSON (`{ status: true, html: "<div>..." }`), parse the html field with regex for episode items. Common episode item attributes: `data-number` (episode number), `data-id` (episode server ID), `href` (watch URL).
- **Fallback episode range generation** — When the episode AJAX API fails, check the page HTML for episode count badges (e.g., `tick-eps` or `tick-sub`), then generate numbered episode objects with constructed watch URLs.

### 5. Testing

Before finishing, run the test script against the new source:

```
node examples/test-script.mjs examples/new-source.js
```

The test chains: `getEntryVideos` → first result → `getVideoDetails` → first episode → `getEpisodeStreams`. All steps must return valid data. If `getEpisodeStreams` returns 0 streams, the test exits non-zero.

**Anti-scraping note**: Some sites heavily obfuscate their video delivery pipeline. `getEpisodeStreams` may legitimately return 0 streams because the stream API requires client-side session context that simple HTTP requests can't replicate. This is a known limitation — the source can still be useful for browsing and episode discovery even without stream extraction.

### 6. Reference Files

Study these files for real-world patterns:

| File | Best for |
|------|----------|
| `examples/example-source.js` | Minimal template with method shapes and JSDoc |
| `examples/nasa-plus.js` | REST API-based source (WordPress JSON API) |
| `examples/archiveorg-cartoons.js` | API-based with pagination and grouping |
| `examples/test-script.mjs` | How sources are validated at runtime |
| _(see player extraction patterns below)_ | Two-step server→sources chain, encrypted server data-ids, embed with AES-protected streams, flw-item cards, fallback iframe URL |
| `examples/player-extraction-patterns.js` | Iframe traversal, external embed (megaplay.su), encrypted player params, JWPlayer extraction |

### 7. Output

After generating the source file:
1. Inform the user of the file path
2. Remind them that `id` must match the filename
3. Run the test script to verify
 

#### Two-step server → sources chain
Some sites (e.g., an-example-site) split stream extraction into two separate API calls:

1. **Servers endpoint**: `/ajax/v2/episode/servers?episodeId={id}` returns HTML with server items. Each server has a `data-type` (sub/dub) and `data-id` (encrypted server ID, often in format `z_{hex_encoded_base64}_{server_number}`).
2. **Sources endpoint**: `/ajax/v2/episode/sources?id={full_data_id}` returns `{link: "https://embed-domain.com/...", type: "iframe"}` — the actual player URL.

This pattern is common on sites that use third-party embed players. Always check for a `/servers` endpoint before trying `/sources` directly.

#### Deep anti-scraping with client-side AES decryption
Some embed players (e.g., an-example-embed-provider) protect the video URL with client-side CryptoJS AES encryption:

- The embed page contains `<div data-id="AES_ENCRYPTED_PAYLOAD" data-hash="AES_KEY" data-mid="KEY_IDENTIFIER">`
- The embed JS uses `CryptoJS.AES.decrypt(data_id, key_from_data_hash, {format: customFormat})` to decrypt the payload
- The decrypted JSON contains fields like `ct` (ciphertext), `iv` (initialization vector), `s` (salt) that are used in a subsequent API call to get the actual m3u8 URL
- The CryptoJS serialization format (`_0x3f5238`) converts between CipherParams objects and JSON with `{ct, iv, s}` base64 fields
- Replicating this requires porting the CryptoJS-compatible AES-CBC decryption with the EvpKDF (EVP_BytesToKey) key derivation

When the embed uses AES obfuscation, the source may still return the iframe URL as a fallback stream (the app may support rendering iframes).

#### Encrypted server data-ID format
Server data-ids often follow the pattern: `z_{hex_encoded_base64}_{server_number}`. The hex segment decodes to a base64 string, which is the RC4-encrypted server identifier. The example site JS uses RC4 + base64 for `_encryptData()`/`_decryptData()` functions. The full `data-id` string (including the `z_` prefix and `_N` suffix) must be passed as-is to the sources endpoint.

### getEpisodeStreams implementation

```javascript
async getEpisodeStreams(episodeId, episodeUrl, server) {
    try {
        // Step 1: Get encrypted server data-ids
        const serversUrl = this.baseUrl + "/ajax/v2/episode/servers?episodeId=" + encodeURIComponent(episodeId);
        const serversResponse = await fetch(serversUrl, { headers: { "X-Requested-With": "XMLHttpRequest", ... } });
        const serversData = await serversResponse.json();
        
        // Parse HTML for server items with data-type matching sub/dub
        const serverType = (server === "DUB") ? "dub" : "sub";
        const serverMatch = serversData.html.match(new RegExp('data-type="' + serverType + '"[^>]*data-id="([^"]+)"', "i"));
        const serverDataId = serverMatch ? serverMatch[1] : null;
        
        if (!serverDataId) return { streams: [], subtitles: [] };
        
        // Step 2: Get iframe URL from sources endpoint
        const sourcesUrl = this.baseUrl + "/ajax/v2/episode/sources?id=" + encodeURIComponent(serverDataId);
        const sourcesResponse = await fetch(sourcesUrl, { headers: { "X-Requested-With": "XMLHttpRequest", ... } });
        const sourcesData = JSON.parse(await sourcesResponse.text());
        
        if (sourcesData.link) {
            // Try to extract video from embed page, or return iframe URL as fallback
            const videoInfo = await this.extractVideoFromPlayer(sourcesData.link);
            if (videoInfo) {
                // Return extracted stream
            }
            // Fallback: return iframe URL
            return { streams: [{ quality: "HD", url: sourcesData.link, type: "mp4", headers: {...} }], subtitles: [] };
        }
        
        return { streams: [], subtitles: [] };
    } catch (error) {
        return { streams: [], subtitles: [] };
    }
}
```

#### Embed player with CryptoJS AES protection
When following iframe URLs leads to an embed page with `data-hash`, `data-id`, `data-mid` attributes, the embed likely uses CryptoJS AES:

- `data-id` = base64 AES-encrypted JSON payload (format `{ct, iv, s}`)
- `data-hash` = base64 AES key (typically 32 bytes for AES-256)
- `data-mid` = base64 key identifier (decodes to e.g. `za_169702_sub`)
- The embed JS decrypts `data-id` with AES using key from `data-hash`, then uses the decrypted `ct`, `iv`, `s` fields to build an API request URL
- The API response (from `/ajax/getS` or similar) contains the actual video URL, subtitles, and backup links

To extract the video URL from this protection layer, you need to:
1. Implement CryptoJS-compatible AES decryption (AES-CBC + EvpKDF with MD5)
2. Parse the decrypted payload for `ct`, `iv`, `s` fields
3. Make an additional API call with these parameters
4. Parse the response for `e` (video URL array), `subtitle`, `backupLink` fields

#### Anti-scraping depth levels

| Level | Protection | Recovery approach |
|-------|-----------|------------------|
| 1 | Basic referer/header check | Set proper `Referer`, `Origin`, `User-Agent` headers |
| 2 | Session cookie required | Fetch homepage first to get cookies, reuse in subsequent requests |
| 3 | AJAX endpoint returns empty data | Server requires client-side session context — try different endpoint patterns (e.g., `/servers` → `/sources`) |
| 4 | Encrypted server IDs | Full encrypted data-id (including prefix/suffix) must be passed to sources endpoint |
| 5 | Client-side AES (CryptoJS) | Requires porting AES-CBC decryption with custom serialization format — the embed JS is heavily obfuscated, key derivation may require reverse-engineering |
