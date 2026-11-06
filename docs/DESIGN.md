# Design

## The idea

A **commonplace book** is the centuries-old habit of copying useful passages from everything you read into one book, sorted under headings. That's this app: tips from many creators, copied out and shelved by topic. It's what "saved" was supposed to be.

The visual language comes from studying with a pen in hand, not from book nostalgia. Cool printer paper, blue-black ink, and **a fluorescent highlighter**. The highlighter is the one loud thing. Each key point has its most important phrase marked with a hand-drawn swipe, and the AI chooses the phrase. Everything else stays quiet.

Deliberately avoided: cream paper with a serif and terracotta accent, near-black with an acid accent, identical rounded cards with soft shadows, all-caps eyebrow labels, `A · B · C` meta strings, monospace data labels, and arrow-suffixed buttons.

## Tokens

| Role | Light | Dark | Notes |
|---|---|---|---|
| paper (background) | `#F4F6F9` | `#161E2E` | cool, slightly blue; dark is ink-navy, not grey-black |
| sheet (raised surface) | `#FFFFFF` | `#1F293C` | bottom sheets, the revisit block |
| ink (text, primary) | `#1D2B4F` | `#E7EBF3` | 12.8:1 / 14.0:1 |
| ink soft (secondary text) | `#566079` | `#A3AEC4` | 5.8:1 / 7.5:1 |
| highlighter | `#FFE45C` | `#F2DC57` | ink on it: 10.9:1 / 12.0:1 |
| rule (dividers) | `#D5DCE6` | `#33405A` | decorative only |
| error ink | `#B4322A` | `#FF9C8F` | |

Spacing uses a 4/8 rhythm: 4, 8, 12, 16, 24, 32, 48. Page gutter is 20 on phones and grows on wide screens. Reading measure is capped at 640 dp.

Radii follow hierarchy: 999 for chips and the FAB pill, 16 for sheets, 4 for the highlighter swipe (it's a marker, not a pill). Elevation is replaced by tone. Sheets are a lighter paper, not shadowed.

## Type

Everything is set in **Recursive**, one variable family with two voices:

- **Casual** (`CASL 1`, `wght 640–720`) for note titles, screen titles, and the revisit quote. It reads as quick confident marker lettering.
- **Linear** (`CASL 0`, `wght 400/560`) for reading text, transcripts, and UI.

Scale (dp): 34 display, 26 title, 20 heading, 17 body-large (reading), 15 body, 13 small. Reading text gets line height 1.55; UI text 1.35. Sentence case everywhere.

## Screens

```
Home                         Note
┌──────────────────────────┐ ┌──────────────────────────┐
│ Commonplace         ⌕  ⚙ │ │ ←                    ☆ ⋮ │
│                          │ │ Write titles like the    │
│ From three weeks ago     │ │ question people search   │
│ ▓Answer in the first 100▓│ │ @seo.with.sam, saved 3d  │
│ words — it's what lands  │ │ ago · Open on Instagram  │
│ in the snippet           │ │                          │
│ Three SEO tips…   Open   │ │ summary paragraph…       │
│──────────────────────────│ │                          │
│ All  SEO  Cooking  Career│ │ Key points               │
│                          │ │ ▓Title = the question▓   │
│ Write titles like the…   │ │ people actually type…    │
│ Answer in the first…     │ │                          │
│ SEO, 3 days ago          │ │ Things to try            │
│──────────────────────────│ │ ☐ Rewrite one title…     │
│ Waiting for the video    │ │                          │
│ instagram.com/reel/…     │ │ Your notes               │
│ [Add the video]          │ │ ...                      │
│                    (+ Add)│ │ Transcript ▸             │
└──────────────────────────┘ └──────────────────────────┘
```

- **Home**: revisit block, then topic shelves as a horizontal row of text chips, then a quiet list of notes separated by rules. No cards. Notes that need attention (waiting for video, failed) sit at the top of the list in their own state, with one clear action.
- **Note**: reading layout. The title is in the casual voice, and the source line is natural language ("from @handle, saved 3 days ago"). Key points carry the highlighter. Actions are checkable. Your notes are editable inline. Transcript and on-screen text are collapsed at the bottom.
- **Add sheet**: Choose a video · Choose screenshots · Paste a link · Write or paste text. The Download hint shows only when Instagram isn't connected.
- **Welcome** (first run): three real steps that do something: Connect Instagram (a button, then "Connected as @name"), the free Gemini key (the key field inline), and "Save reels as usual".
- **Sign in to Instagram**: Instagram's own page in a web view, under one line that says so and what Commonplace reads. After sign-in, the same screen asks one question: "Make notes from the 10 posts you saved last, too?" (Yes, make 10 notes / No, only new saves).
- **Home** with Instagram: pull to look for new saves ("Found 2 new saves. Making the notes."). A note being fetched says "Getting it from Instagram...". If Instagram ends the session, a quiet sheet-coloured banner says new saves aren't coming in and offers "Sign in again". The empty state leads with "Connect Instagram"; once connected it becomes "Save a reel on Instagram, then come back here."
- **Settings**: Instagram first ("Connected as @name", when it last looked, Look now, Disconnect, and one plain paragraph on how it works), then the Gemini key, model, note language, theme, keep videos.

## Motion

Only one moment is choreographed. When a note finishes processing, its key points' highlighter swipes draw left to right in a short stagger (≈350 ms each). It happens once per note, the first time you open it, and is skipped under reduced motion. Everything else uses standard Material transitions.

## Copy rules

- Name things by what they are to the user: "Waiting for the video", not "pending media".
- Buttons say what happens: "Add the video", "Try again", "Save key".
- Errors say what happened and what to do: "Gemini says the free limit is used up for now. Try again in a minute."
