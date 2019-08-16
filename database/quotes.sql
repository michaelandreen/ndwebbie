CREATE TABLE IF NOT EXISTS quotes (
	qid serial PRIMARY KEY,
	time timestamptz NOT NULL DEFAULT now(),
	uid integer NOT NULL REFERENCES users(uid),
	quote text NOT NULL
);

CREATE TABLE IF NOT EXISTS removed_quotes (
	qid serial PRIMARY KEY,
	time timestamptz NOT NULL DEFAULT now(),
	uid integer NOT NULL REFERENCES users(uid),
	removed_by integer NOT NULL REFERENCES users(uid),
	quote text NOT NULL
);
