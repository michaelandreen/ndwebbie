CREATE TABLE ticks (t INTEGER PRIMARY KEY);

INSERT INTO ticks (SELECT * FROM generate_series(0,10000));

CREATE OR REPLACE VIEW ships_home AS
SELECT tick, uid,username, planet, ship
	, COALESCE(f.amount - o.amount,f.amount) AS amount
	, COALESCE(fleets,3) AS fleets
FROM users u JOIN (
	SELECT t AS tick, planet,ship,amount
	FROM (
		SELECT DISTINCT ON (t,planet,mission) t,planet,mission, fid
		FROM ticks
			CROSS JOIN fleets f
		WHERE tick <= t
			AND name IN ('Main','Advanced Unit')
			AND mission = 'Full fleet'
		ORDER BY t,planet,mission,tick DESC, fid DESC
	) f
		JOIN fleet_ships fs USING (fid)
	
) f USING (planet) LEFT OUTER JOIN (
	SELECT t AS tick, planet, ship, SUM(fs.amount) AS amount
		, 3 - COUNT(DISTINCT fid) AS fleets
	FROM ticks
		CROSS JOIN fleets f
		JOIN launch_confirmations USING (fid)
		JOIN fleet_ships fs USING (fid)
	WHERE back > t
		AND landing_tick - eta - 12 < t
	GROUP BY t,planet,ship
) o USING (tick,planet,ship)
WHERE COALESCE(f.amount - o.amount,f.amount) > 0;

CREATE OR REPLACE VIEW available_ships AS
SELECT uid,username, planet, ship, amount, fleets
FROM ships_home
WHERE tick = tick();
