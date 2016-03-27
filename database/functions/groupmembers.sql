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

CREATE OR REPLACE FUNCTION groups(uid integer) RETURNS SETOF CHAR
    AS $_$SELECT gid FROM groupmembers WHERE uid = $1 UNION SELECT ''$_$
    LANGUAGE sql STABLE;
