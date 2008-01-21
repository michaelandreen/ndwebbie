INSERT INTO forum_boards (fcid,fbid,board) VALUES(9,-3,'Call logs');

ALTER TABLE calls ADD COLUMN ftid INTEGER REFERENCES forum_threads(ftid);

CREATE OR REPLACE FUNCTION add_call() RETURNS "trigger"
    AS $_X$
if ($_TD->{event} eq 'INSERT'){
	$rv = spi_exec_query("SELECT nextval('public.forum_threads_ftid_seq') AS id");
	if ($rv->{processed} != 1){
		return 'SKIP';
	}
	$ftid = $rv->{rows}[0]->{id};
	$query = spi_prepare('INSERT INTO forum_threads (fbid,ftid,subject,uid) VALUES(-3,$1,$2,-3)','int4','varchar');
	$rv = spi_exec_prepared($query,$ftid,"$_TD->{new}{member}: $_TD->{new}{landing_tick}");
	spi_freeplan($query);
	if (rv->{status} != SPI_OK_INSERT){
		return 'SKIP';
	}
	$_TD->{new}{ftid} = $ftid;
	return 'MODIFY';
}
return 'SKIP';
$_X$
    LANGUAGE plperl;

CREATE TRIGGER add_call
    BEFORE INSERT ON calls
    FOR EACH ROW
    EXECUTE PROCEDURE add_call();
