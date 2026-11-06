# Commonplace server

A Cloudflare Worker that makes notes for the Play edition of Commonplace, so people sign in with Google instead of bringing their own Gemini key.

- **Sign-in.** The app sends the ID token from "Sign in with Google". The server checks Google's signature, the audience (your OAuth Web client ID), expiry and a verified email. It then returns its own 90-day session.
- **Notes.** The app streams each video or image to `POST /v1/files`, which goes straight on to Gemini's Files API. `POST /v1/note` has Gemini watch them **once** and return what it read (transcript, on-screen text) together with the note, then deletes them from Gemini. `POST /v1/write` is text only, for text notes and "write again". The prompts live here (`src/prompts.json`, exported from the app), so the key can't be used for anything else. (`/v1/extract` is the older read-only step.)
- **Limits.** Each account gets `FREE_NOTES_PER_DAY` notes per UTC day, or `PLUS_NOTES_PER_DAY` with Commonplace Plus. Failed work is refunded.
- **Shared free key.** Everyone on the free plan uses `GEMINI_API_KEY`, which belongs to a Google AI Studio project **without billing**, so it can never cost anything. When Gemini says the free key's day is used up, the server stops trying until midnight Pacific time, and notes wait in the app.
- **Plus.** `POST /v1/plus` checks a Google Play purchase with the Play Developer API (`purchases.subscriptionsv2`). The purchase is tied to the account and can't unlock a second one. If `GEMINI_PAID_API_KEY` is set (a separate project with billing, paid for by subscriptions), subscribers use it and aren't affected by the shared free limit.
- **Deletion.** `DELETE /v1/me` removes everything the server keeps about an account.

## How it keeps every subscriber profitable

- **Free accounts can't cost money.** They only ever use the free key (a project without billing).
- **Every request is metered.** The server reads Gemini's own token counts (`usageMetadata`), prices them with `PAID_PRICE_*_PER_M` and adds them to the account's month (`spend` table).
- **Subscribers have a monthly budget.** Each subscriber uses the paid key until their measured cost reaches `PLUS_MONTHLY_BUDGET_USD` (default $1.00), then the free key until the month ends. A subscriber can't cost more than the budget plus one note (under a cent). Keep the budget well under what a subscription brings in after Google's 15%. With $2.99 a month, that's about $2.54.
- **Cheap by default:**
  - one request per note (watch once, read and write together);
  - Flash-Lite on both keys;
  - thinking set to `MINIMAL`, since Google bills thinking as output;
  - `maxOutputTokens` capped, so a runaway answer can't run up a bill.
- **Watching to fit the video:**
  - up to 90 s (reels): one frame a second, Gemini's default, so captions that flash by aren't missed;
  - up to 3 min: one frame every 2 s;
  - longer: one every 4 s, and only the first 10 minutes. Sound is always heard in full.

  Gemini watches video in low resolution: about 100 tokens a second including sound. A one-minute reel comes to roughly 0.25 to 0.4 cents on Flash-Lite.
- **If a model refuses the thinking setting** (a 400 that mentions thinking), the request is sent again without it, so no note is lost.

## Numbers for the owner

Set `ADMIN_TOKEN` (32+ random characters, `npx wrangler secret put ADMIN_TOKEN`). Then:

```bash
curl -H "Authorization: Bearer <ADMIN_TOKEN>" https://commonplace-api.<you>.workers.dev/v1/admin/stats
```

It shows:
- notes and active users today and this month;
- what the paid key cost this month, and the tokens used;
- how many subscribers there are, and how many reached their budget;
- whether the free key is used up for today.

Without `ADMIN_TOKEN` the endpoint doesn't exist.

The server stores only the email, the name, daily counts, and a hash of each purchase token. Videos never touch storage; they stream through to Gemini and are deleted after reading.

## Run it locally (free, nothing leaves your PC)

Needs Node 22+.

```bash
cd server
npm install
cp .dev.vars.example .dev.vars          # mock keys only
npm run migrate:local
python ../tool/mock_gemini_server.py    # in another terminal, port 8787
npm run dev                             # http://0.0.0.0:8790
```

The `dev` environment has `DEV_FAKES=1`. That makes the server accept made-up sign-ins (`dev:{"sub":"1","email":"a@b.c"}`) and purchases (`fake-<accountRef>-1`), so the app can be tested on an emulator without Google:

```bash
flutter run --flavor play \
  --dart-define=API_BASE_URL=http://10.0.2.2:8790 --dart-define=DEV_FAKES=true
```

Tests run inside the Workers runtime against a real (local) D1 database:

```bash
npm test           # 27 tests
npm run typecheck
```

## Deploy

1. `npx wrangler login` (a free Cloudflare account; no card needed).
2. `npx wrangler d1 create commonplace`, and put the printed `database_id` in `wrangler.jsonc` (top level, not `env.dev`).
3. `npx wrangler d1 migrations apply commonplace --remote` (again after pulling new files in `migrations/`)
4. In `wrangler.jsonc`, set `GOOGLE_CLIENT_IDS` to your OAuth **Web application** client ID.
5. Set the secrets:

   ```bash
   npx wrangler secret put GEMINI_API_KEY        # AI Studio key, project WITHOUT billing
   npx wrangler secret put SESSION_SECRET        # 48+ random characters, e.g. `openssl rand -base64 48`
   npx wrangler secret put PLAY_SERVICE_ACCOUNT < play-service-account.json
   npx wrangler secret put ADMIN_TOKEN           # for /v1/admin/stats
   npx wrangler secret put GEMINI_PAID_API_KEY   # optional, later: project WITH billing
   ```

6. `npx wrangler deploy`. The printed `https://commonplace-api.<you>.workers.dev` is the app's `API_BASE_URL`.

The free Workers plan allows 100,000 requests a day. A note takes about four.

## Rules that come with the free Gemini key

Google's Gemini API terms say:

- **No EU, UK or Switzerland.** Apps offered to users in the European Economic Area, the UK or Switzerland must use paid services. Leave those countries out of the Play listing while the server runs on the free key.
- **18 and over.** Users must be 18 or older.
- **Google sees the content.** On the free tier, Google uses what's sent to improve its products, and people may review it. The app says so on the welcome screen and in Settings.
