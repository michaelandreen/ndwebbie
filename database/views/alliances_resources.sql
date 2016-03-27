CREATE OR REPLACE VIEW alliance_resources AS
WITH planet_estimates AS (
	SELECT ps.tick, alliance, hidden,size,score,(metal+crystal+eonium) AS resources
		,score + (metal+crystal+eonium)/300 + hidden/100 AS nscore2
		,score + (metal+crystal+eonium)/300 + hidden/100 + (endtick()-tick())*(
			250*size + COALESCE(metal_ref + crystal_ref + eonium_ref,7)* 1000
			+ CASE extraction WHEN 0 THEN 3000 WHEN 1 THEN 11500 ELSE COALESCE(extraction,3)*3000*3 END
		)*(1.35+0.005*COALESCE(fincents,20))/100 AS nscore3
	FROM current_planet_stats p
		JOIN current_planet_scans ps USING (pid)
		LEFT OUTER JOIN current_development_scans ds USING (pid)
), planet_ranks AS (
	SELECT *, RANK() OVER(PARTITION BY alliance ORDER BY score DESC) AS rank FROM planet_estimates
), top_planets AS (
	SELECT alliance, sum(resources) AS resources, sum(hidden) AS hidden
		,sum(nscore2)::bigint AS nscore2, sum(nscore3)::bigint AS nscore3
		,count(*) AS planets, sum(score) AS score, sum(size) AS size
		,avg(tick)::int AS avgtick
	FROM planet_ranks WHERE rank <= 60
	GROUP BY alliance
)
SELECT aid,alliance,a.relationship,s.members,r.planets
	,s.score, r.score AS topscore, s.size, r.size AS topsize
	,r.resources,r.hidden
	,(s.score + (resources / 300) + (hidden / 100))::bigint AS nscore
	,nscore2, nscore3, avgtick
FROM alliances a
	JOIN top_planets r USING (alliance)
	LEFT OUTER JOIN (SELECT aid,score,size,members FROM alliance_stats
		WHERE tick = (SELECT max(tick) FROM alliance_stats)) s USING (aid)
;

