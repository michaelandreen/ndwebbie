ALTER TABLE fleets ADD COLUMN sender INTEGER NOT NULL REFERENCES planets(id) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE fleets DROP COLUMN fleet;

ALTER TABLE fleets ALTER COLUMN target DROP NOT NULL;

ALTER TABLE fleets ALTER COLUMN back DROP NOT NULL;

ALTER TABLE fleets ALTER COLUMN eta DROP NOT NULL;

ALTER TABLE fleets ADD COLUMN amount INTEGER;

ALTER TABLE fleets ADD COLUMN name TEXT NOT NULL;

ALTER TABLE fleets ADD COLUMN ingal BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE fleets RENAME COLUMN landing_tick TO tick;

ALTER TABLE fleet_ships RENAME COLUMN fleet TO id;


CREATE TABLE fleet_scans (
	id INTEGER PRIMARY KEY REFERENCES fleets(id),
	scan INTEGER NOT NULL REFERENCES scans(id)
) WITHOUT OIDS;

ALTER TABLE scans DROP COLUMN scan;

ALTER TABLE scans DROP COLUMN type;

ALTER TABLE scans ADD COLUMN type TEXT;

ALTER TABLE scans ADD COLUMN uid INTEGER NOT NULL DEFAULT -1 REFERENCES users(uid) ON UPDATE RESTRICT ON DELETE RESTRICT;

ALTER TABLE scans ADD COLUMN groupscan BOOLEAN NOT NULL DEFAULT False;

ALTER TABLE scans ADD COLUMN parsed BOOLEAN NOT NULL DEFAULT False;

ALTER TABLE scans ADD COLUMN id SERIAL PRIMARY KEY;

ALTER TABLE scans ADD UNIQUE (scan_id, tick, groupscan);

CREATE OR REPLACE FUNCTION planetid(x integer, y integer, z integer, tick integer) RETURNS integer
    AS $_$SELECT id FROM planet_stats WHERE x = $1 AND y = $2 AND z = $3 AND (tick >= $4  OR tick =( SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC LIMIT 1$_$
    LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION planetcoords(IN id integer,IN tick integer, OUT x integer,OUT y integer,OUT z integer)
    AS $_$SELECT x,y,z FROM planet_stats WHERE id = $1 AND (tick >= $2  OR tick =( SELECT max(tick) FROM planet_stats))  ORDER BY tick ASC LIMIT 1$_$
    LANGUAGE sql STABLE;

CREATE TABLE planet_data_types (
	id SERIAL PRIMARY KEY,
	category TEXT NOT NULL,
	name TEXT NOT NULL,
	UNIQUE (category,name)
) WITHOUT OIDS;

INSERT INTO planet_data_types (category,name) VALUES('roid','Metal');
INSERT INTO planet_data_types (category,name) VALUES('roid','Crystal');
INSERT INTO planet_data_types (category,name) VALUES('roid','Eonium');
INSERT INTO planet_data_types (category,name) VALUES('resource','Metal');
INSERT INTO planet_data_types (category,name) VALUES('resource','Crystal');
INSERT INTO planet_data_types (category,name) VALUES('resource','Eonium');
INSERT INTO planet_data_types (category,name) VALUES('tech','Space Travel');
INSERT INTO planet_data_types (category,name) VALUES('tech','Infrastructure');
INSERT INTO planet_data_types (category,name) VALUES('tech','Hulls');
INSERT INTO planet_data_types (category,name) VALUES('tech','Waves');
INSERT INTO planet_data_types (category,name) VALUES('tech','Core Extraction');
INSERT INTO planet_data_types (category,name) VALUES('tech','Covert Ops');
INSERT INTO planet_data_types (category,name) VALUES('tech','Asteroid Mining');
INSERT INTO planet_data_types (category,name) VALUES('struc','Light Factory');
INSERT INTO planet_data_types (category,name) VALUES('struc','Medium Factory');
INSERT INTO planet_data_types (category,name) VALUES('struc','Heavy Factory');
INSERT INTO planet_data_types (category,name) VALUES('struc','Wave Amplifier');
INSERT INTO planet_data_types (category,name) VALUES('struc','Wave Distorter');
INSERT INTO planet_data_types (category,name) VALUES('struc','Metal Refinery');
INSERT INTO planet_data_types (category,name) VALUES('struc','Crystal Refinery');
INSERT INTO planet_data_types (category,name) VALUES('struc','Eonium Refinery');
INSERT INTO planet_data_types (category,name) VALUES('struc','Research Laboratory');
INSERT INTO planet_data_types (category,name) VALUES('struc','Finance Centre');
INSERT INTO planet_data_types (category,name) VALUES('struc','Security Centre');

CREATE TABLE planet_data (
	id INTEGER NOT NULL REFERENCES planets(id),
	scan INTEGER NOT NULL REFERENCES scans(id),
	tick INTEGER NOT NULL,
	rid INTEGER NOT NULL REFERENCES planet_data_types(id),
	amount INTEGER NOT NULL,
	PRIMARY KEY(rid,scan)
) WITHOUT OIDS;

DROP TABLE intel;

CREATE INDEX fleets_tick_index ON fleets (tick);
CREATE INDEX fleets_target_index ON fleets (target);
CREATE INDEX fleets_sender_index ON fleets (sender);
CREATE INDEX fleets_mission_index ON fleets (mission);
CREATE INDEX fleets_ingal_index ON fleets (ingal);

DROP TABLE covop_targets ;

CREATE OR REPLACE VIEW planet_scans AS
SELECT DISTINCT ON (planet) id,planet,tick,metal,crystal,eonium,metal_roids,crystal_roids,eonium_roids
FROM scans s
	JOIN (SELECT scan AS id,amount AS metal_roids FROM planet_data
		WHERE rid = 1) AS mr USING (id)
	JOIN (SELECT scan AS id,amount AS crystal_roids FROM planet_data
		WHERE rid = 2) AS cr USING (id)
	JOIN (SELECT scan AS id,amount AS eonium_roids FROM planet_data
		WHERE rid = 3) AS er USING (id)
	JOIN (SELECT scan AS id,amount AS metal FROM planet_data
		WHERE rid = 4) AS m USING (id)
	JOIN (SELECT scan AS id,amount AS crystal FROM planet_data
		WHERE rid = 5) AS c USING (id)
	JOIN (SELECT scan AS id,amount AS eonium FROM planet_data
		WHERE rid = 6) AS e USING (id)
ORDER BY planet,tick DESC,id DESC;

CREATE OR REPLACE VIEW structure_scans AS
SELECT DISTINCT ON (planet) id,planet,tick, total,distorters,seccents
FROM scans s
	JOIN (SELECT scan AS id, SUM(amount) AS total FROM planet_data
		WHERE rid >= 14 AND rid <= 24 GROUP BY scan) AS t USING (id)
	JOIN (SELECT scan AS id,amount AS distorters FROM planet_data
		WHERE rid = 18) AS d USING (id)
	JOIN (SELECT scan AS id,amount AS seccents FROM planet_data
		WHERE rid = 24) AS sc USING (id)
ORDER BY planet,tick DESC, id DESC
