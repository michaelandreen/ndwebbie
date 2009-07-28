CREATE OR REPLACE FUNCTION find_planet_id(_ruler text, _planet text, _race race) RETURNS integer
    AS $_$
DECLARE
	p RECORD;
	id INTEGER;
	thread INTEGER;
BEGIN
	SELECT pid, race INTO p FROM planets WHERE ruler = _ruler AND planet = _planet;
	IF FOUND THEN
		IF _race <> p.race THEN
			UPDATE planets SET race = _race WHERE pid = p.pid;
		END IF;
		id := p.pid;
	ELSE
		INSERT INTO forum_threads (fbid,subject,uid) VALUES(-2, _ruler || ' OF ' || _planet, -3)
			RETURNING ftid INTO thread;
		INSERT INTO planets(ruler,planet,race,ftid) VALUES(_ruler,_planet,_race,thread)
			RETURNING pid INTO id;
	END IF;
	RETURN id;
END;
$_$
    LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS findplanetid(character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION find_alliance_id(alli text) RETURNS integer
    AS $_$
DECLARE
	id INTEGER;
BEGIN
	SELECT aid FROM INTO id alliances WHERE alliance = alli;
	IF NOT FOUND THEN
		INSERT INTO alliances(alliance) VALUES($1)
			RETURNING aid INTO id;
	END IF;
	RETURN id;
END;
$_$
    LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS find_alliance_id(character varying);

CREATE OR REPLACE FUNCTION coords(x integer, y integer, z integer) RETURNS text
    AS $_$
SELECT $1 || ':' || $2 || ':' || $3
$_$
    LANGUAGE sql IMMUTABLE;

