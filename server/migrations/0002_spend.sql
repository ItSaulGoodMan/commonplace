-- What each account cost per UTC month, measured from Gemini's own token
-- counts. micro_usd counts only the paid key: the free key costs nothing.
CREATE TABLE spend (
  user_id TEXT NOT NULL,
  month TEXT NOT NULL,
  micro_usd INTEGER NOT NULL DEFAULT 0,
  notes INTEGER NOT NULL DEFAULT 0,
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, month)
);

CREATE INDEX spend_month ON spend (month);
