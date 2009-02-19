DROP VIEW available_ships;
CREATE VIEW available_ships AS
SELECT uid,username, planet, ship
	, COALESCE(f.amount - o.amount,f.amount) AS amount
	, COALESCE(fleets,3) AS fleets
FROM users u JOIN (
	SELECT planet,ship,amount
	FROM (
		SELECT DISTINCT ON (planet,mission) planet,mission, fid
		FROM fleets f
		WHERE tick <= tick()
			AND name IN ('Main','Advanced Unit')
			AND mission = 'Full fleet'
		ORDER BY planet,mission,tick DESC, fid DESC
	) f
		JOIN fleet_ships fs USING (fid)
	
) f USING (planet) LEFT OUTER JOIN (
	SELECT planet, ship, SUM(fs.amount) AS amount, 3 - COUNT(DISTINCT fid) AS fleets
	FROM fleets f
		JOIN launch_confirmations USING (fid)
		JOIN fleet_ships fs USING (fid)
	WHERE back > tick()
		AND landing_tick - eta - 12 < tick()
	GROUP BY planet,ship
) o USING (planet,ship)
WHERE COALESCE(f.amount - o.amount,f.amount) > 0

