
/*Changes when target is unclaimed */
CREATE OR REPLACE FUNCTION unclaim_target()
  RETURNS "trigger" AS
$BODY$
if ($_TD->{event} eq 'DELETE' && $_TD->{old}{launched} eq 't'){
	my $uid = $_TD->{old}{uid};
	my $query = spi_prepare(q{UPDATE users
		SET attack_points = attack_points - 1
		WHERE uid = $1},'int4');
	spi_exec_prepared($query,$uid);
	spi_freeplan($query);
}
return;
$BODY$  LANGUAGE 'plperl' VOLATILE;
ALTER FUNCTION updated_target() OWNER TO ndawn;


CREATE TRIGGER unclaim_target AFTER DELETE
   ON raid_claims FOR EACH ROW
   EXECUTE PROCEDURE PUBLIC.unclaim_target();

