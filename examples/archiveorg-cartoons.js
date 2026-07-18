/**
 * Archive.org Classic Cartoons Source for Haishin
 * 
 * This source provides access to public domain classic cartoons from Archive.org.
 * All content is legally free to watch and distribute.
 * 
 * Features Betty Boop, Popeye, Felix the Cat, and other classic animated shorts
 * from the 1930s-1950s that are now in the public domain.
 * 
 * @author Haishin
 * @version 1.0.2
 * @license MIT
 */

var source = {
    // ============================================
    // METADATA
    // ============================================
    id: "archiveorg-cartoons",
    name: "Classic Cartoons",
    version: "1.0.2",
    description: "Public domain classic cartoons from Archive.org. Features Betty Boop, Popeye, Felix the Cat, and more!",
    author: "Haishin",
    baseUrl: "https://archive.org",
    icon: "https://archive.org/images/glogo.png",
    language: "en",
    nsfw: false,
    
    // ============================================
    // CONFIGURATION
    // ============================================
    
    /**
     * The collection to browse
     */
    collection: "classic_cartoons",
    
    /**
     * API endpoint for advanced search
     */
    apiUrl: "https://archive.org/advancedsearch.php",
    
    /**
     * Metadata endpoint
     */
    metadataUrl: "https://archive.org/metadata",
    
    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    
    /**
     * Clean text by removing HTML entities
     */
    cleanText(text) {
        if (!text) return '';
        return text
            .replace(/&amp;/g, '&')
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>')
            .replace(/&quot;/g, '"')
            .replace(/&#039;/g, "'")
            .replace(/&nbsp;/g, ' ')
            .trim();
    },
    
    /**
     * Extract series name from title (e.g., "Betty Boop: Snow White" -> "Betty Boop")
     */
    extractSeriesName(title) {
        if (!title) return "Classic Cartoon";
        
        // Common series patterns
        const patterns = [
            /^(Betty Boop)[:\s]/i,
            /^(Popeye(?:\s+The\s+Sailor)?)[:\s]/i,
            /^(Felix(?:\s+the\s+Cat)?)[:\s]/i,
            /^(Superman)[:\s]/i,
            /^(Woody Woodpecker)[:\s]/i,
            /^(Casper)[:\s]/i,
            /^(Noveltoon)[:\s]/i,
            /^(Gabby)[:\s]/i,
            /^(Flip(?:\s+The\s+Frog)?)[:\s]/i
        ];
        
        for (const pattern of patterns) {
            const match = title.match(pattern);
            if (match) {
                return match[1];
            }
        }
        
        // If no pattern matches, use the title before the colon or the full title
        const colonIndex = title.indexOf(':');
        if (colonIndex > 0) {
            return title.substring(0, colonIndex).trim();
        }
        
        return title;
    },
    
    /**
     * Extract episode title from full title
     */
    extractEpisodeTitle(title) {
        if (!title) return "";
        
        const colonIndex = title.indexOf(':');
        if (colonIndex > 0 && colonIndex < title.length - 1) {
            return title.substring(colonIndex + 1).trim();
        }
        
        return title;
    },
    
    /**
     * Get thumbnail URL for an item
     */
    getThumbnailUrl(identifier) {
        return `https://archive.org/services/img/${identifier}`;
    },
    
    /**
     * Build download URL for a file
     */
    getDownloadUrl(identifier, filename) {
        return `https://archive.org/download/${identifier}/${encodeURIComponent(filename)}`;
    },
    
    // ============================================
    // REQUIRED METHODS
    // ============================================
    
    /**
     * Search for cartoons
     * Groups results by series (Betty Boop, Popeye, etc.)
     */
    async search(query, page = 1) {
        try {
            const rows = 50;
            const start = (page - 1) * rows;
            
            // Search within the classic_cartoons collection
            const searchQuery = query 
                ? `collection:${this.collection} AND (${query})`
                : `collection:${this.collection}`;
            
            const searchUrl = `${this.apiUrl}?q=${encodeURIComponent(searchQuery)}&output=json&rows=${rows}&start=${start}&fl[]=identifier,title,creator,date,description`;
            
            console.log(`Searching: ${searchUrl}`);
            
            const response = await fetch(searchUrl, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    'Accept': 'application/json'
                }
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            const docs = data.response?.docs || [];
            const numFound = data.response?.numFound || 0;
            
            // Group by series
            const seriesMap = new Map();
            
            for (const doc of docs) {
                const seriesName = this.extractSeriesName(doc.title);
                
                if (!seriesMap.has(seriesName)) {
                    seriesMap.set(seriesName, {
                        id: seriesName.toLowerCase().replace(/\s+/g, '-'),
                        title: seriesName,
                        englishTitle: seriesName,
                        coverUrl: this.getThumbnailUrl(doc.identifier),
                        url: `series:${seriesName}`,
                        episodes: []
                    });
                }
                
                seriesMap.get(seriesName).episodes.push({
                    identifier: doc.identifier,
                    title: doc.title,
                    date: doc.date,
                    description: doc.description
                });
            }
            
            // Convert to array and sort by title
            const results = Array.from(seriesMap.values())
                .sort((a, b) => a.title.localeCompare(b.title));
            
            console.log(`Found ${results.length} series from ${docs.length} cartoons`);
            
            return {
                results: results,
                hasNextPage: (start + rows) < numFound
            };
        } catch (error) {
            console.error('Search error:', error);
            throw error;
        }
    },
    
    /**
     * Get series details and all episodes
     */
    async getVideoDetails(videoId, videoUrl) {
        try {
            // The URL format is "series:Series Name" but may be URL-encoded
            // Decode it first to handle %20 -> space, etc.
            const decodedUrl = decodeURIComponent(videoUrl);
            const seriesName = decodedUrl.startsWith('series:') 
                ? decodedUrl.substring(7) 
                : videoId.replace(/-/g, ' ');
            
            console.log(`Fetching series details: ${seriesName}`);
            
            // Search for all cartoons in this series
            const searchQuery = `collection:${this.collection} AND title:(${seriesName})`;
            const searchUrl = `${this.apiUrl}?q=${encodeURIComponent(searchQuery)}&output=json&rows=100&fl[]=identifier,title,creator,date,description`;
            
            const response = await fetch(searchUrl, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    'Accept': 'application/json'
                }
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            const docs = data.response?.docs || [];
            
            if (docs.length === 0) {
                throw new Error(`No cartoons found for series: ${seriesName}`);
            }
            
            // Build episode list
            const episodes = [];
            let coverUrl = '';
            let creator = '';
            let description = '';
            
            // Sort by date and then title
            docs.sort((a, b) => {
                const dateA = a.date || '9999';
                const dateB = b.date || '9999';
                if (dateA !== dateB) return dateA.localeCompare(dateB);
                return (a.title || '').localeCompare(b.title || '');
            });
            
            for (let i = 0; i < docs.length; i++) {
                const doc = docs[i];
                const episodeTitle = this.extractEpisodeTitle(doc.title) || doc.title;
                
                // Use first cartoon's thumbnail as series cover
                if (i === 0) {
                    coverUrl = this.getThumbnailUrl(doc.identifier);
                    creator = doc.creator || 'Unknown';
                    description = doc.description || `Classic ${seriesName} cartoons from the golden age of animation.`;
                }
                
                // Extract year from date
                let year = '';
                if (doc.date) {
                    const yearMatch = doc.date.match(/\d{4}/);
                    if (yearMatch) year = yearMatch[0];
                }
                
                episodes.push({
                    id: doc.identifier,
                    number: i + 1,
                    title: year ? `${episodeTitle} (${year})` : episodeTitle,
                    url: doc.identifier
                });
            }
            
            console.log(`Found ${episodes.length} episodes for ${seriesName}`);
            
            // Single server for Archive.org
            const servers = {
                "Archive.org": "Archive.org"
            };
            
            const episodesByServer = {
                "Archive.org": episodes
            };
            
            return {
                id: videoId,
                title: seriesName,
                englishTitle: seriesName,
                synopsis: this.cleanText(description),
                coverUrl: coverUrl,
                rating: undefined,
                releaseDate: undefined,
                status: "completed",
                genres: ["Animation", "Classic", "Comedy", "Public Domain"],
                servers: servers,
                episodes: episodesByServer,
                episodeRanges: {}
            };
        } catch (error) {
            console.error('Get video details error:', error);
            throw error;
        }
    },
    
    /**
     * Get streaming link for an episode
     * Fetches metadata to find the best video file
     */
    async getEpisodeStreams(episodeId, episodeUrl, server) {
        try {
            const identifier = episodeUrl || episodeId;
            console.log(`Fetching streams for: ${identifier}`);
            
            // Fetch item metadata
            const metadataUrl = `${this.metadataUrl}/${identifier}`;
            
            const response = await fetch(metadataUrl, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    'Accept': 'application/json'
                }
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const metadata = await response.json();
            const files = metadata.files || [];
            
            // Find video files, prioritizing MP4 > OGV > MPEG
            const videoFiles = [];
            
            for (const file of files) {
                const name = file.name || '';
                const format = (file.format || '').toLowerCase();
                
                // Skip thumbnails and metadata
                if (name.includes('_thumb') || name.includes('.xml') || name.includes('.torrent')) {
                    continue;
                }
                
                // Check for video formats
                if (format.includes('mp4') || format.includes('mpeg4') || name.endsWith('.mp4')) {
                    videoFiles.push({
                        name: name,
                        format: 'mp4',
                        quality: this.getQualityLabel(file),
                        size: parseInt(file.size || 0),
                        height: parseInt(file.height || 0),
                        priority: 1
                    });
                } else if (format.includes('ogv') || format.includes('ogg') || name.endsWith('.ogv')) {
                    videoFiles.push({
                        name: name,
                        format: 'ogv',
                        quality: this.getQualityLabel(file),
                        size: parseInt(file.size || 0),
                        height: parseInt(file.height || 0),
                        priority: 2
                    });
                } else if (format.includes('mpeg') || name.endsWith('.mpeg') || name.endsWith('.mpg')) {
                    videoFiles.push({
                        name: name,
                        format: 'mpeg',
                        quality: this.getQualityLabel(file),
                        size: parseInt(file.size || 0),
                        height: parseInt(file.height || 0),
                        priority: 3
                    });
                }
            }
            
            if (videoFiles.length === 0) {
                throw new Error('No video files found for this item');
            }
            
            // Sort by priority (format preference) then by size (larger = better quality)
            videoFiles.sort((a, b) => {
                if (a.priority !== b.priority) return a.priority - b.priority;
                return b.size - a.size;
            });
            
            console.log(`Found ${videoFiles.length} video file(s)`);
            
            // Build streams array
            const streams = videoFiles.slice(0, 3).map(file => ({
                quality: file.quality,
                url: this.getDownloadUrl(identifier, file.name),
                type: file.format === 'mp4' ? 'mp4' : 'mp4', // AVPlayer handles most formats
                headers: {}
            }));
            
            return {
                streams: streams,
                subtitles: []
            };
        } catch (error) {
            console.error('Get episode streams error:', error);
            throw error;
        }
    },
    
    /**
     * Get quality label from file metadata
     */
    getQualityLabel(file) {
        const height = parseInt(file.height || 0);
        const format = (file.format || '').toLowerCase();
        
        if (height >= 720) return 'HD';
        if (height >= 480) return '480p';
        if (height >= 360) return '360p';
        if (height >= 240) return '240p';
        
        // Fallback based on format name
        if (format.includes('512kb')) return '320p';
        if (format.includes('mpeg4')) return 'SD';
        if (format.includes('ogv')) return 'SD';
        
        return 'SD';
    },
    
    /**
     * Get featured/popular cartoons
     */
    async getEntryVideos() {
        try {
            console.log('Fetching featured cartoons');
            
            // Get popular items from the collection
            const searchUrl = `${this.apiUrl}?q=collection:${this.collection}&output=json&rows=20&fl[]=identifier,title,creator,date&sort[]=downloads+desc`;
            
            const response = await fetch(searchUrl, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    'Accept': 'application/json'
                }
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            const docs = data.response?.docs || [];
            
            // Group by series (same as search)
            const seriesMap = new Map();
            
            for (const doc of docs) {
                const seriesName = this.extractSeriesName(doc.title);
                
                if (!seriesMap.has(seriesName)) {
                    seriesMap.set(seriesName, {
                        id: seriesName.toLowerCase().replace(/\s+/g, '-'),
                        title: seriesName,
                        englishTitle: seriesName,
                        coverUrl: this.getThumbnailUrl(doc.identifier),
                        url: `series:${seriesName}`
                    });
                }
            }
            
            const results = Array.from(seriesMap.values()).slice(0, 10);
            
            console.log(`Found ${results.length} featured series`);
            return results;
        } catch (error) {
            console.error('Get featured error:', error);
            return [];
        }
    }
};

// Export the source
source;
