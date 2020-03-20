
CREATE OR REPLACE FUNCTION remove_pseudo_nodes(
	opt_limit_nodes integer[])
    RETURNS TABLE(out_cnt_arc_replacement integer, out_cnt_node_arc_replacement integer)
    LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
	v_node_cnt integer;
	v_lastidx integer;
	v_node_id integer;
	v_nodes integer[];
	v_arc integer;
	v_tmparc integer;
	v_arcs integer[];
	v_arcisdirect boolean;
	v_next_node integer;
	v_prev_node integer;
	v_connstatus character varying;
	v_arcsaredirect boolean[];
	v_leftnode integer;
	v_rightnode integer;
	v_i integer;
	v_j integer;
	v_bidir_adjacency boolean;
	v_geom geometry;
	v_geom_b geometry;
	v_geoms geometry[];
	v_op character(1);
	v_newarcid integer;
	v_start_len numeric;
	v_end_len numeric;
	v_len numeric;
	v_lentotal numeric;
	v_speeds integer;
	v_dirspeed numeric;
	v_revspeed numeric;
	v_dirspeeds numeric[];
	v_revspeeds numeric[];
	v_newdirspeeds numeric[];
	v_newrevspeeds numeric[];
	v_scenarios character varying[];
	v_scenario character varying;
	v_first boolean;
	--v_cnt integer;
BEGIN

	v_node_cnt := 0;
	v_lastidx := -1;
	--v_cnt := 0;

	<<EXTERIOR>>
	loop

		-- Get next node id
		-- without keeping locks or any frozen result set on
		-- the join between nodes table and node_arc_replacement
		-- which will change during this procedure
		if not opt_limit_nodes is null then

			select nodeid, rn
			into v_node_id, v_lastidx
			from
			(
				select nodeid,
				row_number() over (order by nodeid) rn
				from node t1
				left join node_arc_replacement t2
				using (nodeid)
				where t1.connstatus = 'PSEUDO'
				and t2.newarcid is null
				and t1.nodeid = any (opt_limit_nodes)
			) a
			where rn > v_lastidx
			limit 1;

		else

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

		end if;

		--v_cnt := v_cnt + 1;

		if not found then
			raise NOTICE 'no next pseudo node found, finishing';
			exit;
		end if;

		--raise NOTICE '    ---- node id %', v_node_id;

		v_node_cnt := v_node_cnt + 1;
		v_nodes := ARRAY [v_node_id];

		select fromnode, arcid, arcdirect
		into v_leftnode, v_arc, v_arcisdirect
		from
		(select a.fromnode, a.arcid, a.arcdirect,
			row_number() over (order by arcdirect desc) rn
			from node_adjacency a
			inner join node b
			on a.fromnode = b.nodeid
			where a.tonode = v_node_id
			and not a.unusable
			and (b.connstatus is NULL or b.connstatus != 'PSEUDO')
		)	a
		where rn = 1;

		if not found then
			raise notice 'all adjacent nodes are pseudo, skipping node %', v_node_id;
			continue;
		end if;

		v_arcs := ARRAY [v_arc];
		v_arcsaredirect := ARRAY[v_arcisdirect];

		-- Check bidirectionality: is true if is also true on
		-- both sides of pseudo node --
		select arcgeom, bidir_adjacency
		into v_geom, v_bidir_adjacency
		from arc
		where arcid = v_arcs[array_lower(v_arcs,1)];

		v_geoms := ARRAY [v_geom];

		v_prev_node := v_leftnode;
		v_next_node := v_node_id;

		--raise NOTICE '     ---- prev_node %,  next_node:%  arc:%', v_prev_node, v_next_node, v_arc;

		v_first := true;
		v_tmparc := v_arc;

		-- Successively find right nodes unitl a non-pseudo is found
		<<FINDRIGHT>>
		loop

			-- Get the other arc to use as
			--  'right arc'
			select a.tonode, a.arcid, a.arcdirect, b.connstatus
			into v_rightnode, v_arc, v_arcisdirect, v_connstatus
			from node_adjacency a
			inner join node b
			on a.tonode = b.nodeid
			where a.fromnode = v_next_node
			and a.tonode != v_prev_node
			and not a.unusable;

			--raise NOTICE '     A found:%  rightnode %,  arc %, arcisdir %, connstat:%', found, v_rightnode, v_arc, v_arcisdirect, v_connstatus;

			-- PSEUDO node inside cul-de-sac ring
			if not found and v_first then

				select a.tonode, a.arcid, a.arcdirect, b.connstatus
				into v_rightnode, v_arc, v_arcisdirect, v_connstatus
				from node_adjacency a
				inner join node b
				on a.tonode = b.nodeid
				where a.fromnode = v_next_node
				and a.arcid != v_tmparc
				and not a.unusable;

			--raise NOTICE '     B found:%  rightnode %,  arc %, arcisdir %, connstat:%', found, v_rightnode, v_arc, v_arcisdirect, v_connstatus;

			end if;

			v_first := false;

			if not found then
				exit;
			end if;

			v_arcs := v_arcs || v_arc;
			v_arcsaredirect := v_arcsaredirect || false;
			v_prev_node := v_next_node;
			v_next_node := v_rightnode;

			-- Check bidirectionality: is true if is also true on
			-- both sides of pseudo node and all 'right' arcs continued from 'leftarc' analysis before this cycle
			select arcgeom, bidir_adjacency and v_bidir_adjacency
			into v_geom, v_bidir_adjacency
			from arc
			where arcid = v_arc;
			------------------------------------------------

			v_geoms := v_geoms || v_geom;

			-- If right node not pseudo, exit inner cycle
			if v_connstatus is null or v_connstatus != 'PSEUDO' then
				exit;
			end if;

			v_nodes := v_nodes || v_rightnode;

		end loop FINDRIGHT; -- inner while true

		if v_rightnode is null then
			raise exception 'null rightnode prev:% next:% arc:%, arcisdir %, connstat:%', v_prev_node, v_next_node, v_arc, v_arcisdirect, v_connstatus;
		end if;

		-- Mark all adjacencies of all pseudo nodes as
		--  unusable
		update node_adjacency
		set unusable = true
		where arcid = ANY (v_arcs);
		------------------------------------------------

		-- Generate new geometry ----------------------
		v_i := array_lower(v_arcs, 1);
		if v_arcsaredirect[v_i] then
			v_op := 'a';
			v_geom := v_geoms[v_i];
		else
			v_op := 'b';
			v_geom := ST_Reverse(v_geoms[v_i]);
		end if;

		if not ST_GeometryType(v_geom) = 'ST_LineString' then
			raise exception 'Wrong first arc geometry: ''%'', node % replacement -- op:% left arc:%, right arc:%  left:''%'' right:''%'' ',
					ST_GeometryType(v_geom), v_node_id, v_op, v_arcs[v_i-1], v_arcs[v_i],
					st_astext(v_geom), st_astext(v_geom_b);
		end if;

		<<NEWGEOM>>
		FOR v_i IN (1+array_lower(v_arcs, 1)) .. array_upper(v_arcs, 1)
		loop
			if v_arcsaredirect[v_i] then
					v_op := 'a';
					v_geom_b := v_geoms[v_i];
			else
					v_op := 'b';
					v_geom_b := ST_Reverse(v_geoms[v_i]);
			end if;

			v_geom := ST_LineMerge(ST_SnapToGrid(st_collect(v_geom, v_geom_b), 0.000001));

			if not ST_GeometryType(v_geom) = 'ST_LineString' then
				raise exception 'Wrong arc geometry: ''%'', node % replacement -- op:% left arc:%, right arc:%  left:''%'' right:''%'' ',
						ST_GeometryType(v_geom), v_node_id, v_op, v_arcs[v_i-1], v_arcs[v_i],
						st_astext(v_geom), st_astext(v_geom_b);
			end if;

			if not ST_IsValid(v_geom) then
				raise exception 'Invalid arc, node % replacement -- left arc:%, right arc:%', v_node_id, v_arcs[v_i-1], v_arcs[v_i];
			end if;

			if ST_Length(v_geom) = 0 then
				raise exception 'Zero length arc, node % replacement -- left arc:%, right arc:%', v_node_id, v_arcs[v_i-1], v_arcs[v_i];
			end if;

		end loop NEWGEOM; -- FOR v_i IN (1+array_lower(v_arcs, 1)) ..
		------------------------------------------------

		-- Insert arc to get freshly generated arcid
		insert into arc
		(arcgeom, fromnode, tonode, arclength, orig)
		select v_geom,
				st_lineinterpolatepoint(v_geom, 0.0) fromnode,
				st_lineinterpolatepoint(v_geom, 1.0) tonode,
				st_length(v_geom), 'REMPSN'::text orig
		returning arcid into v_newarcid;
		------------------------------------------------

		if v_newarcid is null then
			raise exception 'Null arc id, node % replacement -- left arc:%, right arc:%', v_node_id, v_arcs[v_i-1], v_arcs[v_i];
		end if;

		insert into node_arc_replacement
		(newarcid, nodeid)
		select v_newarcid, unnest(v_nodes);

		-- set adjacencies for new arc
		insert into node_adjacency
		(fromnode, tonode, arcid, arcdirect)
		values
		(v_leftnode, v_rightnode, v_newarcid, true);

		if v_bidir_adjacency then
				insert into node_adjacency
				(fromnode, tonode, arcid, arcdirect)
				values
				(v_rightnode, v_leftnode, v_newarcid, false);
		end if;

		-- Register relations between new arcs and replaced arcs
		v_start_len := 0.0;
		v_end_len := 0.0;
		v_j := 0;
		<<ARCREPLACEMENT>>
		FOR v_i IN array_lower(v_arcs, 1) .. array_upper(v_arcs, 1)
		loop
			v_end_len := v_end_len + ST_Length(v_geoms[v_i]);

			insert into arc_replacement
			(newarcid, ord, replaced_arcid, start_len, end_len)
			select v_newarcid, v_j, v_arcs[v_i], v_start_len, v_end_len;

			v_start_len := v_end_len;

			v_j := v_j + 1;

		end loop ARCREPLACEMENT;

		-- alterar SPEEDS
		select numericval into v_speeds
		from params
		where acronym = 'SPEEDS';

		with ps as (
			select distinct scenario
			from arcspeed
		)
		select array_agg(scenario)
		into v_scenarios
		from ps;

		<<SCENARIOS>>
		foreach v_scenario in ARRAY v_scenarios
		loop

			v_newdirspeeds := ARRAY []::numeric[];
			v_newrevspeeds := ARRAY []::numeric[];

			<<SPEEDS>>
			for v_j in 1 .. v_speeds
			loop
				v_dirspeed := 0.0;
				v_revspeed := 0.0;
				v_lentotal := 0.0;

				<<ARCS>>
				for v_i IN array_lower(v_arcs, 1) .. array_upper(v_arcs, 1)
				loop

					select dirspeeds, revspeeds
					into v_dirspeeds, v_revspeeds
					from arcspeed
					where scenario = v_scenario
					and arcid = v_arcs[v_i];

					v_len := ST_Length(v_geoms[v_i]);
					v_lentotal := v_lentotal + v_len;

					if v_dirspeeds[v_j] < 0.0 then
						v_dirspeed := -1.0;
					else
						v_dirspeed := v_dirspeed + v_dirspeeds[v_j] * v_len;
					end if;

					if v_revspeeds[v_j] < 0.0 then
						v_revspeed := -1.0;
					else
						v_revspeed := v_revspeed + v_revspeeds[v_j] * v_len;
					end if;

				end loop ARCS; -- arcs, v_i

				if v_dirspeed > 0.0 then
					v_dirspeed := v_dirspeed / v_lentotal;
				end if;

				if v_revspeed > 0.0 then
					v_revspeed := v_revspeed / v_lentotal;
				end if;

				v_newdirspeeds := v_newdirspeeds || v_dirspeed;
				v_newrevspeeds := v_newrevspeeds || v_revspeed;

			end loop SPEEDS; --v_speeds, v_j

			insert into arcspeed
			(arcid, scenario, dirspeeds, revspeeds)
			values
			(v_newarcid, v_scenario, v_newdirspeeds, v_newrevspeeds);

		end loop SCENARIOS; -- v_scenarios
		-------------------------------------------------

	end loop EXTERIOR;

	select count(*)
	into out_cnt_arc_replacement
	from arc_replacement;

	select count(*)
	into out_cnt_node_arc_replacement
	from node_arc_replacement;

	return next;

END;
$BODY$;

ALTER FUNCTION remove_pseudo_nodes(integer[])
    OWNER TO ...;
