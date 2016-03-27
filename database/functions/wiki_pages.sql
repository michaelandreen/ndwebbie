CREATE OR REPLACE FUNCTION update_wiki_page() RETURNS trigger
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
$$ LANGUAGE plpgsql;

