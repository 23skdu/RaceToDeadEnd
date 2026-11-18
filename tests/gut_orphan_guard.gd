#!/usr/bin/env godot
## GUT post-run hook that turns any orphaned node into a failed test run.
##
## GUT reports orphans but does not fail the command by default. This hook is
## attached to every Makefile GUT invocation via `-gpost_run_script` so orphan
## regressions are caught locally and in the pre-commit gate.

extends GutHookScript

const MAX_ORPHANS: int = 0


static func orphan_counts(gut: Object) -> Dictionary:
	var counter = gut.get_orphan_counter()
	# GUT records orphan IDs at script end without pruning entries that were
	# freed afterwards. Drop stale entries so only real orphans fail the gate.
	if counter.orphanage != null:
		counter.orphanage.clean()
	return {
		"live": int(counter.orphan_count()),
		"recorded": int(counter.get_orphan_ids().size()),
	}


func run() -> void:
	var counts: Dictionary = orphan_counts(gut)
	var live: int = int(counts.get("live", 0))
	var recorded: int = int(counts.get("recorded", 0))
	if live > MAX_ORPHANS or recorded > MAX_ORPHANS:
		gut.logger.error(
			"Orphan guard failed: %d live orphan(s), %d recorded orphan(s)." % [live, recorded]
		)
		set_exit_code(1)
		return
	gut.logger.log("Orphan guard passed: 0 live and 0 recorded orphans.")
