CREATE OR REPLACE VIEW defcalls AS
SELECT call, status,c.uid, c.landing_tick
	,dc.username AS dc, (c.landing_tick - tick()) AS curreta
	,array_agg(COALESCE(race::text,'')) AS race
	,array_agg(COALESCE(amount,0)) AS amount
	,array_agg(COALESCE(eta,0)) AS eta
	,array_agg(COALESCE(shiptype,'')) AS shiptype
	,array_agg(COALESCE(alliance,'?')) AS alliance
	,array_agg(coords(p2.x,p2.y,p2.z)) AS attackers
FROM calls c
	LEFT OUTER JOIN incomings i USING (call)
	LEFT OUTER JOIN current_planet_stats p2 USING (pid)
	LEFT OUTER JOIN users dc ON c.dc = dc.uid
GROUP BY call,c.uid,dc.username, c.landing_tick, status;

CREATE OR REPLACE VIEW full_defcalls AS
SELECT call,status,x,y,z,pid,landing_tick,dc,curreta
	,defprio, c.race, amount, c.eta, shiptype, c.alliance, attackers
	,COUNT(NULLIF(f.back = f.landing_tick + f.eta - 1, FALSE)) AS fleets
FROM users_defprio u
	JOIN current_planet_stats p USING (pid)
	JOIN defcalls c USING (uid)
	LEFT OUTER JOIN launch_confirmations f USING (pid,landing_tick)
GROUP BY call, x,y,z,pid,landing_tick,dc,curreta,defprio,c.race,amount,c.eta,shiptype,c.alliance,attackers, status
;
