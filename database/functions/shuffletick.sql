CREATE OR REPLACE FUNCTION isshuffletick() RETURNS boolean
AS $$SELECT (SELECT value::integer FROM misc WHERE id = 'TICK') = (SELECT value::integer FROM misc WHERE id = 'SHUFFLETICK')$$
LANGUAGE sql STABLE;
