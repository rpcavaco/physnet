
CREATE OR REPLACE FUNCTION physnet.usr_rede_viaria_speeds(
	p_oid integer)
    RETURNS TABLE(o_dirspeeds numeric[], o_revspeeds numeric[])
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE
    ROWS 1000
AS $BODY$
DECLARE
	v_wvel numeric;
	v_wtime numeric;
BEGIN
	select numericval
	into v_wvel
	from params
	where acronym = 'WALKVEL_MPS';

	-- Array de custos devolvido contém valores para dois tipos de custo de deslocação, por esta ordem:
	-- - custo pedonal
	-- - custo rodoviário

	with psa as (
		select lower(oneway) ow, st_length(the_geom) lv, "V_M_S" vms
		from base.rede_viaria
		where gid = p_oid
	)
	select
	case
	when psa.ow = 'n' or psa.ow = 'tf'
	then ARRAY[v_wvel, -1.0]
	else ARRAY[v_wvel, psb.vms]
	end as dirspeeds,
	case
	when psa.ow = 'n' or psa.ow = 'ft'
	then ARRAY[v_wvel, -1.0]
	else ARRAY[v_wvel, psb.vms]
	end as invspeeds
	into o_dirspeeds, o_invspeeds
	from psa;

	return next;
END;
$BODY$;

ALTER FUNCTION physnet.usr_rede_viaria_speeds(integer)
    OWNER TO ...;
