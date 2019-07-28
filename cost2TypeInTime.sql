
DROP FUNCTION IF EXISTS pgr_cost2TypeInTime;

-- function calculates cost (aggrigated length) along a network from passed long/lat to all currently open assets of a passed type
-- and returns a list of asset ids ordered by distance from given long\lat

CREATE OR REPLACE FUNCTION pgr_cost2TypeInTime(
    IN long double precision,
    IN lat double precision,
    IN typeID integer,
    OUT agg_costs double precision,
    OUT id INTEGER,
    OUT gid INTEGER)
RETURNS SETOF record 
AS
$func$
DECLARE
 result record;
BEGIN
RETURN QUERY
EXECUTE format('
with agg_costs as (
    SELECT
        a.end_vid,
        a.agg_cost,
        b.geom,
        b.id
    from

        --
        -- use pgr_dijkstraCost to calculate cost along network from passed coordinate to passed asset type
        --

        pgr_dijkstraCost (
            $$select id, source, target, cost_len as cost from $$ || $1, 
                (select
                    id
                from
                    ways.network_vertices_pgr
                ORDER BY
                    geom <-> st_transform(
                    st_setsrid(
                    ST_makePoint($2,$3),
                    4326),3857)
                LIMIT 1), (with sources as (
                    select
                        sid,
                        aid
                    from (
                        SELECT
                            distinct on (a.id) b.id as sid,
                            a.id as aid
                        FROM
                            assets AS a, 
                            ways.network_vertices_pgr AS b
                        where
                            a.type_id = $4
                            and a.floor_id = 10
                        ORDER BY
                            a.id,st_centroid(a.geom) <-> b.geom) s)
                select
                    array(select sid from sources)),
                    false) as a,
                ways.network_vertices_pgr as b
            where
                a.end_vid = b.id
            order by
                a.agg_cost),

--
-- find asset ids again (could possibly be returned from subquery in previous statement?)
--

the_ids as (
    select
        sid,aid
    from (
        SELECT
            distinct on (a.id) b.id as sid,
            a.id as aid
        FROM
            assets AS a,
            ways.network_vertices_pgr AS b
        where
            a.type_id = $4
            and a.floor_id = 10
        ORDER BY
            a.id, st_centroid(a.geom) <-> b.geom) a
),

--
-- filter asset ids by if open
--

time_ids as ( select gid from (
                select b.geom_id as gid from opening_times as a, assets as b WHERE
                a.id = b.id AND
                a.day_of_week::integer = EXTRACT(DOW FROM $5) AND
                $5::time between a.opening_time and a.closing_time
            ) t )
SELECT
    a.agg_cost,
    b.aid,
    c.gid
from
    agg_costs as a,
    the_ids as b,
    time_ids as c
where
    a.id = b.sid
    and
    b.aid = c.gid;') 
    using ways.network, long, lat, typeID;
END
$func$
LANGUAGE PLPGSQL;