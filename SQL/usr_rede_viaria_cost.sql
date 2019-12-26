-- FUNCTION: physnet.usr_rede_viaria_cost(integer)

-- DROP FUNCTION physnet.usr_rede_viaria_cost(integer);

CREATE OR REPLACE FUNCTION physnet.usr_rede_viaria_cost(
	p_oid integer)
    RETURNS TABLE(o_dircosts numeric[], o_invcosts numeric[])
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
	from physnet.params
	where acronym = 'WALKVEL_MPS';

	-- Array de custos devolvido contém valores para dois tipos de custo de deslocação, por esta ordem:
	-- - custo pedonal
	-- - custo rodoviário

	with psa as (
		select lower(oneway) ow, st_length(the_geom) lv, "V_M_S" vms
		from base.rede_viaria
		where gid = p_oid
	), psb as (
		select lv / v_wvel as wtime , lv / vms as rtime
		from psa
	)
	select
	case
	when psa.ow = 'n' or psa.ow = 'tf'
	then ARRAY[psb.wtime, -1.0]
	else ARRAY[psb.wtime, psb.rtime]
	end as fromcosts,
	case
	when psa.ow = 'n' or psa.ow = 'ft'
	then ARRAY[psb.wtime, -1.0]
	else ARRAY[psb.wtime, psb.rtime]
	end as tocosts
	into o_dircosts, o_invcosts
	from psa, psb;

	return next;
END;
$BODY$;

ALTER FUNCTION physnet.usr_rede_viaria_cost(integer)
    OWNER TO itinerarium;
