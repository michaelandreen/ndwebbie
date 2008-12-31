CREATE TABLE intel (
	id SERIAL PRIMARY KEY,
	uid INTEGER NOT NULL REFERENCES users(uid),
	sender INTEGER NOT NULL REFERENCES planets(id),
	target INTEGER NOT NULL REFERENCES planets(id),
	mission TEXT NOT NULL,
	name TEXT NOT NULL,
	amount INTEGER,
	tick INTEGER NOT NULL,
	eta INTEGER NOT NULL,
	back INTEGER,
	ingal BOOLEAN NOT NULL
);

INSERT INTO intel (id,uid,sender,target,mission,name,amount,tick,eta,back,ingal)
	(SELECT id,uid,sender,target,mission,name,amount,tick,eta,back,ingal FROM fleets
		WHERE target IS NOT NULL);

ALTER TABLE fleets RENAME COLUMN id TO fid;
ALTER TABLE fleet_ships RENAME COLUMN id TO fid;
ALTER TABLE fleet_scans RENAME COLUMN id TO fid;
ALTER TABLE fleet_scans RENAME COLUMN scan TO id;

CREATE TABLE launch_confirmations (
	fid INTEGER PRIMARY KEY REFERENCES fleets(fid),
	uid INTEGER NOT NULL REFERENCES users(uid),
	target INTEGER NOT NULL REFERENCES planets(id),
	landing_tick INTEGER NOT NULL,
	eta INTEGER NOT NULL,
	back INTEGER NOT NULL
);

INSERT INTO launch_confirmations (fid,uid,target,eta,back,landing_tick) (
	SELECT fid,uid,target,eta,back,tick AS landing_tick FROM fleets
	WHERE fid IN (select fid FROM fleet_ships)
		AND uid <> -1 AND back IS NOT NULL AND target IS NOT NULL
);

CREATE TABLE full_fleets (
	fid INTEGER PRIMARY KEY REFERENCES fleets(fid),
	uid INTEGER NOT NULL REFERENCES users(uid)
);

INSERT INTO full_fleets (fid,uid) (
	SELECT fid,uid FROM fleets WHERE fid IN (select fid FROM fleet_ships)
		AND uid <> -1 AND mission = 'Full fleet' AND name = 'Main'
);

ALTER TABLE fleets DROP COLUMN target;
ALTER TABLE fleets DROP COLUMN eta;
ALTER TABLE fleets DROP COLUMN back;
ALTER TABLE fleets DROP COLUMN ingal;
ALTER TABLE fleets DROP COLUMN uid;

ALTER TABLE fleets RENAME COLUMN sender TO planet;

CREATE TABLE intel_scans (
	id INTEGER REFERENCES scans(id),
	intel INTEGER REFERENCES intel(id),
	PRIMARY KEY (id,intel)
);

INSERT INTO intel_scans (id,intel) (
	SELECT id,fid FROM fleet_scans WHERE id IN (
		SELECT id from scans where type in ('News','Jumpgate')
	)
);

DELETE FROM fleet_scans WHERE id IN (
	SELECT id from scans where type in ('News','Jumpgate')
);

DELETE FROM fleets WHERE fid NOT IN (
	SELECT fid FROM fleet_scans
	UNION SELECT fid FROM full_fleets
	UNION SELECT fid FROM launch_confirmations
);
