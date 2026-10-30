extends RefCounted
# Parity with the web prototype v0.8.1 (fixtures generated from its JavaScript) + generator sanity.

var F: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures_web_v081.json"))

func test_rng_parity(t) -> void:
	for case in F["rng"]:
		var r := DRng.new(int(case[0]))
		for want in case[1]:
			var got := r.next_u32()
			t.check(got == int(want), "rng seed %s: got %d want %d" % [case[0], got, int(want)])

func _ints(a: Array) -> Array:
	var out := []
	for v in a:
		out.append(int(v))
	return out

func test_generator_parity(t) -> void:
	for case in F["gen"]:
		var n := int(case[0])
		var g := Puzzle.generate(n, int(case[1]))
		t.check(g["sol"] == _ints(case[2]), "solution differs for %dx%d seed %s" % [n, n, case[1]])
		t.check(g["puz"] == _ints(case[3]), "puzzle differs for %dx%d seed %s" % [n, n, case[1]])

func test_generator_valid_and_unique(t) -> void:
	for n in [4, 6, 9]:
		var cfg: Dictionary = Puzzle.GRIDS[n]
		for s in [11, 222, 3333]:
			var g := Puzzle.generate(n, s)
			var sol: Array = g["sol"]
			var puz: Array = g["puz"]
			for i in n * n:
				var tmp := sol.duplicate()
				tmp[i] = 0
				t.check(Puzzle.ok(tmp, n, cfg["br"], cfg["bc"], i / n, i % n, sol[i]), "invalid solution %dx%d seed %d cell %d" % [n, n, s, i])
				t.check(puz[i] == 0 or puz[i] == sol[i], "given mismatch")
			t.check(Puzzle.count(puz, n, cfg["br"], cfg["bc"], 2) == 1, "puzzle %dx%d seed %d not unique" % [n, n, s])
			t.check(Puzzle.filled(puz) >= cfg["givens"], "too few givens")

func test_generation_speed(t) -> void:
	var t0 := Time.get_ticks_msec()
	for s in 5:
		Puzzle.generate(9, 1000 + s)
	var ms := (Time.get_ticks_msec() - t0) / 5.0
	print("  9x9 generation: %.0f ms average" % ms)
	t.check(ms < 3000.0, "9x9 generation too slow: %.0f ms" % ms)

func test_combo_parity(t) -> void:
	for case in F["combo"]:
		var got := Rules.combo(_ints(case[0]), int(case[1]))
		t.check(got == int(case[2]), "combo %s n=%s got %d want %s" % [case[0], case[1], got, case[2]])

func test_offers_parity(t) -> void:
	for case in F["offers"]:
		var ids := []
		for o in Rules.offers(int(case[0]), int(case[1])):
			ids.append(o["id"])
		t.check(ids == case[2], "offers seed %s turn %s: %s vs %s" % [case[0], case[1], ids, case[2]])

func test_offers_shape(t) -> void:
	for turn in range(1, 200):
		var o := Rules.offers(77, turn)
		t.check(o.size() >= 3 and o.size() <= 5, "offer count")
		t.check(o[0]["id"] == "whet", "whetstone first")
		t.check(o[1].has("x") or o[1]["id"] == "ward", "versus item second")

func test_no_d20(t) -> void:
	t.check(not Rules.UPGRADES.has(20), "d20 removed from upgrades")
	t.check(Rules.UPGRADES[-1] == 10, "d10 is the top die")
	for o in Rules.SHOP:
		t.check(o.get("f", 0) != 20, "no d20 in shop")
	t.check(Rules.is_wild(10, 10) and not Rules.is_wild(10, 8) and not Rules.is_wild(20, 20), "only the d10 zero is wild")
	t.check(Rules.face_label(10, 10) == "0" and Rules.face_label(7, 8) == "7", "d10 zero label")
