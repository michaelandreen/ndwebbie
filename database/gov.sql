DROP VIEW current_planet_stats_full;
DROP VIEW current_planet_stats;

CREATE TYPE governments AS ENUM ('','Feu','Dic','Dem','Uni');

ALTER TABLE planets ADD COLUMN gov governments NOT NULL DEFAULT ''::governments;

CREATE VIEW current_planet_stats AS
	SELECT p.id, p.nick, p.planet_status, p.hit_us, ps.x, ps.y, ps.z, p.ruler, p.planet, p.race, ps.size, ps.score, ps.value, ps.xp, ps.sizerank, ps.scorerank, ps.valuerank, ps.xprank, alliances.name AS alliance, alliances.relationship, p.alliance_id, p.channel, p.ftid, p.gov
	FROM (SELECT planet_stats.id, planet_stats.tick, planet_stats.x, planet_stats.y, planet_stats.z, planet_stats.size, planet_stats.score, planet_stats.value, planet_stats.xp, planet_stats.sizerank, planet_stats.scorerank, planet_stats.valuerank, planet_stats.xprank FROM planet_stats WHERE (planet_stats.tick = (SELECT max(planet_stats.tick) AS max FROM planet_stats))) ps
		NATURAL JOIN planets p
		LEFT JOIN alliances ON alliances.id = p.alliance_id;


CREATE VIEW current_planet_stats_full AS
    SELECT p.id, p.nick, p.planet_status, p.hit_us, ps.x, ps.y, ps.z, p.ruler, p.planet, p.race, ps.size, ps.score, ps.value, ps.xp, ps.sizerank, ps.scorerank, ps.valuerank, ps.xprank, alliances.name AS alliance, alliances.relationship, p.alliance_id, p.channel, p.ftid, ps.size_gain, ps.score_gain, ps.value_gain, ps.xp_gain, ps.sizerank_gain, ps.scorerank_gain, ps.valuerank_gain, ps.xprank_gain, ps.size_gain_day, ps.score_gain_day, ps.value_gain_day, ps.xp_gain_day, ps.sizerank_gain_day, ps.scorerank_gain_day, ps.valuerank_gain_day, ps.xprank_gain_day,p.gov
	FROM (SELECT planet_stats.id, planet_stats.tick, planet_stats.x, planet_stats.y, planet_stats.z, planet_stats.size, planet_stats.score, planet_stats.value, planet_stats.xp, planet_stats.sizerank, planet_stats.scorerank, planet_stats.valuerank, planet_stats.xprank, planet_stats.size_gain, planet_stats.score_gain, planet_stats.value_gain, planet_stats.xp_gain, planet_stats.sizerank_gain, planet_stats.scorerank_gain, planet_stats.valuerank_gain, planet_stats.xprank_gain, planet_stats.size_gain_day, planet_stats.score_gain_day, planet_stats.value_gain_day, planet_stats.xp_gain_day, planet_stats.sizerank_gain_day, planet_stats.scorerank_gain_day, planet_stats.valuerank_gain_day, planet_stats.xprank_gain_day FROM planet_stats WHERE (planet_stats.tick = (SELECT max(planet_stats.tick) AS max FROM planet_stats))) ps 
		NATURAL JOIN planets p
		LEFT JOIN alliances ON alliances.id = p.alliance_id;
