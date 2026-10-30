extends RefCounted
# Bots: sound deductions, complete games at every level, and exact replay of a recorded action log.

func bot_seats(levels: Array) -> Array:
	var out := []
	for i in levels.size():
		out.append({"name": "Bot%d" % i, "pet": Rules.PETS[i], "bot": levels[i]})
	return out

func test_forced_cells_are_correct(t) -> void:
	for n in [4, 6, 9]:
		for s in [1, 2, 3]:
			var g := Game.new(n, 40 + s, bot_seats(["normal"]), 1)
			var p := g.current()
			var checked := 0
			# repeatedly fill one proven cell and re-check: every proven cell must match the solution
			for step in n * n:
				var placed := false
				for v in range(1, n + 1):
					for c in Bot.forced_cells(g, p, v):
						checked += 1
						t.check(g.sol[c] == v, "%dx%d seed %d: forced %d at %d but solution is %d" % [n, n, s, v, c, g.sol[c]])
						if not placed:
							p.grid[c] = v
							placed = true
				if not placed:
					break
			t.check(checked > 0, "found proven cells")

## Runs a match driven only by Bot.next_action + Game.apply (with the UI's fallback); returns the action log.
func run_bot_match(g: Game) -> Array:
	var log := []
	var fails := 0
	var guard := 0
	while not g.over and guard < 20000:
		guard += 1
		var p := g.current()
		var a := Bot.next_action(g)
		if fails >= 2:
			a = {"a": "lock"} if not p.lk and not p.dv.is_empty() else ({"a": "roll"} if p.dv.is_empty() else {"a": "end"})
		var res := g.apply(a)
		log.append(a)
		fails = 0 if res["ok"] else fails + 1
	return log

func test_bot_matches_finish(t) -> void:
	for n in [4, 6, 9]:
		for lv in [["hard", "hard"], ["normal", "normal", "normal"], ["easy", "normal", "hard", "easy"]]:
			Bot.rng.seed = 5
			var g := Game.new(n, 900 + n, bot_seats(lv), 77)
			var log := run_bot_match(g)
			t.check(g.over, "%dx%d %s: match finished" % [n, n, lv])
			var summary := []
			for p in g.players:
				summary.append("%s:%s t%d m%d" % [p.bot, "done" if p.done else ("out" if p.lost else "?"), p.turn, p.mis])
				if p.bot == "hard":
					t.check(p.mis == 0, "hard bot never misses")
			print("  %dx%d %s" % [n, n, ", ".join(PackedStringArray(summary))])

func test_replay_is_identical(t) -> void:
	for n in [6, 9]:
		Bot.rng.seed = 11
		var g := Game.new(n, 1234, bot_seats(["normal", "easy", "hard"]), 4321)
		var log := run_bot_match(g)
		var r := Game.new(n, 1234, bot_seats(["normal", "easy", "hard"]), 4321)
		for a in log:
			r.apply(a)
		t.check(r.over == g.over and r.cur == g.cur, "replay end state")
		for k in g.players.size():
			var a: PlayerState = g.players[k]
			var b: PlayerState = r.players[k]
			t.check(a.grid == b.grid and a.gold == b.gold and a.mis == b.mis and a.turn == b.turn and a.df == b.df, "%dx%d seat %d identical after replay" % [n, n, k])
