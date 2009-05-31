DROP TABLE IF EXISTS sms;
CREATE TABLE sms (
	id SERIAL PRIMARY KEY,
	msgid TEXT UNIQUE,
	uid INTEGER NOT NULL REFERENCES users(uid),
	status TEXT NOT NULL DEFAULT 'Waiting',
	number TEXT NOT NULL,
	message VARCHAR(140) NOT NULL,
	cost NUMERIC(4,2) NOT NULL DEFAULT 0,
	time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX sms_status_msgid_idx ON sms (status) WHERE msgid IS NULL;

DROP TABLE IF EXISTS clickatell;

CREATE TABLE clickatell (
	api_id TEXT NOT NULL,
	username TEXT NOT NULL,
	password TEXT NOT NULL,
	PRIMARY KEY (api_id, username)
);

