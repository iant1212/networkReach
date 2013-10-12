networkReach
============

Requirements:
> at least PostGIS 2.0, pgRouting 2.0

This SQL function finds the network reach from a starting node for the input distance.

This SQL function returns all the edges associated with accessible nodes on the network within the input distance,
and returns partial edges when the last node is not accessible but some part of the edge is within the accessible 
distance.

The function currently uses a table named 'streets', the field for the distance value is named 'cost', and the field
for geometries is named 'the_geom'.

There is a custom type that needs to be created for this to work.  The SQL for creating the custom type is commented
out at the beginning of the networkReach.sql file.

============
Things to do
=========================
Add table name and cost field name parameters to the function so it can work on any database.

Make it so that any lon/lat input will find the closest point on the closest line and then do the network reach.
