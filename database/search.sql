ALTER TABLE forum_posts ADD textsearch tsvector;

UPDATE forum_posts fp SET textsearch = setweight(to_tsvector(coalesce(ft.subject,'')), 'A') || setweight(to_tsvector(coalesce(u.username,'')), 'B') || setweight(to_tsvector(coalesce(fp.message,'')), 'D') FROM forum_threads ft, users u WHERE fp.ftid = ft.ftid AND u.uid = fp.uid;

CREATE INDEX forum_posts_textsearch_index ON forum_posts USING gin(textsearch);

/*CREATE OR REPLACE FUNCTION update_forum_post() RETURNS "trigger"
AS $_X$
	my $query = spi_prepare(q{UPDATE forum_posts fp
		SET textsearch = setweight(to_tsvector(coalesce(ft.subject,'')), 'A')
			|| setweight(to_tsvector(coalesce(u.username,'')), 'B')
			|| setweight(to_tsvector(coalesce(fp.message,'')), 'D')
		FROM forum_threads ft, users u 
		WHERE fp.ftid = ft.ftid AND u.uid = fp.uid AND fp.fpid = $1},'int4');
	spi_exec_prepared($query,$_TD->{new}{fpid});
	spi_freeplan($query);
$_X$
    LANGUAGE plperl;
*/
CREATE OR REPLACE FUNCTION update_forum_post() RETURNS "trigger"
AS $_X$
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
$_X$
    LANGUAGE plpgsql;

CREATE TRIGGER update_forum_post
    BEFORE INSERT OR UPDATE ON forum_posts
    FOR EACH ROW
    EXECUTE PROCEDURE update_forum_post();
