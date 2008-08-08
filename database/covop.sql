/*
INSERT INTO planet_data_types (category,name) values('planet','Agents');
INSERT INTO planet_data_types (category,name) values('planet','Security Guards');
 */

DROP VIEW planet_scans;

CREATE OR REPLACE VIEW planet_scans AS
    SELECT DISTINCT ON (s.planet) s.id, s.planet, s.tick, m.metal, c.crystal, e.eonium, mr.metal_roids, cr.crystal_roids, er.eonium_roids
		,h.hidden, fl.light, fm.medium, fh.heavy, a.agents, g.guards
	FROM
		(scans s JOIN (SELECT planet_data.scan AS id, planet_data.amount AS metal_roids FROM planet_data WHERE (planet_data.rid = 1)) mr USING (id))
		JOIN (SELECT planet_data.scan AS id, planet_data.amount AS crystal_roids FROM planet_data WHERE (planet_data.rid = 2)) cr USING (id)
		JOIN (SELECT planet_data.scan AS id, planet_data.amount AS eonium_roids FROM planet_data WHERE (planet_data.rid = 3)) er USING (id)
		JOIN (SELECT planet_data.scan AS id, planet_data.amount AS metal FROM planet_data WHERE (planet_data.rid = 4)) m USING (id)
		JOIN (SELECT planet_data.scan AS id, planet_data.amount AS crystal FROM planet_data WHERE (planet_data.rid = 5)) c USING (id)
		JOIN (SELECT planet_data.scan AS id, planet_data.amount AS eonium FROM planet_data WHERE (planet_data.rid = 6)) e USING (id)
		JOIN (SELECT planet_data.scan AS id, planet_data.amount AS hidden FROM planet_data WHERE (planet_data.rid = 25)) h USING (id)
		LEFT OUTER JOIN (SELECT planet_data.scan AS id, planet_data.amount AS light FROM planet_data WHERE (planet_data.rid = 26)) fl USING (id)
		LEFT OUTER JOIN (SELECT planet_data.scan AS id, planet_data.amount AS medium FROM planet_data WHERE (planet_data.rid = 27)) fm USING (id)
		LEFT OUTER JOIN (SELECT planet_data.scan AS id, planet_data.amount AS heavy FROM planet_data WHERE (planet_data.rid = 28)) fh USING (id)
		LEFT OUTER JOIN (SELECT planet_data.scan AS id, planet_data.amount AS agents FROM planet_data WHERE (planet_data.rid = 29)) a USING (id)
		LEFT OUTER JOIN (SELECT planet_data.scan AS id, planet_data.amount AS guards FROM planet_data WHERE (planet_data.rid = 30)) g USING (id)
	ORDER BY s.planet, s.tick DESC, s.id DESC;
