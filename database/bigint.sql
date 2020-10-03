BEGIN;
	DROP VIEW alliance_resources;
	ALTER TABLE alliance_stats ALTER COLUMN score TYPE bigint;
	ALTER TABLE galaxies ALTER COLUMN score TYPE bigint, ALTER COLUMN value TYPE bigint;
	\ir views/alliances_resources.sql
commit;
