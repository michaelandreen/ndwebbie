/*CREATE TABLE ticks (t INTEGER PRIMARY KEY);

INSERT INTO ticks (SELECT * FROM generate_series(0,10000));
*/

CREATE OR REPLACE VIEW ships_home AS
SELECT tick, uid,username, pid, ship
	, COALESCE(f.amount - o.amount,f.amount) AS amount
	, COALESCE(fleets,3) AS fleets
FROM users u JOIN (
	SELECT t AS tick, pid,ship,amount
	FROM (
		SELECT DISTINCT ON (t,pid,mission) t,pid,mission, fid
		FROM ticks
			CROSS JOIN fleets f
		WHERE tick <= t
			AND name IN ('Main','Advanced Unit')
			AND mission = 'Full fleet'
		ORDER BY t,pid,mission,tick DESC, fid DESC
	) f
		JOIN fleet_ships fs USING (fid)
	
) f USING (pid) LEFT OUTER JOIN (
	SELECT t AS tick, pid, ship, SUM(fs.amount) AS amount
		, 3 - COUNT(DISTINCT fid) AS fleets
	FROM ticks
		CROSS JOIN fleets f
		JOIN (SELECT landing_tick, fid, back, eta FROM launch_confirmations) lc USING (fid)
		JOIN fleet_ships fs USING (fid)
	WHERE back > t
		AND landing_tick - eta - 12 < t
	GROUP BY t,pid,ship
) o USING (tick,pid,ship)
WHERE COALESCE(f.amount - o.amount,f.amount) > 0;

CREATE OR REPLACE VIEW available_ships AS
SELECT uid,username, pid, ship, amount, fleets
FROM ships_home
WHERE tick = tick();
