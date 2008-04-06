CREATE TABLE covop_attacks (
	uid integer NOT NULL REFERENCES users(uid),
	tick integer NOT NULL,
	id integer NOT NULL REFERENCES planets(id),
	PRIMARY KEY (id,tick,uid)
);
