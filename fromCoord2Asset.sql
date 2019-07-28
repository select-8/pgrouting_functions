DROP FUNCTION IF EXISTS pgr_fromCoord2Asset;
CREATE OR REPLACE FUNCTION pgr_fromCoord2Asset(
    IN network_table varchar,
    IN _tbl regclass,
    IN x1 double precision,
    IN y1 double precision,
    IN floorFrom varchar,
    IN tgid varchar,
    IN srid INTEGER,
    OUT seq INTEGER,
    OUT cost FLOAT,
    OUT floor varchar,
    OUT geom geometry)
RETURNS SETOF record 
AS
$func$
DECLARE
 result record;
BEGIN
RETURN QUERY
EXECUTE format('
WITH
dijkstra AS (
    SELECT * FROM pgr_dijkstra(
        $$SELECT id, source, target, cost_len AS cost FROM $$ || $1, 
        (select
                a.id
            from
                ways.network_vertices_pgr a, ways.network b
                where a.id IN (b.source,b.target) AND b.floor = $4
        ORDER BY 
            a.the_geom <-> ST_SetSRID(ST_Point($2,$3),$6) LIMIT 1),
        (WITH tid AS (
        SELECT
            $$tid$$::varchar AS param,
            id::int
        from (
            select
                a.id, b.floor
            from
                ways.network_vertices_pgr a, ways.network b
                where a.id IN (b.source,b.target)
            Order by
                a.the_geom <-> (
                    SELECT CASE
                            WHEN geometrytype(geom) LIKE $$POLYGON$$
                                THEN st_centroid(geom)
                            ELSE geom 
                        END AS geom
                    FROM
                        %1s
                    WHERE
                        gid = $5 AND floor_id = b.floor)
                LIMIT 1) AS a)
        SELECT id FROM tid),
        false)
    ),
    with_geom AS (
        SELECT dijkstra.seq, dijkstra.cost, floor,
        CASE
            WHEN dijkstra.node = network.source THEN the_geom
            ELSE ST_Reverse(the_geom)
        END AS route_geom
        FROM dijkstra JOIN ways.network
        ON (edge = id) ORDER BY seq
    )
    SELECT *
    FROM with_geom;', _tbl, _tbl) using network_table, x1, y1, floorFrom, tgid, srid;
END
$func$
LANGUAGE PLPGSQL;

/*

SELECT
    seq, geom, floor
FROM
    pgr_fromCoord2Asset('ways.network','ce.assets',375041.666571, 164915.7938,'2','ax375078686584312ay164904805662317_f2_f3a5a7b935a703dbeb17b13772e30fbc',27700);

*/

