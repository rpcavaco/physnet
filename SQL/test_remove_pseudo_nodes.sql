
CREATE OR REPLACE FUNCTION test_remove_pseudo_nodes(
	)
    RETURNS TABLE(param text, val text)
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
	v_lastidx integer;
	v_prev_node integer;
	v_next_node integer;
	v_node_id integer;
	v_leftnode integer;
	v_rightnode integer;
	v_connstatus character varying;
	v_count integer;

	v_maxcount1 integer;
	v_maxnode_left1 integer;
	v_maxnode_right1 integer;

	v_maxcount2 integer;
	v_maxnode_left2 integer;
	v_maxnode_right2 integer;

	v_single_node integer;
	v_cnt_arc_replacement integer;
	v_cnt_node_arc_replacement integer;
	v_ref_val_node integer;
	v_ref_val_arc integer;
	v_final_result text;
BEGIN

-- Test remove_pseudo_nodes

	v_lastidx := -1;
	v_maxcount1 := 0;
	v_maxcount2 := 0;
	v_final_result := 'OK';

	-- Find multiple consecutive PSEUDOS
	<<EXTERIOR>>
	loop

		select nodeid, rn
		into v_node_id, v_lastidx
		from
		(select nodeid,
		row_number() over (order by nodeid) rn
		from node t1
		left join node_arc_replacement t2
		using (nodeid)
		where t1.connstatus = 'PSEUDO'
		and t2.newarcid is null) a
		where rn > v_lastidx
		limit 1;

		if not found then
			exit;
		end if;

		select fromnode
		into v_leftnode
		from
		(select a.fromnode,
			row_number() over (order by arcdirect desc) rn
			from node_adjacency a
			inner join node b
			on a.fromnode = b.nodeid
			where a.tonode = v_node_id
			and not a.unusable
			and (b.connstatus is NULL or b.connstatus != 'PSEUDO'))	a
		where rn = 1;

		v_prev_node := v_leftnode;
		v_next_node := v_node_id;
		v_count := 0;

		-- Successively find right nodes unitl a non-pseudo is found
		<<FINDRIGHT>>
		loop

			-- Get the other arc to use as
			--  'right arc'
			select a.tonode, b.connstatus
			into v_rightnode, v_connstatus
			from node_adjacency a
			inner join node b
			on a.tonode = b.nodeid
			where a.fromnode = v_next_node
			and a.tonode != v_prev_node
			and not a.unusable;

			if not found then
				exit;
			end if;

			if v_connstatus != 'PSEUDO' then
				if v_count > v_maxcount1 then
					v_maxcount2 := v_maxcount1;
					v_maxnode_left2 := v_maxnode_left1;
					v_maxnode_right2 := v_maxnode_right1;

					v_maxcount1 := v_count;
					v_maxnode_left1 := v_node_id;
					v_maxnode_right1 := v_next_node;
				end if;
				exit;
			end if;

			v_prev_node := v_next_node;
			v_next_node := v_rightnode;

			v_count := v_count + 1;

		end loop FINDRIGHT;

		if v_maxcount1 = 1 then
			v_single_node := v_node_id;
		end if;

	end loop EXTERIOR;

	if v_maxcount1 > 0 then
		v_maxcount1 := v_maxcount1 + 1;
		v_maxcount2 := v_maxcount2 + 1;
	end if;

	param := 'single_pseudo';
	val := v_single_node::text;
	return next;

	param := 'max_consec_pseudos';
	val := v_maxcount1::text;
	return next;

	param := 'left_node';
	val := v_maxnode_left1::text;
	return next;

	param := 'right_node';
	val := v_maxnode_right1::text;
	return next;

---------------------------------------
	select count(*)
	into v_ref_val_node
	from node_arc_replacement;

	select count(*)
	into v_ref_val_arc
	from arc_replacement;

	select out_cnt_arc_replacement, out_cnt_node_arc_replacement
	into v_cnt_arc_replacement, v_cnt_node_arc_replacement
	from remove_pseudo_nodes(ARRAY [v_single_node]);

	param := 'single node test';
	if (v_cnt_arc_replacement - v_ref_val_arc) = 2 and (v_cnt_node_arc_replacement - v_ref_val_node) = 1 then
		val := 'ok';
	else
		v_final_result := 'NOT OK';
		val := format('notok arc:% node:%', (v_cnt_arc_replacement - v_ref_val_arc), (v_cnt_node_arc_replacement - v_ref_val_node));
	end if;
	return next;
---------------------------------------

---------------------------------------
	select count(*)
	into v_ref_val_node
	from node_arc_replacement;

	select count(*)
	into v_ref_val_arc
	from arc_replacement;

	select out_cnt_arc_replacement, out_cnt_node_arc_replacement
	into v_cnt_arc_replacement, v_cnt_node_arc_replacement
	from remove_pseudo_nodes(ARRAY [v_maxnode_left1]);

	param := 'leftmost node test A';
	if (v_cnt_arc_replacement - v_ref_val_arc) = (v_maxcount1+1) and (v_cnt_node_arc_replacement - v_ref_val_node) = v_maxcount1 then
		val := 'ok';
	else
		v_final_result := 'NOT OK';
		val := format('notok arc:%s node:%s', (v_cnt_arc_replacement - v_ref_val_arc), (v_cnt_node_arc_replacement - v_ref_val_node));
	end if;
	return next;
---------------------------------------

---------------------------------------
	select count(*)
	into v_ref_val_node
	from node_arc_replacement;

	select count(*)
	into v_ref_val_arc
	from arc_replacement;

	select out_cnt_arc_replacement, out_cnt_node_arc_replacement
	into v_cnt_arc_replacement, v_cnt_node_arc_replacement
	from remove_pseudo_nodes(ARRAY [v_maxnode_right1]);

	param := 'rightmost node test A';
	if (v_cnt_arc_replacement - v_ref_val_arc) = 0 and (v_cnt_node_arc_replacement - v_ref_val_node) = 0 then
		val := 'ok';
	else
		v_final_result := 'NOT OK';
		val := format('notok arc:%s node:%s', (v_cnt_arc_replacement - v_ref_val_arc), (v_cnt_node_arc_replacement - v_ref_val_node));
	end if;
	return next;
---------------------------------------

---------------------------------------
	select count(*)
	into v_ref_val_node
	from node_arc_replacement;

	select count(*)
	into v_ref_val_arc
	from arc_replacement;

	select out_cnt_arc_replacement, out_cnt_node_arc_replacement
	into v_cnt_arc_replacement, v_cnt_node_arc_replacement
	from remove_pseudo_nodes(ARRAY [v_maxnode_left2]);

	param := 'leftmost node test B';
	if (v_cnt_arc_replacement - v_ref_val_arc) = (v_maxcount2+1) and (v_cnt_node_arc_replacement - v_ref_val_node) = v_maxcount2 then
		val := 'ok';
	else
		v_final_result := 'NOT OK';
		val := format('notok arc:%s node:%s', (v_cnt_arc_replacement - v_ref_val_arc), (v_cnt_node_arc_replacement - v_ref_val_node));
	end if;
	return next;
---------------------------------------

---------------------------------------
	select count(*)
	into v_ref_val_node
	from node_arc_replacement;

	select count(*)
	into v_ref_val_arc
	from arc_replacement;

	select out_cnt_arc_replacement, out_cnt_node_arc_replacement
	into v_cnt_arc_replacement, v_cnt_node_arc_replacement
	from remove_pseudo_nodes(ARRAY [v_maxnode_right2]);

	param := 'rightmost node test B';
	if (v_cnt_arc_replacement - v_ref_val_arc) = 0 and (v_cnt_node_arc_replacement - v_ref_val_node) = 0 then
		val := 'ok';
	else
		v_final_result := 'NOT OK';
		val := format('notok arc:%s node:%s', (v_cnt_arc_replacement - v_ref_val_arc), (v_cnt_node_arc_replacement - v_ref_val_node));
	end if;
	return next;
---------------------------------------

	param := 'FINAL RESULT';
	val := v_final_result;

END;
$BODY$;

ALTER FUNCTION test_remove_pseudo_nodes()
    OWNER TO ...;
