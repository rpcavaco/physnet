CREATE OR REPLACE FUNCTION resetnet(
	)
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS $BODY$

BEGIN

	ALTER SEQUENCE arc_arcid_seq RESTART WITH 1;

	delete from arc;

	ALTER SEQUENCE node_nodeid_seq RESTART WITH 1;

	delete from node;

	delete from node_adjacency;

END;
$BODY$;

ALTER FUNCTION resetnet()
    OWNER TO <your owner>;
