INSERT INTO forum_boards (fcid,fbid,board) VALUES(9,-5,'Raid logs');

ALTER TABLE raids ADD COLUMN ftid INTEGER;


CREATE OR REPLACE FUNCTION add_raid() RETURNS trigger
AS $$
DECLARE
	rec RECORD;
BEGIN
	INSERT INTO forum_threads (ftid,fbid,subject,uid) VALUES
		(DEFAULT,-5,'Raid ' || NEW.id,-3) RETURNING ftid INTO rec;
	NEW.ftid := rec.ftid;
	return NEW;
END;
$$
	LANGUAGE plpgsql;


CREATE TRIGGER add_raid
	BEFORE INSERT ON raids
	FOR EACH ROW
	EXECUTE PROCEDURE add_raid();
