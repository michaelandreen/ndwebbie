CREATE FUNCTION mmdd(d date) RETURNS text AS $SQL$ SELECT to_char($1,'MM-DD') $SQL$ LANGUAGE SQL IMMUTABLE;

