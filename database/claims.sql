DROP TRIGGER IF EXISTS update_target ON raid_claims;
DROP TRIGGER IF EXISTS unclaim_target ON raid_claims;

DROP FUNCTION IF EXISTS updated_target();
DROP FUNCTION IF EXISTS unclaim_target();

CREATE OR REPLACE FUNCTION updated_claim() RETURNS trigger
    AS $_X$
DECLARE
	target INTEGER;
BEGIN
	CASE TG_OP
	WHEN 'INSERT' THEN
		target := NEW.target;
	WHEN 'UPDATE' THEN
		target := NEW.target;
		IF NEW.launched AND NOT OLD.launched THEN
			UPDATE users
			SET attack_points = attack_points + 1
			WHERE uid = OLD.uid;

			INSERT INTO forum_posts (ftid,uid,message)
			VALUES((SELECT ftid FROM users WHERE uid = NEW.uid),NEW.uid
				,'Gave attack point for confirmation of attack on target '
					|| NEW.target || ', wave ' || NEW.wave
				);
		END IF;
	WHEN 'DELETE' THEN
		target := OLD.target;

		IF OLD.launched THEN
			UPDATE users
			SET attack_points = attack_points - 1
			WHERE uid = OLD.uid;
		END IF;
	END CASE;
	UPDATE raid_targets SET modified = NOW() WHERE id = target;
	RETURN NEW;
END;
$_X$ LANGUAGE plpgsql;


CREATE TRIGGER updated_claim
  AFTER INSERT OR DELETE OR UPDATE ON raid_claims
  FOR EACH ROW EXECUTE PROCEDURE updated_claim();

