
CREATE OR REPLACE FUNCTION physnet.infer_nodes(
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
	v_nodes geometry[];
BEGIN
	select numericval
	into v_nodetol
	from params
	where acronym = 'NODETOLERANCE';

	for v_rec in (select fromnode, tonode
		from arc)
	loop
		v_nodes := ARRAY[v_rec.fromnode, v_rec.tonode];

		for v_rec2 in (select unnest(v_nodes) gnode)
		loop

			with ps as (select arcid
			from arc
			where usable and ST_DWithin(fromnode,v_rec2.gnode,v_nodetol))
			select array_agg(arcid)
			into v_outarcs
			from ps;

			with ps1 as (select arcid
			from arc
			where usable and ST_DWithin(tonode,v_rec2.gnode,v_nodetol))
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
				select nextval('node_nodeid_seq'::regclass)
				into v_nodeid;

				insert into node
				(nodeid, all_arcs, incoming_arcs, outgoing_arcs)
				values (v_nodeid, v_allarcs, v_inarcs, v_outarcs);
			EXCEPTION WHEN unique_violation THEN
				continue;
			END;

		end loop;
	end loop;

END;
$BODY$;

ALTER FUNCTION physnet.infer_nodes()
    OWNER TO ....;
