CREATE OR REPLACE VIEW users_defprio AS
SELECT u.*, (0.2 * (u.attack_points / GREATEST(a.attack, 1::numeric))
		+ 0.4 * (u.defense_points / GREATEST(a.defense, 1::numeric))
		+ 0.2 * (p.size::numeric / a.size) + 0.05 * (p.score::numeric / a.score)
		+ 0.15 * (p.value::numeric / a.value))::numeric(3,2) AS defprio
FROM users u
	LEFT JOIN current_planet_stats p USING (pid)
	, (
		SELECT avg(u.attack_points) AS attack, avg(u.defense_points) AS defense, avg(p.size) AS size, avg(p.score) AS score, avg(p.value) AS value
		FROM users u
			JOIN current_planet_stats p USING (pid)
		WHERE u.uid IN ( SELECT groupmembers.uid FROM groupmembers WHERE groupmembers.gid = 'M')
	) a;
