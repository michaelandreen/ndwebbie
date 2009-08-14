DROP VIEW usersingroup;
DROP VIEW full_defcalls;
DROP VIEW defcalls;
DROP VIEW users_defprio;
DROP VIEW available_ships;
DROP VIEW ships_home;

ALTER TABLE groups RENAME gid TO id;
ALTER TABLE groups RENAME flag TO gid;

UPDATE groups SET gid = '' WHERE gid IS NULL;

CREATE FUNCTION new_gid(id INTEGER) RETURNS CHAR AS $$
	SELECT gid FROM groups WHERE id = $1
$$ LANGUAGE SQL STABLE;

ALTER TABLE channel_flags ADD flag CHAR(1);

UPDATE channel_flags SET flag = 'o' WHERE name = 'auto_op';
UPDATE channel_flags SET flag = 'O' WHERE name = 'op';
UPDATE channel_flags SET flag = 'v' WHERE name = 'auto_voice';
UPDATE channel_flags SET flag = 'V' WHERE name = 'voice';
UPDATE channel_flags SET flag = 'i' WHERE name = 'auto_invite';
UPDATE channel_flags SET flag = 'I' WHERE name = 'invite';

CREATE FUNCTION new_flag(id INTEGER) RETURNS CHAR AS $$
	SELECT flag FROM channel_flags WHERE id = $1
$$ LANGUAGE SQL STABLE;

ALTER TABLE channels RENAME name TO channel;
ALTER TABLE channels ALTER channel TYPE citext;

CREATE FUNCTION new_channel(id INTEGER) RETURNS citext AS $$
	SELECT channel FROM channels WHERE id = $1
$$ LANGUAGE SQL STABLE;

ALTER TABLE channel_group_flags DROP CONSTRAINT channel_group_flags_group_fkey;
ALTER TABLE channel_group_flags DROP CONSTRAINT channel_group_flags_flag_fkey;
ALTER TABLE channel_group_flags DROP CONSTRAINT channel_group_flags_channel_fkey;
ALTER TABLE group_roles DROP CONSTRAINT group_roles_gid_fkey;
ALTER TABLE groupmembers DROP CONSTRAINT groupmembers_gid_fkey;
ALTER TABLE raid_access DROP CONSTRAINT raid_access_gid_fkey;
ALTER TABLE forum_access DROP CONSTRAINT forum_access_gid_fkey;
ALTER TABLE wiki_namespace_access DROP CONSTRAINT wiki_namespace_access_gid_fkey;

ALTER TABLE groups DROP CONSTRAINT groups_pkey;
ALTER TABLE groups ADD PRIMARY KEY(gid);

ALTER TABLE channel_flags DROP CONSTRAINT channel_flags_pkey;
ALTER TABLE channel_flags ADD PRIMARY KEY(flag);

ALTER TABLE channels DROP CONSTRAINT channels_pkey;
ALTER TABLE channels DROP CONSTRAINT channels_name_key;
ALTER TABLE channels ADD PRIMARY KEY(channel);

ALTER TABLE channel_group_flags RENAME "group" TO gid;
ALTER TABLE channel_group_flags ALTER flag TYPE CHAR(1) USING (new_flag(flag));
ALTER TABLE channel_group_flags ADD FOREIGN KEY (flag) REFERENCES channel_flags(flag) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE channel_group_flags ALTER gid TYPE CHAR(1) USING (new_gid(gid));
ALTER TABLE channel_group_flags ADD FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE channel_group_flags ALTER channel TYPE citext USING (new_channel(channel));
ALTER TABLE channel_group_flags ADD FOREIGN KEY (channel) REFERENCES channels(channel) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE groupmembers ALTER gid TYPE CHAR(1) USING (new_gid(gid));
ALTER TABLE groupmembers ADD FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE group_roles ALTER gid TYPE CHAR(1) USING (new_gid(gid));
ALTER TABLE group_roles ADD FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE raid_access ALTER gid TYPE CHAR(1) USING (new_gid(gid));
ALTER TABLE raid_access ADD FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE forum_access ALTER gid TYPE CHAR(1) USING (new_gid(gid));
ALTER TABLE forum_access ADD FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE wiki_namespace_access ALTER gid TYPE CHAR(1) USING (new_gid(gid));
ALTER TABLE wiki_namespace_access ADD FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE groups DROP id RESTRICT;
ALTER TABLE groups DROP attack RESTRICT;
ALTER TABLE channel_flags DROP id RESTRICT;
ALTER TABLE channels DROP id RESTRICT;

DROP FUNCTION new_gid(int);
DROP FUNCTION new_flag(int);
DROP FUNCTION new_channel(int);

DROP INDEX users_pnick_key;
DROP INDEX users_hostmask_key;
DROP INDEX users_username_key;

ALTER TABLE users ALTER username TYPE citext;
ALTER TABLE users ALTER pnick TYPE citext;
ALTER TABLE users ALTER hostmask TYPE citext;

ALTER TABLE users ALTER pnick SET NOT NULL;
ALTER TABLE users ALTER hostmask SET NOT NULL;

ALTER TABLE users ADD UNIQUE(username);
ALTER TABLE users ADD UNIQUE(pnick);
ALTER TABLE users ADD UNIQUE(hostmask);


CREATE OR REPLACE VIEW users_defprio AS
SELECT u.*, (0.2 * (u.attack_points / GREATEST(a.attack, 1::numeric))
		+ 0.4 * (u.defense_points / GREATEST(a.defense, 1::numeric))
		+ 0.2 * (p.size::numeric / a.size) + 0.05 * (p.score::numeric / a.score)
		+ 0.15 * (p.value::numeric / a.value))::numeric(3,2) AS defprio
FROM users u
	JOIN current_planet_stats p USING (pid)
	, (
		SELECT avg(u.attack_points) AS attack, avg(u.defense_points) AS defense
			,avg(p.size) AS size, avg(p.score) AS score, avg(p.value) AS value
		FROM users u
			JOIN current_planet_stats p USING (pid)
		WHERE uid IN ( SELECT uid FROM groupmembers WHERE gid = 'M')
	) a;

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


CREATE OR REPLACE FUNCTION change_member() RETURNS trigger
    AS $_X$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.gid = 'M' THEN
			UPDATE planets SET alliance = 'NewDawn' WHERE
				pid = (SELECT pid FROM users WHERE uid = NEW.uid);
		END IF;
	ELSIF TG_OP = 'DELETE' THEN
		IF OLD.gid = 'M' THEN
			UPDATE planets SET alliance = NULL WHERE
				pid = (SELECT pid FROM users WHERE uid = OLD.uid);
		END IF;
	END IF;

	return NEW;
END;
$_X$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_user_planet() RETURNS trigger AS $_X$
BEGIN
	IF COALESCE(NEW.pid <> OLD.pid,TRUE) OR NEW.username <> OLD.username THEN
		UPDATE planets SET nick = NULL WHERE pid = OLD.pid;
		UPDATE planets SET nick = NEW.username WHERE pid = NEW.pid;
	END IF;

	IF COALESCE(NEW.pid <> OLD.pid,TRUE)
			AND (SELECT TRUE FROM groupmembers WHERE gid = 'M' AND uid = NEW.uid) THEN
		UPDATE planets SET alliance = NULL WHERE pid = OLD.pid;
		UPDATE planets SET alliance = 'NewDawn' WHERE pid = NEW.pid;
	END IF;
	RETURN NEW;
END;
$_X$ LANGUAGE plpgsql;

DROP FUNCTION groups(int);
CREATE OR REPLACE FUNCTION groups(uid integer) RETURNS SETOF CHAR
    AS $_$SELECT gid FROM groupmembers WHERE uid = $1 UNION SELECT ''$_$
    LANGUAGE sql STABLE;
