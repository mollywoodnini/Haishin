import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

globalThis.atob ||= (str) => Buffer.from(str, 'base64').toString('binary');
globalThis.encodeURIComponent ||= encodeURIComponent;
globalThis.decodeURIComponent ||= decodeURIComponent;

if (!process.argv[2]) {
    console.error('Usage: node test-script.mjs <path/to/source.js>');
    process.exit(1);
}

const sourcePath = process.argv[2];
console.log(`Testing: ${sourcePath}`);
const code = readFileSync(sourcePath, 'utf-8');

const fn = new Function('var source;\n' + code + '\nreturn source;');
const src = fn();

if (!src) {
    console.error('FAIL: Could not extract `source` object from script');
    process.exit(1);
}

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------
let passed = 0;
let failed = 0;

async function test(name, fn) {
    try {
        const result = await fn();
        if (result === true || result === undefined) {
            console.log(`  PASS  ${name}`);
            passed++;
        } else {
            console.log(`  FAIL  ${name} — ${result}`);
            failed++;
        }
    } catch (e) {
        console.log(`  FAIL  ${name} — ${e.message}`);
        failed++;
    }
}

function assert(condition, msg) {
    if (!condition) throw new Error(msg || 'assertion failed');
}

function isObject(v) {
    return v && typeof v === 'object' && !Array.isArray(v);
}

function isArray(v) {
    return Array.isArray(v);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
async function main() {
    console.log('\n== Metadata ==');
    await test('id is a non-empty kebab-case string', () => {
        assert(typeof src.id === 'string' && src.id.length > 0);
        assert(/^[a-z0-9]+(-[a-z0-9]+)*$/.test(src.id), `id="${src.id}" not kebab-case`);
    });
    await test('name is a non-empty string', () => {
        assert(typeof src.name === 'string' && src.name.length > 0);
    });
    await test('version is a non-empty string', () => {
        assert(typeof src.version === 'string' && src.version.length > 0);
    });
    await test('baseUrl is a valid URL', () => {
        assert(typeof src.baseUrl === 'string' && src.baseUrl.startsWith('http'));
    });
    await test('language is a non-empty string', () => {
        assert(typeof src.language === 'string' && src.language.length > 0);
    });
    await test('nsfw is boolean, description is string', () => {
        assert(typeof src.nsfw === 'boolean');
        assert(typeof src.description === 'string');
    });

    console.log('\n== Method signatures ==');
    const required = ['search', 'getVideoDetails', 'getEpisodeStreams', 'getEntryVideos'];
    for (const name of required) {
        await test(`${name} exists and is async`, () => {
            assert(typeof src[name] === 'function');
            assert(src[name].constructor.name === 'AsyncFunction', `not async: ${src[name].constructor.name}`);
        });
    }

    console.log('\n== Live HTTP tests ==');

    // -- getEntryVideos → first item → getVideoDetails → first episode → getEpisodeStreams

    let entry;
    await test('getEntryVideos() returns items', async () => {
        const r = await src.getEntryVideos();
        assert(isArray(r), 'not an array');
        assert(r.length > 0, 'no entries returned');
        const item = r[0];
        assert(typeof item.id === 'string' && item.id.length > 0, 'item.id invalid');
        assert(typeof item.title === 'string' && item.title.length > 0, 'item.title invalid');
        assert(typeof item.url === 'string' && item.url.length > 0, 'item.url invalid');
        console.log(`       ${r.length} entries, first: "${item.title}"`);
        entry = item;
    });

    if (entry) {
        await test(`getVideoDetails("${entry.id}") returns details`, async () => {
            const r = await src.getVideoDetails(entry.id, entry.url);
            assert(isObject(r), 'not an object');
            assert(typeof r.id === 'string' && r.id.length > 0, 'id invalid');
            assert(typeof r.title === 'string' && r.title.length > 0, 'title invalid');
            assert(isObject(r.servers), 'servers missing');
            assert(isObject(r.episodes), 'episodes missing');
            const serverKeys = Object.keys(r.servers);
            assert(serverKeys.length > 0, 'no servers defined');
            const eps = r.episodes[serverKeys[0]];
            assert(isArray(eps), `episodes[${serverKeys[0]}] not array`);
            assert(eps.length > 0, 'no episodes found');
            assert(typeof eps[0].id === 'string' && eps[0].id.length > 0, 'ep.id invalid');
            assert(typeof eps[0].number === 'number', 'ep.number not number');
            assert(typeof eps[0].url === 'string' && eps[0].url.length > 0, 'ep.url invalid');
            console.log(`       "${r.title}" — ${eps.length} episodes, ${serverKeys.length} server(s)`);
            entry.video = r;
        });
    }

    const video = entry?.video;
    if (video) {
        const serverKey = Object.keys(video.servers)[0];
        const episode = video.episodes[serverKey]?.[0];
        if (episode) {
            await test(`getEpisodeStreams("${episode.id}") returns streams`, async () => {
                const r = await src.getEpisodeStreams(episode.id, episode.url, serverKey);
                assert(isObject(r), 'not an object');
                assert(isArray(r.streams), 'streams not array');
                assert(r.streams.length > 0, '0 streams — source could not extract a playable video URL');
                const s = r.streams[0];
                assert(typeof s.url === 'string' && s.url.length > 0, 'stream.url empty');
                assert(typeof s.quality === 'string' && s.quality.length > 0, 'stream.quality empty');
                assert(['m3u8', 'mp4', 'dash'].includes(s.type), `unexpected type: ${s.type}`);
                console.log(`       ${r.streams.length} stream(s): ${s.url.substring(0, 80)}...`);
            });
        } else {
            console.log('  SKIP  getEpisodeStreams — video has no episodes');
        }
    } else {
        console.log('  SKIP  getVideoDetails/getEpisodeStreams — getEntryVideos returned nothing usable');
    }

    // -----------------------------------------------------------------------
    const total = passed + failed;
    const streamTested = !!(video && Object.keys(video.servers).length > 0 && video.episodes[Object.keys(video.servers)[0]]?.length > 0);
    console.log(`\n${'='.repeat(50)}`);
    if (failed > 0) {
        console.log(`${passed}/${total} passed, ${failed} failed`);
        process.exit(1);
    }
    if (!streamTested) {
        console.log(`All ${total} tests passed`);
        console.log();
        console.log('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
        console.log('!!!   WARNING: getEpisodeStreams was never called.         !!!');
        console.log('!!!   The source may produce zero streams; the app will    !!!');
        console.log('!!!   not be able to play anything.                        !!!');
        console.log('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
        process.exit(1);
    }
    console.log(`All ${total} tests passed`);
}

main().catch(e => {
    console.error('Fatal:', e.message);
    process.exit(1);
});
