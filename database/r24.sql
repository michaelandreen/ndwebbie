ALTER TABLE ship_stats RENAME COLUMN target TO t1;
ALTER TABLE ship_stats ADD t2 text;
ALTER TABLE ship_stats ADD t3 text;
/*scan_id has gotten bigger*/
ALTER TABLE scans ALTER COLUMN scan_id TYPE NUMERIC(10);

/*Changes when target is unclaimed */
/*
CREATE OR REPLACE FUNCTION unclaim_target()
  RETURNS "trigger" AS
$BODY$my $query = spi_prepare('UPDATE raid_targets SET modified = NOW() WHERE id = $1','int4');
my $target = $_TD->{new}{target};
$target = $_TD->{old}{target} IF ($_TD->{event} eq 'DELETE');
spi_exec_prepared($query,$target);
spi_freeplan($query);$BODY$
  LANGUAGE 'plperl' VOLATILE;
ALTER FUNCTION updated_target() OWNER TO ndawn;

CREATE TRIGGER unclaim_target AFTER DELETE
   ON raid_claims FOR EACH ROW
   EXECUTE PROCEDURE PUBLIC.unclaim_target();
*/
