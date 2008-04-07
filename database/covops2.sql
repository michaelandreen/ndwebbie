CREATE OR REPLACE FUNCTION covop_alert(secs integer, strucs integer, gov governments, population integer) RETURNS integer
    AS $_$
	SELECT (70*(1.0+LEAST(COALESCE($1::float/$2,$4),0.30)*2 +
		(CASE $3 
			WHEN 'Dic' THEN 0.20
			WHEN 'Feu' THEN -0.20
			WHEN 'Uni' THEN -0.10
			ELSE 0
		END) + $4/100.0))::integer;
$_$
    LANGUAGE sql IMMUTABLE;
