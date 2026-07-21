/**
 * Libreflix Source for Haishin
 *
 * Provides access to Libreflix, a free and collaborative streaming platform
 * featuring independent audiovisual productions (documentaries, films, series, shorts).
 *
 * @author Haishin
 * @version 1.0.0
 * @license MIT
 */

var source = {
    id: "libreflix",
    name: "Libreflix",
    version: "1.0.0",
    description: "Plataforma de streaming aberta e colaborativa com produções audiovisuais independentes, de livre exibição.",
    author: "Haishin",
    baseUrl: "https://libreflix.org",
    language: "pt",
    nsfw: true,

    cleanText(text) {
        if (!text) return '';
        return text
            .replace(/<[^>]+>/g, '')
            .replace(/&amp;/g, '&')
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>')
            .replace(/&quot;/g, '"')
            .replace(/&#039;/g, "'")
            .replace(/&#x27;/g, "'")
            .replace(/&#x2F;/g, '/')
            .replace(/&#8217;/g, "'")
            .replace(/&#8211;/g, "-")
            .replace(/&#8212;/g, "--")
            .replace(/&nbsp;/g, ' ')
            .trim();
    },

    extractSlugFromUrl(url) {
        if (!url) return '';
        const match = url.match(/\/(?:i|assistir)\/([^\/?#]+)/);
        if (match) return match[1];
        return '';
    },

    extractSlugFromId(id) {
        if (!id) return '';
        if (id.startsWith('libreflix-')) {
            return id.substring(9);
        }
        return id;
    },

    makeId(slug) {
        return 'libreflix-' + slug;
    },

    parseCardsFromHtml(html) {
        const results = [];
        const seenIds = new Set();

        const fragments = html.split('<li class="col-md-3">');
        for (let i = 1; i < fragments.length; i++) {
            const frag = fragments[i];
            const closeLi = frag.indexOf('</li>');
            const cardHtml = closeLi >= 0 ? frag.substring(0, closeLi) : frag;

            const slugMatch = cardHtml.match(/data-target="#assistir([^"]+)"/);
            if (!slugMatch) continue;
            const slug = slugMatch[1];

            const imgMatch = cardHtml.match(/<img[^>]*src="([^"]+)"[^>]*title="([^"]*)"/);
            if (!imgMatch) continue;

            const coverUrl = imgMatch[1].split('?')[0];
            const title = this.cleanText(imgMatch[2]);

            if (!title || title.toLowerCase() === 'play' || title.toLowerCase() === 'watch now') continue;

            const id = this.makeId(slug);
            if (!seenIds.has(id)) {
                seenIds.add(id);
                results.push({
                    id: id,
                    title: title,
                    coverUrl: coverUrl,
                    url: this.baseUrl + '/i/' + slug
                });
            }
        }

        return results;
    },

    async search(query, page) {
        try {
            const url = this.baseUrl + '/busca/' + encodeURIComponent(query);
            console.log('[Libreflix search] Fetching:', url);

            const response = await fetch(url, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
                }
            });

            if (!response.ok) {
                console.log('[Libreflix search] HTTP error:', response.status);
                return { results: [], hasNextPage: false };
            }

            const html = await response.text();
            const results = this.parseCardsFromHtml(html);

            console.log('[Libreflix search] Found', results.length, 'results');
            return { results: results, hasNextPage: false };
        } catch (error) {
            console.error('[Libreflix search] Error:', error.message || error);
            return { results: [], hasNextPage: false };
        }
    },

    async getVideoDetails(videoId, videoUrl) {
        try {
            const slug = this.extractSlugFromUrl(videoUrl) || this.extractSlugFromId(videoId);
            const url = this.baseUrl + '/i/' + slug;

            console.log('[Libreflix getVideoDetails] Fetching:', url);

            const response = await fetch(url, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
                }
            });

            if (!response.ok) {
                console.log('[Libreflix getVideoDetails] HTTP error:', response.status);
                throw new Error('HTTP ' + response.status);
            }

            const html = await response.text();

            const titleMatch = html.match(/<h2>([\s\S]*?)<\/h2>/);
            const title = titleMatch ? this.cleanText(titleMatch[1]) : slug;

            let rating = null;
            const ratingMatch = html.match(/<span[^>]*class="label label-rating[^"]*"[^>]*>([^<]+)<\/span>/);
            if (ratingMatch) {
                rating = parseFloat(ratingMatch[1].trim().replace(',', '.'));
            }

            let year = '';
            const yearMatch = html.match(/<h4>[\s\S]*?(\d{4})/);
            if (yearMatch) year = yearMatch[1];

            let synopsis = '';
            const synopsisRegex = /<h2>[\s\S]*?<\/h2>[\s\S]*?<h4>[\s\S]*?<\/h4>[\s\S]*?<p>([\s\S]*?)<\/p>/;
            const synopsisMatch = html.match(synopsisRegex);
            if (synopsisMatch) {
                synopsis = this.cleanText(synopsisMatch[1]);
            }

            let coverUrl = '';
            const coverMatch = html.match(/<img[^>]*class="film_pic"[^>]*src="([^"]+)"/);
            if (coverMatch) {
                coverUrl = coverMatch[1].split('?')[0];
            }

            const genres = [];
            const tagRegex = /<a\s+href="\/t\/([^"]+)"[^>]*><span[^>]*class="label label-default"[^>]*>([^<]+)<\/span><\/a>/gi;
            let tagMatch;
            while ((tagMatch = tagRegex.exec(html)) !== null) {
                const tag = this.cleanText(tagMatch[2]);
                if (tag) genres.push(tag);
            }

            const catMatch = html.match(/<b>Categories:<\/b>[\s\S]*?<\/div>/i);
            if (catMatch) {
                const catRegex = /<a\s+href="[^"]*">([^<]+)<\/a>/g;
                let catMatch2;
                while ((catMatch2 = catRegex.exec(catMatch[1])) !== null) {
                    const cat = this.cleanText(catMatch2[1]);
                    if (cat) genres.push(cat);
                }
            }

            const isSeries = html.match(/<h3>\s*Epis.dios?\s*<\/h3>/i) !== null ||
                             html.match(/class="ep-list"/i) !== null;

            const servers = {};
            const episodes = {};

            if (isSeries) {
                servers["main"] = "Servidor Principal";

                const epList = [];

                // Find the episode table
                const epTableMatch = html.match(/<h3>\s*Epis.dios?\s*<\/h3>[\s\S]*?<table[^>]*class="ep-list"[^>]*>[\s\S]*?<\/table>/i);
                if (epTableMatch) {
                    const tableHtml = epTableMatch[0];
                    const epRowRegex = /<tr>[\s\S]*?<td[^>]*>\s*(\d+)\s*<\/td>[\s\S]*?<td[^>]*>([\s\S]*?)<\/td>[\s\S]*?<td[^>]*>[\s\S]*?<a\s+href="([^"]+)"[^>]*>/gi;
                    let epRowMatch;
                    while ((epRowMatch = epRowRegex.exec(tableHtml)) !== null) {
                        const epNum = parseInt(epRowMatch[1], 10);
                        const epTitle = this.cleanText(epRowMatch[2]) || 'Episódio ' + epNum;
                        let epUrl = epRowMatch[3];
                        if (epUrl.startsWith('/')) epUrl = this.baseUrl + epUrl;
                        epList.push({
                            id: slug + '-ep-' + epNum,
                            number: epNum,
                            title: epTitle,
                            url: epUrl
                        });
                    }
                }

                if (epList.length === 0) {
                    epList.push({
                        id: slug + '-ep-1',
                        number: 1,
                        title: 'Episódio 1',
                        url: this.baseUrl + '/assistir/' + slug + '/1'
                    });
                }

                episodes["main"] = epList;
            } else {
                servers["main"] = "Servidor Principal";
                episodes["main"] = [
                    {
                        id: slug,
                        number: 1,
                        title: 'Video Completo',
                        url: this.baseUrl + '/assistir/' + slug
                    }
                ];
            }

            console.log('[Libreflix getVideoDetails] Title:', title, '| isSeries:', isSeries, '| Episodes:', episodes["main"].length);

            return {
                id: videoId,
                title: title,
                synopsis: synopsis,
                coverUrl: coverUrl,
                rating: rating,
                releaseDate: year ? year + '-01-01' : undefined,
                status: "completed",
                genres: genres,
                servers: servers,
                episodes: episodes
            };
        } catch (error) {
            console.error('[Libreflix getVideoDetails] Error:', error.message || error);
            throw error;
        }
    },

    async getEpisodeStreams(episodeId, episodeUrl, server) {
        try {
            let url = episodeUrl;
            if (!url || url === 'undefined' || url === 'null') {
                const slug = this.extractSlugFromId(episodeId);
                url = this.baseUrl + '/assistir/' + slug;
            }

            console.log('[Libreflix getEpisodeStreams] Fetching:', url);

            const response = await fetch(url, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    'Referer': this.baseUrl + '/',
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
                }
            });

            if (!response.ok) {
                console.log('[Libreflix getEpisodeStreams] HTTP error:', response.status);
                return { streams: [], subtitles: [] };
            }

            const html = await response.text();
            const streams = [];

            const sourceRegex = /<source\s+src="([^"]+)"[^>]*type="([^"]+)"[^>]*(?:size="(\d+)")?[^>]*(?:label="([^"]*)")?/gi;
            let sourceMatch;
            while ((sourceMatch = sourceRegex.exec(html)) !== null) {
                const videoUrl = sourceMatch[1];
                const type = sourceMatch[2] || 'mp4';
                const size = sourceMatch[3] ? parseInt(sourceMatch[3], 10) : 0;
                const label = sourceMatch[4] || '';
                let quality = 'SD';
                if (label) quality = label;
                else if (size >= 720) quality = 'HD';
                else if (size >= 480) quality = '480p';
                else if (size >= 360) quality = '360p';
                const streamType = videoUrl.includes('.m3u8') ? 'm3u8' : (videoUrl.includes('.mpd') ? 'dash' : 'mp4');
                streams.push({
                    quality: quality,
                    url: videoUrl,
                    type: streamType,
                    headers: { "Referer": this.baseUrl + '/' }
                });
            }

            if (streams.length === 0) {
                const slugMatch = url.match(/\/(?:assistir|i)\/([^\/?#]+)/);
                if (slugMatch) {
                    const slug = slugMatch[1];
                    const directUrl = 'https://vdn.libreflix.org/video/' + slug + '/' + slug + '.720.mp4';
                    try {
                        const testResponse = await fetch(directUrl, {
                            headers: {
                                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                                'Referer': this.baseUrl + '/'
                            }
                        });
                        if (testResponse.ok || testResponse.status === 206) {
                            streams.push({
                                quality: 'HD',
                                url: directUrl,
                                type: 'mp4',
                                headers: { "Referer": this.baseUrl + '/' }
                            });
                        }
                    } catch (e) {}
                }
            }

            console.log('[Libreflix getEpisodeStreams] Returning', streams.length, 'streams');
            return { streams: streams, subtitles: [] };
        } catch (error) {
            console.error('[Libreflix getEpisodeStreams] Error:', error.message || error);
            return { streams: [], subtitles: [] };
        }
    }
};

source;
