
CREATE OR REPLACE FUNCTION resetnet(
	)
    RETURNS void
    LANGUAGE 'plpgsql'
AS $BODY$

BEGIN

	ALTER SEQUENCE node_nodeid_seq RESTART WITH 1;

	delete from node;

	delete from node_adjacency;

	delete from arc_replacement;

	delete from node_arc_replacement;

	delete from arcspeed;

	delete from arc;

	ALTER SEQUENCE arc_arcid_seq RESTART WITH 1;


END;
$BODY$;

ALTER FUNCTION resetnet()
    OWNER TO ...;
