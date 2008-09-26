CREATE TABLE scan_requests (
	id      SERIAL PRIMARY KEY,
	uid     INTEGER NOT NULL REFERENCES users(uid),
	planet  INTEGER NOT NULL REFERENCES planets(id),
	type    TEXT NOT NULL,
	nick    TEXT NOT NULL,
	tick    INTEGER NOT NULL DEFAULT tick(),
	time    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	sent    BOOL NOT NULL DEFAULT FALSE,
	UNIQUE (tick,planet,type,uid)
);

CREATE INDEX scan_requests_time_not_sent_index ON scan_requests(time) WHERE NOT sent;

