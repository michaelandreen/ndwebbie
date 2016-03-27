CREATE OR REPLACE FUNCTION update_forum_thread_posts() RETURNS trigger
	AS $$
BEGIN

	IF TG_OP = 'INSERT' THEN
		UPDATE forum_threads SET posts = posts + 1, mtime = GREATEST(NEW.time,mtime)
			WHERE ftid = NEW.ftid;
	ELSIF TG_OP = 'DELETE' THEN
		UPDATE forum_threads SET posts = posts - 1 WHERE ftid = OLD.ftid;
	ELSIF TG_OP = 'UPDATE' AND NEW.ftid <> OLD.ftid THEN
		UPDATE forum_threads SET posts = posts - 1 WHERE ftid = OLD.ftid;
		UPDATE forum_threads SET posts = posts + 1, mtime = GREATEST(NEW.time,mtime)
			WHERE ftid = NEW.ftid;
	END IF;

	return NEW;
END;
$$
	LANGUAGE plpgsql;
