CREATE TABLE session_log (
	uid INTEGER NOT NULL REFERENCES users(uid),
	time TIMESTAMP WITH TIME ZONE NOT NULL,
	ip INET NOT NULL,
	country CHAR(2) NOT NULL,
	session TEXT NOT NULL,
	remember BOOL NOT NULL,
	PRIMARY KEY(uid,time,ip)
);
