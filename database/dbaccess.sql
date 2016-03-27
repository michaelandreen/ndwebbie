/*
CREATE ROLE intel;
GRANT intel TO test;
*/

GRANT SELECT ON planets TO intel;
GRANT SELECT ON planet_stats TO intel;
GRANT SELECT ON current_planet_stats TO intel;
GRANT SELECT ON current_planet_stats_full TO intel;
GRANT SELECT ON galaxies TO intel;
GRANT SELECT ON alliances TO intel;
GRANT SELECT ON alliance_stats TO intel;
GRANT SELECT ON alliance_resources TO intel;
GRANT SELECT ON intel TO intel;
GRANT SELECT ON intel_scans TO intel;
GRANT SELECT ON scans TO intel;
GRANT SELECT ON fleets TO intel;
GRANT SELECT ON launch_confirmations TO intel;
GRANT SELECT ON fleet_scans TO intel;
GRANT SELECT ON fleet_ships TO intel;
GRANT SELECT ON planet_scans TO intel;
GRANT SELECT ON current_planet_scans TO intel;
GRANT SELECT ON development_scans TO intel;
GRANT SELECT ON current_development_scans TO intel;
GRANT SELECT ON full_intel TO intel;
GRANT SELECT ON planet_tags TO intel;
GRANT SELECT ON available_planet_tags TO intel;

GRANT EXECUTE ON FUNCTION coords(int,int,int) TO intel;
GRANT EXECUTE ON FUNCTION planetcoords(int,int) TO intel;
GRANT EXECUTE ON FUNCTION planetid(int,int,int,int) TO intel;
GRANT EXECUTE ON FUNCTION tick() TO intel;
GRANT EXECUTE ON FUNCTION endtick() TO intel;

ALTER FUNCTION tick() SECURITY DEFINER;
ALTER FUNCTION endtick() SECURITY DEFINER;
