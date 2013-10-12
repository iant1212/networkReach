/*
--create the following TYPE in your database:
CREATE TYPE networkReachType AS
(
  id integer,
  the_geom geometry
);
*/

/*
networkReach parameters:
1: id of the starting point in the vertices_tmp table
2: network reach distance (in units of the edge table cost column)
*/

CREATE OR REPLACE FUNCTION networkReach(integer, integer)
RETURNS SETOF networkReachType AS
$BODY$
  DECLARE
    startNode ALIAS FOR $1;
    networkReachDistance ALIAS FOR $2;

    networkReach networkReachType;
  BEGIN
  
    CREATE TEMP TABLE tempNetwork
    (
      id integer NOT NULL,
      the_geom geometry NOT NULL
    );
        
    INSERT INTO tempNetwork(id, the_geom)
    SELECT s.id edgeID, s.the_geom
    FROM
        (SELECT id1,cost from pgr_drivingDistance(
	  'SELECT id, source, target, cost FROM streets',
	  startNode,networkReachDistance,false,false)
	 ) firstPath
    CROSS JOIN 
        (SELECT id1,cost from pgr_drivingDistance(
	  'SELECT id, source, target, cost FROM streets',
	  startNode,networkReachDistance,false,false)
	 ) secondPath
    INNER JOIN streets s
    ON firstPath.id1 = s.source
    AND secondPath.id1 = s.target;

    INSERT INTO tempNetwork(id, the_geom)
    SELECT allNodes.id, st_linesubstring(allNodes.the_geom, 0.0, (networkReachDistance-allNodes.distance)/allNodes.Cost) 
    FROM
      (SELECT reachNodes.id1, s1.id, s1.cost, reachNodes.cost distance, s1.the_geom
       FROM
         (SELECT id1, cost FROM pgr_drivingDistance(
	 'SELECT id, source, target, cost FROM streets',
	 startNode,networkReachDistance,false,false)
	 ) reachNodes
      JOIN (SELECT id, target, source, cost, the_geom FROM streets) s1 ON reachNodes.id1 = s1.source
      ORDER BY reachNodes.id1
     ) allNodes
    FULL OUTER JOIN tempNetwork
    ON tempNetwork.id = allNodes.id
    WHERE tempNetwork.id IS NULL;

    INSERT INTO tempNetwork(id, the_geom)
    SELECT allNodes.id, st_linesubstring(allNodes.the_geom,1-((networkReachDistance-allNodes.distance)/allNodes.Cost),1) 
    FROM
      (SELECT reachNodes.id1, s1.id, s1.cost, reachNodes.cost distance, s1.the_geom
       FROM
         (SELECT id1, cost FROM pgr_drivingDistance(
	 'SELECT id, source, target, cost FROM streets',
	 startNode,networkReachDistance,false,false)
	 ) reachNodes
       JOIN (SELECT id, target, source, cost, the_geom FROM streets) s1 ON reachNodes.id1 = s1.target 
       ORDER BY reachNodes.id1
      ) allNodes
    FULL OUTER JOIN tempNetwork
    ON tempNetwork.id = allNodes.id
    WHERE tempNetwork.id IS NULL;

  FOR networkReach IN SELECT * FROM tempNetwork
  LOOP
    RETURN NEXT networkReach;
  END LOOP;
END;
$BODY$
  LANGUAGE plpgsql;
