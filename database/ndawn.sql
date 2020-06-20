--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.1
-- Dumped by pg_dump version 9.5.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


SET search_path = public, pg_catalog;

--
-- Name: ead_status; Type: TYPE; Schema: public; Owner: ndawn
--

CREATE TYPE ead_status AS ENUM (
    '',
    'NAP',
    'Friendly',
    'Hostile'
);


ALTER TYPE ead_status OWNER TO ndawn;

--
-- Name: governments; Type: TYPE; Schema: public; Owner: ndawn
--

CREATE TYPE governments AS ENUM (
    '',
    'Feu',
    'Dic',
    'Dem',
    'Uni'
);


ALTER TYPE governments OWNER TO ndawn;

--
-- Name: race; Type: TYPE; Schema: public; Owner: ndawn
--

CREATE TYPE race AS ENUM (
    'Ter',
    'Cat',
    'Xan',
    'Zik',
    'Etd'
);


ALTER TYPE race OWNER TO ndawn;

--
-- Name: add_call(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION add_call() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	thread INTEGER;
BEGIN
	INSERT INTO forum_threads (fbid,subject,uid)
		VALUES(-3,NEW.uid || ': ' || NEW.landing_tick,-3) RETURNING ftid
		INTO STRICT thread;
	NEW.ftid = thread;
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.add_call() OWNER TO ndawn;

--
-- Name: add_raid(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION add_raid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	rec RECORD;
BEGIN
	INSERT INTO forum_threads (ftid,fbid,subject,uid) VALUES
		(DEFAULT,-5,'Raid ' || NEW.id,-3) RETURNING ftid INTO rec;
	NEW.ftid := rec.ftid;
	return NEW;
END;
$$;


ALTER FUNCTION public.add_raid() OWNER TO ndawn;

--
-- Name: add_user(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION add_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	thread INTEGER;
BEGIN
	INSERT INTO forum_threads (fbid,subject,uid)
		VALUES(-1,NEW.uid || ': ' || NEW.username,-3) RETURNING ftid
		INTO STRICT thread;
	NEW.ftid = thread;
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.add_user() OWNER TO ndawn;

--
-- Name: change_member(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION change_member() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		IF NEW.gid = 'M' THEN
			UPDATE planets SET alliance = 'NewDawn' WHERE
				pid = (SELECT pid FROM users WHERE uid = NEW.uid);
		END IF;
	ELSIF TG_OP = 'DELETE' THEN
		IF OLD.gid = 'M' THEN
			UPDATE planets SET alliance = NULL WHERE
				pid = (SELECT pid FROM users WHERE uid = OLD.uid);
		END IF;
	END IF;

	return NEW;
END;
$$;


ALTER FUNCTION public.change_member() OWNER TO ndawn;

--
-- Name: coords(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION coords(x integer, y integer, z integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT $1 || ':' || $2 || ':' || $3
$_$;


ALTER FUNCTION public.coords(x integer, y integer, z integer) OWNER TO ndawn;

--
-- Name: covop_alert(integer, integer, integer, integer, governments, integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION covop_alert(secs integer, strucs integer, roids integer, guards integer, gov governments, population integer) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $_$
	SELECT ((50 + COALESCE($4*5.0/($3+1.0),$6))
		* (1.0+2*LEAST(COALESCE($1::float/CASE $2
			WHEN 0 THEN 1 ELSE $2 END,$6),0.30)
			+ (CASE $5
				WHEN 'Dic' THEN 0.20
				WHEN 'Feu' THEN -0.20
				WHEN 'Uni' THEN -0.10
				ELSE 0
			END) + $6/100.0
		))::integer;
$_$;


ALTER FUNCTION public.covop_alert(secs integer, strucs integer, roids integer, guards integer, gov governments, population integer) OWNER TO ndawn;

--
-- Name: endtick(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION endtick() RETURNS integer
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$SELECT value::integer FROM misc WHERE id = 'ENDTICK'$$;


ALTER FUNCTION public.endtick() OWNER TO ndawn;

--
-- Name: find_alliance_id(text); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION find_alliance_id(alli text) RETURNS integer
    LANGUAGE plpgsql
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
$_$;


ALTER FUNCTION public.find_alliance_id(alli text) OWNER TO ndawn;

--
-- Name: find_planet_id(text, text, race); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION find_planet_id(_ruler text, _planet text, _race race) RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.find_planet_id(_ruler text, _planet text, _race race) OWNER TO ndawn;

--
-- Name: groups(integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION groups(uid integer) RETURNS SETOF character
    LANGUAGE sql STABLE
    AS $_$SELECT gid FROM groupmembers WHERE uid = $1 UNION SELECT ''$_$;


ALTER FUNCTION public.groups(uid integer) OWNER TO ndawn;

--
-- Name: max_bank_hack(bigint, bigint, bigint, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION max_bank_hack(metal bigint, crystal bigint, eonium bigint, tvalue integer, value integer, agents integer) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT LEAST(2000.0*$6*$4/$5, $1*0.10, $6*10000.0)::integer
    + LEAST(2000.0*$6*$4/$5, $2*0.10, $6*10000.0)::integer
    + LEAST(2000.0*$6*$4/$5, $3*0.10, $6*10000.0)::integer
$_$;


ALTER FUNCTION public.max_bank_hack(metal bigint, crystal bigint, eonium bigint, tvalue integer, value integer, agents integer) OWNER TO ndawn;

--
-- Name: mmdd(date); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION mmdd(d date) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$ SELECT to_char($1,'MM-DD') $_$;


ALTER FUNCTION public.mmdd(d date) OWNER TO ndawn;

--
-- Name: old_claim(timestamp with time zone); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION old_claim("timestamp" timestamp with time zone) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$SELECT NOW() - '10 minutes'::INTERVAL > $1;$_$;


ALTER FUNCTION public.old_claim("timestamp" timestamp with time zone) OWNER TO ndawn;

--
-- Name: planetcoords(integer, integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION planetcoords(id integer, tick integer, OUT x integer, OUT y integer, OUT z integer) RETURNS record
    LANGUAGE sql STABLE
    AS $_$SELECT x,y,z FROM planet_stats WHERE pid = $1 AND (tick >= $2  OR tick =( SELECT max(tick) FROM planet_stats))  ORDER BY tick ASC LIMIT 1$_$;


ALTER FUNCTION public.planetcoords(id integer, tick integer, OUT x integer, OUT y integer, OUT z integer) OWNER TO ndawn;

--
-- Name: planetid(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION planetid(x integer, y integer, z integer, tick integer) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$SELECT pid FROM planet_stats WHERE x = $1 AND y = $2 AND z = $3 AND (tick >= $4  OR tick =( SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC LIMIT 1$_$;


ALTER FUNCTION public.planetid(x integer, y integer, z integer, tick integer) OWNER TO ndawn;

--
-- Name: tick(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION tick() RETURNS integer
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$SELECT value::integer FROM misc WHERE id = 'TICK'$$;


ALTER FUNCTION public.tick() OWNER TO ndawn;

--
-- Name: unread_posts(integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION unread_posts(uid integer, OUT unread integer, OUT new integer) RETURNS record
    LANGUAGE sql STABLE
    AS $_$
SELECT count(*)::int AS unread
	,count(NULLIF(fp.time > (SELECT max(time) FROM forum_thread_visits WHERE uid = $1),FALSE))::int AS new
FROM(
	SELECT ftid, ftv.time
	FROM forum_threads ft
		LEFT OUTER JOIN (SELECT * FROM forum_thread_visits WHERE uid = $1)
			ftv USING (ftid)
	WHERE COALESCE(ft.mtime > ftv.time,TRUE)
		AND ((fbid > 0 AND
				fbid IN (SELECT fbid FROM forum_access WHERE gid IN (SELECT groups($1)))
			) OR ft.ftid IN (SELECT ftid FROM forum_priv_access WHERE uid = $1)
		)
	) ft
	JOIN forum_posts fp USING (ftid)
WHERE COALESCE(fp.time > ft.time, TRUE)
$_$;


ALTER FUNCTION public.unread_posts(uid integer, OUT unread integer, OUT new integer) OWNER TO ndawn;

--
-- Name: update_forum_post(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION update_forum_post() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec RECORD;
BEGIN
    SELECT setweight(to_tsvector(coalesce(ft.subject,'')), 'A')
            || setweight(to_tsvector(coalesce(u.username,'')), 'B') AS ts
        INTO STRICT rec
        FROM forum_threads ft, users u
        WHERE NEW.ftid = ft.ftid AND u.uid = NEW.uid;
    NEW.textsearch := rec.ts
        || setweight(to_tsvector(coalesce(NEW.message,'')), 'D');
    return NEW;
END;
$$;


ALTER FUNCTION public.update_forum_post() OWNER TO ndawn;

--
-- Name: update_forum_thread_posts(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION update_forum_thread_posts() RETURNS trigger
    LANGUAGE plpgsql
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
$$;


ALTER FUNCTION public.update_forum_thread_posts() OWNER TO ndawn;

--
-- Name: update_user_planet(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION update_user_planet() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF COALESCE(NEW.pid <> OLD.pid,TRUE) OR NEW.username <> OLD.username THEN
		UPDATE planets SET nick = NULL WHERE pid = OLD.pid;
		UPDATE planets SET nick = NEW.username WHERE pid = NEW.pid;
	END IF;

	IF COALESCE(NEW.pid <> OLD.pid,TRUE)
			AND (SELECT TRUE FROM groupmembers WHERE gid = 'M' AND uid = NEW.uid) THEN
		UPDATE planets SET alliance = NULL WHERE pid = OLD.pid;
		UPDATE planets SET alliance = 'NewDawn' WHERE pid = NEW.pid;
	END IF;
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_user_planet() OWNER TO ndawn;

--
-- Name: update_wiki_page(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION update_wiki_page() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec RECORD;
BEGIN
    SELECT setweight(to_tsvector(wpr.text), 'D') AS ts
        INTO STRICT rec
        FROM wiki_page_revisions wpr
        WHERE NEW.wprev = wpr.wprev;
    NEW.textsearch := rec.ts
        || setweight(to_tsvector(NEW.namespace || ':' || NEW.name), 'A');
    NEW.time = NOW();
    return NEW;
END;
$$;


ALTER FUNCTION public.update_wiki_page() OWNER TO ndawn;

--
-- Name: updated_claim(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION updated_claim() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.updated_claim() OWNER TO ndawn;

--
-- Name: concat(text); Type: AGGREGATE; Schema: public; Owner: ndawn
--

CREATE AGGREGATE concat(text) (
    SFUNC = textcat,
    STYPE = text,
    INITCOND = ''
);


ALTER AGGREGATE public.concat(text) OWNER TO ndawn;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: alliance_stats; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE alliance_stats (
    aid integer NOT NULL,
    tick integer NOT NULL,
    size integer NOT NULL,
    members integer NOT NULL,
    score integer NOT NULL,
    sizerank integer NOT NULL,
    scorerank integer NOT NULL,
    size_gain integer NOT NULL,
    score_gain integer NOT NULL,
    sizerank_gain integer NOT NULL,
    scorerank_gain integer NOT NULL,
    size_gain_day integer NOT NULL,
    score_gain_day integer NOT NULL,
    sizerank_gain_day integer NOT NULL,
    scorerank_gain_day integer NOT NULL,
    members_gain integer NOT NULL,
    members_gain_day integer NOT NULL
);


ALTER TABLE alliance_stats OWNER TO ndawn;

--
-- Name: alliances; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE alliances (
    aid integer NOT NULL,
    alliance text NOT NULL,
    relationship ead_status DEFAULT ''::ead_status NOT NULL
);


ALTER TABLE alliances OWNER TO ndawn;

--
-- Name: development_scans; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE development_scans (
    id integer NOT NULL,
    pid integer NOT NULL,
    tick integer NOT NULL,
    light_fac integer NOT NULL,
    medium_fac integer NOT NULL,
    heavy_fac integer NOT NULL,
    amps integer NOT NULL,
    distorters integer NOT NULL,
    metal_ref integer NOT NULL,
    crystal_ref integer NOT NULL,
    eonium_ref integer NOT NULL,
    reslabs integer NOT NULL,
    fincents integer NOT NULL,
    seccents integer NOT NULL,
    total integer NOT NULL,
    travel integer NOT NULL,
    infra integer NOT NULL,
    hulls integer NOT NULL,
    waves integer NOT NULL,
    extraction integer NOT NULL,
    covert integer NOT NULL,
    mining integer NOT NULL,
    milcents integer NOT NULL,
    structdefs integer NOT NULL
);


ALTER TABLE development_scans OWNER TO ndawn;

--
-- Name: current_development_scans; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW current_development_scans AS
 SELECT DISTINCT ON (ds.pid) ds.id,
    ds.pid,
    ds.tick,
    ds.light_fac,
    ds.medium_fac,
    ds.heavy_fac,
    ds.amps,
    ds.distorters,
    ds.metal_ref,
    ds.crystal_ref,
    ds.eonium_ref,
    ds.reslabs,
    ds.fincents,
    ds.seccents,
    ds.total,
    ds.travel,
    ds.infra,
    ds.hulls,
    ds.waves,
    ds.extraction,
    ds.covert,
    ds.mining
   FROM development_scans ds
  ORDER BY ds.pid, ds.tick DESC, ds.id DESC;


ALTER TABLE current_development_scans OWNER TO ndawn;

--
-- Name: planet_scans; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE planet_scans (
    id integer NOT NULL,
    pid integer NOT NULL,
    tick integer NOT NULL,
    metal bigint NOT NULL,
    crystal bigint NOT NULL,
    eonium bigint NOT NULL,
    hidden bigint NOT NULL,
    metal_roids integer NOT NULL,
    crystal_roids integer NOT NULL,
    eonium_roids integer NOT NULL,
    agents integer NOT NULL,
    guards integer NOT NULL,
    light text NOT NULL,
    medium text NOT NULL,
    heavy text NOT NULL
);


ALTER TABLE planet_scans OWNER TO ndawn;

--
-- Name: current_planet_scans; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW current_planet_scans AS
 SELECT DISTINCT ON (ps.pid) ps.id,
    ps.pid,
    ps.tick,
    ps.metal,
    ps.crystal,
    ps.eonium,
    ps.hidden,
    ps.metal_roids,
    ps.crystal_roids,
    ps.eonium_roids,
    ps.agents,
    ps.guards,
    ps.light,
    ps.medium,
    ps.heavy
   FROM planet_scans ps
  ORDER BY ps.pid, ps.tick DESC, ps.id DESC;


ALTER TABLE current_planet_scans OWNER TO ndawn;

--
-- Name: planet_stats; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE planet_stats (
    pid integer NOT NULL,
    tick integer NOT NULL,
    x integer NOT NULL,
    y integer NOT NULL,
    z integer NOT NULL,
    size integer NOT NULL,
    score integer NOT NULL,
    value integer NOT NULL,
    xp integer NOT NULL,
    sizerank integer NOT NULL,
    scorerank integer NOT NULL,
    valuerank integer NOT NULL,
    xprank integer NOT NULL,
    size_gain integer NOT NULL,
    score_gain integer NOT NULL,
    value_gain integer NOT NULL,
    xp_gain integer NOT NULL,
    sizerank_gain integer NOT NULL,
    scorerank_gain integer NOT NULL,
    valuerank_gain integer NOT NULL,
    xprank_gain integer NOT NULL,
    size_gain_day integer NOT NULL,
    score_gain_day integer NOT NULL,
    value_gain_day integer NOT NULL,
    xp_gain_day integer NOT NULL,
    sizerank_gain_day integer NOT NULL,
    scorerank_gain_day integer NOT NULL,
    valuerank_gain_day integer NOT NULL,
    xprank_gain_day integer NOT NULL
);


ALTER TABLE planet_stats OWNER TO ndawn;

--
-- Name: planets; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE planets (
    pid integer NOT NULL,
    ruler text NOT NULL,
    planet text NOT NULL,
    race race NOT NULL,
    nick citext,
    planet_status ead_status DEFAULT ''::ead_status NOT NULL,
    hit_us integer DEFAULT 0 NOT NULL,
    alliance text,
    channel citext,
    ftid integer NOT NULL,
    gov governments DEFAULT ''::governments NOT NULL
)
WITH (fillfactor='50');

ALTER TABLE planets ADD COLUMN id text UNIQUE NOT NULL;


ALTER TABLE planets OWNER TO ndawn;

--
-- Name: current_planet_stats; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW current_planet_stats AS
 SELECT p.pid,
    p.nick,
    p.planet_status,
    p.hit_us,
    ps.x,
    ps.y,
    ps.z,
    p.ruler,
    p.planet,
    p.race,
    p.alliance,
    a.relationship,
    a.aid,
    p.channel,
    p.ftid,
    p.gov,
    ps.size,
    ps.score,
    ps.value,
    ps.xp,
    ps.sizerank,
    ps.scorerank,
    ps.valuerank,
    ps.xprank
   FROM ((( SELECT planet_stats.pid,
            planet_stats.tick,
            planet_stats.x,
            planet_stats.y,
            planet_stats.z,
            planet_stats.size,
            planet_stats.score,
            planet_stats.value,
            planet_stats.xp,
            planet_stats.sizerank,
            planet_stats.scorerank,
            planet_stats.valuerank,
            planet_stats.xprank
           FROM planet_stats
          WHERE (planet_stats.tick = ( SELECT max(planet_stats_1.tick) AS max
                   FROM planet_stats planet_stats_1))) ps
     JOIN planets p USING (pid))
     LEFT JOIN alliances a USING (alliance));


ALTER TABLE current_planet_stats OWNER TO ndawn;

--
-- Name: alliance_resources; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW alliance_resources AS
 WITH planet_estimates AS (
         SELECT ps.tick,
            p.alliance,
            ps.hidden,
            p.size,
            p.score,
            ((ps.metal + ps.crystal) + ps.eonium) AS resources,
            ((p.score + (((ps.metal + ps.crystal) + ps.eonium) / 300)) + (ps.hidden / 100)) AS nscore2,
            ((((p.score + (((ps.metal + ps.crystal) + ps.eonium) / 300)) + (ps.hidden / 100)))::numeric + (((((endtick() - tick()) * (((250 * p.size) + (COALESCE(((ds.metal_ref + ds.crystal_ref) + ds.eonium_ref), 7) * 1000)) +
                CASE ds.extraction
                    WHEN 0 THEN 3000
                    WHEN 1 THEN 11500
                    ELSE ((COALESCE(ds.extraction, 3) * 3000) * 3)
                END)))::numeric * (1.35 + (0.005 * (COALESCE(ds.fincents, 20))::numeric))) / (100)::numeric)) AS nscore3
           FROM ((current_planet_stats p
             JOIN current_planet_scans ps USING (pid))
             LEFT JOIN current_development_scans ds USING (pid))
        ), planet_ranks AS (
         SELECT planet_estimates.tick,
            planet_estimates.alliance,
            planet_estimates.hidden,
            planet_estimates.size,
            planet_estimates.score,
            planet_estimates.resources,
            planet_estimates.nscore2,
            planet_estimates.nscore3,
            rank() OVER (PARTITION BY planet_estimates.alliance ORDER BY planet_estimates.score DESC) AS rank
           FROM planet_estimates
        ), top_planets AS (
         SELECT planet_ranks.alliance,
            sum(planet_ranks.resources) AS resources,
            sum(planet_ranks.hidden) AS hidden,
            (sum(planet_ranks.nscore2))::bigint AS nscore2,
            (sum(planet_ranks.nscore3))::bigint AS nscore3,
            count(*) AS planets,
            sum(planet_ranks.score) AS score,
            sum(planet_ranks.size) AS size,
            (avg(planet_ranks.tick))::integer AS avgtick
           FROM planet_ranks
          WHERE (planet_ranks.rank <= 60)
          GROUP BY planet_ranks.alliance
        )
 SELECT a.aid,
    a.alliance,
    a.relationship,
    s.members,
    r.planets,
    s.score,
    r.score AS topscore,
    s.size,
    r.size AS topsize,
    r.resources,
    r.hidden,
    ((((s.score)::numeric + (r.resources / (300)::numeric)) + (r.hidden / (100)::numeric)))::bigint AS nscore,
    r.nscore2,
    r.nscore3,
    r.avgtick
   FROM ((alliances a
     JOIN top_planets r USING (alliance))
     LEFT JOIN ( SELECT alliance_stats.aid,
            alliance_stats.score,
            alliance_stats.size,
            alliance_stats.members
           FROM alliance_stats
          WHERE (alliance_stats.tick = ( SELECT max(alliance_stats_1.tick) AS max
                   FROM alliance_stats alliance_stats_1))) s USING (aid));


ALTER TABLE alliance_resources OWNER TO ndawn;

--
-- Name: alliances_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE alliances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE alliances_id_seq OWNER TO ndawn;

--
-- Name: alliances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE alliances_id_seq OWNED BY alliances.aid;


--
-- Name: available_planet_tags; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE available_planet_tags (
    tag citext NOT NULL
);


ALTER TABLE available_planet_tags OWNER TO ndawn;

--
-- Name: fleet_ships; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE fleet_ships (
    fid integer NOT NULL,
    ship text NOT NULL,
    amount integer NOT NULL,
    num integer NOT NULL
);


ALTER TABLE fleet_ships OWNER TO ndawn;

--
-- Name: fleets; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE fleets (
    mission text NOT NULL,
    tick integer NOT NULL,
    fid integer NOT NULL,
    pid integer NOT NULL,
    amount integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE fleets OWNER TO ndawn;

--
-- Name: launch_confirmations; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE launch_confirmations (
    fid integer NOT NULL,
    uid integer NOT NULL,
    pid integer NOT NULL,
    landing_tick integer NOT NULL,
    eta integer NOT NULL,
    back integer NOT NULL,
    num integer NOT NULL
)
WITH (fillfactor='75');


ALTER TABLE launch_confirmations OWNER TO ndawn;

--
-- Name: ticks; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE ticks (
    t integer NOT NULL
);


ALTER TABLE ticks OWNER TO ndawn;

--
-- Name: users; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE users (
    uid integer NOT NULL,
    username citext NOT NULL,
    pid integer,
    password text,
    attack_points numeric(3,0) DEFAULT 0 NOT NULL,
    defense_points numeric(4,1) DEFAULT 0 NOT NULL,
    scan_points numeric(5,0) DEFAULT 0 NOT NULL,
    humor_points numeric(3,0) DEFAULT 0 NOT NULL,
    hostmask citext NOT NULL,
    sms text,
    rank integer,
    laston timestamp with time zone,
    ftid integer NOT NULL,
    css text,
    email text,
    pnick citext NOT NULL,
    info text,
    birthday date,
    timezone text DEFAULT 'GMT'::text NOT NULL,
    call_if_needed boolean DEFAULT false NOT NULL,
    sms_note text DEFAULT ''::text NOT NULL
)
WITH (fillfactor='50');


ALTER TABLE users OWNER TO ndawn;

--
-- Name: ships_home; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW ships_home AS
 SELECT f.tick,
    u.uid,
    u.username,
    u.pid,
    f.ship,
    COALESCE((f.amount - o.amount), (f.amount)::bigint) AS amount,
    COALESCE(o.fleets, (3)::bigint) AS fleets
   FROM ((users u
     JOIN ( SELECT f_1.t AS tick,
            f_1.pid,
            fs.ship,
            fs.amount
           FROM (( SELECT DISTINCT ON (ticks.t, f_2.pid, f_2.mission) ticks.t,
                    f_2.pid,
                    f_2.mission,
                    f_2.fid
                   FROM (ticks
                     CROSS JOIN fleets f_2)
                  WHERE ((f_2.tick <= ticks.t) AND (f_2.name = ANY (ARRAY['Main'::text, 'Advanced Unit'::text])) AND (f_2.mission = 'Full fleet'::text))
                  ORDER BY ticks.t, f_2.pid, f_2.mission, f_2.tick DESC, f_2.fid DESC) f_1
             JOIN fleet_ships fs USING (fid))) f USING (pid))
     LEFT JOIN ( SELECT ticks.t AS tick,
            f_1.pid,
            fs.ship,
            sum(fs.amount) AS amount,
            (3 - count(DISTINCT f_1.fid)) AS fleets
           FROM (((ticks
             CROSS JOIN fleets f_1)
             JOIN ( SELECT launch_confirmations.landing_tick,
                    launch_confirmations.fid,
                    launch_confirmations.back,
                    launch_confirmations.eta
                   FROM launch_confirmations) lc USING (fid))
             JOIN fleet_ships fs USING (fid))
          WHERE ((lc.back > ticks.t) AND (((lc.landing_tick - lc.eta) - 12) < ticks.t))
          GROUP BY ticks.t, f_1.pid, fs.ship) o USING (tick, pid, ship))
  WHERE (COALESCE((f.amount - o.amount), (f.amount)::bigint) > 0);


ALTER TABLE ships_home OWNER TO ndawn;

--
-- Name: available_ships; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW available_ships AS
 SELECT ships_home.uid,
    ships_home.username,
    ships_home.pid,
    ships_home.ship,
    ships_home.amount,
    ships_home.fleets
   FROM ships_home
  WHERE (ships_home.tick = tick());


ALTER TABLE available_ships OWNER TO ndawn;

--
-- Name: call_statuses; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE call_statuses (
    status text NOT NULL
);


ALTER TABLE call_statuses OWNER TO ndawn;

--
-- Name: calls; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE calls (
    call integer NOT NULL,
    uid integer NOT NULL,
    dc integer,
    landing_tick integer NOT NULL,
    info text NOT NULL,
    ftid integer NOT NULL,
    calc text DEFAULT ''::text NOT NULL,
    status text DEFAULT 'Open'::text NOT NULL
);


ALTER TABLE calls OWNER TO ndawn;

--
-- Name: calls_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE calls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE calls_id_seq OWNER TO ndawn;

--
-- Name: calls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE calls_id_seq OWNED BY calls.call;


--
-- Name: channel_flags; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE channel_flags (
    name text NOT NULL,
    flag character(1) NOT NULL
);


ALTER TABLE channel_flags OWNER TO ndawn;

--
-- Name: channel_group_flags; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE channel_group_flags (
    channel citext NOT NULL,
    gid character(1) NOT NULL,
    flag character(1) NOT NULL
);


ALTER TABLE channel_group_flags OWNER TO ndawn;

--
-- Name: channels; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE channels (
    channel citext NOT NULL,
    description text NOT NULL
);


ALTER TABLE channels OWNER TO ndawn;

--
-- Name: clickatell; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE clickatell (
    api_id text NOT NULL,
    username text NOT NULL,
    password text NOT NULL
);


ALTER TABLE clickatell OWNER TO ndawn;

--
-- Name: covop_attacks; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE covop_attacks (
    uid integer NOT NULL,
    tick integer NOT NULL,
    pid integer NOT NULL
);


ALTER TABLE covop_attacks OWNER TO ndawn;

--
-- Name: current_planet_stats_full; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW current_planet_stats_full AS
 SELECT p.alliance,
    p.pid,
    p.ruler,
    p.planet,
    p.race,
    p.nick,
    p.planet_status,
    p.hit_us,
    p.channel,
    p.ftid,
    p.gov,
    ps.tick,
    ps.x,
    ps.y,
    ps.z,
    ps.size,
    ps.score,
    ps.value,
    ps.xp,
    ps.sizerank,
    ps.scorerank,
    ps.valuerank,
    ps.xprank,
    ps.size_gain,
    ps.score_gain,
    ps.value_gain,
    ps.xp_gain,
    ps.sizerank_gain,
    ps.scorerank_gain,
    ps.valuerank_gain,
    ps.xprank_gain,
    ps.size_gain_day,
    ps.score_gain_day,
    ps.value_gain_day,
    ps.xp_gain_day,
    ps.sizerank_gain_day,
    ps.scorerank_gain_day,
    ps.valuerank_gain_day,
    ps.xprank_gain_day,
    alliances.aid,
    alliances.relationship
   FROM ((planets p
     JOIN ( SELECT planet_stats.pid,
            planet_stats.tick,
            planet_stats.x,
            planet_stats.y,
            planet_stats.z,
            planet_stats.size,
            planet_stats.score,
            planet_stats.value,
            planet_stats.xp,
            planet_stats.sizerank,
            planet_stats.scorerank,
            planet_stats.valuerank,
            planet_stats.xprank,
            planet_stats.size_gain,
            planet_stats.score_gain,
            planet_stats.value_gain,
            planet_stats.xp_gain,
            planet_stats.sizerank_gain,
            planet_stats.scorerank_gain,
            planet_stats.valuerank_gain,
            planet_stats.xprank_gain,
            planet_stats.size_gain_day,
            planet_stats.score_gain_day,
            planet_stats.value_gain_day,
            planet_stats.xp_gain_day,
            planet_stats.sizerank_gain_day,
            planet_stats.scorerank_gain_day,
            planet_stats.valuerank_gain_day,
            planet_stats.xprank_gain_day
           FROM planet_stats
          WHERE (planet_stats.tick = ( SELECT max(planet_stats_1.tick) AS max
                   FROM planet_stats planet_stats_1))) ps USING (pid))
     LEFT JOIN alliances USING (alliance));


ALTER TABLE current_planet_stats_full OWNER TO ndawn;

--
-- Name: ship_stats; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE ship_stats (
    ship text NOT NULL,
    class text NOT NULL,
    t1 text NOT NULL,
    type text NOT NULL,
    init integer NOT NULL,
    armor integer NOT NULL,
    damage integer NOT NULL,
    metal integer NOT NULL,
    crystal integer NOT NULL,
    eonium integer NOT NULL,
    race text NOT NULL,
    guns integer DEFAULT 0 NOT NULL,
    eres integer DEFAULT 0 NOT NULL,
    t2 text,
    t3 text,
    id integer NOT NULL
);


ALTER TABLE ship_stats OWNER TO ndawn;

--
-- Name: def_leeches; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW def_leeches AS
 WITH f AS (
         SELECT lc.uid,
            lc.fid,
            lc.pid,
            f.pid AS fpid,
            lc.landing_tick,
            lc.eta,
            lc.back,
            sum((((fs.amount * ((s.metal + s.crystal) + s.eonium)))::numeric / 100.0)) AS value
           FROM (((launch_confirmations lc
             JOIN fleets f USING (fid))
             JOIN fleet_ships fs USING (fid))
             JOIN ship_stats s ON ((fs.ship = s.ship)))
          WHERE (f.mission = 'Defend'::text)
          GROUP BY lc.uid, lc.fid, lc.pid, f.pid, lc.landing_tick, lc.eta, lc.back
        ), f2 AS (
         SELECT f.uid,
            sum((f.value / (COALESCE(p.value, ( SELECT planet_stats.value
                   FROM planet_stats
                  WHERE ((planet_stats.pid = f.fpid) AND (planet_stats.tick = (c.landing_tick - f.eta)))
                  ORDER BY planet_stats.tick DESC
                 LIMIT 1)))::numeric)) AS sent_value
           FROM (((calls c
             JOIN users u USING (uid))
             JOIN f USING (pid, landing_tick))
             LEFT JOIN ( SELECT planet_stats.pid AS fpid,
                    planet_stats.value,
                    planet_stats.tick AS landing_tick
                   FROM planet_stats) p USING (fpid, landing_tick))
          GROUP BY f.uid
        )
 SELECT d.uid,
    d.username,
    d.defense_points,
    count(d.call) AS calls,
    sum(d.fleets) AS fleets,
    sum(d.recalled) AS recalled,
    count(NULLIF(d.fleets, 0)) AS defended_calls,
    (sum(d.value))::numeric(4,2) AS value,
    (f2.sent_value)::numeric(4,2) AS sent_value
   FROM (( SELECT u.uid,
            u.username,
            u.defense_points,
            c.call,
            count(f.back) AS fleets,
            count(NULLIF((((f.landing_tick + f.eta) - 1) = f.back), true)) AS recalled,
            sum((f.value / (COALESCE(p.value, ( SELECT planet_stats.value
                   FROM planet_stats
                  WHERE ((planet_stats.pid = f.pid) AND (planet_stats.tick = (c.landing_tick - f.eta)))
                  ORDER BY planet_stats.tick DESC
                 LIMIT 1)))::numeric)) AS value
           FROM (((users u
             JOIN calls c USING (uid))
             LEFT JOIN f USING (pid, landing_tick))
             LEFT JOIN ( SELECT planet_stats.pid,
                    planet_stats.value,
                    planet_stats.tick AS landing_tick
                   FROM planet_stats) p USING (pid, landing_tick))
          GROUP BY u.uid, u.username, u.defense_points, c.call) d
     LEFT JOIN f2 USING (uid))
  GROUP BY d.uid, d.username, d.defense_points, f2.sent_value;


ALTER TABLE def_leeches OWNER TO ndawn;

--
-- Name: incomings; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE incomings (
    call integer NOT NULL,
    pid integer NOT NULL,
    eta integer NOT NULL,
    amount integer NOT NULL,
    fleet text NOT NULL,
    shiptype text DEFAULT '?'::text NOT NULL,
    inc integer NOT NULL
);


ALTER TABLE incomings OWNER TO ndawn;

--
-- Name: defcalls; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW defcalls AS
 SELECT c.call,
    c.status,
    c.uid,
    c.landing_tick,
    dc.username AS dc,
    (c.landing_tick - tick()) AS curreta,
    array_agg(COALESCE((p2.race)::text, ''::text)) AS race,
    array_agg(COALESCE(i.amount, 0)) AS amount,
    array_agg(COALESCE(i.eta, 0)) AS eta,
    array_agg(COALESCE(i.shiptype, ''::text)) AS shiptype,
    array_agg(COALESCE(p2.alliance, '?'::text)) AS alliance,
    array_agg(coords(p2.x, p2.y, p2.z)) AS attackers
   FROM (((calls c
     LEFT JOIN incomings i USING (call))
     LEFT JOIN current_planet_stats p2 USING (pid))
     LEFT JOIN users dc ON ((c.dc = dc.uid)))
  GROUP BY c.call, c.uid, dc.username, c.landing_tick, c.status;


ALTER TABLE defcalls OWNER TO ndawn;

--
-- Name: defense_missions; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE defense_missions (
    call integer NOT NULL,
    fleet integer NOT NULL,
    announced boolean DEFAULT false NOT NULL,
    pointed boolean DEFAULT false NOT NULL
);


ALTER TABLE defense_missions OWNER TO ndawn;

--
-- Name: dumps; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE dumps (
    tick integer NOT NULL,
    type text NOT NULL,
    dump text NOT NULL,
    modified integer DEFAULT 0 NOT NULL
);


ALTER TABLE dumps OWNER TO ndawn;

--
-- Name: email_change; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE email_change (
    id text DEFAULT md5(((now() + (random() * '100 years'::interval)))::text) NOT NULL,
    uid integer NOT NULL,
    email text NOT NULL,
    confirmed boolean DEFAULT false NOT NULL,
    time timestamptz DEFAULT now()
);

ALTER TABLE email_change OWNER TO ndawn;

--
-- Name: fleet_scans; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE fleet_scans (
    fid integer NOT NULL,
    id integer NOT NULL
);


ALTER TABLE fleet_scans OWNER TO ndawn;

--
-- Name: fleet_ships_num_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE fleet_ships_num_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fleet_ships_num_seq OWNER TO ndawn;

--
-- Name: fleet_ships_num_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE fleet_ships_num_seq OWNED BY fleet_ships.num;


--
-- Name: fleets_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE fleets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fleets_id_seq OWNER TO ndawn;

--
-- Name: fleets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE fleets_id_seq OWNED BY fleets.fid;


--
-- Name: forum_access; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE forum_access (
    fbid integer NOT NULL,
    gid character(1) NOT NULL,
    post boolean DEFAULT false NOT NULL,
    moderate boolean DEFAULT false NOT NULL
);


ALTER TABLE forum_access OWNER TO ndawn;

--
-- Name: forum_boards; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE forum_boards (
    fbid integer NOT NULL,
    fcid integer NOT NULL,
    board text NOT NULL
);


ALTER TABLE forum_boards OWNER TO ndawn;

--
-- Name: forum_boards_fbid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE forum_boards_fbid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE forum_boards_fbid_seq OWNER TO ndawn;

--
-- Name: forum_boards_fbid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE forum_boards_fbid_seq OWNED BY forum_boards.fbid;


--
-- Name: forum_categories; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE forum_categories (
    fcid integer NOT NULL,
    category text NOT NULL
);


ALTER TABLE forum_categories OWNER TO ndawn;

--
-- Name: forum_categories_fcid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE forum_categories_fcid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE forum_categories_fcid_seq OWNER TO ndawn;

--
-- Name: forum_categories_fcid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE forum_categories_fcid_seq OWNED BY forum_categories.fcid;


--
-- Name: forum_posts; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE forum_posts (
    fpid integer NOT NULL,
    ftid integer NOT NULL,
    message text NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL,
    uid integer NOT NULL,
    textsearch tsvector NOT NULL
);


ALTER TABLE forum_posts OWNER TO ndawn;

--
-- Name: forum_posts_fpid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE forum_posts_fpid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE forum_posts_fpid_seq OWNER TO ndawn;

--
-- Name: forum_posts_fpid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE forum_posts_fpid_seq OWNED BY forum_posts.fpid;


--
-- Name: forum_priv_access; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE forum_priv_access (
    uid integer NOT NULL,
    ftid integer NOT NULL
);


ALTER TABLE forum_priv_access OWNER TO ndawn;

--
-- Name: forum_thread_visits; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE forum_thread_visits (
    uid integer NOT NULL,
    ftid integer NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL
)
WITH (fillfactor='50');


ALTER TABLE forum_thread_visits OWNER TO ndawn;

--
-- Name: forum_threads; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE forum_threads (
    ftid integer NOT NULL,
    fbid integer NOT NULL,
    subject text NOT NULL,
    sticky boolean DEFAULT false NOT NULL,
    uid integer NOT NULL,
    posts integer DEFAULT 0 NOT NULL,
    mtime timestamp with time zone DEFAULT now() NOT NULL,
    ctime timestamp with time zone DEFAULT now() NOT NULL
)
WITH (fillfactor='50');


ALTER TABLE forum_threads OWNER TO ndawn;

--
-- Name: forum_threads_ftid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE forum_threads_ftid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE forum_threads_ftid_seq OWNER TO ndawn;

--
-- Name: forum_threads_ftid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE forum_threads_ftid_seq OWNED BY forum_threads.ftid;


--
-- Name: groupmembers; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE groupmembers (
    gid character(1) NOT NULL,
    uid integer NOT NULL
);


ALTER TABLE groupmembers OWNER TO ndawn;

--
-- Name: users_defprio; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW users_defprio AS
 SELECT u.uid,
    u.username,
    u.pid,
    u.password,
    u.attack_points,
    u.defense_points,
    u.scan_points,
    u.humor_points,
    u.hostmask,
    u.sms,
    u.rank,
    u.laston,
    u.ftid,
    u.css,
    u.email,
    u.pnick,
    u.info,
    u.birthday,
    u.timezone,
    u.call_if_needed,
    u.sms_note,
    ((((((0.2 * (u.attack_points / GREATEST(a.attack, (1)::numeric))) + (0.4 * (u.defense_points / GREATEST(a.defense, (1)::numeric)))) + (0.2 * ((p.size)::numeric / a.size))) + (0.05 * ((p.score)::numeric / a.score))) + (0.15 * ((p.value)::numeric / a.value))))::numeric(3,2) AS defprio
   FROM (users u
     LEFT JOIN current_planet_stats p USING (pid)),
    ( SELECT avg(u_1.attack_points) AS attack,
            avg(u_1.defense_points) AS defense,
            avg(p_1.size) AS size,
            avg(p_1.score) AS score,
            avg(p_1.value) AS value
           FROM (users u_1
             JOIN current_planet_stats p_1 USING (pid))
          WHERE (u_1.uid IN ( SELECT groupmembers.uid
                   FROM groupmembers
                  WHERE (groupmembers.gid = 'M'::bpchar)))) a;


ALTER TABLE users_defprio OWNER TO ndawn;

--
-- Name: full_defcalls; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW full_defcalls AS
 SELECT c.call,
    c.status,
    p.x,
    p.y,
    p.z,
    u.pid,
    c.landing_tick,
    c.dc,
    c.curreta,
    u.defprio,
    c.race,
    c.amount,
    c.eta,
    c.shiptype,
    c.alliance,
    c.attackers,
    count(NULLIF((f.back = ((f.landing_tick + f.eta) - 1)), false)) AS fleets
   FROM (((users_defprio u
     JOIN current_planet_stats p USING (pid))
     JOIN defcalls c USING (uid))
     LEFT JOIN launch_confirmations f USING (pid, landing_tick))
  GROUP BY c.call, p.x, p.y, p.z, u.pid, c.landing_tick, c.dc, c.curreta, u.defprio, c.race, c.amount, c.eta, c.shiptype, c.alliance, c.attackers, c.status;


ALTER TABLE full_defcalls OWNER TO ndawn;

--
-- Name: full_fleets; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE full_fleets (
    fid integer NOT NULL,
    uid integer NOT NULL
);


ALTER TABLE full_fleets OWNER TO ndawn;

--
-- Name: intel; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE intel (
    id integer NOT NULL,
    uid integer NOT NULL,
    sender integer NOT NULL,
    target integer NOT NULL,
    mission text NOT NULL,
    name text NOT NULL,
    amount integer,
    tick integer NOT NULL,
    eta integer NOT NULL,
    back integer,
    ingal boolean NOT NULL
);


ALTER TABLE intel OWNER TO ndawn;

--
-- Name: full_intel; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW full_intel AS
 SELECT s.alliance AS salliance,
    coords(s.x, s.y, s.z) AS scoords,
    i.sender,
    s.nick AS snick,
    t.alliance AS talliance,
    coords(t.x, t.y, t.z) AS tcoords,
    i.target,
    t.nick AS tnick,
    i.mission,
    i.tick,
    min(i.eta) AS eta,
    i.amount,
    i.ingal,
    i.uid,
    u.username
   FROM (((intel i
     JOIN users u USING (uid))
     JOIN current_planet_stats t ON ((i.target = t.pid)))
     JOIN current_planet_stats s ON ((i.sender = s.pid)))
  GROUP BY i.tick, i.mission, t.x, t.y, t.z, s.x, s.y, s.z, i.amount, i.ingal, u.username, i.uid, t.alliance, s.alliance, t.nick, s.nick, i.sender, i.target;


ALTER TABLE full_intel OWNER TO ndawn;

--
-- Name: galaxies; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE galaxies (
    x integer NOT NULL,
    y integer NOT NULL,
    tick integer NOT NULL,
    size integer NOT NULL,
    score integer NOT NULL,
    value integer NOT NULL,
    xp integer NOT NULL,
    planets integer NOT NULL,
    sizerank integer NOT NULL,
    scorerank integer NOT NULL,
    valuerank integer NOT NULL,
    xprank integer NOT NULL,
    size_gain integer NOT NULL,
    score_gain integer NOT NULL,
    value_gain integer NOT NULL,
    xp_gain integer NOT NULL,
    planets_gain integer NOT NULL,
    sizerank_gain integer NOT NULL,
    scorerank_gain integer NOT NULL,
    valuerank_gain integer NOT NULL,
    xprank_gain integer NOT NULL,
    size_gain_day integer NOT NULL,
    score_gain_day integer NOT NULL,
    value_gain_day integer NOT NULL,
    xp_gain_day integer NOT NULL,
    planets_gain_day integer NOT NULL,
    sizerank_gain_day integer NOT NULL,
    scorerank_gain_day integer NOT NULL,
    valuerank_gain_day integer NOT NULL,
    xprank_gain_day integer NOT NULL
);


ALTER TABLE galaxies OWNER TO ndawn;

--
-- Name: group_roles; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE group_roles (
    gid character(1) NOT NULL,
    role character varying(32) NOT NULL
);


ALTER TABLE group_roles OWNER TO ndawn;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE groups (
    groupname text NOT NULL,
    gid character(1) NOT NULL
);


ALTER TABLE groups OWNER TO ndawn;

--
-- Name: incomings_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE incomings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE incomings_id_seq OWNER TO ndawn;

--
-- Name: incomings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE incomings_id_seq OWNED BY incomings.inc;


--
-- Name: intel_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE intel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE intel_id_seq OWNER TO ndawn;

--
-- Name: intel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE intel_id_seq OWNED BY intel.id;


--
-- Name: intel_scans; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE intel_scans (
    id integer NOT NULL,
    intel integer NOT NULL
);


ALTER TABLE intel_scans OWNER TO ndawn;

--
-- Name: irc_requests; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE irc_requests (
    id integer NOT NULL,
    channel text NOT NULL,
    message text NOT NULL,
    sent boolean DEFAULT false NOT NULL,
    uid integer NOT NULL
);


ALTER TABLE irc_requests OWNER TO ndawn;

--
-- Name: irc_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE irc_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE irc_requests_id_seq OWNER TO ndawn;

--
-- Name: irc_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE irc_requests_id_seq OWNED BY irc_requests.id;


--
-- Name: last_smokes; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE last_smokes (
    nick citext NOT NULL,
    "time" timestamp with time zone NOT NULL
);


ALTER TABLE last_smokes OWNER TO ndawn;

--
-- Name: misc; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE misc (
    id text NOT NULL,
    value text
);


ALTER TABLE misc OWNER TO ndawn;

--
-- Name: planet_tags; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE planet_tags (
    pid integer NOT NULL,
    tag citext NOT NULL,
    uid integer NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE planet_tags OWNER TO ndawn;

--
-- Name: planets_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE planets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE planets_id_seq OWNER TO ndawn;

--
-- Name: planets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE planets_id_seq OWNED BY planets.pid;


--
-- Name: raid_access; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE raid_access (
    raid integer NOT NULL,
    gid character(1) NOT NULL
);


ALTER TABLE raid_access OWNER TO ndawn;

--
-- Name: raid_claims; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE raid_claims (
    target integer NOT NULL,
    uid integer NOT NULL,
    wave integer NOT NULL,
    joinable boolean DEFAULT false NOT NULL,
    launched boolean DEFAULT false NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
)
WITH (fillfactor='50');


ALTER TABLE raid_claims OWNER TO ndawn;

--
-- Name: raid_targets; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE raid_targets (
    id integer NOT NULL,
    raid integer NOT NULL,
    pid integer NOT NULL,
    comment text,
    modified timestamp with time zone DEFAULT now() NOT NULL
)
WITH (fillfactor='50');


ALTER TABLE raid_targets OWNER TO ndawn;

--
-- Name: raid_targets_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE raid_targets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE raid_targets_id_seq OWNER TO ndawn;

--
-- Name: raid_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE raid_targets_id_seq OWNED BY raid_targets.id;


--
-- Name: raids; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE raids (
    id integer NOT NULL,
    tick integer NOT NULL,
    open boolean DEFAULT false NOT NULL,
    waves integer DEFAULT 3 NOT NULL,
    message text NOT NULL,
    removed boolean DEFAULT false NOT NULL,
    released_coords boolean DEFAULT false NOT NULL,
    ftid integer NOT NULL
);


ALTER TABLE raids OWNER TO ndawn;

--
-- Name: raids_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE raids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE raids_id_seq OWNER TO ndawn;

--
-- Name: raids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE raids_id_seq OWNED BY raids.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE roles (
    role character varying(32) NOT NULL
);


ALTER TABLE roles OWNER TO ndawn;

--
-- Name: scan_requests; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE scan_requests (
    id integer NOT NULL,
    uid integer NOT NULL,
    pid integer NOT NULL,
    type text NOT NULL,
    nick text NOT NULL,
    tick integer DEFAULT tick() NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL,
    sent boolean DEFAULT false NOT NULL
);


ALTER TABLE scan_requests OWNER TO ndawn;

--
-- Name: scan_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE scan_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE scan_requests_id_seq OWNER TO ndawn;

--
-- Name: scan_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE scan_requests_id_seq OWNED BY scan_requests.id;


--
-- Name: scans; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE scans (
    tick integer NOT NULL,
    scan_id text NOT NULL,
    pid integer,
    type text,
    uid integer DEFAULT '-1'::integer NOT NULL,
    groupscan boolean DEFAULT false NOT NULL,
    parsed boolean DEFAULT false NOT NULL,
    id integer NOT NULL
);


ALTER TABLE scans OWNER TO ndawn;

--
-- Name: scans_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE scans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE scans_id_seq OWNER TO ndawn;

--
-- Name: scans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE scans_id_seq OWNED BY scans.id;


--
-- Name: session_log; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE session_log (
    uid integer NOT NULL,
    "time" timestamp with time zone NOT NULL,
    ip inet NOT NULL,
    country character(2) NOT NULL,
    session text NOT NULL,
    remember boolean NOT NULL
);


ALTER TABLE session_log OWNER TO ndawn;

--
-- Name: ship_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE ship_stats_id_seq
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ship_stats_id_seq OWNER TO ndawn;

--
-- Name: ship_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE ship_stats_id_seq OWNED BY ship_stats.id;


--
-- Name: sms; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE sms (
    id integer NOT NULL,
    msgid text,
    uid integer NOT NULL,
    status text DEFAULT 'Waiting'::text NOT NULL,
    number text NOT NULL,
    message character varying(140) NOT NULL,
    cost numeric(4,2) DEFAULT 0 NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE sms OWNER TO ndawn;

--
-- Name: sms_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE sms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sms_id_seq OWNER TO ndawn;

--
-- Name: sms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE sms_id_seq OWNED BY sms.id;


--
-- Name: smslist; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE smslist (
    nick text NOT NULL,
    sms text NOT NULL,
    info text
);


ALTER TABLE smslist OWNER TO ndawn;

--
-- Name: table_updates; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW table_updates AS
 SELECT t.schemaname,
    t.relname,
    c.reloptions,
    t.n_tup_upd,
    t.n_tup_hot_upd,
        CASE
            WHEN (t.n_tup_upd > 0) THEN ((((t.n_tup_hot_upd)::numeric / (t.n_tup_upd)::numeric) * 100.0))::numeric(5,2)
            ELSE NULL::numeric
        END AS hot_ratio
   FROM (pg_stat_all_tables t
     JOIN (pg_class c
     JOIN pg_namespace n ON ((c.relnamespace = n.oid))) ON (((n.nspname = t.schemaname) AND (c.relname = t.relname) AND (t.n_tup_upd > 0))));


ALTER TABLE table_updates OWNER TO ndawn;

--
-- Name: users_uid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE users_uid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_uid_seq OWNER TO ndawn;

--
-- Name: users_uid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE users_uid_seq OWNED BY users.uid;


--
-- Name: wiki_namespace_access; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE wiki_namespace_access (
    namespace text NOT NULL,
    gid character(1) NOT NULL,
    edit boolean DEFAULT false NOT NULL,
    post boolean DEFAULT false NOT NULL,
    moderate boolean DEFAULT false NOT NULL
);


ALTER TABLE wiki_namespace_access OWNER TO ndawn;

--
-- Name: wiki_namespaces; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE wiki_namespaces (
    namespace character varying(16) NOT NULL
);


ALTER TABLE wiki_namespaces OWNER TO ndawn;

--
-- Name: wiki_page_access; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE wiki_page_access (
    wpid integer NOT NULL,
    uid integer NOT NULL,
    edit boolean DEFAULT false NOT NULL,
    moderate boolean DEFAULT false NOT NULL
);


ALTER TABLE wiki_page_access OWNER TO ndawn;

--
-- Name: wiki_page_revisions; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE wiki_page_revisions (
    wpid integer,
    wprev integer NOT NULL,
    parent integer,
    text text NOT NULL,
    comment text NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL,
    uid integer
);


ALTER TABLE wiki_page_revisions OWNER TO ndawn;

--
-- Name: wiki_page_revisions_wprev_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE wiki_page_revisions_wprev_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE wiki_page_revisions_wprev_seq OWNER TO ndawn;

--
-- Name: wiki_page_revisions_wprev_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE wiki_page_revisions_wprev_seq OWNED BY wiki_page_revisions.wprev;


--
-- Name: wiki_pages; Type: TABLE; Schema: public; Owner: ndawn
--

CREATE TABLE wiki_pages (
    wpid integer NOT NULL,
    name character varying(255) NOT NULL,
    namespace text DEFAULT ''::text NOT NULL,
    textsearch tsvector DEFAULT to_tsvector(''::text) NOT NULL,
    wprev integer,
    "time" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE wiki_pages OWNER TO ndawn;

--
-- Name: wiki_pages_wpid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE wiki_pages_wpid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE wiki_pages_wpid_seq OWNER TO ndawn;

--
-- Name: wiki_pages_wpid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE wiki_pages_wpid_seq OWNED BY wiki_pages.wpid;


--
-- Name: aid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY alliances ALTER COLUMN aid SET DEFAULT nextval('alliances_id_seq'::regclass);


--
-- Name: call; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY calls ALTER COLUMN call SET DEFAULT nextval('calls_id_seq'::regclass);


--
-- Name: num; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleet_ships ALTER COLUMN num SET DEFAULT nextval('fleet_ships_num_seq'::regclass);


--
-- Name: fid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleets ALTER COLUMN fid SET DEFAULT nextval('fleets_id_seq'::regclass);


--
-- Name: fbid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_boards ALTER COLUMN fbid SET DEFAULT nextval('forum_boards_fbid_seq'::regclass);


--
-- Name: fcid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_categories ALTER COLUMN fcid SET DEFAULT nextval('forum_categories_fcid_seq'::regclass);


--
-- Name: fpid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_posts ALTER COLUMN fpid SET DEFAULT nextval('forum_posts_fpid_seq'::regclass);


--
-- Name: ftid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_threads ALTER COLUMN ftid SET DEFAULT nextval('forum_threads_ftid_seq'::regclass);


--
-- Name: inc; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY incomings ALTER COLUMN inc SET DEFAULT nextval('incomings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel ALTER COLUMN id SET DEFAULT nextval('intel_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY irc_requests ALTER COLUMN id SET DEFAULT nextval('irc_requests_id_seq'::regclass);


--
-- Name: pid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planets ALTER COLUMN pid SET DEFAULT nextval('planets_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_targets ALTER COLUMN id SET DEFAULT nextval('raid_targets_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raids ALTER COLUMN id SET DEFAULT nextval('raids_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scan_requests ALTER COLUMN id SET DEFAULT nextval('scan_requests_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scans ALTER COLUMN id SET DEFAULT nextval('scans_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY ship_stats ALTER COLUMN id SET DEFAULT nextval('ship_stats_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY sms ALTER COLUMN id SET DEFAULT nextval('sms_id_seq'::regclass);


--
-- Name: uid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY users ALTER COLUMN uid SET DEFAULT nextval('users_uid_seq'::regclass);


--
-- Name: wprev; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_page_revisions ALTER COLUMN wprev SET DEFAULT nextval('wiki_page_revisions_wprev_seq'::regclass);


--
-- Name: wpid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_pages ALTER COLUMN wpid SET DEFAULT nextval('wiki_pages_wpid_seq'::regclass);


--
-- Name: accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY users
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (uid);


--
-- Name: alliance_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY alliance_stats
    ADD CONSTRAINT alliance_stats_pkey PRIMARY KEY (aid, tick);


--
-- Name: alliances_name_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY alliances
    ADD CONSTRAINT alliances_name_key UNIQUE (alliance);


--
-- Name: alliances_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY alliances
    ADD CONSTRAINT alliances_pkey PRIMARY KEY (aid);


--
-- Name: available_planet_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY available_planet_tags
    ADD CONSTRAINT available_planet_tags_pkey PRIMARY KEY (tag);


--
-- Name: call_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY call_statuses
    ADD CONSTRAINT call_statuses_pkey PRIMARY KEY (status);


--
-- Name: calls_member_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY calls
    ADD CONSTRAINT calls_member_key UNIQUE (uid, landing_tick);


--
-- Name: calls_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY calls
    ADD CONSTRAINT calls_pkey PRIMARY KEY (call);


--
-- Name: channel_flags_name_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY channel_flags
    ADD CONSTRAINT channel_flags_name_key UNIQUE (name);


--
-- Name: channel_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY channel_flags
    ADD CONSTRAINT channel_flags_pkey PRIMARY KEY (flag);


--
-- Name: channel_group_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY channel_group_flags
    ADD CONSTRAINT channel_group_flags_pkey PRIMARY KEY (channel, gid, flag);


--
-- Name: channels_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY channels
    ADD CONSTRAINT channels_pkey PRIMARY KEY (channel);


--
-- Name: clickatell_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY clickatell
    ADD CONSTRAINT clickatell_pkey PRIMARY KEY (api_id, username);


--
-- Name: covop_attacks_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY covop_attacks
    ADD CONSTRAINT covop_attacks_pkey PRIMARY KEY (pid, tick, uid);


--
-- Name: defense_missions_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY defense_missions
    ADD CONSTRAINT defense_missions_pkey PRIMARY KEY (fleet);


--
-- Name: development_scans_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY development_scans
    ADD CONSTRAINT development_scans_pkey PRIMARY KEY (id);


--
-- Name: dumps_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY dumps
    ADD CONSTRAINT dumps_pkey PRIMARY KEY (tick, type, modified);


--
-- Name: email_change_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY email_change
    ADD CONSTRAINT email_change_pkey PRIMARY KEY (id);


--
-- Name: fleet_scans_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleet_scans
    ADD CONSTRAINT fleet_scans_pkey PRIMARY KEY (fid);


--
-- Name: fleet_ships_num_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleet_ships
    ADD CONSTRAINT fleet_ships_num_key UNIQUE (num);


--
-- Name: fleet_ships_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleet_ships
    ADD CONSTRAINT fleet_ships_pkey PRIMARY KEY (fid, ship);


--
-- Name: fleets_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleets
    ADD CONSTRAINT fleets_pkey PRIMARY KEY (fid);


--
-- Name: forum_access_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_access
    ADD CONSTRAINT forum_access_pkey PRIMARY KEY (fbid, gid);


--
-- Name: forum_boards_fcid_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_boards
    ADD CONSTRAINT forum_boards_fcid_key UNIQUE (fcid, board);


--
-- Name: forum_boards_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_boards
    ADD CONSTRAINT forum_boards_pkey PRIMARY KEY (fbid);


--
-- Name: forum_categories_category_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_categories
    ADD CONSTRAINT forum_categories_category_key UNIQUE (category);


--
-- Name: forum_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_categories
    ADD CONSTRAINT forum_categories_pkey PRIMARY KEY (fcid);


--
-- Name: forum_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_pkey PRIMARY KEY (fpid);


--
-- Name: forum_priv_access_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_priv_access
    ADD CONSTRAINT forum_priv_access_pkey PRIMARY KEY (uid, ftid);


--
-- Name: forum_thread_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_thread_visits
    ADD CONSTRAINT forum_thread_visits_pkey PRIMARY KEY (uid, ftid);


--
-- Name: forum_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_threads
    ADD CONSTRAINT forum_threads_pkey PRIMARY KEY (ftid);


--
-- Name: full_fleets_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY full_fleets
    ADD CONSTRAINT full_fleets_pkey PRIMARY KEY (fid);


--
-- Name: galaxies_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY galaxies
    ADD CONSTRAINT galaxies_pkey PRIMARY KEY (tick, x, y);


--
-- Name: group_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY group_roles
    ADD CONSTRAINT group_roles_pkey PRIMARY KEY (gid, role);


--
-- Name: groupmembers_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY groupmembers
    ADD CONSTRAINT groupmembers_pkey PRIMARY KEY (gid, uid);


--
-- Name: groups_groupname_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_groupname_key UNIQUE (groupname);


--
-- Name: groups_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (gid);


--
-- Name: incomings_call_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY incomings
    ADD CONSTRAINT incomings_call_key UNIQUE (call, pid, fleet);


--
-- Name: incomings_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY incomings
    ADD CONSTRAINT incomings_pkey PRIMARY KEY (inc);


--
-- Name: intel_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel
    ADD CONSTRAINT intel_pkey PRIMARY KEY (id);


--
-- Name: intel_scans_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel_scans
    ADD CONSTRAINT intel_scans_pkey PRIMARY KEY (id, intel);


--
-- Name: irc_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY irc_requests
    ADD CONSTRAINT irc_requests_pkey PRIMARY KEY (id);


--
-- Name: last_smokes_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY last_smokes
    ADD CONSTRAINT last_smokes_pkey PRIMARY KEY (nick);


--
-- Name: launch_confirmations_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY launch_confirmations
    ADD CONSTRAINT launch_confirmations_pkey PRIMARY KEY (fid);


--
-- Name: misc_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY misc
    ADD CONSTRAINT misc_pkey PRIMARY KEY (id);


--
-- Name: planet_scans_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_scans
    ADD CONSTRAINT planet_scans_pkey PRIMARY KEY (id);


--
-- Name: planet_stats_id_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_stats
    ADD CONSTRAINT planet_stats_id_key UNIQUE (pid, tick);


--
-- Name: planet_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_stats
    ADD CONSTRAINT planet_stats_pkey PRIMARY KEY (tick, x, y, z);


--
-- Name: planet_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_tags
    ADD CONSTRAINT planet_tags_pkey PRIMARY KEY (pid, uid, tag);


--
-- Name: planets_ftid_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planets
    ADD CONSTRAINT planets_ftid_key UNIQUE (ftid);


--
-- Name: planets_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planets
    ADD CONSTRAINT planets_pkey PRIMARY KEY (pid);


--
-- Name: raid_access_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_access
    ADD CONSTRAINT raid_access_pkey PRIMARY KEY (raid, gid);


--
-- Name: raid_claims_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_claims
    ADD CONSTRAINT raid_claims_pkey PRIMARY KEY (target, uid, wave);


--
-- Name: raid_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_targets
    ADD CONSTRAINT raid_targets_pkey PRIMARY KEY (id);


--
-- Name: raid_targets_raid_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_targets
    ADD CONSTRAINT raid_targets_raid_key UNIQUE (raid, pid);


--
-- Name: raids_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raids
    ADD CONSTRAINT raids_pkey PRIMARY KEY (id);


--
-- Name: roles_role_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY roles
    ADD CONSTRAINT roles_role_key UNIQUE (role);


--
-- Name: scan_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scan_requests
    ADD CONSTRAINT scan_requests_pkey PRIMARY KEY (id);


--
-- Name: scan_requests_tick_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scan_requests
    ADD CONSTRAINT scan_requests_tick_key UNIQUE (tick, pid, type, uid);


--
-- Name: scans_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scans
    ADD CONSTRAINT scans_pkey PRIMARY KEY (id);


--
-- Name: scans_scan_id_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scans
    ADD CONSTRAINT scans_scan_id_key UNIQUE (scan_id, tick, groupscan);


--
-- Name: session_log_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY session_log
    ADD CONSTRAINT session_log_pkey PRIMARY KEY (uid, "time", ip);


--
-- Name: ship_stats_id_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY ship_stats
    ADD CONSTRAINT ship_stats_id_key UNIQUE (id);

ALTER TABLE ship_stats CLUSTER ON ship_stats_id_key;


--
-- Name: ship_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY ship_stats
    ADD CONSTRAINT ship_stats_pkey PRIMARY KEY (ship);


--
-- Name: sms_msgid_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY sms
    ADD CONSTRAINT sms_msgid_key UNIQUE (msgid);


--
-- Name: sms_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY sms
    ADD CONSTRAINT sms_pkey PRIMARY KEY (id);


--
-- Name: smslist_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY smslist
    ADD CONSTRAINT smslist_pkey PRIMARY KEY (sms);


--
-- Name: ticks_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY ticks
    ADD CONSTRAINT ticks_pkey PRIMARY KEY (t);


--
-- Name: users_hostmask_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_hostmask_key UNIQUE (hostmask);


--
-- Name: users_planet_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_planet_key UNIQUE (pid);


--
-- Name: users_pnick_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pnick_key UNIQUE (pnick);


--
-- Name: users_tfid_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_tfid_key UNIQUE (ftid);


--
-- Name: users_username_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: wiki_namespace_access_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_namespace_access
    ADD CONSTRAINT wiki_namespace_access_pkey PRIMARY KEY (gid, namespace);


--
-- Name: wiki_namespaces_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_namespaces
    ADD CONSTRAINT wiki_namespaces_pkey PRIMARY KEY (namespace);


--
-- Name: wiki_page_access_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_page_access
    ADD CONSTRAINT wiki_page_access_pkey PRIMARY KEY (uid, wpid);


--
-- Name: wiki_page_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_page_revisions
    ADD CONSTRAINT wiki_page_revisions_pkey PRIMARY KEY (wprev);


--
-- Name: wiki_pages_namespace_key; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_pages
    ADD CONSTRAINT wiki_pages_namespace_key UNIQUE (namespace, name);


--
-- Name: wiki_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_pages
    ADD CONSTRAINT wiki_pages_pkey PRIMARY KEY (wpid);


--
-- Name: development_scans_planet_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX development_scans_planet_index ON development_scans USING btree (pid, tick);


--
-- Name: fleets_sender_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX fleets_sender_index ON fleets USING btree (pid);


--
-- Name: forum_posts_ftid_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX forum_posts_ftid_index ON forum_posts USING btree (ftid);


--
-- Name: forum_posts_textsearch_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX forum_posts_textsearch_index ON forum_posts USING gin (textsearch);


CREATE INDEX forum_threads_mtime_index ON forum_threads USING btree (mtime);

--
-- Name: groupmembers_uid_key; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX groupmembers_uid_key ON groupmembers USING btree (uid);


--
-- Name: intel_tick_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX intel_tick_index ON intel USING btree (tick);


--
-- Name: planet_scans_planet_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX planet_scans_planet_index ON planet_scans USING btree (pid, tick);


--
-- Name: planet_stats_scorerank_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX planet_stats_scorerank_index ON planet_stats USING btree (tick, scorerank);


--
-- Name: planet_stats_sizerank_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX planet_stats_sizerank_index ON planet_stats USING btree (tick, sizerank);


--
-- Name: planet_stats_valuerank_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX planet_stats_valuerank_index ON planet_stats USING btree (tick, valuerank);


--
-- Name: planet_stats_xprank_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX planet_stats_xprank_index ON planet_stats USING btree (tick, xprank);


--
-- Name: planets_alliance_id_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX planets_alliance_id_index ON planets USING btree (alliance);


--
-- Name: scan_requests_time_not_sent_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX scan_requests_time_not_sent_index ON scan_requests USING btree ("time") WHERE (NOT sent);


--
-- Name: scans_not_parsed_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX scans_not_parsed_index ON scans USING btree (groupscan) WHERE (NOT parsed);


--
-- Name: scans_planet_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX scans_planet_index ON scans USING btree (pid, type, tick);


--
-- Name: sms_status_msgid_idx; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX sms_status_msgid_idx ON sms USING btree (status) WHERE (msgid IS NULL);


--
-- Name: smslist_nick_key; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE UNIQUE INDEX smslist_nick_key ON smslist USING btree (lower(nick));


--
-- Name: users_birthday_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX users_birthday_index ON users USING btree (mmdd(birthday)) WHERE (birthday IS NOT NULL);


--
-- Name: wiki_pages_textsearch_index; Type: INDEX; Schema: public; Owner: ndawn
--

CREATE INDEX wiki_pages_textsearch_index ON wiki_pages USING gin (textsearch);


--
-- Name: add_call; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER add_call BEFORE INSERT ON calls FOR EACH ROW EXECUTE PROCEDURE add_call();


--
-- Name: add_raid; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER add_raid BEFORE INSERT ON raids FOR EACH ROW EXECUTE PROCEDURE add_raid();


--
-- Name: add_remove_member; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER add_remove_member AFTER INSERT OR DELETE ON groupmembers FOR EACH ROW EXECUTE PROCEDURE change_member();


--
-- Name: add_user; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER add_user BEFORE INSERT ON users FOR EACH ROW EXECUTE PROCEDURE add_user();


--
-- Name: update_forum_post; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER update_forum_post BEFORE INSERT OR UPDATE ON forum_posts FOR EACH ROW EXECUTE PROCEDURE update_forum_post();


--
-- Name: update_forum_thread_posts; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER update_forum_thread_posts AFTER INSERT OR DELETE OR UPDATE ON forum_posts FOR EACH ROW EXECUTE PROCEDURE update_forum_thread_posts();


--
-- Name: update_planet; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER update_planet AFTER UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE update_user_planet();

CREATE TRIGGER update_user_planet_check BEFORE UPDATE ON users FOR EACH ROW WHEN (NEW.pid IS NOT NULL AND OLD.pid IS NULL) EXECUTE PROCEDURE update_user_planet_check();


--
-- Name: update_wiki_page; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER update_wiki_page BEFORE UPDATE ON wiki_pages FOR EACH ROW EXECUTE PROCEDURE update_wiki_page();


--
-- Name: updated_claim; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER updated_claim AFTER INSERT OR DELETE OR UPDATE ON raid_claims FOR EACH ROW EXECUTE PROCEDURE updated_claim();


--
-- Name: alliance_stats_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY alliance_stats
    ADD CONSTRAINT alliance_stats_id_fkey FOREIGN KEY (aid) REFERENCES alliances(aid);


--
-- Name: calls_dc_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY calls
    ADD CONSTRAINT calls_dc_fkey FOREIGN KEY (dc) REFERENCES users(uid) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: calls_ftid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY calls
    ADD CONSTRAINT calls_ftid_fkey FOREIGN KEY (ftid) REFERENCES forum_threads(ftid);


--
-- Name: calls_member_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY calls
    ADD CONSTRAINT calls_member_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: calls_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY calls
    ADD CONSTRAINT calls_status_fkey FOREIGN KEY (status) REFERENCES call_statuses(status);


--
-- Name: channel_group_flags_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY channel_group_flags
    ADD CONSTRAINT channel_group_flags_channel_fkey FOREIGN KEY (channel) REFERENCES channels(channel) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: channel_group_flags_flag_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY channel_group_flags
    ADD CONSTRAINT channel_group_flags_flag_fkey FOREIGN KEY (flag) REFERENCES channel_flags(flag) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: channel_group_flags_gid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY channel_group_flags
    ADD CONSTRAINT channel_group_flags_gid_fkey FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: covop_attacks_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY covop_attacks
    ADD CONSTRAINT covop_attacks_id_fkey FOREIGN KEY (pid) REFERENCES planets(pid);


--
-- Name: covop_attacks_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY covop_attacks
    ADD CONSTRAINT covop_attacks_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: defense_missions_call_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY defense_missions
    ADD CONSTRAINT defense_missions_call_fkey FOREIGN KEY (call) REFERENCES calls(call) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: defense_missions_fleet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY defense_missions
    ADD CONSTRAINT defense_missions_fleet_fkey FOREIGN KEY (fleet) REFERENCES fleets(fid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: development_scans_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY development_scans
    ADD CONSTRAINT development_scans_id_fkey FOREIGN KEY (id) REFERENCES scans(id);


--
-- Name: development_scans_planet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY development_scans
    ADD CONSTRAINT development_scans_planet_fkey FOREIGN KEY (pid) REFERENCES planets(pid);


--
-- Name: email_change_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY email_change
    ADD CONSTRAINT email_change_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: fleet_scans_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleet_scans
    ADD CONSTRAINT fleet_scans_id_fkey FOREIGN KEY (fid) REFERENCES fleets(fid) ON DELETE CASCADE;


--
-- Name: fleet_scans_scan_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleet_scans
    ADD CONSTRAINT fleet_scans_scan_fkey FOREIGN KEY (id) REFERENCES scans(id);


--
-- Name: fleet_ships_fleet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleet_ships
    ADD CONSTRAINT fleet_ships_fleet_fkey FOREIGN KEY (fid) REFERENCES fleets(fid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: fleet_ships_ship_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleet_ships
    ADD CONSTRAINT fleet_ships_ship_fkey FOREIGN KEY (ship) REFERENCES ship_stats(ship);


--
-- Name: fleets_sender_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleets
    ADD CONSTRAINT fleets_sender_fkey FOREIGN KEY (pid) REFERENCES planets(pid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_access_fbid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_access
    ADD CONSTRAINT forum_access_fbid_fkey FOREIGN KEY (fbid) REFERENCES forum_boards(fbid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_access_gid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_access
    ADD CONSTRAINT forum_access_gid_fkey FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_boards_fcid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_boards
    ADD CONSTRAINT forum_boards_fcid_fkey FOREIGN KEY (fcid) REFERENCES forum_categories(fcid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_posts_ftid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_ftid_fkey FOREIGN KEY (ftid) REFERENCES forum_threads(ftid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_posts_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_priv_access_ftid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_priv_access
    ADD CONSTRAINT forum_priv_access_ftid_fkey FOREIGN KEY (ftid) REFERENCES forum_threads(ftid) ON DELETE CASCADE;


--
-- Name: forum_priv_access_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_priv_access
    ADD CONSTRAINT forum_priv_access_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: forum_thread_visits_ftid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_thread_visits
    ADD CONSTRAINT forum_thread_visits_ftid_fkey FOREIGN KEY (ftid) REFERENCES forum_threads(ftid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_thread_visits_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_thread_visits
    ADD CONSTRAINT forum_thread_visits_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_threads_fbid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_threads
    ADD CONSTRAINT forum_threads_fbid_fkey FOREIGN KEY (fbid) REFERENCES forum_boards(fbid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_threads_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_threads
    ADD CONSTRAINT forum_threads_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: full_fleets_fid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY full_fleets
    ADD CONSTRAINT full_fleets_fid_fkey FOREIGN KEY (fid) REFERENCES fleets(fid);


--
-- Name: full_fleets_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY full_fleets
    ADD CONSTRAINT full_fleets_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: group_roles_gid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY group_roles
    ADD CONSTRAINT group_roles_gid_fkey FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: group_roles_role_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY group_roles
    ADD CONSTRAINT group_roles_role_fkey FOREIGN KEY (role) REFERENCES roles(role);


--
-- Name: groupmembers_gid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY groupmembers
    ADD CONSTRAINT groupmembers_gid_fkey FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: groupmembers_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY groupmembers
    ADD CONSTRAINT groupmembers_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: incomings_call_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY incomings
    ADD CONSTRAINT incomings_call_fkey FOREIGN KEY (call) REFERENCES calls(call) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: incomings_sender_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY incomings
    ADD CONSTRAINT incomings_sender_fkey FOREIGN KEY (pid) REFERENCES planets(pid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: intel_scans_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel_scans
    ADD CONSTRAINT intel_scans_id_fkey FOREIGN KEY (id) REFERENCES scans(id);


--
-- Name: intel_scans_intel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel_scans
    ADD CONSTRAINT intel_scans_intel_fkey FOREIGN KEY (intel) REFERENCES intel(id) ON DELETE CASCADE;


--
-- Name: intel_sender_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel
    ADD CONSTRAINT intel_sender_fkey FOREIGN KEY (sender) REFERENCES planets(pid);


--
-- Name: intel_target_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel
    ADD CONSTRAINT intel_target_fkey FOREIGN KEY (target) REFERENCES planets(pid);


--
-- Name: intel_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel
    ADD CONSTRAINT intel_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: irc_requests_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY irc_requests
    ADD CONSTRAINT irc_requests_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: launch_confirmations_fid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY launch_confirmations
    ADD CONSTRAINT launch_confirmations_fid_fkey FOREIGN KEY (fid) REFERENCES fleets(fid);


--
-- Name: launch_confirmations_target_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY launch_confirmations
    ADD CONSTRAINT launch_confirmations_target_fkey FOREIGN KEY (pid) REFERENCES planets(pid);


--
-- Name: launch_confirmations_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY launch_confirmations
    ADD CONSTRAINT launch_confirmations_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: planet_scans_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_scans
    ADD CONSTRAINT planet_scans_id_fkey FOREIGN KEY (id) REFERENCES scans(id);


--
-- Name: planet_scans_planet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_scans
    ADD CONSTRAINT planet_scans_planet_fkey FOREIGN KEY (pid) REFERENCES planets(pid);


--
-- Name: planet_stats_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_stats
    ADD CONSTRAINT planet_stats_id_fkey FOREIGN KEY (pid) REFERENCES planets(pid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: planet_tags_pid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_tags
    ADD CONSTRAINT planet_tags_pid_fkey FOREIGN KEY (pid) REFERENCES planets(pid);


--
-- Name: planet_tags_tag_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_tags
    ADD CONSTRAINT planet_tags_tag_fkey FOREIGN KEY (tag) REFERENCES available_planet_tags(tag);


--
-- Name: planet_tags_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_tags
    ADD CONSTRAINT planet_tags_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: planets_alliance_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planets
    ADD CONSTRAINT planets_alliance_fkey FOREIGN KEY (alliance) REFERENCES alliances(alliance) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: planets_ftid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planets
    ADD CONSTRAINT planets_ftid_fkey FOREIGN KEY (ftid) REFERENCES forum_threads(ftid) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: raid_access_gid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_access
    ADD CONSTRAINT raid_access_gid_fkey FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: raid_access_raid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_access
    ADD CONSTRAINT raid_access_raid_fkey FOREIGN KEY (raid) REFERENCES raids(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: raid_claims_target_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_claims
    ADD CONSTRAINT raid_claims_target_fkey FOREIGN KEY (target) REFERENCES raid_targets(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: raid_claims_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_claims
    ADD CONSTRAINT raid_claims_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: raid_targets_planet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_targets
    ADD CONSTRAINT raid_targets_planet_fkey FOREIGN KEY (pid) REFERENCES planets(pid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: raid_targets_raid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_targets
    ADD CONSTRAINT raid_targets_raid_fkey FOREIGN KEY (raid) REFERENCES raids(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: scan_requests_planet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scan_requests
    ADD CONSTRAINT scan_requests_planet_fkey FOREIGN KEY (pid) REFERENCES planets(pid);


--
-- Name: scan_requests_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scan_requests
    ADD CONSTRAINT scan_requests_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: scans_planet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scans
    ADD CONSTRAINT scans_planet_fkey FOREIGN KEY (pid) REFERENCES planets(pid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: scans_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scans
    ADD CONSTRAINT scans_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: session_log_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY session_log
    ADD CONSTRAINT session_log_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: sms_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY sms
    ADD CONSTRAINT sms_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: users_planet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_planet_fkey FOREIGN KEY (pid) REFERENCES planets(pid) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: users_tfid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_tfid_fkey FOREIGN KEY (ftid) REFERENCES forum_threads(ftid) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: wiki_namespace_access_gid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_namespace_access
    ADD CONSTRAINT wiki_namespace_access_gid_fkey FOREIGN KEY (gid) REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: wiki_namespace_access_namespace_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_namespace_access
    ADD CONSTRAINT wiki_namespace_access_namespace_fkey FOREIGN KEY (namespace) REFERENCES wiki_namespaces(namespace);


--
-- Name: wiki_page_access_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_page_access
    ADD CONSTRAINT wiki_page_access_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: wiki_page_access_wpid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_page_access
    ADD CONSTRAINT wiki_page_access_wpid_fkey FOREIGN KEY (wpid) REFERENCES wiki_pages(wpid);


--
-- Name: wiki_page_revisions_parent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_page_revisions
    ADD CONSTRAINT wiki_page_revisions_parent_fkey FOREIGN KEY (parent) REFERENCES wiki_page_revisions(wprev);


--
-- Name: wiki_page_revisions_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_page_revisions
    ADD CONSTRAINT wiki_page_revisions_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid);


--
-- Name: wiki_page_revisions_wpid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_page_revisions
    ADD CONSTRAINT wiki_page_revisions_wpid_fkey FOREIGN KEY (wpid) REFERENCES wiki_pages(wpid);


--
-- Name: wiki_pages_namespace_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_pages
    ADD CONSTRAINT wiki_pages_namespace_fkey FOREIGN KEY (namespace) REFERENCES wiki_namespaces(namespace);


--
-- Name: wiki_pages_wprev_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY wiki_pages
    ADD CONSTRAINT wiki_pages_wprev_fkey FOREIGN KEY (wprev) REFERENCES wiki_page_revisions(wprev);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: coords(integer, integer, integer); Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON FUNCTION coords(x integer, y integer, z integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION coords(x integer, y integer, z integer) FROM ndawn;
GRANT ALL ON FUNCTION coords(x integer, y integer, z integer) TO ndawn;
GRANT ALL ON FUNCTION coords(x integer, y integer, z integer) TO PUBLIC;
GRANT ALL ON FUNCTION coords(x integer, y integer, z integer) TO intel;


--
-- Name: endtick(); Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON FUNCTION endtick() FROM PUBLIC;
REVOKE ALL ON FUNCTION endtick() FROM ndawn;
GRANT ALL ON FUNCTION endtick() TO ndawn;
GRANT ALL ON FUNCTION endtick() TO PUBLIC;
GRANT ALL ON FUNCTION endtick() TO intel;


--
-- Name: planetcoords(integer, integer); Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON FUNCTION planetcoords(id integer, tick integer, OUT x integer, OUT y integer, OUT z integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION planetcoords(id integer, tick integer, OUT x integer, OUT y integer, OUT z integer) FROM ndawn;
GRANT ALL ON FUNCTION planetcoords(id integer, tick integer, OUT x integer, OUT y integer, OUT z integer) TO ndawn;
GRANT ALL ON FUNCTION planetcoords(id integer, tick integer, OUT x integer, OUT y integer, OUT z integer) TO PUBLIC;
GRANT ALL ON FUNCTION planetcoords(id integer, tick integer, OUT x integer, OUT y integer, OUT z integer) TO intel;


--
-- Name: planetid(integer, integer, integer, integer); Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON FUNCTION planetid(x integer, y integer, z integer, tick integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION planetid(x integer, y integer, z integer, tick integer) FROM ndawn;
GRANT ALL ON FUNCTION planetid(x integer, y integer, z integer, tick integer) TO ndawn;
GRANT ALL ON FUNCTION planetid(x integer, y integer, z integer, tick integer) TO PUBLIC;
GRANT ALL ON FUNCTION planetid(x integer, y integer, z integer, tick integer) TO intel;


--
-- Name: tick(); Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON FUNCTION tick() FROM PUBLIC;
REVOKE ALL ON FUNCTION tick() FROM ndawn;
GRANT ALL ON FUNCTION tick() TO ndawn;
GRANT ALL ON FUNCTION tick() TO PUBLIC;
GRANT ALL ON FUNCTION tick() TO intel;


--
-- Name: alliance_stats; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE alliance_stats FROM PUBLIC;
REVOKE ALL ON TABLE alliance_stats FROM ndawn;
GRANT ALL ON TABLE alliance_stats TO ndawn;
GRANT SELECT ON TABLE alliance_stats TO intel;


--
-- Name: alliances; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE alliances FROM PUBLIC;
REVOKE ALL ON TABLE alliances FROM ndawn;
GRANT ALL ON TABLE alliances TO ndawn;
GRANT SELECT ON TABLE alliances TO intel;


--
-- Name: development_scans; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE development_scans FROM PUBLIC;
REVOKE ALL ON TABLE development_scans FROM ndawn;
GRANT ALL ON TABLE development_scans TO ndawn;
GRANT SELECT ON TABLE development_scans TO intel;


--
-- Name: current_development_scans; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE current_development_scans FROM PUBLIC;
REVOKE ALL ON TABLE current_development_scans FROM ndawn;
GRANT ALL ON TABLE current_development_scans TO ndawn;
GRANT SELECT ON TABLE current_development_scans TO intel;


--
-- Name: planet_scans; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE planet_scans FROM PUBLIC;
REVOKE ALL ON TABLE planet_scans FROM ndawn;
GRANT ALL ON TABLE planet_scans TO ndawn;
GRANT SELECT ON TABLE planet_scans TO intel;


--
-- Name: current_planet_scans; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE current_planet_scans FROM PUBLIC;
REVOKE ALL ON TABLE current_planet_scans FROM ndawn;
GRANT ALL ON TABLE current_planet_scans TO ndawn;
GRANT SELECT ON TABLE current_planet_scans TO intel;


--
-- Name: planet_stats; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE planet_stats FROM PUBLIC;
REVOKE ALL ON TABLE planet_stats FROM ndawn;
GRANT ALL ON TABLE planet_stats TO ndawn;
GRANT SELECT ON TABLE planet_stats TO intel;


--
-- Name: planets; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE planets FROM PUBLIC;
REVOKE ALL ON TABLE planets FROM ndawn;
GRANT ALL ON TABLE planets TO ndawn;
GRANT SELECT ON TABLE planets TO intel;


--
-- Name: current_planet_stats; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE current_planet_stats FROM PUBLIC;
REVOKE ALL ON TABLE current_planet_stats FROM ndawn;
GRANT ALL ON TABLE current_planet_stats TO ndawn;
GRANT SELECT ON TABLE current_planet_stats TO intel;


--
-- Name: alliance_resources; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE alliance_resources FROM PUBLIC;
REVOKE ALL ON TABLE alliance_resources FROM ndawn;
GRANT ALL ON TABLE alliance_resources TO ndawn;
GRANT SELECT ON TABLE alliance_resources TO intel;


--
-- Name: available_planet_tags; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE available_planet_tags FROM PUBLIC;
REVOKE ALL ON TABLE available_planet_tags FROM ndawn;
GRANT ALL ON TABLE available_planet_tags TO ndawn;
GRANT SELECT ON TABLE available_planet_tags TO intel;


--
-- Name: fleet_ships; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE fleet_ships FROM PUBLIC;
REVOKE ALL ON TABLE fleet_ships FROM ndawn;
GRANT ALL ON TABLE fleet_ships TO ndawn;
GRANT SELECT ON TABLE fleet_ships TO intel;


--
-- Name: fleets; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE fleets FROM PUBLIC;
REVOKE ALL ON TABLE fleets FROM ndawn;
GRANT ALL ON TABLE fleets TO ndawn;
GRANT SELECT ON TABLE fleets TO intel;


--
-- Name: launch_confirmations; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE launch_confirmations FROM PUBLIC;
REVOKE ALL ON TABLE launch_confirmations FROM ndawn;
GRANT ALL ON TABLE launch_confirmations TO ndawn;
GRANT SELECT ON TABLE launch_confirmations TO intel;


--
-- Name: current_planet_stats_full; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE current_planet_stats_full FROM PUBLIC;
REVOKE ALL ON TABLE current_planet_stats_full FROM ndawn;
GRANT ALL ON TABLE current_planet_stats_full TO ndawn;
GRANT SELECT ON TABLE current_planet_stats_full TO intel;


--
-- Name: fleet_scans; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE fleet_scans FROM PUBLIC;
REVOKE ALL ON TABLE fleet_scans FROM ndawn;
GRANT ALL ON TABLE fleet_scans TO ndawn;
GRANT SELECT ON TABLE fleet_scans TO intel;


--
-- Name: intel; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE intel FROM PUBLIC;
REVOKE ALL ON TABLE intel FROM ndawn;
GRANT ALL ON TABLE intel TO ndawn;
GRANT SELECT ON TABLE intel TO intel;


--
-- Name: full_intel; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE full_intel FROM PUBLIC;
REVOKE ALL ON TABLE full_intel FROM ndawn;
GRANT ALL ON TABLE full_intel TO ndawn;
GRANT SELECT ON TABLE full_intel TO intel;


--
-- Name: galaxies; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE galaxies FROM PUBLIC;
REVOKE ALL ON TABLE galaxies FROM ndawn;
GRANT ALL ON TABLE galaxies TO ndawn;
GRANT SELECT ON TABLE galaxies TO intel;


--
-- Name: intel_scans; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE intel_scans FROM PUBLIC;
REVOKE ALL ON TABLE intel_scans FROM ndawn;
GRANT ALL ON TABLE intel_scans TO ndawn;
GRANT SELECT ON TABLE intel_scans TO intel;


--
-- Name: planet_tags; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE planet_tags FROM PUBLIC;
REVOKE ALL ON TABLE planet_tags FROM ndawn;
GRANT ALL ON TABLE planet_tags TO ndawn;
GRANT SELECT ON TABLE planet_tags TO intel;


--
-- Name: scans; Type: ACL; Schema: public; Owner: ndawn
--

REVOKE ALL ON TABLE scans FROM PUBLIC;
REVOKE ALL ON TABLE scans FROM ndawn;
GRANT ALL ON TABLE scans TO ndawn;
GRANT SELECT ON TABLE scans TO intel;


--
-- PostgreSQL database dump complete
--

