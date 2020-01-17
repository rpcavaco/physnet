--SELECT set_config('search_path', '$user", physnet_staging, public', false);


CREATE OR REPLACE FUNCTION build_adjacency()
    RETURNS TABLE(out_min_nodeforarc_count integer, out_max_nodeforarc_count integer)
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE
    ROWS 1000
AS $BODY$
DECLARE
	v_fnode integer;
	v_tnode integer;
	v_rec record;
	c_arcs NO SCROLL CURSOR FOR select arcid, bidir_adjacency as bda
		from arc
		where not rejected;
	v_cnt integer;
BEGIN

	-- Clear adjacency table
	delete from node_adjacency;

	v_cnt := 0;
	-- Select all arc ids from usable arcs
	for v_rec in c_arcs
	loop
		--v_cnt := v_cnt + 1;

		SELECT nodeid FROM node
		where outgoing_arcs @> ARRAY[v_rec.arcid]
		INTO v_fnode;

		SELECT nodeid FROM node
		where incoming_arcs @> ARRAY[v_rec.arcid]
		INTO v_tnode;

		INSERT INTO node_adjacency
		(fromnode, tonode, arc, arcdirect)
		VALUES
		(v_fnode, v_tnode, v_rec.arcid, true);

		if v_rec.bda then
				INSERT INTO node_adjacency
				(fromnode, tonode, arc, arcdirect)
				VALUES
				(v_tnode, v_fnode, v_rec.arcid, false);
		end if;

	end loop;

	with ps as (select arc, count(*) cnt
	from node_adjacency
	group by arc)
	select min(cnt), max(cnt)
	into out_min_nodeforarc_count, out_max_nodeforarc_count
	from ps;

	return next;

END;
$BODY$;

ALTER FUNCTION build_adjacency()
    OWNER TO ...;
