CREATE TABLE wiki_namespaces (
	namespace VARCHAR(16) PRIMARY KEY
);

CREATE TABLE wiki_pages (
	wpid SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	namespace TExt NOT NULL REFERENCES wiki_namespaces(namespace) DEFAULT '',
	textsearch tsvector NOT NULL DEFAULT to_tsvector(''),
	UNIQUE(namespace,name)
);

CREATE INDEX wiki_pages_textsearch_index ON wiki_pages USING gin (textsearch);

CREATE TABLE wiki_page_revisions (
	wpid INTEGER REFERENCES wiki_pages(wpid),
	wprev SERIAL NOT NULL PRIMARY KEY,
	parent INTEGER REFERENCES wiki_page_revisions(wprev),
	text TEXT NOT NULL,
	comment TEXT NOT NULL,
	time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	uid INTEGER REFERENCES users(uid)
);

ALTER TABLE wiki_pages ADD COLUMN wprev INTEGER REFERENCES wiki_page_revisions(wprev);

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
	return NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_wiki_page
	BEFORE UPDATE ON wiki_pages
	FOR EACH ROW
	EXECUTE PROCEDURE update_wiki_page();

CREATE TABLE wiki_namespace_access (
	namespace TEXT NOT NULL REFERENCES wiki_namespaces(namespace),
	gid INTEGER NOT NULL REFERENCES groups(gid),
	edit BOOL NOT NULL DEFAULT FALSE,
	post BOOL NOT NULL DEFAULT FALSE,
	moderate BOOL NOT NULL DEFAULT FALSE,
	PRIMARY KEY(gid,namespace)
);

CREATE TABLE wiki_page_access (
	wpid INTEGER NOT NULL REFERENCES wiki_pages(wpid),
	uid INTEGER NOT NULL REFERENCES users(uid),
	edit BOOL NOT NULL DEFAULT FALSE,
	moderate BOOL NOT NULL DEFAULT FALSE,
	PRIMARY KEY(uid,wpid)
);

INSERT INTO wiki_namespaces VALUES ('');
INSERT INTO wiki_namespaces VALUES ('Members');
INSERT INTO wiki_namespaces VALUES ('HC');
INSERT INTO wiki_namespaces VALUES ('Tech');
INSERT INTO wiki_namespaces VALUES ('Info');

INSERT INTO wiki_pages (name,namespace) VALUES('Main','Info');
INSERT INTO wiki_page_revisions (wpid,text,comment,uid) VALUES(1,'Welcome to the main page!', 'First revision', 1);
UPDATE wiki_pages set wprev = 1 WHERE wpid = 1;

