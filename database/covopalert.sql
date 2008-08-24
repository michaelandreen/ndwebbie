
CREATE OR REPLACE FUNCTION covop_alert(secs integer, strucs integer, roids integer
	, guards integer, gov governments, population integer) RETURNS integer
	AS $_$
	SELECT ((50 + COALESCE($4*5.0/($3+1.0),$6))
		* (1.0+LEAST(COALESCE($1::float/$2,$6),0.30)*2
			+ (CASE $5
				WHEN 'Dic' THEN 0.20
				WHEN 'Feu' THEN -0.20
				WHEN 'Uni' THEN -0.10
				ELSE 0
			END) + $6/100.0
		))::integer;
$_$
	LANGUAGE sql IMMUTABLE;
