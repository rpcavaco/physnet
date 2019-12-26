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

	ALTER SEQUENCE physnet.arc_arcid_seq RESTART WITH 1;

	delete from physnet.arc;

	ALTER SEQUENCE physnet.node_nodeid_seq RESTART WITH 1;

	delete from physnet.node;

END;
$BODY$;

ALTER FUNCTION physnet.resetnet()
    OWNER TO itinerarium;
