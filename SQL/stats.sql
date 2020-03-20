CREATE OR REPLACE FUNCTION physnet.stats(
	)
    RETURNS TABLE(out_label text, out_value text)
    LANGUAGE 'plpgsql'

    COST 100
    STABLE
    ROWS 1000
AS $BODY$
DECLARE
	v_rec record;
	v_intval integer;
BEGIN

	out_label := 'number of arcs';
	select count(*)
	into v_intval
	from arc
	where not rejected;
	out_value := v_intval::text;
	return next;

	out_label := 'rejected arcs';
	select count(*)
	into v_intval
	from arc
	where rejected;
	out_value := v_intval::text;
	return next;

	out_label := 'total of nodes';
	select count(*)
	into v_intval
	from node;
	out_value := v_intval::text;
	return next;

	out_label := 'node cardinality (min, avg, max)';
	with ps as (select array_length(all_arcs, 1) card
	from node)
	select min(card) minc, round(avg(card), 2) avgc, max(card) maxc
	into v_rec
	from ps;
	out_value := format('%s; %s; %s', v_rec.minc, v_rec.avgc, v_rec.maxc);
	return next;

END;
$BODY$;

ALTER FUNCTION physnet.stats()
    OWNER TO ....;
