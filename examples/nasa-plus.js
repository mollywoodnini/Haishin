/**
 * NASA+ Source for Haishin
 * 
 * Provides access to official NASA video content including live streams,
 * documentaries, and mission updates via the NASA+ public API.
 * 
 * @version 1.0.1
 * @author Haishin
 * @license MIT
 */

var source = {
    // ============================================
    // METADATA
    // ============================================
    
    id: "nasa-plus",
    name: "NASA+",
    version: "1.0.1",
    description: "Official streaming service from the National Aeronautics and Space Administration",
    author: "Haishin",
    baseUrl: "https://plus.nasa.gov",
    apiUrl: "https://plus.nasa.gov/wp-json/wp/v2",
    icon: "https://plus.nasa.gov/wp-content/uploads/2023/03/cropped-nasa-png-placeholder.png",
    language: "en",
    nsfw: false,

    // ============================================
    // REQUIRED METHODS
    // ============================================

    /**
     * Search for videos by query.
     * Uses the WordPress REST API search endpoint.
     */
    async search(query, page) {
        // Page is 1-indexed in Haishin, same in WP API
        const limit = 20;
        
        console.log(`[NASA+ search] Starting search for query="${query}", page=${page}`);
        
        try {
            // Use the search endpoint restricted to video subtype
            const searchUrl = `${this.apiUrl}/search?search=${encodeURIComponent(query)}&subtype=video&per_page=${limit}&page=${page}&_embed`;
            
            console.log(`[NASA+ search] Fetching URL: ${searchUrl}`);
            
            const response = await fetch(searchUrl);
            console.log(`[NASA+ search] Response status: ${response.status}, ok: ${response.ok}`);
            
            if (!response.ok) {
                throw new Error(`Search failed: ${response.status}`);
            }

            const data = await response.json();
            console.log(`[NASA+ search] Received ${Array.isArray(data) ? data.length : 'non-array'} items`);
            
            if (!Array.isArray(data)) {
                console.error(`[NASA+ search] Expected array but got: ${typeof data}`);
                return { results: [], hasNextPage: false };
            }
            
            // WP API returns total pages in header
            // Note: headers may not be available in all JS runtime environments
            let totalPages = 1;
            try {
                if (response.headers && typeof response.headers.get === 'function') {
                    totalPages = parseInt(response.headers.get("X-WP-TotalPages") || "1");
                }
            } catch (headerError) {
                console.log(`[NASA+ search] Could not read headers: ${headerError.message || headerError}`);
            }
            // Fallback: assume more pages if we got a full page of results
            const hasNextPage = data.length >= limit ? true : (page < totalPages);
            console.log(`[NASA+ search] Total pages: ${totalPages}, hasNextPage: ${hasNextPage}, data.length: ${data.length}`);

            const results = [];
            for (let i = 0; i < data.length; i++) {
                const item = data[i];
                console.log(`[NASA+ search] Processing item ${i}: id=${item.id}, title=${item.title}`);
                
                try {
                    // Try to find the best cover image
                    let coverUrl = item.featured_image_url || null;
                    console.log(`[NASA+ search] Item ${i} featured_image_url: ${coverUrl}`);
                    
                    if (!coverUrl && item._embedded && item._embedded['wp:featuredmedia']) {
                        const media = item._embedded['wp:featuredmedia'][0];
                        coverUrl = media ? media.source_url : null;
                        console.log(`[NASA+ search] Item ${i} fallback coverUrl from _embedded: ${coverUrl}`);
                    }

                    // Title can be a string (search endpoint) or object (standard endpoint)
                    let title = item.title;
                    console.log(`[NASA+ search] Item ${i} title type: ${typeof title}`);
                    if (typeof title === 'object' && title !== null && title.rendered) {
                        title = title.rendered;
                    }

                    const result = {
                        id: item.id.toString(),
                        title: this._decodeHtml(String(title || "")),
                        url: item.url || item.link, // Search uses 'url', posts use 'link'
                        coverUrl: coverUrl
                    };
                    console.log(`[NASA+ search] Item ${i} mapped: id=${result.id}, title="${result.title}", url=${result.url}`);
                    results.push(result);
                } catch (itemError) {
                    console.error(`[NASA+ search] Error processing item ${i}:`, itemError.message || itemError);
                }
            }

            console.log(`[NASA+ search] Successfully mapped ${results.length} results`);
            return {
                results,
                hasNextPage
            };
        } catch (error) {
            console.error(`[NASA+ search] Error: ${error.message || error}`);
            console.error(`[NASA+ search] Error stack: ${error.stack || 'no stack'}`);
            // Return empty results on error to prevent app crash
            return { results: [], hasNextPage: false };
        }
    },

    /**
     * Get detailed information about a video.
     * Uses the 'video' post type endpoint.
     */
    async getVideoDetails(videoId, videoUrl) {
        // videoId might be a numeric ID or a slug (extracted from URL path)
        // We need to handle both cases
        
        console.log(`[NASA+ getVideoDetails] Starting for videoId=${videoId}, videoUrl=${videoUrl}`);
        
        try {
            let data;
            
            // Check if videoId is numeric or a slug
            const isNumericId = /^\d+$/.test(videoId);
            console.log(`[NASA+ getVideoDetails] videoId is numeric: ${isNumericId}`);
            
            if (isNumericId) {
                // Direct lookup by ID
                const detailsUrl = `${this.apiUrl}/video/${videoId}`;
                console.log(`[NASA+ getVideoDetails] Fetching by ID: ${detailsUrl}`);
                
                const response = await fetch(detailsUrl);
                console.log(`[NASA+ getVideoDetails] Response status: ${response.status}, ok: ${response.ok}`);
                
                if (!response.ok) {
                    throw new Error(`Get video details failed: ${response.status}`);
                }
                
                data = await response.json();
            } else {
                // Lookup by slug - WP API returns an array when querying by slug
                const detailsUrl = `${this.apiUrl}/video?slug=${encodeURIComponent(videoId)}`;
                console.log(`[NASA+ getVideoDetails] Fetching by slug: ${detailsUrl}`);
                
                const response = await fetch(detailsUrl);
                console.log(`[NASA+ getVideoDetails] Response status: ${response.status}, ok: ${response.ok}`);
                
                if (!response.ok) {
                    throw new Error(`Get video details failed: ${response.status}`);
                }
                
                const results = await response.json();
                console.log(`[NASA+ getVideoDetails] Slug query returned ${Array.isArray(results) ? results.length : 'non-array'} results`);
                
                if (!Array.isArray(results) || results.length === 0) {
                    throw new Error(`Video not found for slug: ${videoId}`);
                }
                
                data = results[0];
            }
            
            console.log(`[NASA+ getVideoDetails] Received data for id: ${data.id}`);
            
            // Extract metadata from custom fields (meta)
            // Based on API analysis: meta.video-url contains the master m3u8
            
            const meta = data.meta || {};
            const streamUrl = meta['video-url'];
            const duration = meta.runtime; // in seconds
            const rating = meta.rating;
            
            console.log(`[NASA+ getVideoDetails] Meta - streamUrl: ${streamUrl}, duration: ${duration}, rating: ${rating}`);
            
            // Extract description (rendered HTML)
            const synopsis = data.content ? this._stripHtml(data.content.rendered) : "";
            console.log(`[NASA+ getVideoDetails] Synopsis length: ${synopsis.length}`);
            
            // Featured image
            const coverUrl = data.featured_image_url || null;
            console.log(`[NASA+ getVideoDetails] CoverUrl: ${coverUrl}`);

            const result = {
                id: data.id.toString(),
                title: this._decodeHtml(data.title.rendered),
                synopsis: synopsis,
                coverUrl: coverUrl,
                rating: null, // NASA doesn't stick to standard numeric ratings
                releaseDate: data.date, // ISO format
                status: "completed",
                genres: ["Space", "Science", "Documentary"],
                
                // We map the HLS stream directly as a server
                servers: {
                    "nasa-main": "NASA+ Master Stream"
                },
                episodes: {
                    "nasa-main": [
                        {
                            id: "main",
                            number: 1,
                            title: "Full Video",
                            url: streamUrl // Pass the direct stream URL to the next step
                        }
                    ]
                }
            };
            
            console.log(`[NASA+ getVideoDetails] Returning result: title="${result.title}", episodeUrl=${streamUrl}`);
            return result;

        } catch (error) {
            console.error(`[NASA+ getVideoDetails] Error: ${error.message || error}`);
            console.error(`[NASA+ getVideoDetails] Error stack: ${error.stack || 'no stack'}`);
            throw error;
        }
    },

    /**
     * Get streaming URLs.
     * Since we extracted the direct HLS URL in details, we just return it here.
     */
    async getEpisodeStreams(episodeId, episodeUrl) {
        console.log(`[NASA+ getEpisodeStreams] Starting for episodeId=${episodeId}, episodeUrl=${episodeUrl}`);
        
        if (!episodeUrl) {
            console.error(`[NASA+ getEpisodeStreams] No stream URL provided`);
            throw new Error("No stream URL found");
        }

        const result = {
            streams: [
                {
                    quality: "auto",
                    url: episodeUrl,
                    type: "m3u8"
                }
            ],
            subtitles: [] // NASA usually burns in subs or provides CC in the HLS stream
        };
        
        console.log(`[NASA+ getEpisodeStreams] Returning stream: ${episodeUrl}`);
        return result;
    },

    /**
     * Get entry videos (first glance of available content).
     * Uses the main video endpoint sorted by date.
     */
    async getEntryVideos() {
        const limit = 20;
        const page = 1;
        console.log(`[NASA+ getEntryVideos] Starting`);
        
        try {
            // Add _embed to get featured media in response
            const url = `${this.apiUrl}/video?per_page=${limit}&page=${page}&_embed`;
            console.log(`[NASA+ getEntryVideos] Fetching URL: ${url}`);
            
            const response = await fetch(url);
            console.log(`[NASA+ getEntryVideos] Response status: ${response.status}, ok: ${response.ok}`);
            
            if (!response.ok) {
                throw new Error(`Get entry videos failed: ${response.status}`);
            }

            const data = await response.json();
            console.log(`[NASA+ getEntryVideos] Received ${Array.isArray(data) ? data.length : 'non-array'} items`);

            const results = [];
            for (let i = 0; i < data.length; i++) {
                const item = data[i];
                try {
                    // Try to find the best cover image
                    let coverUrl = item.featured_image_url || null;
                    
                    if (!coverUrl && item._embedded && item._embedded['wp:featuredmedia']) {
                        const media = item._embedded['wp:featuredmedia'][0];
                        coverUrl = media ? media.source_url : null;
                    }
                    
                    const result = {
                        id: item.id.toString(),
                        title: this._decodeHtml(item.title.rendered),
                        coverUrl: coverUrl,
                        url: item.link
                    };
                    console.log(`[NASA+ getEntryVideos] Item ${i}: id=${result.id}, title="${result.title}", coverUrl=${coverUrl}`);
                    results.push(result);
                } catch (itemError) {
                    console.error(`[NASA+ getEntryVideos] Error processing item ${i}:`, itemError.message || itemError);
                }
            }

            console.log(`[NASA+ getEntryVideos] Returning ${results.length} results`);
            return results;

        } catch (error) {
            console.error(`[NASA+ getEntryVideos] Error: ${error.message || error}`);
            console.error(`[NASA+ getEntryVideos] Error stack: ${error.stack || 'no stack'}`);
            return [];
        }
    },

    // ============================================
    // HELPER METHODS
    // ============================================

    _decodeHtml(html) {
        if (!html) return "";
        return html
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#039;/g, "'")
            .replace(/&#8217;/g, "'")
            .replace(/&#8211;/g, "-")
            .replace(/&#8212;/g, "--");
    },

    _stripHtml(html) {
        if (!html) return "";
        return html.replace(/<[^>]*>?/gm, "")
                   .replace(/\n\n/g, "\n")
                   .trim();
    }
};

// Export the source
source;
