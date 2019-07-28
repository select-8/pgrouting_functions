--DROP FUNCTION IF EXISTS pgr_fromPoint2Point;
DROP FUNCTION IF EXISTS pgr_fromCoord2Coord;
CREATE OR REPLACE FUNCTION pgr_fromCoord2Coord(
    IN network_table varchar,
    IN x1 double precision,
    IN y1 double precision,
    IN floorFrom varchar,
    IN x2 double precision,
    IN y2 double precision,
    IN floorTo varchar,
    IN srid INTEGER,
    OUT seq INTEGER,
    OUT cost FLOAT,
    OUT floor varchar,
    OUT geom geometry)
RETURNS SETOF record AS
$BODY$

WITH
dijkstra AS (
    SELECT * FROM pgr_dijkstra(
        'SELECT id, source, target, cost_len AS cost FROM ' || $1,
        -- source
        (select
                a.id
            from
                ways.network_vertices_pgr a, ways.network b
                where a.id IN (b.source,b.target) AND b.floor = $4
            ORDER BY 
                a.the_geom <-> ST_SetSRID(ST_Point($2,$3),$8) LIMIT 1),
        -- target
        (select
                a.id
            from
                ways.network_vertices_pgr a, ways.network b
                where a.id IN (b.source,b.target) AND b.floor = $7
            ORDER BY 
                a.the_geom <-> ST_SetSRID(ST_Point($5,$6),$8) LIMIT 1),
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
    FROM with_geom;
$BODY$
LANGUAGE 'sql';