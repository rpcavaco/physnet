
CREATE OR REPLACE FUNCTION rollback_remove_pseudo_nodes(
	)
    RETURNS TABLE(param text, val text)
    LANGUAGE 'plpgsql'
AS $BODY$
BEGIN

	UPDATE node_adjacency
	SET unusable = false
	FROM arc_replacement
	WHERE node_adjacency.arcid = arc_replacement.replaced_arcid
	AND node_adjacency.unusable;

	delete from node_adjacency a
	where exists (
		select 1 from arc b
		where a.arcid = b.arcid
		and orig = 'REMPSN'
	);

	delete from arcspeed a
	where exists (
		select 1 from arc b
		where a.arcid = b.arcid
		and orig = 'REMPSN'
	);

	delete from node_arc_replacement a
	where exists (
		select 1 from arc b
		where a.newarcid = b.arcid
		and orig = 'REMPSN'
	);

	delete from arc_replacement a
	where exists (
		select 1 from arc b
		where a.newarcid = b.arcid
		and orig = 'REMPSN'
	);

	delete from arc
	where orig = 'REMPSN';

	select count(*)
	into val
	from arcspeed
	where arcid in
	(select arcid
	from arc
	where orig = 'REMPSN');

	param := 'replacing arcspeed count';
	return next;

	select count(*)
	into val
	from arc
	where orig = 'REMPSN';

	param := 'replacing arc count';
	return next;

	select count(*)
	into val
	from node_adjacency a
		where not exists (
			select 1 from arc b
			where b.arcid = a.arcid
		);

	param := 'node_adjacency count';
	return next;

	select count(*)
	into val
	from node_adjacency a
	where unusable;

	param := 'node_adjacency unusable count';
	return next;

END;
$BODY$;

ALTER FUNCTION rollback_remove_pseudo_nodes()
    OWNER TO ...;
