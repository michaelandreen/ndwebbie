INSERT INTO forum_categories (fcid,category) VALUES(-1000, 'Private');
INSERT INTO forum_boards (fcid,fbid,board) VALUES(-1000, -1999, 'Private');

CREATE TABLE forum_priv_access (
	uid INTEGER REFERENCES users(uid),
	ftid INTEGER REFERENCES forum_threads(ftid),
	PRIMARY KEY(uid,ftid)
);

CREATE OR REPLACE FUNCTION unread_posts(IN uid int, OUT unread int, OUT "new" int) AS
$SQL$
	SELECT count(*)::int AS unread, count(NULLIF(fp.time > (SELECT max(time)
			FROM forum_thread_visits WHERE uid = $1),FALSE))::int AS new
		FROM forum_threads ft
			JOIN forum_posts fp USING (ftid)
			LEFT OUTER JOIN (SELECT * FROM forum_thread_visits
				WHERE uid = $1) ftv ON ftv.ftid = ft.ftid
		WHERE (ftv.time IS NULL OR fp.time > ftv.time) AND (
			(fbid > 0 AND fbid IN (SELECT fbid FROM forum_access
				WHERE gid IN (SELECT groups($1)))
			) OR ft.ftid IN (SELECT ftid FROM forum_priv_access WHERE uid = $1))
$SQL$ LANGUAGE sql STABLE;
