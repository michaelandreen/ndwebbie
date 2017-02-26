CREATE OR REPLACE FUNCTION escape_html(_unescaped text) RETURNS text
    AS $_$
DECLARE
BEGIN
	_unescaped := replace(_unescaped, '&', '&amp;');
	_unescaped := replace(_unescaped, '"', '&quot;');
	_unescaped := replace(_unescaped, '<', '&lt;');
	_unescaped := replace(_unescaped, '>', '&gt;');
	RETURN _unescaped;
END;
$_$
    LANGUAGE plpgsql IMMUTABLE;

