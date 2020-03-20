-- FUNCTION: physnet_staging.rotateleft_azimuth(geometry, geometry, geometry)

-- DROP FUNCTION physnet_staging.rotateleft_azimuth(geometry, geometry, geometry);

CREATE OR REPLACE FUNCTION rotateleft_azimuth(
	p_pt1 geometry,
	p_pt2 geometry,
	opt_ptprev geometry)
    RETURNS numeric
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
	v1 numeric;
	v_offset numeric;
	ret numeric;
	v_q4 numeric;
BEGIN
	v_q4 := pi() * 2.0;

	if st_geometrytype(p_pt1) != 'ST_Point' then
		raise exception 'p_pt1 is not a point';
	end if;
	if st_geometrytype(p_pt2) != 'ST_Point' then
		raise exception 'p_pt2 is not a point';
	end if;

	v_offset := 0.0;
	if not opt_ptprev is null then
		v_offset := ST_Azimuth(p_pt1, opt_ptprev);
	end if;

	v1 := ST_Azimuth(p_pt1, p_pt2) - v_offset;

	if v1 < 0 then
		v1 := v_q4 + v1;
	end if;

	ret := mod(v1, v_q4);

	return ret;
END;
$BODY$;

ALTER FUNCTION rotateleft_azimuth(geometry, geometry, geometry)
    OWNER TO ...;
