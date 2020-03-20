
CREATE OR REPLACE FUNCTION infer_nodes(
	)
    RETURNS void
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
	v_rec record;
	v_rec2 record;
	v_nodetol numeric;
	v_nodeid integer;
	v_outarcs integer[];
	v_inarcs integer[];
	v_allarcs integer[];
	v_card integer;
	v_connstatus character varying(6);
BEGIN
	select numericval
	into v_nodetol
	from params
	where acronym = 'NODETOLERANCE';

	delete from node;
	delete from node_adjacency;
	delete from arc_replacement;
	delete from node_arc_replacement;

	ALTER SEQUENCE node_nodeid_seq RESTART WITH 1;

	for v_rec in (
		select ARRAY[fromnode, tonode] as nodes
		from arc
		where reject_motive is null
	)
	loop
		for v_rec2 in (select unnest(v_rec.nodes) gnode)
		loop

			with ps as (select arcid
			from arc
			where reject_motive is null and ST_DWithin(fromnode,v_rec2.gnode,v_nodetol))
			select array_agg(arcid)
			into v_outarcs
			from ps;

			with ps1 as (select arcid
			from arc
			where reject_motive is null and ST_DWithin(tonode,v_rec2.gnode,v_nodetol))
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

			v_card := array_length(v_allarcs, 1);
			v_connstatus := null;

			-- Node is pseudo node if cardinality == 2 and
			-- 	serves no cul-de-sac
			if v_card = 2 then
				if not exists (
					select from arc
					where arcid = any (v_allarcs)
					and culdesac
				) then
						v_connstatus := 'PSEUDO';
				end if;
			elsif v_card = 1 then
				v_connstatus := 'DANGLE';
			end if;

			BEGIN
				insert into node
				(nodeid, all_arcs, incoming_arcs, outgoing_arcs, connstatus, geom)
				select nextval('node_nodeid_seq'::regclass),
					v_allarcs, v_inarcs, v_outarcs, v_connstatus, v_rec2.gnode;
			EXCEPTION WHEN unique_violation THEN
				continue;
			END;

		end loop;
	end loop;

END;
$BODY$;

ALTER FUNCTION infer_nodes()
    OWNER TO ...;
