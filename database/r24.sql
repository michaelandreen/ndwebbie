ALTER TABLE ship_stats RENAME COLUMN target TO t1;
ALTER TABLE ship_stats ADD t2 text;
ALTER TABLE ship_stats ADD t3 text;
/*scan_id has gotten bigger*/
ALTER TABLE scans ALTER COLUMN scan_id TYPE NUMERIC(10);
