DROP VIEW users_defprio;
DROP VIEW current_planet_stats;
DROP VIEW current_planet_stats_full;
DROP VIEW current_planet_scans;
DROP VIEW current_development_scans;


ALTER TABLE planets ALTER ruler TYPE text;
ALTER TABLE planets ALTER planet TYPE text;
ALTER TABLE planets ALTER nick TYPE citext;
ALTER TABLE planets ALTER channel TYPE citext;
ALTER TABLE alliances RENAME name TO alliance;
ALTER TABLE alliances ALTER alliance TYPE text;
ALTER TABLE alliances RENAME id TO aid;
ALTER TABLE alliance_stats RENAME id TO aid;

CREATE FUNCTION alliance_name(id INTEGER) RETURNS TEXT AS $$
	SELECT alliance FROM alliances WHERE aid = $1
$$ LANGUAGE SQL STABLE;

ALTER TABLE planets RENAME id TO pid;
ALTER TABLE planets RENAME alliance_id TO alliance;
ALTER TABLE planetS DROP CONSTRAINT planets_alliance_id_fkey;
ALTER TABLE planets ALTER alliance TYPE text USING alliance_name(alliance);
ALTER TABLE planetS ADD FOREIGN KEY (alliance) REFERENCES alliances(alliance) ON UPDATE CASCADE ON DELETE SET NULL;

DROP FUNCTION alliance_name(INTEGER);

ALTER TABLE planet_stats RENAME id TO pid;
ALTER TABLE users RENAME planet TO pid;
ALTER TABLE fleets RENAME planet TO pid;
ALTER TABLE launch_confirmations RENAME target TO pid;
ALTER TABLE development_scans RENAME planet TO pid;
ALTER TABLE planet_scans RENAME planet TO pid;
ALTER TABLE raid_targets RENAME planet TO pid;
ALTER TABLE scan_requests RENAME planet TO pid;
ALTER TABLE scans RENAME planet TO pid;
ALTER TABLE covop_attacks RENAME id TO pid;
ALTER TABLE incomings RENAME sender TO pid;

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

CREATE OR REPLACE VIEW users_defprio AS
SELECT u.*, (0.2 * (u.attack_points / GREATEST(a.attack, 1::numeric))
		+ 0.4 * (u.defense_points / GREATEST(a.defense, 1::numeric))
		+ 0.2 * (p.size::numeric / a.size) + 0.05 * (p.score::numeric / a.score)
		+ 0.15 * (p.value::numeric / a.value))::numeric(3,2) AS defprio
FROM users u
	JOIN current_planet_stats p USING (pid)
	, (
		SELECT avg(u.attack_points) AS attack, avg(u.defense_points) AS defense
			,avg(p.size) AS size, avg(p.score) AS score, avg(p.value) AS value
		FROM users u
			JOIN current_planet_stats p USING (pid)
		WHERE uid IN ( SELECT uid FROM groupmembers WHERE gid = 2)
	) a;

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

CREATE OR REPLACE VIEW current_planet_scans AS
SELECT DISTINCT ON (pid) ps.*
FROM planet_scans ps
ORDER BY pid, tick DESC, id DESC;

CREATE OR REPLACE VIEW current_development_scans AS
SELECT DISTINCT ON (pid) ds.*
FROM development_scans ds
ORDER BY pid, tick DESC, id DESC;

CREATE OR REPLACE FUNCTION update_user_planet() RETURNS trigger AS $_X$
BEGIN
	IF COALESCE(NEW.pid <> OLD.pid,TRUE) OR NEW.username <> OLD.username THEN
		UPDATE planets SET nick = NULL WHERE pid = OLD.pid;
		UPDATE planets SET nick = NEW.username WHERE pid = NEW.pid;
	END IF;

	IF COALESCE(NEW.pid <> OLD.pid,TRUE)
			AND (SELECT TRUE FROM groupmembers WHERE gid = 2 AND uid = NEW.uid) THEN
		UPDATE planets SET alliance = NULL WHERE pid = OLD.pid;
		UPDATE planets SET alliance = 'NewDawn' WHERE pid = NEW.pid;
	END IF;
	RETURN NEW;
END;
$_X$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION planetid(x integer, y integer, z integer, tick integer) RETURNS integer
    AS $_$SELECT pid FROM planet_stats WHERE x = $1 AND y = $2 AND z = $3 AND (tick >= $4  OR tick =( SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC LIMIT 1$_$
    LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION planetcoords(id integer, tick integer, OUT x integer, OUT y integer, OUT z integer) RETURNS record
    AS $_$SELECT x,y,z FROM planet_stats WHERE pid = $1 AND (tick >= $2  OR tick =( SELECT max(tick) FROM planet_stats))  ORDER BY tick ASC LIMIT 1$_$
    LANGUAGE sql STABLE;

CREATE OR REPLACE VIEW alliance_resources AS
WITH planet_estimates AS (
	SELECT ps.tick, alliance, hidden,size,score,(metal+crystal+eonium) AS resources
		,score + (metal+crystal+eonium)/300 + hidden/100 AS nscore2
		,score + (metal+crystal+eonium)/300 + hidden/100 + (endtick()-tick())*(
			250*size + COALESCE(metal_ref + crystal_ref + eonium_ref,7)* 1000
			+ CASE extraction WHEN 0 THEN 3000 WHEN 1 THEN 11500 ELSE COALESCE(extraction,3)*3000*3 END
		)*(1.35+0.005*COALESCE(fincents,20))/100 AS nscore3
	FROM current_planet_stats p
		JOIN current_planet_scans ps USING (pid)
		LEFT OUTER JOIN current_development_scans ds USING (pid)
), planet_ranks AS (
	SELECT *, RANK() OVER(PARTITION BY alliance ORDER BY score DESC) AS rank FROM planet_estimates
), top_planets AS (
	SELECT alliance, sum(resources) AS resources, sum(hidden) AS hidden
		,sum(nscore2)::bigint AS nscore2, sum(nscore3)::bigint AS nscore3
		,count(*) AS planets, sum(score) AS score, sum(size) AS size
		,avg(tick)::int AS avgtick
	FROM planet_ranks WHERE rank <= 60
	GROUP BY alliance
)
SELECT aid,alliance,a.relationship,s.members,r.planets
	,s.score, r.score AS topscore, s.size, r.size AS topsize
	,r.resources,r.hidden
	,(s.score + (resources / 300) + (hidden / 100))::bigint AS nscore
	,nscore2, nscore3, avgtick
FROM alliances a
	JOIN top_planets r USING (alliance)
	LEFT OUTER JOIN (SELECT aid,score,size,members FROM alliance_stats
		WHERE tick = (SELECT max(tick) FROM alliance_stats)) s USING (aid)
;

CREATE OR REPLACE VIEW defcalls AS
SELECT c.id,c.member AS uid, c.landing_tick, covered, open
	,dc.username AS dc, (c.landing_tick - tick()) AS curreta
	,array_agg(COALESCE(race::text,'')) AS race
	,array_agg(COALESCE(amount,0)) AS amount
	,array_agg(COALESCE(eta,0)) AS eta
	,array_agg(COALESCE(shiptype,'')) AS shiptype
	,array_agg(COALESCE(alliance,'?')) AS alliance
	,array_agg(coords(p2.x,p2.y,p2.z)) AS attackers
FROM calls c
	LEFT OUTER JOIN incomings i ON c.id = i.call
	LEFT OUTER JOIN current_planet_stats p2 USING (pid)
	LEFT OUTER JOIN users dc ON c.dc = dc.uid
GROUP BY c.id,c.member,dc.username, c.landing_tick, covered, open;

CREATE OR REPLACE VIEW full_defcalls AS
SELECT id,covered,open,x,y,z,pid,landing_tick,dc,curreta
	,defprio, c.race, amount, c.eta, shiptype, c.alliance, attackers
	,COUNT(NULLIF(f.back = f.landing_tick + f.eta - 1, FALSE)) AS fleets
FROM users_defprio u
	JOIN current_planet_stats p USING (pid)
	JOIN defcalls c USING (uid)
	LEFT OUTER JOIN launch_confirmations f USING (pid,landing_tick)
GROUP BY id, x,y,z,pid,landing_tick,dc,curreta,defprio,c.race,amount,c.eta,shiptype,c.alliance,attackers, covered, open
;

DROP AGGREGATE array_accum(anyelement);
