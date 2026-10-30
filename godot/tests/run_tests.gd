# Headless test runner: godot --headless --path godot --script res://tests/run_tests.gd
# Each test file in res://tests/ named test_*.gd extends RefCounted and has methods starting with "test_".
# A test fails by calling t.fail("message"). Exit code 0 = all passed.
extends SceneTree

var failures := 0
var current := ""

func fail(msg: String) -> void:
	failures += 1
	printerr("FAIL ", current, ": ", msg)

func check(cond: bool, msg: String) -> void:
	if not cond:
		fail(msg)

func _initialize() -> void:
	await process_frame  # let the tree finish starting so nodes added by tests (HTTPRequest) are inside it
	var ran := 0
	var dir := DirAccess.open("res://tests")
	var files := []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			current = f
			fail("could not load (parse error?)")
			continue
		var suite = script.new()
		for m in suite.get_method_list():
			var n: String = m["name"]
			if n.begins_with("test_"):
				current = f + "::" + n
				await suite.call(n, self)
				ran += 1
	print("Ran %d tests, %d failures" % [ran, failures])
	quit(1 if failures > 0 or ran == 0 else 0)
