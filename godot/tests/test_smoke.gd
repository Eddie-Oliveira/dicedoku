extends RefCounted
# Pipeline smoke test: proves CI can start Godot headless and run a suite.

func test_engine_runs(t) -> void:
	t.check(Engine.get_version_info()["major"] == 4, "expected Godot 4")

func test_math(t) -> void:
	t.check(1 + 1 == 2, "arithmetic")
