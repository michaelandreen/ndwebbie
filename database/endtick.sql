CREATE FUNCTION endtick() RETURNS integer
AS $$SELECT value::integer FROM misc WHERE id = 'ENDTICK'$$
LANGUAGE sql STABLE;
