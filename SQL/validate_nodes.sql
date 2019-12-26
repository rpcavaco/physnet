
CREATE OR REPLACE FUNCTION validate_nodes(
	)
    RETURNS TABLE(out_arcid integer, out_nodecount integer)
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS $BODY$
DECLARE
	v_rec record;
	v_rec2 record;
BEGIN
	for v_rec in (select arcid
		from arc)
	loop

		for v_rec2 in (
			select count(*) cnt from node
			where all_arcs @> ARRAY[v_rec.arcid]

			--v_rec.arcid = any(all_arcs)
		)
		loop

		--if v_rec2.cnt != 2 then -- 20191226 -- cardinalidade UM é admitida como representação do CUL-DE-SAC
			if v_rec2.cnt > 2 then

				out_arcid := v_rec.arcid;
				out_nodecount := v_rec2.cnt;

				if v_rec2.cnt = 0 then
					update arc
					set usable = false
					where arcid = out_arcid;
				end if;

				return next;

			end if;


		end loop;
	end loop;

eND;
$BODY$;

ALTER FUNCTION validate_nodes()
    OWNER TO ......;
