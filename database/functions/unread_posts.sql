CREATE OR REPLACE FUNCTION unread_posts(IN uid int, OUT unread int, OUT "new" int) AS
$SQL$
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
$SQL$ LANGUAGE sql STABLE;
