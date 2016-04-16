DROP FUNCTION IF EXISTS hostile_alliances(INT,INT);
CREATE OR REPLACE FUNCTION hostile_alliances (first INT, last INT)
RETURNS table(aid INT, alliance TEXT, hostile_count BIGINT, targeted BIGINT, targeted_raids BIGINT)
AS $SQL$
WITH hostile_alliances AS (
	SELECT COALESCE(aid,-1) AS aid, count(*) AS hostile_count
	FROM calls c
		JOIN incomings i USING (call)
		JOIN current_planet_stats s USING (pid)
	WHERE c.landing_tick BETWEEN $1 + i.eta AND $2 + i.eta
	GROUP BY aid
), alliance_targets_1 AS (
	SELECT COALESCE(aid,-1) AS aid, exists(
			SELECT pid FROM raid_targets rt
			JOIN raids r ON rt.raid = r.id
			WHERE rt.pid = p.pid AND lc.landing_tick BETWEEN r.tick AND r.tick + r.waves - 1
		) AS raid_target
	FROM launch_confirmations lc
		JOIN current_planet_stats p USING (pid)
		JOIN fleets f USING (fid)
	WHERE f.mission = 'Attack'
		AND lc.landing_tick BETWEEN $1 + lc.eta AND $2 + lc.eta
), alliance_targets AS (
	SELECT aid, count(*) AS targeted, count(NULLIF(raid_target,false)) AS targeted_raids
	FROM alliance_targets_1
	GROUP BY aid
)
SELECT aid, alliance, hostile_count, targeted, targeted_raids
FROM hostile_alliances
	LEFT JOIN alliance_targets USING (aid)
	LEFT JOIN alliances USING (aid)
$SQL$ LANGUAGE SQL STABLE;

