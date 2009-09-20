/* Some generic cleanup */

ALTER TABLE forum_posts ALTER textsearch SET NOT NULL;

DROP FUNCTION IF EXISTS add_intel(integer,integer,integer,integer,integer,integer,integer,integer,integer,character varying,integer);
DROP FUNCTION IF EXISTS add_intel2(integer, integer, integer, integer, integer, integer, integer, integer, character varying, character varying);
DROP FUNCTION IF EXISTS add_intel2(integer, integer, integer, integer, integer, integer, integer, integer, integer, character varying, character varying);
DROP FUNCTION IF EXISTS add_intel4(tick integer, eta integer, x1 integer, y1 integer, z1 integer, x2 integer, y2 integer, z2 integer, amount integer, mission character varying, uid integer);
DROP FUNCTION IF EXISTS calc_rank(integer);
DROP FUNCTION IF EXISTS calc_rank3(integer);
DROP FUNCTION IF EXISTS calculate_rankings(integer);
DROP FUNCTION IF EXISTS covop_alert(integer, integer, governments, integer);
DROP FUNCTION IF EXISTS covop_alert(bigint, integer, governments, integer);
DROP FUNCTION IF EXISTS max_bank_hack(integer,integer,integer,integer,integer);
DROP FUNCTION IF EXISTS max_bank_hack(bigint,bigint,bigint,integer,integer);
DROP FUNCTION IF EXISTS populate_ticks();


/* Updating old triggers */
ALTER TABLE users DROP COLUMN last_forum_visit;

CREATE OR REPLACE FUNCTION update_user_planet() RETURNS trigger AS $_X$
BEGIN
	IF COALESCE(NEW.planet <> OLD.planet,TRUE) OR NEW.username <> OLD.username THEN
		UPDATE planets SET nick = NULL WHERE id = OLD.planet;
		UPDATE planets SET nick = NEW.username WHERE id = NEW.planet;
	END IF;

	IF COALESCE(NEW.planet <> OLD.planet,TRUE)
			AND (SELECT TRUE FROM groupmembers WHERE gid = 2 AND uid = NEW.uid) THEN
		UPDATE planets SET alliance_id = NULL WHERE id = OLD.planet;
		UPDATE planets SET alliance_id = 1 WHERE id = NEW.planet;
	END IF;
	RETURN NEW;
END;
$_X$ LANGUAGE plpgsql;

ALTER TABLE users ALTER ftid SET NOT NULL;

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

CREATE OR REPLACE FUNCTION change_member() RETURNS trigger
    AS $_X$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.gid = 2 THEN
			UPDATE planets SET alliance_id = 1 WHERE
				id = (SELECT planet FROM users WHERE uid = NEW.uid);
		END IF;
	ELSIF TG_OP = 'DELETE' THEN
		IF OLD.gid = 2 THEN
			UPDATE planets SET alliance_id = NULL WHERE
				id = (SELECT planet FROM users WHERE uid = OLD.uid);
		END IF;
	END IF;

	return NEW;
END;
$_X$ LANGUAGE plpgsql;

ALTER TABLE calls ALTER ftid SET NOT NULL;

CREATE OR REPLACE FUNCTION add_call() RETURNS trigger
    AS $_X$
DECLARE
	thread INTEGER;
BEGIN
	INSERT INTO forum_threads (fbid,subject,uid)
		VALUES(-3,NEW.member || ': ' || NEW.landing_tick,-3) RETURNING ftid
		INTO STRICT thread;
	NEW.ftid = thread;
	RETURN NEW;
END;
$_X$ LANGUAGE plpgsql;
