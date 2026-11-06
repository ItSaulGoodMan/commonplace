-- People signed in with Google. `id` is Google's account id (the token's `sub`).
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  created_at INTEGER NOT NULL,
  -- Commonplace Plus, from Google Play: access lasts until plus_until (ms).
  plus_until INTEGER,
  plus_product TEXT,
  plus_token TEXT,
  plus_checked_at INTEGER
);

-- What each person used per UTC day.
CREATE TABLE usage (
  user_id TEXT NOT NULL,
  day TEXT NOT NULL,
  notes INTEGER NOT NULL DEFAULT 0,
  rewrites INTEGER NOT NULL DEFAULT 0,
  uploads INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day)
);

-- Proof that a note's extract step was paid for, so its write step is free.
CREATE TABLE tickets (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);

-- Files uploaded to Gemini's Files API, and whose they are.
CREATE TABLE files (
  name TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  uri TEXT NOT NULL,
  pool TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

-- A Play purchase belongs to one account.
CREATE TABLE purchases (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL
);

-- Small shared facts, e.g. until when the free Gemini key is used up.
CREATE TABLE shared_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE INDEX usage_day ON usage (day);
CREATE INDEX files_user ON files (user_id);
CREATE INDEX tickets_user ON tickets (user_id);
