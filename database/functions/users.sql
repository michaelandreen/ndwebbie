CREATE OR REPLACE FUNCTION update_user_planet() RETURNS trigger AS $_X$
BEGIN
	IF COALESCE(NEW.pid <> OLD.pid,TRUE) OR NEW.username <> OLD.username THEN
		UPDATE planets SET nick = NULL WHERE pid = OLD.pid;
		UPDATE planets SET nick = NEW.username WHERE pid = NEW.pid;
	END IF;

	IF COALESCE(NEW.pid <> OLD.pid,TRUE)
			AND (SELECT TRUE FROM groupmembers WHERE gid = 2 AND uid = NEW.uid) THEN
		UPDATE planets SET alliance = NULL WHERE pid = OLD.pid;
		UPDATE planets SET alliance = 'NewDawn' WHERE pid = NEW.pid;
	END IF;
	RETURN NEW;
END;
$_X$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_user() RETURNS trigger
    AS $_X$
DECLARE
	thread INTEGER;
BEGIN
	INSERT INTO forum_threads (fbid,subject,uid)
		VALUES(-1,NEW.uid || ': ' || NEW.username,-3) RETURNING ftid
		INTO STRICT thread;
	NEW.ftid = thread;
	RETURN NEW;
END;
$_X$ LANGUAGE plpgsql;
