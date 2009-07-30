DROP VIEW IF EXISTS full_defcalls;
DROP VIEW IF EXISTS defcalls;

CREATE TABLE call_statuses (
	status TEXT PRIMARY KEY
);

INSERT INTO call_statuses VALUES('Open'),('Covered'),('Ignored');

ALTER TABLE calls ADD COLUMN status TEXT NOT NULL REFERENCES call_statuses(status)
DEFAULT 'Open';

UPDATE calls SET status = (CASE WHEN covered THEN 'Covered' WHEN NOT OPEN THEN
	'Ignored' ELSE 'Open' END);

ALTER TABLE calls DROP COLUMN open;
ALTER TABLE calls DROP COLUMN covered;
ALTER TABLE calls DROP COLUMN shiptypes;
ALTER TABLE calls RENAME id TO call;
ALTER TABLE calls RENAME member TO uid;
ALTER TABLE incomings RENAME id TO inc;

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

CREATE OR REPLACE FUNCTION add_call() RETURNS trigger
	AS $_X$
DECLARE
	thread INTEGER;
BEGIN
	INSERT INTO forum_threads (fbid,subject,uid)
		VALUES(-3,NEW.uid || ': ' || NEW.landing_tick,-3) RETURNING ftid
		INTO STRICT thread;
	NEW.ftid = thread;
	RETURN NEW;
END;
$_X$ LANGUAGE plpgsql;
