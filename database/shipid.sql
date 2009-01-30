ALTER TABLE ship_stats ADD id SERIAL UNIQUE NOT NULL;
UPDATE ship_stats SET id = id - 3;
