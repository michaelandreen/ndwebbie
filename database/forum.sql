
ALTER TABLE forum_threads ADD posts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE forum_threads ADD mtime TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now();
ALTER TABLE forum_threads ADD ctime TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now();


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


CREATE TRIGGER update_forum_thread_posts
	AFTER INSERT OR UPDATE OR DELETE ON forum_posts
	FOR EACH ROW
	EXECUTE PROCEDURE update_forum_thread_posts();

UPDATE forum_threads ft SET posts = p.posts, mtime = p.time, ctime = p.ctime
	FROM (SELECT ftid, count(fpid) AS posts, max(time) AS time, min(time) AS ctime
		FROM forum_posts group by ftid) p
	WHERE p.ftid = ft.ftid;

