extends SceneTree
## Headless test runner:
##   godot --headless --script res://tests/run_tests.gd
## Runs every `test_*` method of every tests/test_*.gd file and exits with
## status 1 when anything fails.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var files := DirAccess.get_files_at("res://tests")
	var total := 0
	var failed := 0
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")) or f == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.tree = self
			var result: Variant = t.call(name)
			if result is Signal:
				await result
			total += 1
			if t.failures.is_empty():
				print("  ok    %s.%s" % [f.get_basename(), name])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [f.get_basename(), name])
				for msg in t.failures:
					print("          ", msg)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
