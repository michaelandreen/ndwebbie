BEGIN;
	DROP VIEW alliance_resources;
	ALTER TABLE alliance_stats ALTER COLUMN score TYPE bigint, ALTER COLUMN score_gain_day TYPE bigint;
	ALTER TABLE galaxies ALTER COLUMN score TYPE bigint, ALTER COLUMN value TYPE bigint, ALTER COLUMN score_gain_day TYPE bigint, ALTER COLUMN value_gain_day TYPE bigint;
	\ir views/alliances_resources.sql
commit;
