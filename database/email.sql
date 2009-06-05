DROP TABLE IF EXISTS email_change;
CREATE TABLE email_change (
	id TEXT PRIMARY KEY DEFAULT (md5((now() + random() * interval '100 year')::text)),
	uid INTEGER NOT NULL REFERENCES users(uid),
	email TEXT NOT NULL,
	confirmed BOOLEAN NOT NULL DEFAULT false
);
