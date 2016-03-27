CREATE VIEW current_planet_stats AS
SELECT p.pid, p.nick, p.planet_status, p.hit_us, ps.x, ps.y, ps.z, p.ruler, p.planet, p.race
	,alliance, a.relationship, a.aid, p.channel, p.ftid, p.gov
	,ps.size, ps.score, ps.value, ps.xp, ps.sizerank, ps.scorerank, ps.valuerank, ps.xprank
FROM ( SELECT pid, tick, x, y, z, size, score, value, xp, sizerank, scorerank, valuerank, xprank
		FROM planet_stats
		WHERE tick = ( SELECT max(tick) AS max FROM planet_stats)
	) ps
	NATURAL JOIN planets p
	LEFT JOIN alliances a USING (alliance);

CREATE OR REPLACE VIEW current_planet_stats_full AS
SELECT *
FROM planets p
	NATURAL JOIN (
		SELECT *
		FROM planet_stats
		WHERE tick = ( SELECT max(tick) AS max FROM planet_stats)
	) ps
	LEFT JOIN alliances USING (alliance);

CREATE OR REPLACE FUNCTION change_member() RETURNS trigger
    AS $_X$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.gid = 2 THEN
			UPDATE planets SET alliance = 'NewDawn' WHERE
				pid = (SELECT pid FROM users WHERE uid = NEW.uid);
		END IF;
	ELSIF TG_OP = 'DELETE' THEN
		IF OLD.gid = 2 THEN
			UPDATE planets SET alliance = NULL WHERE
				pid = (SELECT pid FROM users WHERE uid = OLD.uid);
		END IF;
	END IF;

	return NEW;
END;
$_X$ LANGUAGE plpgsql;

