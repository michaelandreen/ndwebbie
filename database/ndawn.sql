--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


--
-- Name: plperl; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: postgres
--

CREATE PROCEDURAL LANGUAGE plperl;


SET search_path = public, pg_catalog;

--
-- Name: add_intel(integer, integer, integer, integer, integer, integer, integer, integer, integer, character varying, integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION add_intel(tick integer, eta integer, x1 integer, y1 integer, z1 integer, x2 integer, y2 integer, z2 integer, amount integer, mission character varying, uid integer) RETURNS boolean
    AS $_$my ($tick, $eta, $x1, $y1, $z1, $x2, $y2, $z2, $amount, $mission, $uid) = @_;
$ingal = false;
if ($x1 == $x2 && $y1 == $y2) {
$ingal = true;
}
if ($tick < 0){
  $rv = spi_exec_query("SELECT tick FROM planet_stats ORDER BY tick DESC LIMIT 1;");
  $tick = $rv->{rows}[0]->{tick};
}
$rv = spi_exec_query("SELECT id,tick FROM planet_stats WHERE x = $x1 AND y = $y1 AND z = $z1 AND (tick = $tick OR tick = (SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC;");
unless ($rv->{processed} >= 1){
return false;
} 
$id1 = $rv->{rows}[0]->{id};
$rv = spi_exec_query("SELECT id,tick FROM planet_stats WHERE x = $x2 AND y = $y2 AND z = $z2 AND (tick = $tick OR tick = (SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC;");
unless ($rv->{processed} >= 1){
return false;
} 
$id2 = $rv->{rows}[0]->{id};
$tick += $eta;
spi_exec_query("INSERT INTO intel (target,sender,tick,eta,mission,uid,ingal, amount) VALUES ($id1, $id2, $tick,$eta, '$mission', $uid, $ingal, $amount)");
return true;$_$
    LANGUAGE plperl;


ALTER FUNCTION public.add_intel(tick integer, eta integer, x1 integer, y1 integer, z1 integer, x2 integer, y2 integer, z2 integer, amount integer, mission character varying, uid integer) OWNER TO ndawn;

--
-- Name: add_intel2(integer, integer, integer, integer, integer, integer, integer, integer, character varying, character varying); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION add_intel2(integer, integer, integer, integer, integer, integer, integer, integer, character varying, character varying) RETURNS boolean
    AS $_$my ($tick, $x1, $y1, $z1, $x2, $y2, $z2, $amount, $mission, $user) = @_;
$ingal = false;
if ($x1 == $x2 && $y1 == $y2) {
$ingal = true;
}
if ($tick < 0){
  $rv = spi_exec_query("SELECT tick FROM planet_stats ORDER BY tick DESC LIMIT 1;");
  $tick = $rv->{rows}[0]->{tick};
}
$rv = spi_exec_query("SELECT id FROM planet_stats WHERE x = $x1 AND y = $y1 AND z = $z1 AND tick = $tick;");
unless ($rv->{processed} == 1){
return false;
} 
$id1 = $rv->{rows}[0]->{id};
$rv = spi_exec_query("SELECT id FROM planet_stats WHERE x = $x2 AND y = $y2 AND z = $z2 AND tick = $tick;");
unless ($rv->{processed} == 1){
return false;
} 
$id2 = $rv->{rows}[0]->{id};
spi_exec_query("INSERT INTO intel (target,sender,tick,mission,\"user\",ingal, amount) VALUES ($id1, $id2, $tick, '$mission', '$user', $ingal, $amount)");
return true;$_$
    LANGUAGE plperl;


ALTER FUNCTION public.add_intel2(integer, integer, integer, integer, integer, integer, integer, integer, character varying, character varying) OWNER TO ndawn;

--
-- Name: add_intel2(integer, integer, integer, integer, integer, integer, integer, integer, integer, character varying, character varying); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION add_intel2(integer, integer, integer, integer, integer, integer, integer, integer, integer, character varying, character varying) RETURNS boolean
    AS $_$my ($tick, $eta, $x1, $y1, $z1, $x2, $y2, $z2, $amount, $mission, $uid) = @_;
unless ($uid = /^(-?\d+)$/){
	$rv = spi_exec_query("SELECT id FROM users WHERE username = '$uid';");
	$uid = $rv->{rows}[0]->{id};
}
$ingal = false;
if ($x1 == $x2 && $y1 == $y2) {
$ingal = true;
}
if ($tick < 0){
  $rv = spi_exec_query("SELECT tick FROM planet_stats ORDER BY tick DESC LIMIT 1;");
  $tick = $rv->{rows}[0]->{tick};
}
$rv = spi_exec_query("SELECT id,tick FROM planet_stats WHERE x = $x1 AND y = $y1 AND z = $z1 AND (tick = $tick OR tick = (SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC;");
unless ($rv->{processed} >= 1){
return false;
} 
$id1 = $rv->{rows}[0]->{id};
$rv = spi_exec_query("SELECT id,tick FROM planet_stats WHERE x = $x2 AND y = $y2 AND z = $z2 AND (tick = $tick OR tick = (SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC;");
unless ($rv->{processed} >= 1){
return false;
} 
$id2 = $rv->{rows}[0]->{id};
$tick += $eta;
spi_exec_query("INSERT INTO intel (target,sender,tick,eta,mission,uid,ingal, amount) VALUES ($id1, $id2, $tick,$eta, '$mission', $uid, $ingal, $amount)");
return true;$_$
    LANGUAGE plperl;


ALTER FUNCTION public.add_intel2(integer, integer, integer, integer, integer, integer, integer, integer, integer, character varying, character varying) OWNER TO ndawn;

--
-- Name: add_intel4(integer, integer, integer, integer, integer, integer, integer, integer, integer, character varying, integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION add_intel4(tick integer, eta integer, x1 integer, y1 integer, z1 integer, x2 integer, y2 integer, z2 integer, amount integer, mission character varying, uid integer) RETURNS information_schema.cardinal_number
    AS $_$my ($tick, $eta, $x1, $y1, $z1, $x2, $y2, $z2, $amount, $mission, $uid) = @_;
$ingal = false;
if ($x1 == $x2 && $y1 == $y2) {
$ingal = true;
}
if ($tick < 0){
  $rv = spi_exec_query("SELECT tick FROM planet_stats ORDER BY tick DESC LIMIT 1;");
  $tick = $rv->{rows}[0]->{tick};
}
$rv = spi_exec_query("SELECT id,tick FROM planet_stats WHERE x = $x1 AND y = $y1 AND z = $z1 AND (tick = $tick OR tick = (SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC;");
unless ($rv->{processed} >= 1){
return false;
} 
$id1 = $rv->{rows}[0]->{id};
$rv = spi_exec_query("SELECT id,tick FROM planet_stats WHERE x = $x2 AND y = $y2 AND z = $z2 AND (tick = $tick OR tick = (SELECT max(tick) FROM planet_stats)) ORDER BY tick ASC;");
unless ($rv->{processed} >= 1){
return false;
} 
$id2 = $rv->{rows}[0]->{id};
$tick += $eta;
spi_exec_query("INSERT INTO intel (target,sender,tick,eta,mission,uid,ingal, amount) VALUES ($id1, $id2, $tick,$eta, '$mission', $uid, $ingal, $amount)");
return true;$_$
    LANGUAGE plperl;


ALTER FUNCTION public.add_intel4(tick integer, eta integer, x1 integer, y1 integer, z1 integer, x2 integer, y2 integer, z2 integer, amount integer, mission character varying, uid integer) OWNER TO ndawn;

--
-- Name: calc_rank(integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION calc_rank(tick integer) RETURNS void
    AS $_$my ($tick) = @_;
spi_exec_query("DELETE FROM rankings WHERE tick = $tick");
my %ranks = ();
my $rv = spi_exec_query("SELECT id, score FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY score DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
	$id = $rv->{rows}[$row-1]->{id};
	$ranks{$id}{'score'} = $row;
}

my $rv = spi_exec_query("SELECT id, value FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY value DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
	$id = $rv->{rows}[$row-1]->{id};
	$ranks{$id}{'value'} = $row;
}

my $rv = spi_exec_query("SELECT id, size FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY size DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
	$id = $rv->{rows}[$row-1]->{id};
	$ranks{$id}{'size'} = $row;
}

my $rv = spi_exec_query("SELECT id, (score-value) as xp FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY xp DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
	$id = $rv->{rows}[$row-1]->{id};
	$ranks{$id}{'xp'} = $row;
}
foreach $key (keys(%ranks)){
	spi_exec_query("INSERT INTO rankings (id,tick,score,value,size,xp) VALUES($key,$tick,".$ranks{$key}{'score'}.",".$ranks{$key}{'value'}.",".$ranks{$key}{'size'}.",".$ranks{$key}{'xp'}.")");
}
$_$
    LANGUAGE plperl;


ALTER FUNCTION public.calc_rank(tick integer) OWNER TO ndawn;

--
-- Name: calc_rank3(integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION calc_rank3(tick integer) RETURNS information_schema.cardinal_number
    AS $_$my ($tick) = @_;
#spi_exec_query("DELETE FROM rankings WHERE tick = $tick");
my %ranks = ();
my $rv = spi_exec_query("SELECT id, score FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY score DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
	$id = $rv->{rows}[$row-1]->{id};
	#$ranks{$id}{'score'} = $row;
}

my $rv = spi_exec_query("SELECT id, value FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY value DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
	$id = $rv->{rows}[$row-1]->{id};
	#$ranks{$id}{'value'} = $row;
}

my $rv = spi_exec_query("SELECT id, size FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY size DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
	$id = $rv->{rows}[$row-1]->{id};
	#$ranks{$id}{'size'} = $row;
}

my $rv = spi_exec_query("SELECT id, (score-value) as xp FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY xp DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
	$id = $rv->{rows}[$row-1]->{id};
	#$ranks{$id}{'xp'} = $row;
}
foreach $key (keys(%ranks)){
	#spi_exec_query("INSERT INTO rankings (id,tick,score,value,size,xp) VALUES($key,$tick,".$ranks{$key}{'score'}.",".$ranks{$key}{'value'}.",".$ranks{$key}{'size'}.",".$ranks{$key}{'xp'}.")");
}
$_$
    LANGUAGE plperl;


ALTER FUNCTION public.calc_rank3(tick integer) OWNER TO ndawn;

--
-- Name: calculate_rankings(integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION calculate_rankings(integer) RETURNS void
    AS $_$my ($tick) = @_;
spi_exec_query("DELETE FROM rankings WHERE tick = $tick");
my $rv = spi_exec_query("SELECT id, score FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY score DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
$id = $rv->{rows}[$row-1]->{id};
spi_exec_query("INSERT INTO rankings (id,tick,score) VALUES($id,$tick,$row)");
}

my $rv = spi_exec_query("SELECT id, value FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY value DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
$id = $rv->{rows}[$row-1]->{id};
spi_exec_query("UPDATE rankings SET value = $row WHERE id = $id AND tick = $tick");
}

my $rv = spi_exec_query("SELECT id, size FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY size DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
$id = $rv->{rows}[$row-1]->{id};
spi_exec_query("UPDATE rankings SET size = $row WHERE id = $id AND tick = $tick");
}

my $rv = spi_exec_query("SELECT id, (score-value) as xp FROM planets NATURAL JOIN planet_stats WHERE tick = $tick ORDER BY xp DESC");
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
for ($row = 1; $row <= $nrows; ++$row ){
$id = $rv->{rows}[$row-1]->{id};
spi_exec_query("UPDATE rankings SET xp = $row WHERE id = $id AND tick = $tick");
}
$_$
    LANGUAGE plperl;


ALTER FUNCTION public.calculate_rankings(integer) OWNER TO ndawn;

--
-- Name: change_member(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION change_member() RETURNS "trigger"
    AS $_X$if ($_TD->{event} eq 'INSERT' && $_TD->{new}{gid} == 2){
	$rv = spi_exec_query("SELECT * FROM users WHERE uid = $_TD->{new}{uid};");
	if ($rv->{rows}[0]->{planet}){
		spi_exec_query("UPDATE planets SET alliance_id = 1 WHERE id = $rv->{rows}[0]->{planet};");
	}
}
if ($_TD->{event} eq 'DELETE' && $_TD->{old}{gid} == 2){
	$rv = spi_exec_query("SELECT * FROM users WHERE uid = $_TD->{old}{uid};");
	if ($rv->{rows}[0]->{planet}){
		spi_exec_query("UPDATE planets SET alliance_id = NULL WHERE id = $rv->{rows}[0]{planet};");
	}
}
return;$_X$
    LANGUAGE plperl;


ALTER FUNCTION public.change_member() OWNER TO ndawn;

--
-- Name: coords(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION coords(x integer, y integer, z integer) RETURNS text
    AS $_$my ($x,$y,$z) = @_;
return "$x:$y:$z";$_$
    LANGUAGE plperl IMMUTABLE;


ALTER FUNCTION public.coords(x integer, y integer, z integer) OWNER TO ndawn;

--
-- Name: find_alliance_id(character varying); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION find_alliance_id(character varying) RETURNS integer
    AS $_$my ($name) = @_;
print "test";
my $query = spi_prepare('SELECT id FROM alliances WHERE name=$1','varchar');
my $rv = spi_exec_prepared($query,$name);
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
if ($nrows == 1){
	$id = $rv->{rows}[0]->{id};
}
else {
	$rv = spi_exec_query("SELECT nextval('public.alliances_id_seq') AS id");
	if ($rv->{processed} != 1){
		return;
	}
	$id = $rv->{rows}[0]->{id};
	my $query = spi_prepare('INSERT INTO alliances(id,name,relationship) VALUES($1,$2,NULL)','int4','varchar');
	$rv = spi_exec_prepared($query,$id,$name);
	spi_freeplan($query);
	if (rv->{status} != SPI_OK_INSERT){
		return;
	}
}
return $id;$_$
    LANGUAGE plperl;


ALTER FUNCTION public.find_alliance_id(character varying) OWNER TO ndawn;

--
-- Name: findplanetid(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION findplanetid(character varying, character varying, character varying) RETURNS integer
    AS $_$my ($ruler, $planet, $race) = @_;
my $query = spi_prepare('SELECT id, race FROM planets WHERE ruler=$1 AND planet=$2','varchar','varchar');
my $rv = spi_exec_prepared($query,$ruler,$planet);
spi_freeplan($query);
my $status = $rv->{status};
my $nrows = $rv->{processed};
my $id;
if ($nrows == 1){
	$id = $rv->{rows}[0]->{id};
	unless ($race eq $rv->{rows}[0]->{race}){
		$query = spi_prepare('UPDATE planets SET race=$1 where id=$2','varchar','int4');
		spi_exec_prepared($query,$race,$id);
		spi_freeplan($query);
	}
}else {
	$rv = spi_exec_query("SELECT nextval('public.planets_id_seq') AS id");
	if ($rv->{processed} != 1){
		return;
	}
	$id = $rv->{rows}[0]->{id};
	$query = spi_prepare('INSERT INTO planets(id,ruler,planet,race) VALUES($1,$2,$3,$4)','int4','varchar','varchar','varchar');
	$rv = spi_exec_prepared($query,$id,$ruler,$planet,$race);
	spi_freeplan($query);
	if (rv->{status} != SPI_OK_INSERT){
		return;
	}
	$query = spi_prepare('INSERT INTO forum_threads (fbid,planet,subject) VALUES($1,$2,$3)','int4','int4','varchar');
	$rv = spi_exec_prepared($query,-2,$id,"$ruler OF $planet");
	spi_freeplan($query);
	if (rv->{status} != SPI_OK_INSERT){
		return;
	}
}
return $id;$_$
    LANGUAGE plperl;


ALTER FUNCTION public.findplanetid(character varying, character varying, character varying) OWNER TO ndawn;

--
-- Name: groups(integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION groups(uid integer) RETURNS SETOF integer
    AS $_$SELECT gid FROM groupmembers WHERE uid = $1 UNION SELECT -1$_$
    LANGUAGE sql STABLE;


ALTER FUNCTION public.groups(uid integer) OWNER TO ndawn;

--
-- Name: max_bank_hack(integer, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION max_bank_hack(metal integer, crystal integer, eonium integer, tvalue integer, value integer) RETURNS integer
    AS $_$SELECT LEAST(2000*15*$4::numeric/$5,$1*0.10, 15*7500)::integer + LEAST(2000*15*$4::numeric/$5,$2*0.10, 15*7500)::integer+LEAST(2000*15*$4::numeric/$5,$3*0.10, 15*7500)::integer$_$
    LANGUAGE sql IMMUTABLE;


ALTER FUNCTION public.max_bank_hack(metal integer, crystal integer, eonium integer, tvalue integer, value integer) OWNER TO ndawn;

--
-- Name: planetid(integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION planetid(x integer, y integer, z integer, tick integer) RETURNS integer
    AS $_$SELECT id FROM planet_stats WHERE x = $1 AND y = $2 AND z = $3 AND (tick = $4 OR tick =( SELECT max(tick) FROM planet_stats) ) ORDER BY tick ASC LIMIT 1$_$
    LANGUAGE sql STABLE;


ALTER FUNCTION public.planetid(x integer, y integer, z integer, tick integer) OWNER TO ndawn;

--
-- Name: plperl_call_handler(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION plperl_call_handler() RETURNS language_handler
    AS '$libdir/plperl', 'plperl_call_handler'
    LANGUAGE c;


ALTER FUNCTION public.plperl_call_handler() OWNER TO postgres;

--
-- Name: populate_ticks(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION populate_ticks() RETURNS void
    AS $_$my $rv = spi_exec_query("SELECT tick FROM planet_stats ORDER BY tick DESC LIMIT 1;");
my $nrows = $rv->{processed};
if ($nrows == 1){
$tick = $rv->{rows}[0]->{tick};
spi_exec_query("DELETE FROM ticks;");
spi_exec_query("INSERT INTO ticks(tick) (SELECT generate_series(36, tick,tick/50) FROM (SELECT tick FROM planet_stats ORDER BY tick DESC LIMIT 1) as foo);");
spi_exec_query("INSERT INTO ticks(tick) VALUES($tick)");
}$_$
    LANGUAGE plperl;


ALTER FUNCTION public.populate_ticks() OWNER TO ndawn;

--
-- Name: tick(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION tick() RETURNS integer
    AS $$SELECT value::integer FROM misc WHERE id = 'TICK'$$
    LANGUAGE sql STABLE;


ALTER FUNCTION public.tick() OWNER TO postgres;

--
-- Name: update_user_planet(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION update_user_planet() RETURNS "trigger"
    AS $_X$my $rv = spi_exec_query("SELECT * FROM groupmembers WHERE uid = $_TD->{new}{uid} AND gid = 2;");
if ($rv->{processed} == 1){# && ($_TD->{old}{planet} != $_TD->{new}{planet})){
	if ($_TD->{old}{planet}){
		spi_exec_query("UPDATE planets SET alliance_id = NULL WHERE id = $_TD->{old}{planet};");
	}
	if ($_TD->{new}{planet}){
		spi_exec_query("UPDATE planets SET alliance_id = 1 WHERE id = $_TD->{new}{planet};");
	}
}
if ($_TD->{old}{planet}){
	spi_exec_query("UPDATE planets SET nick = NULL WHERE id = $_TD->{old}{planet};");
}
if ($_TD->{new}{planet}){
	spi_exec_query("UPDATE planets SET nick = '$_TD->{new}{username}' WHERE id = $_TD->{new}{planet};");
}
return;$_X$
    LANGUAGE plperl;


ALTER FUNCTION public.update_user_planet() OWNER TO ndawn;

--
-- Name: updated_target(); Type: FUNCTION; Schema: public; Owner: ndawn
--

CREATE FUNCTION updated_target() RETURNS "trigger"
    AS $_X$my $query = spi_prepare('UPDATE raid_targets SET modified = NOW() WHERE id = $1','int4');
my $target = $_TD->{new}{target};
$target = $_TD->{old}{target} if ($_TD->{event} eq 'DELETE');
spi_exec_prepared($query,$target);
spi_freeplan($query);$_X$
    LANGUAGE plperl;


ALTER FUNCTION public.updated_target() OWNER TO ndawn;

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
-- Name: alliance_stats; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE alliance_stats (
    id integer NOT NULL,
    tick integer NOT NULL,
    size integer NOT NULL,
    members integer NOT NULL,
    score integer NOT NULL
);


ALTER TABLE public.alliance_stats OWNER TO ndawn;

--
-- Name: alliances; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE alliances (
    id integer NOT NULL,
    name character varying NOT NULL,
    relationship text
);


ALTER TABLE public.alliances OWNER TO ndawn;

--
-- Name: alliances_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE alliances_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.alliances_id_seq OWNER TO ndawn;

--
-- Name: alliances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE alliances_id_seq OWNED BY alliances.id;


--
-- Name: calls; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE calls (
    id integer NOT NULL,
    member integer NOT NULL,
    dc integer,
    landing_tick integer NOT NULL,
    info text NOT NULL,
    covered boolean DEFAULT false NOT NULL,
    shiptypes text,
    open boolean DEFAULT true NOT NULL
);


ALTER TABLE public.calls OWNER TO ndawn;

--
-- Name: calls_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE calls_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.calls_id_seq OWNER TO ndawn;

--
-- Name: calls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE calls_id_seq OWNED BY calls.id;


--
-- Name: channel_flags; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE channel_flags (
    id integer NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.channel_flags OWNER TO ndawn;

--
-- Name: channel_flags_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE channel_flags_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.channel_flags_id_seq OWNER TO ndawn;

--
-- Name: channel_flags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE channel_flags_id_seq OWNED BY channel_flags.id;


--
-- Name: channel_group_flags; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE channel_group_flags (
    channel integer NOT NULL,
    "group" integer NOT NULL,
    flag integer NOT NULL
);


ALTER TABLE public.channel_group_flags OWNER TO ndawn;

--
-- Name: channels; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE channels (
    id integer NOT NULL,
    name text NOT NULL,
    description text NOT NULL
);


ALTER TABLE public.channels OWNER TO ndawn;

--
-- Name: channels_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE channels_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.channels_id_seq OWNER TO ndawn;

--
-- Name: channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE channels_id_seq OWNED BY channels.id;


--
-- Name: covop_targets; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE covop_targets (
    planet integer NOT NULL,
    metal integer,
    crystal integer,
    eonium integer,
    structures integer,
    sec_centres integer,
    dists integer,
    last_covop integer,
    covop_by integer
);


ALTER TABLE public.covop_targets OWNER TO ndawn;

--
-- Name: planet_stats; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE planet_stats (
    id integer NOT NULL,
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
    xprank integer NOT NULL
);


ALTER TABLE public.planet_stats OWNER TO ndawn;

--
-- Name: planets; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE planets (
    id integer NOT NULL,
    ruler character varying NOT NULL,
    planet character varying NOT NULL,
    race character varying,
    nick character varying,
    planet_status text,
    hit_us integer DEFAULT 0 NOT NULL,
    alliance_id integer,
    channel text
);


ALTER TABLE public.planets OWNER TO ndawn;

--
-- Name: current_planet_stats; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW current_planet_stats AS
    SELECT p.id, p.nick, p.planet_status, p.hit_us, ps.x, ps.y, ps.z, p.ruler, p.planet, p.race, ps.size, ps.score, ps.value, ps.xp, ps.sizerank, ps.scorerank, ps.valuerank, ps.xprank, alliances.name AS alliance, alliances.relationship, p.alliance_id, p.channel FROM (((SELECT planet_stats.id, planet_stats.tick, planet_stats.x, planet_stats.y, planet_stats.z, planet_stats.size, planet_stats.score, planet_stats.value, planet_stats.xp, planet_stats.sizerank, planet_stats.scorerank, planet_stats.valuerank, planet_stats.xprank FROM planet_stats WHERE (planet_stats.tick = (SELECT max(planet_stats.tick) AS max FROM planet_stats))) ps NATURAL JOIN planets p) LEFT JOIN alliances ON ((alliances.id = p.alliance_id)));


ALTER TABLE public.current_planet_stats OWNER TO ndawn;

--
-- Name: defense_requests; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE defense_requests (
    id integer NOT NULL,
    uid integer NOT NULL,
    message text NOT NULL,
    sent boolean DEFAULT false NOT NULL
);


ALTER TABLE public.defense_requests OWNER TO ndawn;

--
-- Name: defense_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE defense_requests_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.defense_requests_id_seq OWNER TO ndawn;

--
-- Name: defense_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE defense_requests_id_seq OWNED BY defense_requests.id;


--
-- Name: dumps; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE dumps (
    tick integer NOT NULL,
    "type" text NOT NULL,
    dump text NOT NULL,
    modified integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.dumps OWNER TO ndawn;

--
-- Name: fleet_ships; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE fleet_ships (
    fleet integer NOT NULL,
    ship text NOT NULL,
    amount integer NOT NULL
);


ALTER TABLE public.fleet_ships OWNER TO ndawn;

--
-- Name: fleets; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE fleets (
    uid integer NOT NULL,
    fleet integer NOT NULL,
    target integer NOT NULL,
    mission text NOT NULL,
    landing_tick integer NOT NULL,
    id integer NOT NULL,
    eta integer NOT NULL,
    back integer NOT NULL
);


ALTER TABLE public.fleets OWNER TO ndawn;

--
-- Name: fleets_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE fleets_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.fleets_id_seq OWNER TO ndawn;

--
-- Name: fleets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE fleets_id_seq OWNED BY fleets.id;


--
-- Name: forum_access; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE forum_access (
    fbid integer NOT NULL,
    gid integer NOT NULL,
    post boolean DEFAULT false NOT NULL
);


ALTER TABLE public.forum_access OWNER TO ndawn;

--
-- Name: forum_boards; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE forum_boards (
    fbid integer NOT NULL,
    fcid integer NOT NULL,
    board text NOT NULL
);


ALTER TABLE public.forum_boards OWNER TO ndawn;

--
-- Name: forum_boards_fbid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE forum_boards_fbid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.forum_boards_fbid_seq OWNER TO ndawn;

--
-- Name: forum_boards_fbid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE forum_boards_fbid_seq OWNED BY forum_boards.fbid;


--
-- Name: forum_categories; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE forum_categories (
    fcid integer NOT NULL,
    category text NOT NULL
);


ALTER TABLE public.forum_categories OWNER TO ndawn;

--
-- Name: forum_categories_fcid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE forum_categories_fcid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.forum_categories_fcid_seq OWNER TO ndawn;

--
-- Name: forum_categories_fcid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE forum_categories_fcid_seq OWNED BY forum_categories.fcid;


--
-- Name: forum_posts; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE forum_posts (
    fpid integer NOT NULL,
    ftid integer NOT NULL,
    message text NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL,
    uid integer NOT NULL
);


ALTER TABLE public.forum_posts OWNER TO ndawn;

--
-- Name: forum_posts_fpid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE forum_posts_fpid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.forum_posts_fpid_seq OWNER TO ndawn;

--
-- Name: forum_posts_fpid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE forum_posts_fpid_seq OWNED BY forum_posts.fpid;


--
-- Name: forum_thread_visits; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE forum_thread_visits (
    uid integer NOT NULL,
    ftid integer NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.forum_thread_visits OWNER TO ndawn;

--
-- Name: forum_threads; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE forum_threads (
    ftid integer NOT NULL,
    fbid integer NOT NULL,
    subject text NOT NULL,
    planet integer,
    log_uid integer
);


ALTER TABLE public.forum_threads OWNER TO ndawn;

--
-- Name: forum_threads_ftid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE forum_threads_ftid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.forum_threads_ftid_seq OWNER TO ndawn;

--
-- Name: forum_threads_ftid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE forum_threads_ftid_seq OWNED BY forum_threads.ftid;


--
-- Name: galaxies; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE galaxies (
    x integer NOT NULL,
    y integer NOT NULL,
    tick integer NOT NULL,
    name character varying NOT NULL,
    size integer NOT NULL,
    score integer NOT NULL,
    value integer NOT NULL
);


ALTER TABLE public.galaxies OWNER TO ndawn;

--
-- Name: groupmembers; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE groupmembers (
    gid integer NOT NULL,
    uid integer NOT NULL
);


ALTER TABLE public.groupmembers OWNER TO ndawn;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE groups (
    gid integer NOT NULL,
    groupname text NOT NULL,
    flag character(1),
    attack boolean DEFAULT false NOT NULL
);


ALTER TABLE public.groups OWNER TO ndawn;

--
-- Name: groups_gid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE groups_gid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.groups_gid_seq OWNER TO ndawn;

--
-- Name: groups_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE groups_gid_seq OWNED BY groups.gid;


--
-- Name: incomings; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE incomings (
    call integer NOT NULL,
    sender integer NOT NULL,
    eta integer NOT NULL,
    amount integer NOT NULL,
    fleet text NOT NULL,
    shiptype text DEFAULT '?'::text NOT NULL,
    id integer NOT NULL
);


ALTER TABLE public.incomings OWNER TO ndawn;

--
-- Name: incomings_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE incomings_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.incomings_id_seq OWNER TO ndawn;

--
-- Name: incomings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE incomings_id_seq OWNED BY incomings.id;


SET default_with_oids = true;

--
-- Name: intel; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE intel (
    target integer NOT NULL,
    sender integer NOT NULL,
    tick integer NOT NULL,
    mission character varying NOT NULL,
    ingal boolean NOT NULL,
    amount integer NOT NULL,
    eta smallint DEFAULT 16 NOT NULL,
    uid integer NOT NULL
);


ALTER TABLE public.intel OWNER TO ndawn;

SET default_with_oids = false;

--
-- Name: intel_messages; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE intel_messages (
    id integer NOT NULL,
    uid integer NOT NULL,
    message text NOT NULL,
    handled boolean DEFAULT false NOT NULL,
    handled_by integer,
    report_date timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.intel_messages OWNER TO ndawn;

--
-- Name: intel_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE intel_messages_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.intel_messages_id_seq OWNER TO ndawn;

--
-- Name: intel_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE intel_messages_id_seq OWNED BY intel_messages.id;


--
-- Name: log; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE log (
    id integer NOT NULL,
    uid integer NOT NULL,
    "time" timestamp without time zone DEFAULT now() NOT NULL,
    text text NOT NULL
);


ALTER TABLE public.log OWNER TO ndawn;

--
-- Name: log_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE log_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.log_id_seq OWNER TO ndawn;

--
-- Name: log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE log_id_seq OWNED BY log.id;


--
-- Name: misc; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE misc (
    id text NOT NULL,
    value text
);


ALTER TABLE public.misc OWNER TO ndawn;

--
-- Name: planets_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE planets_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.planets_id_seq OWNER TO ndawn;

--
-- Name: planets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE planets_id_seq OWNED BY planets.id;


--
-- Name: raid_access; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE raid_access (
    raid integer NOT NULL,
    gid integer NOT NULL
);


ALTER TABLE public.raid_access OWNER TO ndawn;

--
-- Name: raid_claims; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE raid_claims (
    target integer NOT NULL,
    uid integer NOT NULL,
    wave integer NOT NULL,
    joinable boolean DEFAULT false NOT NULL,
    launched boolean DEFAULT false NOT NULL
);


ALTER TABLE public.raid_claims OWNER TO ndawn;

--
-- Name: raid_targets; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE raid_targets (
    id integer NOT NULL,
    raid integer NOT NULL,
    planet integer NOT NULL,
    "comment" text,
    modified timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.raid_targets OWNER TO ndawn;

--
-- Name: raid_targets_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE raid_targets_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.raid_targets_id_seq OWNER TO ndawn;

--
-- Name: raid_targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE raid_targets_id_seq OWNED BY raid_targets.id;


--
-- Name: raids; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE raids (
    id integer NOT NULL,
    tick integer NOT NULL,
    open boolean DEFAULT false NOT NULL,
    waves integer DEFAULT 3 NOT NULL,
    message text NOT NULL,
    removed boolean DEFAULT false NOT NULL,
    released_coords boolean DEFAULT false NOT NULL
);


ALTER TABLE public.raids OWNER TO ndawn;

--
-- Name: raids_id_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE raids_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.raids_id_seq OWNER TO ndawn;

--
-- Name: raids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE raids_id_seq OWNED BY raids.id;


--
-- Name: scans; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE scans (
    tick integer NOT NULL,
    "type" character varying,
    scan_id integer NOT NULL,
    scan text,
    planet integer
);


ALTER TABLE public.scans OWNER TO ndawn;

--
-- Name: ship_stats; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE ship_stats (
    name text NOT NULL,
    "class" text NOT NULL,
    target text NOT NULL,
    "type" text NOT NULL,
    init integer NOT NULL,
    armor integer NOT NULL,
    damage integer NOT NULL,
    metal integer NOT NULL,
    crystal integer NOT NULL,
    eonium integer NOT NULL,
    race text NOT NULL,
    guns integer DEFAULT 0 NOT NULL,
    eres integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.ship_stats OWNER TO ndawn;

SET default_with_oids = true;

--
-- Name: ticks; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE ticks (
    tick integer NOT NULL
);


ALTER TABLE public.ticks OWNER TO ndawn;

SET default_with_oids = false;

--
-- Name: users; Type: TABLE; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE TABLE users (
    uid integer NOT NULL,
    username text NOT NULL,
    planet integer,
    "password" text NOT NULL,
    attack_points integer DEFAULT 0 NOT NULL,
    defense_points integer DEFAULT 0 NOT NULL,
    scan_points integer DEFAULT 0 NOT NULL,
    humor_points integer DEFAULT 0 NOT NULL,
    hostmask text,
    sms text,
    rank integer,
    laston timestamp with time zone
);


ALTER TABLE public.users OWNER TO ndawn;

--
-- Name: users_uid_seq; Type: SEQUENCE; Schema: public; Owner: ndawn
--

CREATE SEQUENCE users_uid_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.users_uid_seq OWNER TO ndawn;

--
-- Name: users_uid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: ndawn
--

ALTER SEQUENCE users_uid_seq OWNED BY users.uid;


--
-- Name: usersingroup; Type: VIEW; Schema: public; Owner: ndawn
--

CREATE VIEW usersingroup AS
    SELECT groups.gid, groups.groupname, users.uid, users.username FROM ((users NATURAL JOIN groupmembers) NATURAL JOIN groups);


ALTER TABLE public.usersingroup OWNER TO ndawn;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE alliances ALTER COLUMN id SET DEFAULT nextval('alliances_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE calls ALTER COLUMN id SET DEFAULT nextval('calls_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE channel_flags ALTER COLUMN id SET DEFAULT nextval('channel_flags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE channels ALTER COLUMN id SET DEFAULT nextval('channels_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE defense_requests ALTER COLUMN id SET DEFAULT nextval('defense_requests_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE fleets ALTER COLUMN id SET DEFAULT nextval('fleets_id_seq'::regclass);


--
-- Name: fbid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE forum_boards ALTER COLUMN fbid SET DEFAULT nextval('forum_boards_fbid_seq'::regclass);


--
-- Name: fcid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE forum_categories ALTER COLUMN fcid SET DEFAULT nextval('forum_categories_fcid_seq'::regclass);


--
-- Name: fpid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE forum_posts ALTER COLUMN fpid SET DEFAULT nextval('forum_posts_fpid_seq'::regclass);


--
-- Name: ftid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE forum_threads ALTER COLUMN ftid SET DEFAULT nextval('forum_threads_ftid_seq'::regclass);


--
-- Name: gid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE groups ALTER COLUMN gid SET DEFAULT nextval('groups_gid_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE incomings ALTER COLUMN id SET DEFAULT nextval('incomings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE intel_messages ALTER COLUMN id SET DEFAULT nextval('intel_messages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE log ALTER COLUMN id SET DEFAULT nextval('log_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE planets ALTER COLUMN id SET DEFAULT nextval('planets_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE raid_targets ALTER COLUMN id SET DEFAULT nextval('raid_targets_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE raids ALTER COLUMN id SET DEFAULT nextval('raids_id_seq'::regclass);


--
-- Name: uid; Type: DEFAULT; Schema: public; Owner: ndawn
--

ALTER TABLE users ALTER COLUMN uid SET DEFAULT nextval('users_uid_seq'::regclass);


--
-- Name: accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (uid);


--
-- Name: alliance_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY alliance_stats
    ADD CONSTRAINT alliance_stats_pkey PRIMARY KEY (id, tick);


--
-- Name: alliances_name_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY alliances
    ADD CONSTRAINT alliances_name_key UNIQUE (name);


--
-- Name: alliances_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY alliances
    ADD CONSTRAINT alliances_pkey PRIMARY KEY (id);


--
-- Name: calls_member_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY calls
    ADD CONSTRAINT calls_member_key UNIQUE (member, landing_tick);


--
-- Name: calls_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY calls
    ADD CONSTRAINT calls_pkey PRIMARY KEY (id);


--
-- Name: channel_flags_name_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY channel_flags
    ADD CONSTRAINT channel_flags_name_key UNIQUE (name);


--
-- Name: channel_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY channel_flags
    ADD CONSTRAINT channel_flags_pkey PRIMARY KEY (id);


--
-- Name: channel_group_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY channel_group_flags
    ADD CONSTRAINT channel_group_flags_pkey PRIMARY KEY (channel, "group", flag);


--
-- Name: channels_name_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY channels
    ADD CONSTRAINT channels_name_key UNIQUE (name);


--
-- Name: channels_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY channels
    ADD CONSTRAINT channels_pkey PRIMARY KEY (id);


--
-- Name: covOp_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY covop_targets
    ADD CONSTRAINT "covOp_targets_pkey" PRIMARY KEY (planet);


--
-- Name: defense_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY defense_requests
    ADD CONSTRAINT defense_requests_pkey PRIMARY KEY (id);


--
-- Name: dumps_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY dumps
    ADD CONSTRAINT dumps_pkey PRIMARY KEY (tick, "type", modified);


--
-- Name: fleet_ships_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY fleet_ships
    ADD CONSTRAINT fleet_ships_pkey PRIMARY KEY (fleet, ship);


--
-- Name: fleets_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY fleets
    ADD CONSTRAINT fleets_pkey PRIMARY KEY (id);


--
-- Name: fleets_uid_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY fleets
    ADD CONSTRAINT fleets_uid_key UNIQUE (uid, fleet);


--
-- Name: forum_access_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY forum_access
    ADD CONSTRAINT forum_access_pkey PRIMARY KEY (fbid, gid);


--
-- Name: forum_boards_fcid_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY forum_boards
    ADD CONSTRAINT forum_boards_fcid_key UNIQUE (fcid, board);


--
-- Name: forum_boards_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY forum_boards
    ADD CONSTRAINT forum_boards_pkey PRIMARY KEY (fbid);


--
-- Name: forum_categories_category_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY forum_categories
    ADD CONSTRAINT forum_categories_category_key UNIQUE (category);


--
-- Name: forum_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY forum_categories
    ADD CONSTRAINT forum_categories_pkey PRIMARY KEY (fcid);


--
-- Name: forum_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_pkey PRIMARY KEY (fpid);


--
-- Name: forum_thread_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY forum_thread_visits
    ADD CONSTRAINT forum_thread_visits_pkey PRIMARY KEY (uid, ftid);


--
-- Name: forum_threads_log_uid_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY forum_threads
    ADD CONSTRAINT forum_threads_log_uid_key UNIQUE (log_uid);


--
-- Name: forum_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY forum_threads
    ADD CONSTRAINT forum_threads_pkey PRIMARY KEY (ftid);


--
-- Name: forum_threads_planet_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY forum_threads
    ADD CONSTRAINT forum_threads_planet_key UNIQUE (planet);


--
-- Name: galaxies_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY galaxies
    ADD CONSTRAINT galaxies_pkey PRIMARY KEY (x, y, tick);


--
-- Name: groupmembers_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY groupmembers
    ADD CONSTRAINT groupmembers_pkey PRIMARY KEY (gid, uid);


--
-- Name: groups_groupname_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_groupname_key UNIQUE (groupname);


--
-- Name: groups_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (gid);


--
-- Name: incomings_call_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY incomings
    ADD CONSTRAINT incomings_call_key UNIQUE (call, sender, fleet);


--
-- Name: incomings_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY incomings
    ADD CONSTRAINT incomings_pkey PRIMARY KEY (id);


--
-- Name: intel_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY intel_messages
    ADD CONSTRAINT intel_messages_pkey PRIMARY KEY (id);


--
-- Name: log_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY log
    ADD CONSTRAINT log_pkey PRIMARY KEY (id);


--
-- Name: misc_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY misc
    ADD CONSTRAINT misc_pkey PRIMARY KEY (id);


--
-- Name: planet_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY planet_stats
    ADD CONSTRAINT planet_stats_pkey PRIMARY KEY (tick, x, y, z);


--
-- Name: planet_stats_tick_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY planet_stats
    ADD CONSTRAINT planet_stats_tick_key UNIQUE (tick, x, y, z);


--
-- Name: planets_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY planets
    ADD CONSTRAINT planets_pkey PRIMARY KEY (id);


--
-- Name: planets_ruler_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY planets
    ADD CONSTRAINT planets_ruler_key UNIQUE (ruler, planet);


--
-- Name: raid_access_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY raid_access
    ADD CONSTRAINT raid_access_pkey PRIMARY KEY (raid, gid);


--
-- Name: raid_claims_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY raid_claims
    ADD CONSTRAINT raid_claims_pkey PRIMARY KEY (target, uid, wave);


--
-- Name: raid_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY raid_targets
    ADD CONSTRAINT raid_targets_pkey PRIMARY KEY (id);


--
-- Name: raid_targets_raid_planet_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY raid_targets
    ADD CONSTRAINT raid_targets_raid_planet_key UNIQUE (planet, raid);


--
-- Name: raids_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY raids
    ADD CONSTRAINT raids_pkey PRIMARY KEY (id);


--
-- Name: scans_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY scans
    ADD CONSTRAINT scans_pkey PRIMARY KEY (tick, scan_id);


--
-- Name: ship_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY ship_stats
    ADD CONSTRAINT ship_stats_pkey PRIMARY KEY (name);


--
-- Name: ticks_pkey; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY ticks
    ADD CONSTRAINT ticks_pkey PRIMARY KEY (tick);


--
-- Name: users_planet_key; Type: CONSTRAINT; Schema: public; Owner: ndawn; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_planet_key UNIQUE (planet);


--
-- Name: forum_access_gid_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX forum_access_gid_index ON forum_access USING btree (gid);


--
-- Name: forum_posts_ftid_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX forum_posts_ftid_index ON forum_posts USING btree (ftid);


--
-- Name: forum_posts_time_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX forum_posts_time_index ON forum_posts USING btree ("time");


--
-- Name: groupmembers_uid_key; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX groupmembers_uid_key ON groupmembers USING btree (uid);


--
-- Name: inteL_ingal_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX "inteL_ingal_index" ON intel USING btree (ingal);


--
-- Name: intel_eta_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX intel_eta_index ON intel USING btree (eta);


--
-- Name: intel_launchtick_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX intel_launchtick_index ON intel USING btree (((tick - eta)));


--
-- Name: intel_mission_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX intel_mission_index ON intel USING btree (mission);


--
-- Name: intel_sender_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX intel_sender_index ON intel USING btree (sender);


--
-- Name: intel_target_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX intel_target_index ON intel USING btree (target);


--
-- Name: intel_tick_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX intel_tick_index ON intel USING btree (tick);


--
-- Name: planet_stats_coord_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX planet_stats_coord_index ON planet_stats USING btree (x, y, z);


--
-- Name: planet_stats_id_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX planet_stats_id_index ON planet_stats USING btree (id);


--
-- Name: planet_stats_score_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX planet_stats_score_index ON planet_stats USING btree (tick, score);


--
-- Name: planet_stats_size_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX planet_stats_size_index ON planet_stats USING btree (tick, size);


--
-- Name: planet_stats_tick_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX planet_stats_tick_index ON planet_stats USING btree (tick);


--
-- Name: planet_stats_value_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX planet_stats_value_index ON planet_stats USING btree (tick, value);


--
-- Name: planets_alliance_id_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX planets_alliance_id_index ON planets USING btree (alliance_id);


--
-- Name: planets_nick_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX planets_nick_index ON planets USING btree (nick);


--
-- Name: raid_targets_modified_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE INDEX raid_targets_modified_index ON raid_targets USING btree (modified);


--
-- Name: users_hostmask_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE UNIQUE INDEX users_hostmask_index ON users USING btree (lower(hostmask));


--
-- Name: users_username_index; Type: INDEX; Schema: public; Owner: ndawn; Tablespace: 
--

CREATE UNIQUE INDEX users_username_index ON users USING btree (lower(username));


--
-- Name: add_remove_member; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER add_remove_member
    AFTER INSERT OR DELETE ON groupmembers
    FOR EACH ROW
    EXECUTE PROCEDURE change_member();


--
-- Name: update_planet; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER update_planet
    AFTER UPDATE ON users
    FOR EACH ROW
    EXECUTE PROCEDURE update_user_planet();


--
-- Name: update_target; Type: TRIGGER; Schema: public; Owner: ndawn
--

CREATE TRIGGER update_target
    AFTER INSERT OR DELETE OR UPDATE ON raid_claims
    FOR EACH ROW
    EXECUTE PROCEDURE updated_target();


--
-- Name: alliance_stats_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY alliance_stats
    ADD CONSTRAINT alliance_stats_id_fkey FOREIGN KEY (id) REFERENCES alliances(id);


--
-- Name: calls_dc_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY calls
    ADD CONSTRAINT calls_dc_fkey FOREIGN KEY (dc) REFERENCES users(uid) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: calls_member_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY calls
    ADD CONSTRAINT calls_member_fkey FOREIGN KEY (member) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: channel_group_flags_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY channel_group_flags
    ADD CONSTRAINT channel_group_flags_channel_fkey FOREIGN KEY (channel) REFERENCES channels(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: channel_group_flags_flag_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY channel_group_flags
    ADD CONSTRAINT channel_group_flags_flag_fkey FOREIGN KEY (flag) REFERENCES channel_flags(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: channel_group_flags_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY channel_group_flags
    ADD CONSTRAINT channel_group_flags_group_fkey FOREIGN KEY ("group") REFERENCES groups(gid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: covOp_targets_planet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY covop_targets
    ADD CONSTRAINT "covOp_targets_planet_fkey" FOREIGN KEY (planet) REFERENCES planets(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: covop_targets_covop_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY covop_targets
    ADD CONSTRAINT covop_targets_covop_by_fkey FOREIGN KEY (covop_by) REFERENCES users(uid) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: defense_requests_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY defense_requests
    ADD CONSTRAINT defense_requests_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: fleet_ships_fleet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleet_ships
    ADD CONSTRAINT fleet_ships_fleet_fkey FOREIGN KEY (fleet) REFERENCES fleets(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: fleets_target_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleets
    ADD CONSTRAINT fleets_target_fkey FOREIGN KEY (target) REFERENCES planets(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: fleets_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY fleets
    ADD CONSTRAINT fleets_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


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
-- Name: forum_threads_log_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_threads
    ADD CONSTRAINT forum_threads_log_uid_fkey FOREIGN KEY (log_uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_threads_planet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY forum_threads
    ADD CONSTRAINT forum_threads_planet_fkey FOREIGN KEY (planet) REFERENCES planets(id) ON UPDATE CASCADE ON DELETE CASCADE;


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
    ADD CONSTRAINT incomings_call_fkey FOREIGN KEY (call) REFERENCES calls(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: incomings_sender_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY incomings
    ADD CONSTRAINT incomings_sender_fkey FOREIGN KEY (sender) REFERENCES planets(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: intel_messages_handled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel_messages
    ADD CONSTRAINT intel_messages_handled_by_fkey FOREIGN KEY (handled_by) REFERENCES users(uid) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: intel_messages_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel_messages
    ADD CONSTRAINT intel_messages_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: intel_sender_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel
    ADD CONSTRAINT intel_sender_fkey FOREIGN KEY (sender) REFERENCES planets(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: intel_target_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel
    ADD CONSTRAINT intel_target_fkey FOREIGN KEY (target) REFERENCES planets(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: intel_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY intel
    ADD CONSTRAINT intel_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: log_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY log
    ADD CONSTRAINT log_uid_fkey FOREIGN KEY (uid) REFERENCES users(uid) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: planet_stats_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planet_stats
    ADD CONSTRAINT planet_stats_id_fkey FOREIGN KEY (id) REFERENCES planets(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: planets_alliance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY planets
    ADD CONSTRAINT planets_alliance_id_fkey FOREIGN KEY (alliance_id) REFERENCES alliances(id) ON UPDATE SET NULL ON DELETE SET NULL;


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
    ADD CONSTRAINT raid_targets_planet_fkey FOREIGN KEY (planet) REFERENCES planets(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: raid_targets_raid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY raid_targets
    ADD CONSTRAINT raid_targets_raid_fkey FOREIGN KEY (raid) REFERENCES raids(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: scans_planet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY scans
    ADD CONSTRAINT scans_planet_fkey FOREIGN KEY (planet) REFERENCES planets(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: users_planet_fkey; Type: FK CONSTRAINT; Schema: public; Owner: ndawn
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_planet_fkey FOREIGN KEY (planet) REFERENCES planets(id) ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO ndawn;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

