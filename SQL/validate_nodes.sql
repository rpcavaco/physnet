
CREATE OR REPLACE FUNCTION validate_nodes(
	)
    RETURNS TABLE(out_arcid integer, out_nodecount integer)
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
	v_rec record;
	v_rec2 record;
BEGIN
	for v_rec in (select arcid
		from arc
		where reject_motive is null)
	loop

		for v_rec2 in (
			select count(*) cnt from node
			where all_arcs @> ARRAY[v_rec.arcid]
		)
		loop

			if v_rec2.cnt = 0 then
				update arc
				set reject_motive = 'NONODES'
				where arcid = v_rec.arcid;
			end if;

			if v_rec2.cnt > 2 then

				out_arcid := v_rec.arcid;
				out_nodecount := v_rec2.cnt;
				return next;

			end if;

		end loop;
	end loop;

eND;
$BODY$;

ALTER FUNCTION validate_nodes()
    OWNER TO ...;
