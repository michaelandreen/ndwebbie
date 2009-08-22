DROP VIEW IF EXISTS full_intel;
CREATE VIEW full_intel AS
SELECT s.alliance AS salliance ,coords(s.x,s.y,s.z) AS scoords, i.sender, s.nick AS snick
	,t.alliance AS talliance,coords(t.x,t.y,t.z) AS tcoords, i.target, t.nick AS tnick
	,i.mission, i.tick, MIN(i.eta) AS eta, i.amount, i.ingal
	,uid,u.username
FROM intel i
	JOIN users u USING (uid)
	JOIN current_planet_stats t ON i.target = t.pid
	JOIN current_planet_stats s ON i.sender = s.pid
GROUP BY i.tick,i.mission,t.x,t.y,t.z,s.x,s.y,s.z,i.amount,i.ingal,u.username,uid
	,t.alliance,s.alliance,t.nick,s.nick,i.sender,i.target
;
