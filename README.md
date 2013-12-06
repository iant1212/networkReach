networkReach
============

Requirements:
> at least PostGIS 2.0, pgRouting 2.0

This SQL function finds the network reach from a given node for the input distance.

This SQL function returns all the edges associated with accessible nodes on the network within the input distance,
and returns partial edges when the last node is not accessible but some part of the edge is within the accessible 
distance.

The function takes as arguments the edge table name, the geometry field, the cost, the startnode, and the maximum cost in the network (calculated on said cost field)
Also the edge table needs to have a unique id field named 'id'.

The function no longer uses a custom type, but declares the table type returned.

============
Things to do
=========================

