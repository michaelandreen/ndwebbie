CREATE OR REPLACE FUNCTION planetid(x integer, y integer, z integer, tick integer) RETURNS integer
    AS $_$SELECT pid FROM planet_stats WHERE x = $1 AND y = $2 AND z = $3 AND (tick >= $4  OR tick =( SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC LIMIT 1$_$
    LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION planetcoords(id integer, tick integer, OUT x integer, OUT y integer, OUT z integer) RETURNS record
    AS $_$SELECT x,y,z FROM planet_stats WHERE pid = $1 AND (tick >= $2  OR tick =( SELECT max(tick) FROM planet_stats))  ORDER BY tick ASC LIMIT 1$_$
    LANGUAGE sql STABLE;

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
