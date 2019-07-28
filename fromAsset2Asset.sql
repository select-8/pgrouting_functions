--DROP FUNCTION IF EXISTS pgr_fromA2IorI2A;
DROP FUNCTION IF EXISTS pgr_fromAsset2Asset;
CREATE OR REPLACE FUNCTION pgr_fromAsset2Asset(
    IN network_table varchar,
    IN _tblfrom regclass,
    IN _tblto regclass,
    IN sgid varchar,
    IN tgid varchar,
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
        (with sid as (
        SELECT
            $$sid$$::varchar as param,
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
                        %s
                    WHERE
                        gid = $2 AND floor_id = b.floor)
                LIMIT 1) AS a)
        SELECT id FROM sid),
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
                        gid = $3 AND floor_id = b.floor)
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
    FROM with_geom;', _tblfrom, _tblto) using network_table, sgid, tgid;
END
$func$
LANGUAGE PLPGSQL;
