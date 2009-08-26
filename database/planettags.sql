CREATE TABLE available_planet_tags (
	tag CITEXT PRIMARY KEY
);

CREATE TABLE planet_tags (
	pid INTEGER NOT NULL REFERENCES planets (pid)
	,tag CITEXT NOT NULL REFERENCES available_planet_tags (tag)
	,uid INTEGER REFERENCES users (uid)
	,time TIMESTAMPTZ NOT NULL DEFAULT NOW()
	,PRIMARY KEY (pid,uid,tag)
);
