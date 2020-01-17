-- FUNCTION: physnet.resetnet()

-- DROP FUNCTION physnet.resetnet();

CREATE OR REPLACE FUNCTION physnet.resetnet(
	)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS $BODY$

BEGIN

	ALTER SEQUENCE arc_arcid_seq RESTART WITH 1;

	delete from arcspeed;

	delete from arc;

	ALTER SEQUENCE node_nodeid_seq RESTART WITH 1;

	delete from node;

	delete from node_adjacency;

END;
$BODY$;

ALTER FUNCTION physnet.resetnet()
    OWNER TO ...;
