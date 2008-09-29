ALTER TABLE users ADD birthday DATE;

CREATE FUNCTION mmdd(d date) RETURNS text AS $SQL$ SELECT to_char($1,'MM-DD') $SQL$ LANGUAGE SQL IMMUTABLE;

CREATE INDEX users_birthday_index ON users (mmdd(birthday)) WHERE birthday IS NOT NULL;
