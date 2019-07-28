
## [pgrouting](https://pgrouting.org/) functions for indoor networks

### pgr_cost2TypeInTime()
Calculates cost (aggrigated length) along a network from passed long/lat to all currently open assets of a passed type and returns a list of asset ids ordered by distance from given long\lat. Requires table of assets with types.

### pgr_fromAsset2Asset()
Routes from given feature id (*currently gid*) in some source table to given feature id in some target table. 


### pgr_fromCoordtoAsset()
##### Indoor
Routes from a given XY (with srid and floor value) to an given id in some table


### pgr_fromCoord2Coord()
##### Indoor
Routes from a given XY (with srid and floor value) to another given XY (with srid and floor value)

#### prerequisites: 
 - network table naming to follow osm standard (ways.network)
 - network attributed with _floor_ value