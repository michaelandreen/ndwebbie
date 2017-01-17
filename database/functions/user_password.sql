CREATE OR REPLACE FUNCTION user_password() RETURNS trigger
    AS $_X$
DECLARE
	old_password TEXT;
BEGIN
	IF TG_OP = 'UPDATE'
	THEN
		old_password := OLD.password;
	END IF;
	IF COALESCE(NEW.password <> old_password,TRUE) AND
		NOT NEW.password SIMILAR TO '$2a$\d+$[a-zA-Z0-9./]+'
	THEN
		NEW.password := crypt(NEW.password,gen_salt('bf',10));
	END IF;
	RETURN NEW;
END;
$_X$ LANGUAGE plpgsql;

/*
alter table users alter COLUMN password drop not null ;
DROP TRIGGER user_password ON users;
CREATE TRIGGER user_password BEFORE INSERT OR UPDATE OF password ON users FOR EACH ROW EXECUTE PROCEDURE user_password();
*/
