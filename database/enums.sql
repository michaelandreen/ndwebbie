CREATE TYPE ead_status AS ENUM ('','NAP','Friendly','Hostile');

DROP VIEW current_planet_stats_full;

DROP VIEW current_planet_stats;

ALTER TABLE planets ALTER COLUMN planet_status TYPE ead_status USING planet_status::ead_status;
ALTER TABLE planets ALTER COLUMN planet_status SET DEFAULT ''::ead_status;
UPDATE planets SET planet_status = '' WHERE planet_status IS NULL;
ALTER TABLE planets ALTER COLUMN planet_status SET NOT NULL;

ALTER TABLE alliances ALTER COLUMN relationship TYPE ead_status USING relationship::ead_status;
ALTER TABLE alliances ALTER COLUMN relationship SET DEFAULT ''::ead_status;
UPDATE alliances SET relationship = '' WHERE relationship IS NULL;
ALTER TABLE alliances ALTER COLUMN relationship SET NOT NULL;


CREATE VIEW current_planet_stats AS
    SELECT p.id, p.nick, p.planet_status, p.hit_us, ps.x, ps.y, ps.z, p.ruler, p.planet, p.race, ps.size, ps.score, ps.value, ps.xp, ps.sizerank, ps.scorerank, ps.valuerank, ps.xprank, alliances.name AS alliance, alliances.relationship, p.alliance_id, p.channel, p.ftid FROM (((SELECT planet_stats.id, planet_stats.tick, planet_stats.x, planet_stats.y, planet_stats.z, planet_stats.size, planet_stats.score, planet_stats.value, planet_stats.xp, planet_stats.sizerank, planet_stats.scorerank, planet_stats.valuerank, planet_stats.xprank FROM planet_stats WHERE (planet_stats.tick = (SELECT max(planet_stats.tick) AS max FROM planet_stats))) ps NATURAL JOIN planets p) LEFT JOIN alliances ON ((alliances.id = p.alliance_id)));


CREATE VIEW current_planet_stats_full AS
    SELECT p.id, p.nick, p.planet_status, p.hit_us, ps.x, ps.y, ps.z, p.ruler, p.planet, p.race, ps.size, ps.score, ps.value, ps.xp, ps.sizerank, ps.scorerank, ps.valuerank, ps.xprank, alliances.name AS alliance, alliances.relationship, p.alliance_id, p.channel, p.ftid, ps.size_gain, ps.score_gain, ps.value_gain, ps.xp_gain, ps.sizerank_gain, ps.scorerank_gain, ps.valuerank_gain, ps.xprank_gain, ps.size_gain_day, ps.score_gain_day, ps.value_gain_day, ps.xp_gain_day, ps.sizerank_gain_day, ps.scorerank_gain_day, ps.valuerank_gain_day, ps.xprank_gain_day FROM (((SELECT planet_stats.id, planet_stats.tick, planet_stats.x, planet_stats.y, planet_stats.z, planet_stats.size, planet_stats.score, planet_stats.value, planet_stats.xp, planet_stats.sizerank, planet_stats.scorerank, planet_stats.valuerank, planet_stats.xprank, planet_stats.size_gain, planet_stats.score_gain, planet_stats.value_gain, planet_stats.xp_gain, planet_stats.sizerank_gain, planet_stats.scorerank_gain, planet_stats.valuerank_gain, planet_stats.xprank_gain, planet_stats.size_gain_day, planet_stats.score_gain_day, planet_stats.value_gain_day, planet_stats.xp_gain_day, planet_stats.sizerank_gain_day, planet_stats.scorerank_gain_day, planet_stats.valuerank_gain_day, planet_stats.xprank_gain_day FROM planet_stats WHERE (planet_stats.tick = (SELECT max(planet_stats.tick) AS max FROM planet_stats))) ps NATURAL JOIN planets p) LEFT JOIN alliances ON ((alliances.id = p.alliance_id)));


CREATE OR REPLACE FUNCTION find_alliance_id(character varying) RETURNS integer
    AS $_$
my ($name) = @_;
my $query = spi_prepare('SELECT id FROM alliances WHERE name=$1','varchar');
my $rv = spi_exec_prepared($query,$name);
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
if ($nrows == 1){
	$id = $rv->{rows}[0]->{id};
}
else {
	$rv = spi_exec_query("SELECT nextval('public.alliances_id_seq') AS id");
	if ($rv->{processed} != 1){
		return;
	}
	$id = $rv->{rows}[0]->{id};
	my $query = spi_prepare('INSERT INTO alliances(id,name) VALUES($1,$2)','int4','varchar');
	$rv = spi_exec_prepared($query,$id,$name);
	spi_freeplan($query);
	if (rv->{status} != SPI_OK_INSERT){
		return;
	}
}
return $id;
$_$
    LANGUAGE plperl;
