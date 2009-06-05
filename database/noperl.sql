CREATE OR REPLACE FUNCTION find_planet_id(_ruler text, _planet text, _race race) RETURNS integer
    AS $_$
DECLARE
	p RECORD;
	pid INTEGER;
	thread INTEGER;
BEGIN
	SELECT id, race INTO p FROM planets WHERE ruler = _ruler AND planet = _planet;
	IF FOUND THEN
		IF _race <> p.race THEN
			UPDATE planets SET race = _race WHERE id = p.id;
		END IF;
		pid := p.id;
	ELSE
		INSERT INTO forum_threads (fbid,subject,uid) VALUES(-2, _ruler || ' OF ' || _planet, -3)
			RETURNING ftid INTO thread;
		INSERT INTO planets(ruler,planet,race,ftid) VALUES(_ruler,_planet,_race,thread)
			RETURNING id INTO pid;
	END IF;
	RETURN pid;
END;
$_$
    LANGUAGE plpgsql;

DROP FUNCTION findplanetid(character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION find_alliance_id(alliance text) RETURNS integer
    AS $_$
DECLARE
	aid INTEGER;
BEGIN
	SELECT id FROM INTO aid alliances WHERE name = alliance;
	IF NOT FOUND THEN
		INSERT INTO alliances(name) VALUES($1)
			RETURNING id INTO aid;
	END IF;
	RETURN aid;
END;
$_$
    LANGUAGE plpgsql;

DROP FUNCTION find_alliance_id(character varying);

CREATE OR REPLACE FUNCTION coords(x integer, y integer, z integer) RETURNS text
    AS $_$
SELECT $1 || ':' || $2 || ':' || $3
$_$
    LANGUAGE sql IMMUTABLE;
