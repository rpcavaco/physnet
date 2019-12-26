


CREATE OR REPLACE FUNCTION physnet.collect_arcs(
	)
    RETURNS TABLE(param text, val integer)
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
    ROWS 1000
AS $BODY$
DECLARE
	v_rec record;
	v_sqlf text;
	v_sqlp text;
	--v_costfsc text;
	v_nodetol numeric;
BEGIN
	--v_costfsc := 'physnet';
	v_sqlp := 'insert into arc (srcid, srcarcid, dircosts, invcosts, arcgeom, fromnode, tonode) ';

	select numericval
	into v_nodetol
	from params
	where acronym = 'NODETOLERANCE';

	for v_rec in (select sid,
		schemaname as sc, tablename as tn, oidfield as oidf, geomfield as geof,
		costfunction as cf
		from sources
	)
	loop
		v_sqlf := v_sqlp || ' select ' || v_rec.sid || ' srcid, ' || v_rec.oidf || ' srcarcid, ' ||
		  '(' || v_rec.cf || '(' || v_rec.oidf || ')).o_dircosts, ' ||
		  '(' || v_rec.cf || '(' || v_rec.oidf || ')).o_invcosts, ' ||
		  v_rec.geof || ' arcgeom, ' ||
		  'st_line_interpolate_point(' || v_rec.geof || ', 0.0) fromnode, ' ||
		  'st_line_interpolate_point(' || v_rec.geof || ', 1.0) tomnode ' ||
		  'from ' || v_rec.sc || '.' || v_rec.tn;

		execute v_sqlf;
	end loop;

	update arc
	set usable = true
	where st_length(arcgeom) >= v_nodetol;

	update arc
	set usable = false
	where st_length(arcgeom) < v_nodetol;

	select count(*)
	into val
	from arc
	where usable;

	param := 'usable';
	return next;

	select count(*)
	into val
	from arc
	where not usable;

	param := 'unusable';
	return next;

END
$BODY$;

ALTER FUNCTION collect_arcs()
    OWNER TO ......;
