# Balance study for 9x9 (run in CI: godot --headless --path godot --script res://tests/sim_balance.gd).
# Compares how many numbers start on the board (givens) and how the givens are spread over the digits.
# Logic: share of the puzzle solvable with simple singles (what a casual player can see).
# Dice: turns a perfect-placement bot needs (dice/economy bound), and turns spent waiting only for 9s.
extends SceneTree

const SEEDS := 20

func _initialize() -> void:
	await process_frame
	var out := []
	out.append("| mode | target | givens (avg) | gen ms avg/max | given 9s | given 7-9 | singles-solvable | turns avg | turns p90 | 9-wait turns |")
	out.append("|---|---|---|---|---|---|---|---|---|---|")
	for g in [28, 32, 36, 42]:
		for mode in ["random", "even", "boost"]:
			out.append(row(g, mode))
	out.append("")
	out.append(fairness())
	var text := "\n".join(PackedStringArray(out))
	print(text)
	quit(0)

func closure_pct(g: Game, p: PlayerState) -> float:
	var saved := p.grid.duplicate()
	var empty0 := 81 - Puzzle.filled(p.grid)
	while true:
		var fill := {}
		for v in range(1, 10):
			for c in Bot.forced_cells(g, p, v):
				fill[c] = v
		if fill.is_empty():
			break
		for c in fill:
			p.grid[c] = fill[c]
	var solved := 81 - Puzzle.filled(saved) - (81 - Puzzle.filled(p.grid))
	p.grid = saved
	return 100.0 * solved / max(1, empty0)

## Plays one solo hard-bot game on the seat's puzzle; returns [turns, turns waiting only on 9s].
func play(g: Game) -> Array:
	var p := g.current()
	var wait9 := 0
	var guard := 0
	var fails := 0
	while not g.over and guard < 4000:
		guard += 1
		var a := Bot.next_action(g)
		if fails >= 2:
			a = {"a": "lock"} if not p.lk and not p.dv.is_empty() else ({"a": "roll"} if p.dv.is_empty() else {"a": "end"})
		var res := g.apply(a)
		fails = 0 if res["ok"] else fails + 1
		if a["a"] == "end" and res["ok"]:
			var only9 := true
			var any := false
			for j in 81:
				if p.grid[j] == 0:
					any = true
					if p.sol[j] != 9:
						only9 = false
			if any and only9:
				wait9 += 1
	return [p.turn, wait9]

func row(target: int, mode: String) -> String:
	var gv := []
	var ms := []
	var n9 := []
	var n789 := []
	var logic := []
	var turns := []
	var w9 := []
	for s in SEEDS:
		var seed_value := 1000 + s * 7919 + target
		var t0 := Time.get_ticks_msec()
		var g := Game.new(9, seed_value, [{"name": "Bot", "pet": "cat", "bot": "hard"}], s + 1, target, mode)
		ms.append(Time.get_ticks_msec() - t0)
		var p := g.current()
		var c := Puzzle.digit_counts(p.puz, 9)
		gv.append(Puzzle.filled(p.puz))
		n9.append(c[9])
		n789.append(c[7] + c[8] + c[9])
		logic.append(closure_pct(g, p))
		var r := play(g)
		turns.append(r[0])
		w9.append(r[1])
	turns.sort()
	return "| %s | %d | %.1f | %.0f / %d | %.1f | %.1f | %.0f%% | %.1f | %d | %.1f |" % [mode, target, avg(gv), avg(ms), ms.max(), avg(n9), avg(n789), avg(logic), avg(turns), turns[int(turns.size() * 0.9)], avg(w9)]

## Same puzzle for 4 seats: v0.10 random relabel vs fair relabel.
func fairness() -> String:
	var lines := ["| seat relabel | spread of given 9s (max-min) | spread of given 7-9 | spread of bot turns |", "|---|---|---|---|"]
	for fair in [false, true]:
		var s9 := []
		var s789 := []
		var st := []
		for s in SEEDS:
			var base := Puzzle.generate(9, 5000 + s, 34, "random")
			var c9 := []
			var c789 := []
			var tt := []
			for k in 4:
				var mine := base if k == 0 else Puzzle.transform(base["sol"], base["puz"], 9, 3, 3, DRng.new(77 + 13 * k + s), fair)
				var c := Puzzle.digit_counts(mine["puz"], 9)
				c9.append(c[9])
				c789.append(c[7] + c[8] + c[9])
				var g := Game.new(9, 1, [{"name": "Bot", "pet": "cat", "bot": "hard"}], s + 1)
				var p := g.current()
				p.sol = mine["sol"].duplicate()
				p.puz = mine["puz"].duplicate()
				p.grid = mine["puz"].duplicate()
				tt.append(play(g)[0])
			s9.append(c9.max() - c9.min())
			s789.append(c789.max() - c789.min())
			st.append(tt.max() - tt.min())
		lines.append("| %s | %.1f | %.1f | %.1f |" % ["fair (new)" if fair else "random (v0.10)", avg(s9), avg(s789), avg(st)])
	return "\n".join(PackedStringArray(lines))

func avg(a: Array) -> float:
	var t := 0.0
	for v in a:
		t += float(v)
	return t / max(1, a.size())
