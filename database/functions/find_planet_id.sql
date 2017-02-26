DROP FUNCTIOn IF EXISTS find_planet_id(text,text,race);
CREATE OR REPLACE FUNCTION find_planet_id(_id text, _ruler text, _planet text, _race race) RETURNS integer
    AS $_$
DECLARE
	p RECORD;
	planet_id INTEGER;
	thread INTEGER;
BEGIN
	SELECT pid, ftid, race, ruler, planet INTO p FROM planets WHERE id = _id;
	IF FOUND THEN
		IF _race <> p.race OR _planet <> p.planet OR _ruler <> p.ruler THEN
			UPDATE planets SET race = _race, planet = _planet, ruler = _ruler WHERE pid = p.pid;
			UPDATE forum_threads SET subject = escape_html(_ruler) || ' OF ' || escape_html(_planet)
				WHERE ftid = p.ftid;
			INSERT INTO forum_posts (ftid, uid, message) VALUES(p.ftid, -2, 'Planet changed data from ('
				|| escape_html(p.ruler) || ', ' || escape_html(p.planet) || ', ' || p.race || ') to ('
				|| escape_html(_ruler) || ', ' || escape_html(_planet) || ', ' || _race || ').');
		END IF;
		planet_id := p.pid;
	ELSE
		INSERT INTO forum_threads (fbid,uid,subject) VALUES(-2, -3,
				escape_html(_ruler) || ' OF ' || escape_html(_planet))
			RETURNING ftid INTO thread;
		INSERT INTO planets(id, ruler,planet,race,ftid) VALUES(_id, _ruler,_planet,_race,thread)
			RETURNING pid INTO planet_id;
	END IF;
	RETURN planet_id;
END;
$_$
    LANGUAGE plpgsql;

