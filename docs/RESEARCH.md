# Research notes

Done on 2026-11-06 before writing any code. Each section ends with the decision it led to.

## 1. Why saved reels never get rewatched

Commentary on read-later apps (Pocket, Instapaper, bookmarks) agrees on a few points. Nobody has published rigorous research here, so treat these as working assumptions:

- **Saving is effortless; returning takes work.** The queue grows until people feel guilty and abandon it.
- **Saving feels like progress.** The act of collecting satisfies the urge to learn, even when nothing is learned.
- **Nothing brings you back.** Saved items disappear from view, and no trigger reminds you they exist.
- **Retrieval cues are weak.** A grid of thumbnails gives you no way to find "that SEO tip about titles".
- **The real job is finding later, not reading later.** The intent is usually "I might need this", not "I will watch this tonight".

**Decisions**
- The note is the product, not the video. Each reel becomes something you can skim in 10 seconds: a title, a summary, and highlighted key points.
- Search covers everything: title, summary, points, transcript, on-screen text, and your own notes.
- Every note lands on a topic shelf (SEO, Cooking, ...). The AI assigns it, and you can change it.
- **Revisit.** The home screen always opens with one older note you haven't looked at in a while. It changes daily rather than on every refresh, so it feels deliberate. This is the trigger to come back.
- **Things to try.** Actionable reels get checkable actions, which turns "aspirational saving" into something you can finish.

## 2. Getting the reel's content

Instagram has no public API for saved posts or for downloading another account's media.

- The GraphQL endpoints that unofficial downloaders relied on are being shut down server-side. The old `doc_id`s now return errors, and the replacements rotate.
- Fetching a reel page anonymously from here returned an empty app shell behind a login/challenge wall, with no metadata.
- Getting around that means bot-check circumvention: spoofing crawler user agents or fingerprints. That is off the table. It breaks Instagram's terms, and it breaks again every few weeks.

What *is* reliable and legitimate:

- **The video file itself.** Instagram's share sheet has **Download** for public reels, and Android's screen recorder works for everything else. The user shares the file to Commonplace or picks it with the system photo picker, which needs no permissions.
- **The link.** Sharing a reel to the app gives a URL (`ACTION_SEND`, `text/plain`). Commonplace saves it right away as a note waiting for its video, so nothing gets lost, and attaching the video takes one tap.
- **Text.** A pasted caption or any text works too.

**First decision:** video-first, with link and text capture. Automatic link-to-video would need the user's own logged-in Instagram session inside an in-app browser.

**Revised at the owner's request (November 2026): sign in with Instagram.** The owner wanted saving a reel on Instagram to be enough, and sharing a link to be enough. That needs their own session, so Commonplace now does what the "logged-in session" option above describes:

- **Sign-in happens on Instagram's own page**, in a web view inside the app. The owner types their password into Instagram, not into Commonplace. Two-step codes and "is this you?" checks are answered there by the owner. Commonplace only notices when the session cookie appears (`MainActivity.kt` reads it from Android's `CookieManager`, because it's HttpOnly) and stores it in the Keystore.
- **It reads what instagram.com reads**: `GET /api/v1/feed/saved/posts/` for the Saved list (newest save first, paged by `max_id`) and `GET /api/v1/media/{id}/info/` for one post. These go out with the owner's cookies, the web view's own user agent, and the headers the website sends (`X-IG-App-ID: 936619743392459`, `X-CSRFToken`). The video then comes from the CDN link in that answer. The shapes match a current open-source client of the same endpoints ([gitnasr/Instagram-Saved-Posts](https://github.com/gitnasr/Instagram-Saved-Posts), `src/lib/instagram-api.ts` and `src/types/instagram.ts`), and the shortcode-to-id conversion is the base-64 scheme instaloader uses.
- **It stays light.** A check reads one page and stops at the first post it has seen before. Checks happen when the app opens or comes back to the front, at most every two minutes, or when the owner pulls to refresh. There is no background polling. At most 20 new notes come from one check, which also protects Gemini's free daily limit.
- **It never works around Instagram.** A `login_required`, `checkpoint_required` or `challenge_required` answer marks the session as signed out, and the owner is sent back to the real sign-in page. A "please wait" answer pauses the queue for ten minutes. Nothing is retried in a loop.
- **The honest caveats.** These are undocumented endpoints, so Instagram can change them without notice. Automated access also isn't something Instagram's terms allow, so the owner is told in Settings how it works. The share-a-video path still works without signing in, as a fallback.

On first sign-in the owner chooses whether their 10 latest saves become notes too, or only new saves from then on. A table of seen post ids stops a deleted note from coming back.

## 3. Turning a video into notes

| Option | Audio | On-screen text | Cost | Verdict |
|---|---|---|---|---|
| Gemini (AI Studio key) | yes | yes, it watches the frames | **free tier, no card**; rate-limited | **default** |
| Whisper (OpenAI/Groq) + LLM | yes | no | paid / free tier | needs two keys |
| On-device whisper.cpp | yes | no | free | heavy native build, can't summarise |

Many tip reels are mostly **text overlays over music**, so an engine that only hears audio misses the content. Gemini reads both from one upload.

The pipeline has two stages, so notes can be regenerated without re-uploading the video:

1. **Extract** (video → transcript, on-screen text, visual notes, language, @handle)
2. **Distill** (text → title, summary, key points with a highlight phrase, actions, topic, tags)

Both stages use `models/{model}:generateContent` with `generationConfig.responseMimeType = application/json` and `responseJsonSchema`. Files under ~15 MB go inline (`inlineData`). Larger ones use the resumable Files API upload (`fileData.fileUri`) and are polled until `ACTIVE`.

**Cost rule:** the owner must never be charged by surprise. The app tells people to create the key in AI Studio *without* enabling billing, which keeps it on the free tier. It says honestly that Google may use free-tier inputs to improve its products. Rate-limit errors (429) read as "Free limit reached", and the note can be retried later. Development tests run against a local mock of the Gemini REST API, never the real one.

## 4. Platform and stack

- **Flutter 3.47.9 / Dart 3.13.7**, Android first. The code is platform-neutral. iOS still needs a Share Extension target (supported by `receive_sharing_intent`) and a Mac to build.
- **Architecture** follows the official Flutter skill (`flutter-apply-architecture-best-practices`): MVVM with `ChangeNotifier` ViewModels, repositories over services, constructor injection via `provider`.
- **Storage:** Drift (SQLite), with migrations available for future features.
- **Secrets:** API key in `flutter_secure_storage` (Android Keystore), never in prefs or logs.
- **Share target:** `receive_sharing_intent` for `text/plain`, `video/*`, and `image/*`.
- **Picker:** `image_picker`, which uses the Android Photo Picker (no storage permission).

## Sources

- Instagram endpoint churn: [yt-dlp #11151](https://github.com/yt-dlp/yt-dlp/issues/11151), [instaloader #2706](https://github.com/instaloader/instaloader/pull/2706), [Instagram-Downloader #38](https://github.com/hoaianle/Instagram-Downloader/issues/38), [Scrapfly 2026 guide](https://scrapfly.io/blog/posts/how-to-scrape-instagram)
- Read-later behaviour: [The save-for-later paradox](https://creativerly.com/the-save-for-later-paradox-why-we-hoard-digital-content-we-never-read), [Why you never read what you save](https://refloat.pages.dev/blog/why-you-never-read-what-you-save/), [A 20-year history of read-it-later apps](https://www.slax.com/blog/read-it-later-history/)
- Gemini: [video understanding](https://aistudio.google.com/docs/video-understanding), [models](https://aistudio.google.com/docs/models), [generateContent reference](https://aistudio.google.com/api-reference/generate-content), [structured output](https://aistudio.google.com/docs/structured-output), [pricing](https://ai.google.dev/gemini-api/docs/pricing)
