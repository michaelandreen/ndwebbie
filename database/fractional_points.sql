ALTER TABLE users ALTER COLUMN defense_points TYPE NUMERIC(4,1);
ALTER TABLE users ALTER COLUMN attack_points TYPE NUMERIC(3,0);
UPDATE users set humor_points = -100 where humor_points < -100;
ALTER TABLE users ALTER COLUMN humor_points TYPE NUMERIC(3,0);
ALTER TABLE users ALTER COLUMN scan_points TYPE NUMERIC(5,0);
