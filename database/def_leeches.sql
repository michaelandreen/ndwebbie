CREATE OR REPLACE VIEW def_leeches AS
WITH f AS (
	SELECT uid,fid,lc.pid,f.pid AS fpid,landing_tick,eta,back, SUM(fs.amount*(s.metal + s.crystal + s.eonium)/100.0) AS value
	FROM launch_confirmations lc
		JOIN fleets f USING (fid)
		JOIN fleet_ships fs USING (fid)
		JOIN ship_stats s ON fs.ship = s.name
	WHERE mission = 'Defend'
	GROUP BY uid,fid,lc.pid,f.pid,landing_tick,eta,back
), f2 AS (
	SELECT f.uid
		,SUM(f.value / COALESCE(p.value, (SELECT value FROM planet_stats WHERE pid = f.fpid AND tick = landing_tick - eta ORDER BY tick DESC LIMIT 1))) AS sent_value
	FROM calls c
		JOIN users u USING (uid)
		JOIN f USING (pid,landing_tick)
		LEFT JOIN (SELECT pid AS fpid,value,tick AS landing_tick FROM planet_stats) AS p USING (fpid, landing_tick)
	GROUP BY f.uid
)
SELECT uid,username,defense_points,count(call) AS calls
	, SUM(fleets) AS fleets, SUM(recalled) AS recalled
	,count(NULLIF(fleets,0)) AS defended_calls
	,SUM(value)::NUMERIC(4,2) AS value
	,sent_value::NUMERIC(4,2)
FROM (SELECT u.uid,username,defense_points,call,count(f.back) AS fleets
		, count(NULLIF(f.landing_tick + f.eta -1 = f.back,TRUE)) AS recalled
		,SUM(f.value / COALESCE(p.value, (SELECT value FROM planet_stats WHERE pid = f.pid AND tick = landing_tick - eta ORDER BY tick DESC LIMIT 1))) AS value
	FROM users u
		JOIN calls c USING (uid)
		LEFT JOIN f USING (pid,landing_tick)
		LEFT JOIN (SELECT pid,value,tick AS landing_tick FROM planet_stats) AS p USING (pid, landing_tick)
	GROUP BY u.uid,username,defense_points,call
) d
	LEFT JOIN f2 USING (uid)
GROUP BY uid,username,defense_points, sent_value
