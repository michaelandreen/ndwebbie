CREATE OR REPLACE VIEW current_development_scans AS
SELECT DISTINCT ON (pid) ds.*
FROM development_scans ds
ORDER BY pid, tick DESC, id DESC;

CREATE OR REPLACE VIEW current_planet_scans AS
SELECT DISTINCT ON (planet) ps.*
FROM planet_scans ps
ORDER BY planet, tick DESC, id DESC;

CREATE OR REPLACE VIEW current_structure_scans AS
SELECT DISTINCT ON (planet) ss.*
FROM structure_scans ss
ORDER BY planet, tick DESC, id DESC;

CREATE OR REPLACE VIEW current_tech_scans AS
SELECT DISTINCT ON (planet) ts.*
FROM tech_scans ts
ORDER BY planet, tick DESC, id DESC;
