-- FUNCTION: physnet.collect_arcs()

-- DROP FUNCTION physnet.collect_arcs();

CREATE OR REPLACE FUNCTION physnet.collect_arcs(
	)
    RETURNS TABLE (param text, val integer)
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
AS $BODY$
DECLARE
	v_rec record;
	v_sqlf text;
	v_sqlp text;
	v_costfsc text;
	v_nodetol numeric;
BEGIN
	v_costfsc := 'physnet';
	v_sqlp := 'insert into physnet.arc (srcid, srcarcid, dircosts, invcosts, arcgeom, fromnode, tonode) ';

	select numericval
	into v_nodetol
	from physnet.params
	where acronym = 'NODETOLERANCE';

	for v_rec in (select sid,
		schemaname as sc, tablename as tn, oidfield as oidf, geomfield as geof,
		costfunction as cf
		from physnet.sources
	)
	loop
		v_sqlf := v_sqlp || ' select ' || v_rec.sid || ' srcid, ' || v_rec.oidf || ' srcarcid, ' ||
		  '(' || v_costfsc || '.' || v_rec.cf || '(' || v_rec.oidf || ')).o_dircosts, ' ||
		  '(' || v_costfsc || '.' || v_rec.cf || '(' || v_rec.oidf || ')).o_invcosts, ' ||
		  v_rec.geof || ' arcgeom, ' ||
		  'st_line_interpolate_point(' || v_rec.geof || ', 0.0) fromnode, ' ||
		  'st_line_interpolate_point(' || v_rec.geof || ', 1.0) tomnode ' ||
		  'from ' || v_rec.sc || '.' || v_rec.tn;

		execute v_sqlf;
	end loop;

	update physnet.arc
	set usable = true
	where st_length(arcgeom) >= v_nodetol;

	update physnet.arc
	set usable = false
	where st_length(arcgeom) < v_nodetol;

	select count(*)
	into val
	from physnet.arc
	where usable;

	param := 'usable';
	return next;

	select count(*)
	into val
	from physnet.arc
	where not usable;

	param := 'unusable';
	return next;

END
$BODY$;

ALTER FUNCTION physnet.collect_arcs()
    OWNER TO itinerarium;
