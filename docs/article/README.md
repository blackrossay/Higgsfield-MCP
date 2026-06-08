# Article — "Anatomy of an AI Token"

A companion technical article walking through how the video [`assets/anatomy-of-an-ai-token.mp4`](../../assets/anatomy-of-an-ai-token.mp4) was generated end-to-end with [`@higgsfield/cli`](https://www.npmjs.com/package/@higgsfield/cli) on a corporate Windows VM (no admin, behind Zscaler).

## Versions

| File | Where to publish | Notes |
|---|---|---|
| [`anatomy-of-an-ai-token.md`](anatomy-of-an-ai-token.md) | This GitHub repo, docs | Canonical source. Full markdown with embedded images, code blocks, and tables. |
| [`anatomy-of-an-ai-token.devto.md`](anatomy-of-an-ai-token.devto.md) | [dev.to](https://dev.to/new) | Has dev.to front-matter (`title`, `tags`, `cover_image`, `canonical_url`). Copy-paste the whole file into the editor — front-matter is parsed automatically. **Published:** https://dev.to/blackrossay/anatomy-of-an-ai-token-how-i-generated-a-cinematic-visualisation-of-the-ai-inference-pipeline-from-1f8e |
| [`anatomy-of-an-ai-token.linkedin.md`](anatomy-of-an-ai-token.linkedin.md) | [LinkedIn long-form articles](https://www.linkedin.com/article/new) | Lean narrative version. Code blocks/tables flattened to prose. Hashtags at bottom. Cover image: upload `anatomy-poster.jpg` manually. Includes back-link to the dev.to canonical. |
| [`anatomy-of-an-ai-token.linkedin-feed.md`](anatomy-of-an-ai-token.linkedin-feed.md) | LinkedIn feed (the "Start a post" composer, not the article composer) | Two short variants (curiosity hook ~1,400 chars, provocative hook ~900 chars). Designed to drive traffic to the dev.to article so comments accumulate there. |

## Assets

| File | Purpose |
|---|---|
| [`anatomy-poster.jpg`](anatomy-poster.jpg) | Hero / cover image (datacenter aisle, frame at 3.5 s) |
| [`anatomy-poster-end.jpg`](anatomy-poster-end.jpg) | Secondary embed (golden-tokens-on-GPU, frame at 6.5 s) |
| [`../../assets/anatomy-of-an-ai-token.mp4`](../../assets/anatomy-of-an-ai-token.mp4) | The video itself, 9 MB, 8 s, 16:9, no audio |

## Reproducing the poster frames

The two `.jpg` files were extracted from the MP4 with `ffmpeg`:

```powershell
ffmpeg -y -ss 00:00:03.5 -i assets/anatomy-of-an-ai-token.mp4 -frames:v 1 -q:v 2 docs/article/anatomy-poster.jpg
ffmpeg -y -ss 00:00:06.5 -i assets/anatomy-of-an-ai-token.mp4 -frames:v 1 -q:v 2 docs/article/anatomy-poster-end.jpg
```

No FFmpeg on a corporate VM? Grab a portable build (no admin) — same pattern as the Higgsfield installer:

```powershell
mkdir vendor; cd vendor
curl.exe -fLso ffmpeg.zip "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
C:\Windows\System32\tar.exe -xf ffmpeg.zip
.\ffmpeg-master-latest-win64-gpl\bin\ffmpeg.exe -version
```
