DROP VIEW planet_scans;
DROP VIEW structure_scans;

CREATE TABLE planet_scans (
	id            integer PRIMARY KEY REFERENCES scans(id),
	planet        integer NOT NULL REFERENCES planets(id),
	tick          integer NOT NULL,
	metal         bigint  NOT NULL,
	crystal       bigint NOT NULL,
	eonium        bigint NOT NULL,
	hidden        bigint NOT NULL,
	metal_roids   integer NOT NULL,
	crystal_roids integer NOT NULL,
	eonium_roids  integer NOT NULL,
	agents        integer NOT NULL,
	guards        integer NOT NULL,
	light         TEXT NOT NULL,
	medium        TEXT NOT NULL,
	heavy         TEXT NOT NULL
);


CREATE TABLE structure_scans (
	id          integer PRIMARY KEY REFERENCES scans(id),
	planet      integer NOT NULL REFERENCES planets(id),
	tick        integer NOT NULL,
	light_fac   integer NOT NULL,
	medium_fac  integer NOT NULL,
	heavy_fac   integer NOT NULL,
	amps        integer NOT NULL,
	distorters  integer NOT NULL,
	metal_ref   integer NOT NULL,
	crystal_ref integer NOT NULL,
	eonium_ref  integer NOT NULL,
	reslabs     integer NOT NULL,
	fincents    integer NOT NULL,
	seccents    integer NOT NULL,
	total       integer NOT NULL
);

CREATE TABLE tech_scans (
	id          integer PRIMARY KEY REFERENCES scans(id),
	planet      integer NOT NULL REFERENCES planets(id),
	tick        integer NOT NULL,
	travel      integer NOT NULL,
	infra       integer NOT NULL,
	hulls       integer NOT NULL,
	waves       integer NOT NULL,
	extraction  integer NOT NULL,
	covert      integer NOT NULL,
	mining      integer NOT NULL
);

CREATE OR REPLACE VIEW current_planet_scans AS
SELECT DISTINCT ON (planet) ps.*
FROM planet_scans ps
ORDER BY planet, tick DESC, id DESC;

CREATE OR REPLACE VIEW current_structure_scans AS
SELECT DISTINCT ON (planet) ss.*
FROM structure_scans ss
ORDER BY planet, tick DESC, id DESC;

CREATE OR REPLACE VIEW current_tech_scans AS
SELECT DISTINCT ON (planet) ts.*
FROM tech_scans ts
ORDER BY planet, tick DESC, id DESC;

CREATE INDEX planet_scans_planet_index ON planet_scans(planet,tick);
CREATE INDEX structure_scans_planet_index ON structure_scans(planet,tick);
CREATE INDEX tech_scans_planet_index ON tech_scans(planet,tick);

DROP TABLE planet_data;
DROP TABLE planet_data_types;
