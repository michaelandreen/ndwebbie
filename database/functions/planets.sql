CREATE OR REPLACE FUNCTION planetid(x integer, y integer, z integer, tick integer) RETURNS integer
    AS $_$SELECT pid FROM planet_stats WHERE x = $1 AND y = $2 AND z = $3 AND (tick >= $4  OR tick =( SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC LIMIT 1$_$
    LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION planetcoords(id integer, tick integer, OUT x integer, OUT y integer, OUT z integer) RETURNS record
    AS $_$SELECT x,y,z FROM planet_stats WHERE pid = $1 AND (tick >= $2  OR tick =( SELECT max(tick) FROM planet_stats))  ORDER BY tick ASC LIMIT 1$_$
    LANGUAGE sql STABLE;

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

CREATE OR REPLACE FUNCTION coords(x integer, y integer, z integer) RETURNS text
    AS $_$
SELECT $1 || ':' || $2 || ':' || $3
$_$
    LANGUAGE sql IMMUTABLE;
