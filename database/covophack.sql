CREATE OR REPLACE FUNCTION max_bank_hack(metal bigint, crystal bigint, eonium bigint, tvalue integer, value integer, agents integer) RETURNS integer
    AS $_$
SELECT LEAST(2000.0*$6*$4/$5, $1*0.10, $6*10000.0)::integer
    + LEAST(2000.0*$6*$4/$5, $2*0.10, $6*10000.0)::integer
    + LEAST(2000.0*$6*$4/$5, $3*0.10, $6*10000.0)::integer
$_$
    LANGUAGE sql IMMUTABLE;


CREATE OR REPLACE FUNCTION max_bank_hack(metal bigint, crystal bigint, eonium bigint, tvalue integer, value integer) RETURNS integer
    AS $_$
SELECT LEAST(2000.0*15*$4/$5,$1*0.10, 15*10000.0)::integer
    + LEAST(2000.0*15*$4/$5,$2*0.10, 15*10000.0)::integer
    + LEAST(2000.0*15*$4/$5,$3*0.10, 15*10000.0)::integer
$_$
    LANGUAGE sql IMMUTABLE;
