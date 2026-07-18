/**
 * Player Extraction Patterns — Sanitized Reference
 *
 * Demonstrates common video player extraction patterns found in streaming sites.
 * All URLs, IDs, and site-specific values are placeholders.
 * Use this as a structural reference when building new sources.
 *
 * @license MIT
 */

var source = {
    id: "example-patterns",
    name: "Player Extraction Patterns",
    version: "1.0.0",
    description: "Sanitized reference demonstrating common player extraction patterns.",
    author: "Haishin",
    baseUrl: "https://example.com",
    language: "en",
    nsfw: false,

    // ============================================
    // HELPER FUNCTIONS
    // ============================================

    cleanText(text) {
        if (!text) return '';
        return text
            .replace(/<[^>]+>/g, '')
            .replace(/&amp;/g, '&')
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>')
            .replace(/&quot;/g, '"')
            .replace(/&#039;/g, "'")
            .replace(/&nbsp;/g, ' ')
            .trim();
    },

    parseQueryParams(url) {
        const params = {};
        const queryStart = url.indexOf('?');
        if (queryStart === -1) return params;
        const queryString = url.substring(queryStart + 1);
        const pairs = queryString.split('&');
        for (const pair of pairs) {
            const eqIndex = pair.indexOf('=');
            if (eqIndex === -1) continue;
            const key = pair.substring(0, eqIndex);
            const value = pair.substring(eqIndex + 1);
            try {
                params[key] = decodeURIComponent(value);
            } catch (e) {
                params[key] = value;
            }
        }
        return params;
    },

    tryDecodeBase64Url(encoded) {
        if (!encoded || encoded.length < 10) return null;
        try {
            const decoded = atob(encoded);
            if (decoded.startsWith('http://') || decoded.startsWith('https://')) {
                return decoded;
            }
            try {
                const doubleDecoded = atob(decoded);
                if (doubleDecoded.startsWith('http://') || doubleDecoded.startsWith('https://')) {
                    return doubleDecoded;
                }
            } catch (e) {}
        } catch (e) {}
        try {
            const urlDecoded = decodeURIComponent(encoded);
            const decoded = atob(urlDecoded);
            if (decoded.startsWith('http://') || decoded.startsWith('https://')) {
                return decoded;
            }
        } catch (e) {}
        return null;
    },

    getVideoType(url) {
        if (url.includes('.m3u8') || url.includes('m3u8-proxy') || url.includes('/master.m3u8')) {
            return 'm3u8';
        } else if (url.includes('.mpd')) {
            return 'dash';
        }
        return 'mp4';
    },

    getPlaybackHeaders(videoUrl) {
        const headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        };
        if (videoUrl.includes('proxy.example.com') || videoUrl.includes('m3u8-proxy')) {
            headers["Origin"] = "https://player.example.com";
            headers["Referer"] = "https://player.example.com/";
        } else {
            headers["Referer"] = "https://player.example.com/";
        }
        return headers;
    },

    // ============================================
    // PLAYER EXTRACTION PATTERNS
    // ============================================

    /**
     * Pattern 1: Extract video URL from player page URL parameters.
     *
     * Player URLs often carry encrypted parameters like:
     *   player.php?embed=BASE64&url2=BASE64&url3=BASE64&ref=example.com
     *
     * Common parameter names: embed, double_player, Blogger, hianime, url2, url3
     * The generic loop checks all params except known non-video ones (ref, url2, url3).
     */
    extractFromUrlParams(playerUrl) {
        const urlParams = this.parseQueryParams(playerUrl);
        const knownParamNames = ['double_player', 'Blogger', 'hianime', 'embed', 'url2', 'url3'];
        for (const paramName of knownParamNames) {
            const paramValue = urlParams[paramName];
            if (paramValue) {
                const decodedUrl = this.tryDecodeBase64Url(paramValue);
                if (decodedUrl) {
                    return { url: decodedUrl, type: this.getVideoType(decodedUrl), subtitles: [] };
                }
            }
        }
        for (const key of Object.keys(urlParams)) {
            if (key !== 'ref' && key !== 'url2' && key !== 'url3') {
                const decodedUrl = this.tryDecodeBase64Url(urlParams[key]);
                if (decodedUrl) {
                    return { url: decodedUrl, type: this.getVideoType(decodedUrl), subtitles: [] };
                }
            }
        }
        return null;
    },

    // ============================================
    // PATTERN: Iframe Traversal
    // ============================================

    /**
     * The player chain often goes:
     *   episode page → player.php → external embed (megaplay.su, embtaku.pro, etc.) → JWPlayer
     *
     * This method demonstrates following iframes recursively and extracting
     * the video URL from the final page's JWPlayer setup.
     */
    async extractVideoFromPlayer(playerUrl, fetchHeaders) {
        try {
            // Step 1: Check URL params for direct base64-encoded video URLs
            const urlParams = this.parseQueryParams(playerUrl);
            const paramNames = ['double_player', 'Blogger', 'hianime', 'embed', 'url2', 'url3'];
            for (const paramName of paramNames) {
                const paramValue = urlParams[paramName];
                if (paramValue) {
                    const decodedUrl = this.tryDecodeBase64Url(paramValue);
                    if (decodedUrl) {
                        return { url: decodedUrl, type: this.getVideoType(decodedUrl), subtitles: [] };
                    }
                }
            }
            for (const key of Object.keys(urlParams)) {
                if (key !== 'ref' && key !== 'url2' && key !== 'url3') {
                    const decodedUrl = this.tryDecodeBase64Url(urlParams[key]);
                    if (decodedUrl) {
                        return { url: decodedUrl, type: this.getVideoType(decodedUrl), subtitles: [] };
                    }
                }
            }

            // Step 2: Fetch the player page
            const response = await fetch(playerUrl, {
                headers: {
                    'User-Agent': fetchHeaders['User-Agent'],
                    'Referer': 'https://referrer.example.com/',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
                }
            });
            if (!response.ok) return null;
            const html = await response.text();

            // Step 3: Check for known iframe patterns
            const histreamMatch = html.match(/<iframe[^>]*src="([^"]*histream\/play\.php[^"]*)"/i);
            if (histreamMatch) {
                return await this.extractVideoFromHistream(histreamMatch[1], fetchHeaders);
            }

            const embedMatch = html.match(/<iframe[^>]*src="(https?:\/\/(?:embtaku\.pro|example\.film|embed\d*\.com)[^"]+)"/i);
            if (embedMatch) {
                return await this.extractVideoFromEmbed(embedMatch[1], fetchHeaders);
            }

            const megaplayMatch = html.match(/<iframe[^>]*src="(https?:\/\/megaplay\.su[^"]+)"/i);
            if (megaplayMatch) {
                return await this.extractVideoFromMegaplay(megaplayMatch[1], fetchHeaders);
            }

            const streamingMatch = html.match(/<iframe[^>]*src="([^"]*streaming\.php[^"]*)"/i);
            if (streamingMatch) {
                let streamUrl = streamingMatch[1];
                if (!streamUrl.startsWith('http')) {
                    streamUrl = 'https://embed.example.com' + streamUrl;
                }
                return await this.extractVideoFromEmbed(streamUrl, fetchHeaders);
            }

            const domainMatch = playerUrl.match(/^(https?:\/\/[^\/]+)/);
            if (domainMatch) {
                const domain = domainMatch[1].replace(/\./g, '\\.');
                const genericIframeMatch = html.match(new RegExp(`<iframe[^>]*src="(${domain}[^"]+)"`, 'i'));
                if (genericIframeMatch) {
                    return await this.extractVideoFromNestedPage(genericIframeMatch[1], fetchHeaders);
                }
            }

            const htmlResult = this.extractVideoFromHtml(html);
            if (htmlResult) return htmlResult;

            const base64Patterns = [
                /(?:file|src|source|url)\s*[:=]\s*["']([A-Za-z0-9+/=]{50,})["']/gi,
                /atob\s*\(\s*["']([A-Za-z0-9+/=]{50,})["']\s*\)/gi,
                /["']([A-Za-z0-9+/=]{100,})["']/gi
            ];
            for (const pattern of base64Patterns) {
                let match;
                while ((match = pattern.exec(html)) !== null) {
                    const decodedUrl = this.tryDecodeBase64Url(match[1]);
                    if (decodedUrl) {
                        return { url: decodedUrl, type: this.getVideoType(decodedUrl), subtitles: [] };
                    }
                }
            }

            return null;
        } catch (error) {
            return null;
        }
    },

    // ============================================
    // PATTERN: External Embed Extraction (megaplay.su style)
    // ============================================

    /**
     * External embed pages (like megaplay.su) serve a simple JWPlayer setup
     * with a direct `file:` URL. The standard extractVideoFromHtml regex works.
     *
     * Typical response:
     *   <script>
     *     jwplayer("player-container").setup({
     *         file: "https://cdn.example.com/video.mp4?v=1234567890",
     *         image: "https://cdn.example.com/thumb.jpg?v=1234567890",
     *         type: "mp4",
     *         tracks: [],
     *         ...
     *     });
     *   </script>
     */
    async extractVideoFromMegaplay(embedUrl, fetchHeaders) {
        try {
            const response = await fetch(embedUrl, {
                headers: {
                    'User-Agent': fetchHeaders['User-Agent'],
                    'Referer': 'https://referrer.example.com/',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
                }
            });
            if (!response.ok) return null;
            const html = await response.text();
            return this.extractVideoFromHtml(html);
        } catch (error) {
            return null;
        }
    },

    // ============================================
    // PATTERN: Histream /play.php Extraction
    // ============================================

    async extractVideoFromHistream(histreamUrl, fetchHeaders) {
        try {
            const response = await fetch(histreamUrl, {
                headers: {
                    'User-Agent': fetchHeaders['User-Agent'],
                    'Referer': 'https://referrer.example.com/',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
                }
            });
            if (!response.ok) return null;
            const html = await response.text();

            const encodedUrlMatch = html.match(/const\s+encodedUrl\s*=\s*"([^"]+)"/);
            if (encodedUrlMatch) {
                try {
                    const decodedUrl = atob(encodedUrlMatch[1]);
                    let type = 'mp4';
                    if (decodedUrl.includes('.m3u8') || decodedUrl.includes('m3u8-proxy')) {
                        type = 'm3u8';
                    } else if (decodedUrl.includes('.mpd')) {
                        type = 'dash';
                    }
                    const subtitles = this.extractSubtitlesFromHtml(html);
                    return { url: decodedUrl, type: type, subtitles: subtitles };
                } catch (e) {}
            }
            return this.extractVideoFromHtml(html);
        } catch (error) {
            return null;
        }
    },

    // ============================================
    // PATTERN: Nested Player Page (same domain)
    // ============================================

    async extractVideoFromNestedPage(pageUrl, fetchHeaders) {
        try {
            const response = await fetch(pageUrl, {
                headers: {
                    'User-Agent': fetchHeaders['User-Agent'],
                    'Referer': 'https://referrer.example.com/',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
                }
            });
            if (!response.ok) return null;
            const html = await response.text();

            const result = this.extractVideoFromHtml(html);
            if (result) return result;

            const fileUrlMatch = html.match(/var\s+fileUrl\s*=\s*"([^"]+)"/);
            if (fileUrlMatch) {
                const videoUrl = fileUrlMatch[1];
                return {
                    url: videoUrl,
                    type: this.getVideoType(videoUrl),
                    subtitles: this.extractSubtitlesFromHtml(html)
                };
            }
            return null;
        } catch (error) {
            return null;
        }
    },

    // ============================================
    // PATTERN: JWPlayer HTML Extraction
    // ============================================

    extractVideoFromHtml(html) {
        const fileMatch = html.match(/file:\s*"([^"]+)"/);
        if (fileMatch) {
            const videoUrl = fileMatch[1];
            let type = 'mp4';
            if (videoUrl.includes('.m3u8') || videoUrl.includes('/master.m3u8')) {
                type = 'm3u8';
            } else if (videoUrl.includes('.mpd')) {
                type = 'dash';
            }
            const subtitles = this.extractSubtitlesFromHtml(html);
            return { url: videoUrl, type: type, subtitles: subtitles };
        }

        const sourcesMatch = html.match(/sources:\s*\[([\s\S]*?)\]/);
        if (sourcesMatch) {
            const sourceMatch = sourcesMatch[1].match(/file:\s*"([^"]+)"/);
            if (sourceMatch) {
                const videoUrl = sourceMatch[1];
                let type = 'mp4';
                if (videoUrl.includes('.m3u8')) type = 'm3u8';
                const subtitles = this.extractSubtitlesFromHtml(html);
                return { url: videoUrl, type: type, subtitles: subtitles };
            }
        }
        return null;
    },

    // ============================================
    // PATTERN: Subtitle Extraction
    // ============================================

    extractSubtitlesFromHtml(html) {
        const subtitles = [];
        const tracksMatch = html.match(/tracks:\s*\[([^\]]+)\]/);
        if (tracksMatch) {
            try {
                const tracksStr = '[' + tracksMatch[1] + ']';
                const cleanedTracksStr = tracksStr.replace(/,\s*\]/g, ']');
                const tracks = JSON.parse(cleanedTracksStr);
                for (const track of tracks) {
                    if (track.file && (track.kind === 'captions' || track.kind === 'subtitles')) {
                        subtitles.push({
                            url: track.file,
                            label: track.label || 'Unknown',
                            language: track.label ? track.label.toLowerCase().substring(0, 2) : 'en'
                        });
                    }
                }
            } catch (e) {}
        }
        return subtitles;
    },

    // ============================================
    // PATTERN: Encrypted Embed Extraction (embtaku style)
    // ============================================

    async extractVideoFromEmbed(embedUrl, fetchHeaders, depth = 0) {
        if (depth > 3) return null;

        try {
            const response = await fetch(embedUrl, {
                headers: {
                    'User-Agent': fetchHeaders['User-Agent'],
                    'Referer': 'https://referrer.example.com/',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
                }
            });
            if (!response.ok) return null;
            const html = await response.text();

            const jsRedirectMatch = html.match(/window\.location\.(?:replace|href)\s*[=(]\s*['"]([^'"]+)['"]/i);
            if (jsRedirectMatch) {
                return await this.extractVideoFromEmbed(jsRedirectMatch[1], fetchHeaders, depth + 1);
            }

            const directSourceMatch = html.match(/sources\s*:\s*\[\s*\{\s*file\s*:\s*['"]([^'"]+)['"]/i);
            if (directSourceMatch) {
                const videoUrl = directSourceMatch[1];
                return { url: videoUrl, type: this.getVideoType(videoUrl), subtitles: this.extractSubtitlesFromHtml(html) };
            }

            const encryptedDataMatch = html.match(/data-value\s*=\s*["']([^"']+)["']/);
            const cryptoKeyMatch = html.match(/CryptoJS\.AES\.decrypt\([^,]+,\s*["']([^"']+)["']/);
            if (encryptedDataMatch && cryptoKeyMatch) {
                const decrypted = this.decryptCryptoJS(encryptedDataMatch[1], cryptoKeyMatch[1]);
                if (decrypted) {
                    try {
                        const data = JSON.parse(decrypted);
                        if (data.source && data.source[0] && data.source[0].file) {
                            const videoUrl = data.source[0].file;
                            return { url: videoUrl, type: this.getVideoType(videoUrl), subtitles: this.extractSubtitlesFromHtml(html) };
                        }
                    } catch (e) {}
                }
            }

            const atobMatch = html.match(/(?:source|file|src)\s*[:=]\s*atob\s*\(\s*['"]([^'"]+)['"]\s*\)/i);
            if (atobMatch) {
                const decoded = this.tryDecodeBase64Url(atobMatch[1]);
                if (decoded) {
                    return { url: decoded, type: this.getVideoType(decoded), subtitles: this.extractSubtitlesFromHtml(html) };
                }
            }

            const m3u8Match = html.match(/['"]([^'"]*\.m3u8[^'"]*)['"]/i);
            if (m3u8Match) {
                let videoUrl = m3u8Match[1].replace(/\\/g, '');
                return { url: videoUrl, type: 'm3u8', subtitles: this.extractSubtitlesFromHtml(html) };
            }

            const nestedIframeMatch = html.match(/<iframe[^>]*src=["']([^"']+)["']/i);
            if (nestedIframeMatch) {
                let nestedUrl = nestedIframeMatch[1];
                if (!nestedUrl.startsWith('http')) {
                    const domainMatch = embedUrl.match(/^(https?:\/\/[^\/]+)/);
                    if (domainMatch) {
                        nestedUrl = domainMatch[1] + (nestedUrl.startsWith('/') ? '' : '/') + nestedUrl;
                    }
                }
                return await this.extractVideoFromEmbed(nestedUrl, fetchHeaders, depth + 1);
            }

            return null;
        } catch (error) {
            return null;
        }
    },

    // ============================================
    // PATTERN: Simple CryptoJS Decryption
    // ============================================

    decryptCryptoJS(encryptedData, key) {
        try {
            const decoded = atob(encryptedData);
            if (decoded.startsWith('{') || decoded.startsWith('[')) {
                return decoded;
            }
            let result = '';
            for (let i = 0; i < decoded.length; i++) {
                result += String.fromCharCode(decoded.charCodeAt(i) ^ key.charCodeAt(i % key.length));
            }
            if (result.startsWith('{') || result.startsWith('[')) {
                return result;
            }
            return null;
        } catch (e) {
            return null;
        }
    },

    // ============================================
    // PATTERN: AJAX API Fallback
    // ============================================

    async tryEmbedApi(videoId, fetchHeaders) {
        const apiEndpoints = [
            `https://embed.example.com/encrypt-ajax.php?id=${videoId}`,
            `https://embed.example.com/ajax.php?id=${videoId}`
        ];
        for (const apiUrl of apiEndpoints) {
            try {
                const response = await fetch(apiUrl, {
                    headers: {
                        'User-Agent': fetchHeaders['User-Agent'],
                        'Referer': 'https://embed.example.com/',
                        'Accept': 'application/json, text/plain, */*',
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                });
                if (!response.ok) continue;
                const text = await response.text();
                try {
                    const data = JSON.parse(text);
                    if (data.source && Array.isArray(data.source) && data.source.length > 0) {
                        const source = data.source[0];
                        const videoUrl = source.file || source.src || source.url;
                        if (videoUrl) {
                            return { url: videoUrl, type: this.getVideoType(videoUrl), subtitles: [] };
                        }
                    }
                    if (data.data && data.data.source) {
                        const source = data.data.source[0];
                        const videoUrl = source.file || source.src || source.url;
                        if (videoUrl) {
                            return { url: videoUrl, type: this.getVideoType(videoUrl), subtitles: [] };
                        }
                    }
                } catch (e) {
                    const m3u8Match = text.match(/https?:[^"'\s]*\.m3u8[^"'\s]*/i);
                    if (m3u8Match) {
                        return { url: m3u8Match[0].replace(/\\/g, ''), type: 'm3u8', subtitles: [] };
                    }
                }
            } catch (e) {}
        }
        return null;
    },

    // ============================================
    // PATTERN: Episode Streams Pipeline
    // ============================================

    async getEpisodeStreams(episodeId, episodeUrl, server) {
        try {
            const response = await fetch(episodeUrl, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'Accept-Language': 'en-US,en;q=0.9'
                },
                redirect: 'follow'
            });
            if (!response.ok) return { streams: [], subtitles: [] };
            const html = await response.text();

            const streams = [];
            const serverType = (server === "DUB") ? "dub" : "sub";

            const serverSectionRegex = new RegExp(
                `<div[^>]*class="type"[^>]*data-type="${serverType}"[^>]*>[\\s\\S]*?<ul>([\\s\\S]*?)<\\/ul>`,
                'i'
            );
            const serverSection = html.match(serverSectionRegex);
            const playerLinks = [];

            if (serverSection) {
                const playerRegex = /<li[^>]*class=['"]player-type-link[^'"]*['"][^>]*data-type=['"]([^'"]+)['"][^>]*data-encrypted-url1=['"]([^'"]+)['"][^>]*data-encrypted-url2=['"]([^'"]+)['"][^>]*data-encrypted-url3=['"]([^'"]+)['"][^>]*>[^<]*([^<]+)/gi;
                let playerMatch;
                while ((playerMatch = playerRegex.exec(serverSection[1])) !== null) {
                    playerLinks.push({
                        type: playerMatch[1],
                        enc1: playerMatch[2],
                        enc2: playerMatch[3],
                        enc3: playerMatch[4],
                        quality: (playerMatch[5] + playerMatch[6]).trim()
                    });
                }
            }

            if (playerLinks.length === 0) {
                const defaultTypeMatch = html.match(/const defaultType\s*=\s*"([^"]+)"/);
                const defaultEnc1Match = html.match(/const defaultEnc1\s*=\s*"([^"]+)"/);
                const defaultEnc2Match = html.match(/const defaultEnc2\s*=\s*"([^"]+)"/);
                const defaultEnc3Match = html.match(/const defaultEnc3\s*=\s*"([^"]+)"/);
                if (defaultEnc1Match) {
                    playerLinks.push({
                        type: defaultTypeMatch ? defaultTypeMatch[1] : 'default',
                        enc1: defaultEnc1Match[1],
                        enc2: defaultEnc2Match ? defaultEnc2Match[1] : '',
                        enc3: defaultEnc3Match ? defaultEnc3Match[1] : '',
                        quality: 'HD'
                    });
                }
            }

            const fetchHeaders = {
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
            };

            let allSubtitles = [];
            for (const player of playerLinks.slice(0, 3)) {
                const playerUrl = `https://player.example.com/player.php?${player.type}=${encodeURIComponent(player.enc1)}&url2=${encodeURIComponent(player.enc2)}&url3=${encodeURIComponent(player.enc3)}&ref=example.com`;
                const videoInfo = await this.extractVideoFromPlayer(playerUrl, fetchHeaders);
                if (videoInfo) {
                    const playbackHeaders = this.getPlaybackHeaders(videoInfo.url);
                    streams.push({
                        quality: player.quality,
                        url: videoInfo.url,
                        type: videoInfo.type,
                        headers: playbackHeaders
                    });
                    if (videoInfo.subtitles && videoInfo.subtitles.length > 0 && allSubtitles.length === 0) {
                        allSubtitles = videoInfo.subtitles;
                    }
                    if (streams.length >= 2) break;
                }
            }

            if (streams.length > 0) {
                return { streams: streams, subtitles: allSubtitles };
            }
            return { streams: [], subtitles: [] };
        } catch (error) {
            return { streams: [], subtitles: [] };
        }
    }
};

source;
