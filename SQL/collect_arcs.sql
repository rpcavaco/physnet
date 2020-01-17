--SELECT set_config('search_path', '$user", physnet_staging, public', false);

CREATE OR REPLACE FUNCTION collect_arcs(p_limit_src int[])
    RETURNS TABLE(param text, val integer)
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
    ROWS 1000
AS $BODY$
DECLARE
	v_rec record;
	v_selA text;
	v_selB text;
	v_nodetol numeric;
	v_maxarcid integer;
BEGIN

	select numericval
	into v_nodetol
	from params
	where acronym = 'NODETOLERANCE';

	for v_rec in (select sid,
		schemaname as sc, tablename as tn, oidfield as oidf, geomfield as geof,
		speedfunction as sf
		from sources
	)
	loop
			if not p_limit_src is null and not ARRAY[v_rec.sid] <@ p_limit_src then
					continue;
			end if;

			delete from arcspeed ars
			where  exists (
				select from arc ar
				where  ar.arcid = ars.arcid
				and srcid = v_rec.sid
			);

			delete from arc
			where srcid = v_rec.sid;
	end loop;

	select coalesce(max(arcid), 0) + 1
	into v_maxarcid
	from arc;

	for v_rec in (select sid,
		schemaname as sc, tablename as tn, oidfield as oidf, geomfield as geof,
		speedfunction as sf, bidir_adjacency as bda
		from sources order by sid
	)
	loop

			execute format('ALTER SEQUENCE arc_arcid_seq RESTART WITH %s', v_maxarcid);

			v_selA := format('insert into arc (srcid, srcarcid, arcgeom, arclength, fromnode, tonode, bidir_adjacency) ' ||
							 'select $1 srcid, %I srcarcid, %I arcgeom, ST_Length(%I) arclength, ' ||
							 'st_lineinterpolatepoint(%I, 0.0) fromnode, ' ||
							 'st_lineinterpolatepoint(%I, 1.0) tonode, $2 bda from %I.%I',
							v_rec.oidf, v_rec.geof, v_rec.geof, v_rec.geof, v_rec.geof, v_rec.sc, v_rec.tn);

			execute v_selA using v_rec.sid, v_rec.bda;

			v_selB := format('insert into arcspeed (arcid, scenario, dirspeeds, revspeeds) ' ||
							 'select arcid, ''BASE'' scenario, (%I(srcarcid)).o_dirspeeds, (%I(srcarcid)).o_revspeeds from arc',
										v_rec.sf, v_rec.sf);

			execute v_selB;

	end loop;

	update arc
	set rejected = false
	where st_length(arcgeom) >= v_nodetol;

	update arc
	set rejected = true,
	reject_motive = 'TOOSHORT'
	where st_length(arcgeom) < v_nodetol;

	select count(*)
	into val
	from arc
	where not rejected;

	param := 'not_rejected';
	return next;

	select count(*)
	into val
	from arc
	where rejected;

	param := 'rejected';
	return next;

END
$BODY$;

ALTER FUNCTION collect_arcs(integer[])
    OWNER TO ...;
