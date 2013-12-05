/*
--Returns the following :
Table
(
  id integer,			-- The edge's ID
  geom geometry, 		-- The geometry (is partial if factor <> 1)
  factor double precision 	-- How much of the original edge (based on length) did we take
);
*/

/*
networkReach parameters:
1: The edge table
2: The cost field in the edgeTable to base calculations on 
3: The geometry field in the edgeTable
4: Id of the starting point in the vertices_tmp table
5: Network reach distance (in units of the edge table cost column)
*/
CREATE OR REPLACE FUNCTION parkering_routing.networkReachPartial(edgeTable regclass, costfield character varying, geomfield character varying, startnode integer, networkReachDistance double precision)
RETURNS TABLE(id integer, geom geometry, factor double precision) AS
$BODY$
  DECLARE
	-- nothing to declare here, we now return a table instead of declaring types
  BEGIN

    -- Create a temporary table for the network whilst we process it
    -- DROP on commit so we do not get problems reusing it again in this session
    CREATE TEMP TABLE tempNetwork
    (
      id integer NOT NULL,
      geom geometry NOT NULL,
      factor double precision NOT NULL
    ) 
    ON COMMIT DROP; 


    EXECUTE '    
    INSERT INTO tempNetwork(id, geom, factor)
    SELECT et.id, et.' || format('%s',geomfield) || ' AS geom, 1 as factor
    FROM
        (SELECT id1,cost from pgr_drivingDistance(
          ''SELECT id, source, target, ' || quote_ident(costField) || ' AS cost FROM ' || format('%s',edgeTable) || ''',
          ' || format('%s',startnode) || ',' || format('%s', networkReachDistance) || ',false,false)
         ) firstPath
    CROSS JOIN 
        (SELECT id1,cost from pgr_drivingDistance(
          ''SELECT id, source, target, ' || quote_ident(costField) || ' AS cost FROM ' || format('%s',edgeTable) || ''',
          ' || format('%s',startnode) || ',' || format('%s', networkReachDistance) || ',false,false)
         ) secondPath
    INNER JOIN ' || format('%s',edgeTable) || ' et 
    ON firstPath.id1 = et.source
    AND secondPath.id1 = et.target;';

    EXECUTE format('
    INSERT INTO tempNetwork(id, geom, factor)
    SELECT allNodes.id, st_line_substring(allNodes.geom, 0.0, (' || format('%s', networkReachDistance) || '-allNodes.distance)/allNodes.Cost), (' || format('%s', networkReachDistance) || '-allNodes.distance)/allNodes.Cost AS factor
    FROM
      (SELECT reachNodes.id1, et.id, et.cost, reachNodes.cost distance, et.' || format('%s',geomfield) || '
       FROM
         (SELECT id1, cost FROM pgr_drivingDistance(
         ''SELECT id, source, target, ' || quote_ident(costField) || ' AS cost FROM ' || format('%s',edgeTable) || ''',
         ' || format('%s',startnode) || ',' || format('%s', networkReachDistance) || ',false,false)
         ) reachNodes
      JOIN (SELECT p.id, p.target, p.source, p.' || quote_ident(costField) || ' AS cost, p.geom FROM ' || format('%s',edgeTable) || ' p) et ON reachNodes.id1 = et.source
      ORDER BY reachNodes.id1
     ) allNodes
    FULL OUTER JOIN tempNetwork
    ON tempNetwork.id = allNodes.id
    WHERE tempNetwork.id IS NULL;', edgeTable);

    EXECUTE format('
    INSERT INTO tempNetwork(id, geom, factor)
    SELECT allNodes.id, st_line_substring(allNodes.geom,1-((' || format('%s', networkReachDistance) || '-allNodes.distance)/allNodes.Cost),1), (' || format('%s', networkReachDistance) || '-allNodes.distance)/allNodes.Cost AS factor
    FROM
      (SELECT reachNodes.id1, et.id, et.cost, reachNodes.cost distance, et.' || format('%s',geomfield) || '
       FROM
         (SELECT id1, cost FROM pgr_drivingDistance(
         ''SELECT id, source, target, ' || quote_ident(costField) || ' AS cost FROM ' || format('%s',edgeTable) || ''',
         ' || format('%s',startnode) || ',' || format('%s', networkReachDistance) || ',false,false)
         ) reachNodes
       JOIN (SELECT p.id, p.target, p.source, p.' || quote_ident(costField) || ' AS cost, p.' || format('%s',geomfield) || ' FROM ' || format('%s',edgeTable) || ' p) et ON reachNodes.id1 = et.target
       ORDER BY reachNodes.id1
      ) allNodes
    FULL OUTER JOIN tempNetwork
    ON tempNetwork.id = allNodes.id
    WHERE tempNetwork.id IS NULL;', edgeTable);

  
    RETURN QUERY SELECT t.id, t.geom, t.factor FROM tempNetwork t;
  
END;
$BODY$
  LANGUAGE plpgsql;