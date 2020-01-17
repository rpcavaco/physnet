
-- SELECT set_config('search_path', '$user", physnet_staging, public', false);

CREATE OR REPLACE FUNCTION infer_nodes(
	)
    RETURNS void
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS $BODY$
DECLARE
	v_rec record;
	v_rec2 record;
	v_nodetol numeric;
	v_nodeid integer;
	v_outarcs integer[];
	v_inarcs integer[];
	v_allarcs integer[];
BEGIN
	select numericval
	into v_nodetol
	from params
	where acronym = 'NODETOLERANCE';

	delete from node;

	ALTER SEQUENCE node_nodeid_seq RESTART WITH 1;

	for v_rec in (
		select ARRAY[fromnode, tonode] as nodes
		from arc where not rejected
	)
	loop
		for v_rec2 in (select unnest(v_rec.nodes) gnode)
		loop

			with ps as (select arcid
			from arc
			where not rejected and ST_DWithin(fromnode,v_rec2.gnode,v_nodetol))
			select array_agg(arcid)
			into v_outarcs
			from ps;

			with ps1 as (select arcid
			from arc
			where not rejected and ST_DWithin(tonode,v_rec2.gnode,v_nodetol))
			select array_agg(arcid)
			into v_inarcs
			from ps1;

			select array(
				select unnest(v_outarcs) a
				UNION
				select unnest(v_inarcs) a
				order by a
			)
			into v_allarcs;

			BEGIN
				insert into node
				(nodeid, all_arcs, incoming_arcs, outgoing_arcs, ispseudo)
				select nextval('node_nodeid_seq'::regclass),
					v_allarcs, v_inarcs, v_outarcs,
					(array_length(v_allarcs, 1) = 2);
			EXCEPTION WHEN unique_violation THEN
				continue;
			END;

		end loop;
	end loop;

END;
$BODY$;

ALTER FUNCTION infer_nodes()
    OWNER TO ...;
