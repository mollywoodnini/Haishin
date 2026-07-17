---
description: Create a new Haishin JS source by live-scraping a website
agent: source-adder
---

Create a new Haishin JavaScript source by live-scraping $ARGUMENTS.

1. Gather requirements: ask for website URL, source name, ID, language, author, NSFW
2. Fetch the website and analyze HTML structure (entry page, search, video details, streams)
3. Generate a complete source.js in examples/ following the Haishin JS source contract
4. Include all required metadata and four required methods: search, getVideoDetails, getEpisodeStreams, getEntryVideos
