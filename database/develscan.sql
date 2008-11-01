DROP VIEW current_structure_scans;
DROP VIEW current_tech_scans;
DROP TABLE structure_scans;
DROP TABLE tech_scans;

CREATE TABLE development_scans (
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
	total       integer NOT NULL,

	travel      integer NOT NULL,
	infra       integer NOT NULL,
	hulls       integer NOT NULL,
	waves       integer NOT NULL,
	extraction  integer NOT NULL,
	covert      integer NOT NULL,
	mining      integer NOT NULL
);

CREATE OR REPLACE VIEW current_development_scans AS
SELECT DISTINCT ON (planet) ds.*
FROM development_scans ds
ORDER BY planet, tick DESC, id DESC;

CREATE INDEX development_scans_planet_index ON development_scans(planet,tick);
