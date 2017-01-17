CREATE OR REPLACE FUNCTION sms_credits() RETURNS trigger
    AS $_X$
BEGIN
	IF NEW.cost <> OLD.cost
	THEN
		UPDATE clickatell SET credits = credits + OLD.cost - NEW.cost;
	END IF;
	RETURN NEW;
END;
$_X$ LANGUAGE plpgsql;

/*
ALTER TABLE clickatell ADD COLUMN credits NUMERIC NOT NULL DEFAULT 0.0;
CREATE TRIGGER sms_credits AFTER UPDATE OF cost ON sms FOR EACH ROW WHEN (NEW.cost <> OLD.cost) EXECUTE PROCEDURE sms_credits();
*/
