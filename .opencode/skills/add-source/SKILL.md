---
name: add-source
description: "Use when the user asks to create, generate, scaffold, or write a new Haishin JavaScript source that scrapes a website. This skill live-fetches the target website, analyzes its HTML structure, and generates a complete source.js file following the Haishin JS source contract."
---

# Adding a New Haishin Source

When the user asks to create a new source, follow this workflow to analyze the target website and generate a complete `source.js` file.

## Workflow

### 1. Gather Requirements

Ask the user for:
- **Website URL** — The site to scrape (e.g. `https://exampleanime.com`)
- **Author** (optional) — Default to the user's name

After getting the URL, fetch the website and infer all required metadata:
- **Source ID** — A kebab-case slug derived from the domain name (e.g. `example-anime` from `exampleanime.com`)
- **Source name** — From `<title>`, `og:site_name`, or `og:title` meta
- **Language code** — From `<html lang="...">` attribute or `og:locale`

**NSFW is always `true`** — do not ask the user.

### 2. Analyze the Website

Use `webfetch` to fetch the target website and analyze its structure:

#### Entry Page (Home/Recent/Latest)
- Fetch the homepage or a `/latest` / `/browse` page
- Identify the video/series listing pattern (CSS selectors or regex patterns for cards, links, images)
- Determine how to extract: video `id`, `title`, `coverUrl`, `url`

#### Search
- Determine the search URL pattern (e.g. `/?s={query}`, `/search?q={query}`, `/api/search?q=`)
- Fetch a search result page to identify the HTML structure

#### Video Details Page
- Identify the HTML pattern for: title, synopsis, cover image, status, genres
- Determine how episodes are listed and structured
- Identify server/player options

#### Episode/Stream Page
- Determine how to extract the video stream URL (m3u8, mp4, etc.)
- Look for iframe embeds, JWPlayer config, video elements, or API endpoints
- Identify subtitle tracks if available

### 3. Generate the Source File

Create a new `.js` file in `examples/` (or the directory the user specifies) following this template structure:

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

Optionally add:
- `icon` — URL to site logo/favicon
- `apiUrl` — If using a REST API instead of HTML scraping

#### Helper Methods (recommended)
- `cleanText(text)` — Strip HTML tags and decode entities
- `extractIdFromUrl(url)` — Parse video/series ID from URLs

#### Required Methods

Implement all four methods with live scraping:

**`search(query, page)`** — Returns `{ results: [{ id, title, coverUrl, url }], hasNextPage: boolean }`
- Fetch the search page HTML
- Parse video cards/sections using regex (JavaScriptCore has no DOM API)
- Use regex patterns like `/<article[^>]*>[\s\S]*?<a[^>]*href="([^"]+)"[^>]*>[\s\S]*?<img[^>]*src="([^"]+)"/gi`
- Handle pagination if available

**`getVideoDetails(videoId, videoUrl)`** — Returns full `JSVideoDetails`
- Fetch the video/series page
- Extract: title, synopsis, coverUrl, status, genres, servers, episodes
- Parse episode list with pattern `<a href="EP_URL">EP_TITLE</a>`
- Return servers and episodes keyed by server name
- If episodes span multiple pages, implement `episodeRanges` for pagination

**`getEpisodeStreams(episodeId, episodeUrl, server)`** — Returns `{ streams: [{ quality, url, type, headers? }], subtitles?: [...] }`
- Fetch the episode/watch page
- Extract video URL from player config, iframe, or API endpoint
- Common extraction strategies:
  - Look for `file: "URL"` in JWPlayer setup
  - Follow iframe src and recursively extract
  - Decode base64-encoded URLs
  - Call internal AJAX API endpoints
- Return streams with appropriate headers (Referer, User-Agent, Origin)

**`getEntryVideos()`** — Returns `[{ id, title, coverUrl, url }]`
- Fetch the homepage or browse page
- Parse the first page of content (recently added, popular, etc.)
- Return up to 20 items

### 4. Coding Guidelines

- **No DOM API** — JavaScriptCore has no `document`, `DOMParser`, or `URL` class. Use regex for all HTML parsing.
- **No ES modules** — Use `var source = { ... }` pattern. No `import`/`export`.
- **Async/await** — All methods should be `async`; use `await fetch(...)`.
- **Error handling** — Wrap each method in try/catch, log errors with `console.log`, return empty results rather than crashing.
- **Headers** — Include `User-Agent` header on all requests. Add `Referer` and `Accept` as needed.
- **fetch API** — Use the standard `fetch(url, { headers, ... })` pattern.
- **Console logging** — Use `console.log` extensively for debugging (output is visible in the app's debug console).
- **No external dependencies** — All logic must be self-contained in the single `.js` file.

### 5. Reference Files

Use these as reference for real-world implementation patterns:

- `examples/example-source.js` — Minimal template with all required methods
- `examples/gogoanime-source.js` — Complex HTML scraping with iframe traversal, base64 decoding, and multiple server support
- `examples/nasa-plus.js` — API-based source using WordPress REST API
- `examples/archiveorg-cartoons.js` — Archive.org scraping with pagination

### 6. Output

After generating the source file:
1. Inform the user of the file path
2. Suggest they install it via the app's "Install from Files" option in Sources
3. Remind them to update the `id` field to match the filename
