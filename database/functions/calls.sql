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
