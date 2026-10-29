extends RefCounted
# Game rules (port of the web prototype's multiplayer suite, adapted to local pass-and-play, no d20).

func seats(k: int) -> Array:
	var names := ["Ana", "Bob", "Cy", "Di"]
	var out := []
	for i in k:
		out.append({"name": names[i], "pet": Rules.PETS[i]})
	return out

func mk(n: int, k: int, s: int = 5) -> Game:
	return Game.new(n, s, seats(k), 99)

## Put the current seat in the placing phase with chosen dice.
func locked(g: Game, faces: Array, values: Array, kinds: Array = []) -> PlayerState:
	var p := g.current()
	p.df = faces.duplicate()
	p.dk = kinds.duplicate() if not kinds.is_empty() else faces.map(func(_f): return "std")
	p.dv = values.duplicate()
	p.du = values.map(func(_v): return false)
	p.dh = values.map(func(_v): return false)
	p.lk = true
	p.rolls = 0
	return p

func empty_cell(g: Game, p: PlayerState, want: int = -1) -> int:
	for j in p.grid.size():
		if p.grid[j] == 0 and (want < 0 or g.sol[j] == want):
			return j
	return -1

func wrong_cell(g: Game, p: PlayerState, v: int) -> int:
	for j in p.grid.size():
		if p.grid[j] == 0 and g.sol[j] != v:
			return j
	return -1

func test_turn_rotation(t) -> void:
	var g := mk(4, 3)
	t.check(g.cur == 0, "seat 0 starts")
	g.roll()
	t.check(g.end_turn()["ok"] and g.cur == 1, "passes to seat 1")
	g.roll(); g.end_turn()
	t.check(g.cur == 2, "then seat 2")
	g.roll(); g.end_turn()
	t.check(g.cur == 0, "wraps to seat 0")
	t.check(not g.end_turn()["ok"], "cannot end turn before rolling")

func test_solo_keeps_turn(t) -> void:
	var g := mk(4, 1)
	g.roll(); g.end_turn()
	t.check(g.cur == 0 and g.current().turn == 2 and not g.over, "solo keeps the turn")

func test_roll_hold_lock(t) -> void:
	var g := mk(6, 2)
	var p := g.current()
	t.check(not g.lock()["ok"], "no lock before rolling")
	t.check(g.can_pick(0)["msg"] == "Lock your dice first", "no placing before lock")
	g.roll()
	t.check(p.dv.size() == 5 and p.rolls == 2 and not p.lk, "first roll")
	for v in p.dv:
		t.check(v >= 1 and v <= 6, "d6 range")
	t.check(g.hold(1)["ok"] and p.dh[1], "hold")
	var kept: int = p.dv[1]
	g.roll()
	t.check(p.dv[1] == kept, "held die kept")
	g.roll()
	t.check(p.lk and p.rolls == 0, "auto-lock after third roll")
	t.check(not g.roll()["ok"] and not g.hold(0)["ok"], "frozen once locked")

func test_hold_cap_and_all_dice_roll(t) -> void:
	var g := mk(9, 2)
	var p := g.current()
	p.df = [6, 6, 6, 6, 6, 8, 8, 10, 10]
	p.dk = []
	for f in p.df:
		p.dk.append("std")
	g.roll()
	t.check(p.dv.size() == 9 and not p.dv.has(0), "all 9 dice roll (no hand limit)")
	var held := 0
	for i in 9:
		if g.is_useless(p, i):
			continue
		if g.hold(i)["ok"]:
			held += 1
	t.check(p.held_count() <= Rules.MAXH, "hold cap 5")

func test_place_hit_miss_lose(t) -> void:
	var g := mk(4, 2)
	var p := locked(g, [4, 4, 4, 4, 4], [1, 2, 3, 4, 1])
	var c := empty_cell(g, p, 1)
	var r := g.place(0, c)
	t.check(r["ok"] and r["hit"] and p.grid[c] == 1 and p.gold == 1 and p.mis == 0, "hit places and pays 1 gold")
	t.check(not g.place(0, empty_cell(g, p))["ok"], "used die cannot be placed again")
	for k in 3:
		var i := 1 + k
		var w := wrong_cell(g, p, p.dv[i])
		if w < 0:
			continue
		g.place(i, w)
	t.check(p.mis == 3 and p.lost, "three mistakes: lost")
	t.check(g.cur == 1, "turn passes when a player loses")
	g.roll(); g.end_turn()
	t.check(g.cur == 1, "lost player skipped in rotation")

func test_wild_and_dead(t) -> void:
	var g := mk(6, 2)
	var p := locked(g, [10, 10, 8, 6, 6], [10, 9, 7, 2, 3])
	t.check(g.is_wild(p, 0) and not g.is_dead(p, 0), "d10 zero is wild")
	t.check(g.is_dead(p, 1) and g.is_dead(p, 2), "faces above grid size are dead")
	t.check(g.can_pick(1)["msg"] == "Dead face: cannot be placed", "dead message")
	var c := empty_cell(g, p)
	var r := g.place(0, c)
	t.check(r["hit"] and p.grid[c] == g.sol[c] and p.mis == 0, "wild fills any cell with the right number")

func test_completed_numbers(t) -> void:
	var g := mk(4, 1)
	var p := g.current()
	for j in 16:
		if g.sol[j] == 1:
			p.grid[j] = 1
	locked(g, [4, 4, 4, 4, 4], [1, 2, 2, 2, 2])
	t.check(g.is_useless(p, 0) and not g.is_useless(p, 1), "completed number detected")
	t.check(g.can_pick(0)["msg"] == "Number complete: cannot be placed", "cannot place completed number")
	locked(g, [4, 4, 4, 4, 4], [1, 2, 2, 2, 2], ["mirror", "std", "std", "std", "std"])
	t.check(not g.is_useless(p, 0), "mirror die still useful while its mirror number is open")

func test_abilities(t) -> void:
	var g := mk(6, 1)
	var p := g.current()
	var target := empty_cell(g, p)
	var v: int = g.sol[target]
	locked(g, [6, 6, 6, 6, 6], [7 - v, 1, 1, 1, 1], ["mirror", "std", "std", "std", "std"])
	t.check(g.place(0, target)["hit"], "mirror places N+1-v")
	target = empty_cell(g, p)
	v = g.sol[target]
	var miss := 1 if v != 1 else 2
	locked(g, [6, 6, 6, 6, 6], [miss, 1, 1, 1, 1], ["safe", "std", "std", "std", "std"])
	var m0 := p.mis
	g.place(0, target)
	t.check(p.mis == m0 and p.grid[target] == 0, "safe die: miss costs nothing")
	var g0 := p.gold
	locked(g, [6, 6, 6, 6, 6], [v, 1, 1, 1, 1], ["golden", "std", "std", "std", "std"])
	g.place(0, target)
	t.check(p.gold == g0 + 3, "golden pays 3")
	# loaded: useful faces more often than a plain die
	var g2 := mk(9, 1)
	var q := g2.current()
	q.df = [10, 10]
	q.dk = ["std", "loaded"]
	for j in q.grid.size():
		if g2.sol[j] != 1:
			q.grid[j] = g2.sol[j]
	var a := 0
	var b := 0
	for k in 3000:
		if g2._need(q, 10, g2._roll_die(q, 1)):
			a += 1
		if g2._need(q, 10, g2._roll_die(q, 0)):
			b += 1
	t.check(a > b, "loaded beats plain (%d vs %d)" % [a, b])

func test_end_turn_rewards(t) -> void:
	var g := mk(4, 1)
	var p := g.current()
	g.roll()
	var gold := p.gold
	g.end_turn()
	t.check(p.gold == gold + 1, "turn without placements pays 1 gold")
	g.roll()
	p.dv = [3, 3, 3, 3, 3]
	var h := p.hints
	g.end_turn()
	t.check(p.hints == h + 2, "five of a kind = 2 hints")

func test_hint(t) -> void:
	var g := mk(4, 1)
	var p := g.current()
	p.hints = 1
	var c := empty_cell(g, p)
	locked(g, [4, 4, 4, 4, 4], [g.sol[c], 1, 1, 1, 1])
	var r := g.hint(0)
	t.check(r["ok"] and r["hit"] and p.hints == 0 and p.mis == 0, "hint places the die correctly for free")
	t.check(not g.hint(1)["ok"], "no hints left")

func test_shop(t) -> void:
	var g := mk(9, 2)
	var p := g.current()
	var item := ""
	for k in range(1, 100):
		p.turn = k
		for x in g.offers():
			if x.has("f"):
				item = x["id"]
		if item != "":
			break
	t.check(item != "", "found a turn selling dice")
	t.check(g.buy(item)["msg"] == "Not enough gold", "needs gold")
	p.gold = 50
	g.roll()
	t.check(g.buy(item)["ok"] and p.df.size() == 6 and p.dv.size() == 6 and p.dv[5] == 0, "die joins pool, padded")
	t.check(g.buy(item)["msg"] == "Sold out this turn", "once per turn")
	p.gold = 50
	p.df = [4, 4, 4, 4, 4, 4, 4, 4, 4]
	p.bt = []
	t.check(g.buy(item)["msg"] == "Dice pool is full (9)", "pool cap 9")
	t.check(not g.buy("whet")["ok"], "whetstone only through upgrade()")
	p.df = [4, 6, 6, 6, 6]
	p.gold = 50
	var steps := []
	for k in 4:
		steps.append(g.upgrade(0)["ok"])
	t.check(steps == [true, true, true, false] and p.df[0] == 10, "d4>d6>d8>d10 then stops (no d20)")
	t.check(g.upgrade(0)["msg"] == "Already the strongest die (d10)", "max message")

func _turn_with(g: Game, id: String) -> bool:
	var p := g.current()
	for k in range(1, 400):
		p.turn = k
		for o in g.offers():
			if o["id"] == id:
				return true
	return false

func test_curses(t) -> void:
	var g := mk(4, 2)
	var a: PlayerState = g.players[0]
	var b: PlayerState = g.players[1]
	# solo: no rival
	var solo := mk(4, 1)
	solo.current().gold = 50
	if _turn_with(solo, "hex"):
		t.check(solo.buy("hex")["msg"] == "No rival to curse", "no rival in solo")
	# Ana hexes Bob
	a.gold = 50
	t.check(_turn_with(g, "hex"), "hex appears in stock")
	t.check(g.buy("hex")["ok"] and b.pending.size() == 1 and a.gold == 46, "hex sent and charged 4")
	g.roll(); g.end_turn()
	g.roll()
	t.check(b.rolls == 1 and b.pending.is_empty(), "hex: 2 rolls instead of 3 (got rolls left %d)" % b.rolls)
	g.end_turn()
	# blight
	a.bt = []
	_turn_with(g, "blight")
	g.buy("blight")
	g.roll(); g.end_turn()
	b.df = [10, 10, 10, 10, 10]
	g.roll()
	t.check(b.dv.count(1) >= 2, "blight: at least two 1s (%s)" % [b.dv])
	g.end_turn()
	# shackle
	a.bt = []
	_turn_with(g, "shackle")
	g.buy("shackle")
	g.roll(); g.end_turn()
	b.df = [4, 4, 4, 4, 4]
	g.roll()
	for i in 5:
		g.hold(i)
	t.check(b.held_count() <= 1 and b.shk == 1, "shackle: hold only 1")
	g.end_turn()
	t.check(b.shk == 0, "shackle cleared")
	# ward
	g.roll(); g.end_turn()
	b.gold = 20
	_turn_with(g, "ward")
	t.check(g.buy("ward")["ok"] and b.ward == 1, "ward bought")
	g.roll(); g.end_turn()
	a.bt = []
	_turn_with(g, "hex")
	g.buy("hex")
	g.roll(); g.end_turn()
	var r := g.roll()
	t.check(b.rolls == 2 and b.ward == 0 and "Ward blocked Hex" in r["msg"], "ward blocks hex")

func test_curse_target_choice(t) -> void:
	var g := mk(4, 3)
	g.current().gold = 50
	_turn_with(g, "hex")
	g.buy("hex", 2)
	t.check(g.players[2].pending.size() == 1 and g.players[1].pending.is_empty(), "curse goes to the chosen seat")

## Simple bot: holds fitting dice, locks, places every fitting die, buys whetstones/dice/curses.
func play_bot_game(t, n: int, k: int, s: int) -> Dictionary:
	var g := Game.new(n, s, seats(k), s)
	var guard := 0
	while not g.over and guard < 2000:
		guard += 1
		var p := g.current()
		for r in 3:
			if p.lk:
				break
			g.roll()
			if p.lk:
				break
			for i in p.df.size():
				var v: int = p.dv[i]
				if v == 0 or g.is_dead(p, i) or g.is_useless(p, i) or p.dh[i]:
					continue
				if g.is_wild(p, i) or empty_fit(g, p, i) >= 0:
					g.hold(i)
		if not p.lk:
			g.lock()
		for i in p.df.size():
			if not p.active() or g.cur != g.players.find(p):
				break
			if not g.can_pick(i)["ok"]:
				continue
			var c := empty_fit(g, p, i)
			if c >= 0:
				g.place(i, c)
		if not p.active() or g.players[g.cur] != p:
			continue
		for o in g.offers():
			if p.gold < o["c"]:
				continue
			if o["id"] == "whet":
				var lo := 0
				for i in p.df.size():
					if p.df[i] < p.df[lo]:
						lo = i
				if p.df[lo] < 10 and n == 9:
					g.upgrade(lo)
			elif o.has("x") and p.gold >= o["c"] + 3:
				g.buy(o["id"])
			elif o.has("f") and p.df.size() < Rules.MAXP:
				g.buy(o["id"])
		g.end_turn()
	return {"g": g, "guard": guard}

func empty_fit(g: Game, p: PlayerState, i: int) -> int:
	for j in p.grid.size():
		if p.grid[j] == 0 and g.fits(p, i, j):
			return j
	return -1

func test_full_bot_games(t) -> void:
	for n in [4, 6, 9]:
		for k in [1, 2, 4]:
			var res := play_bot_game(t, n, k, 100 * n + k)
			var g: Game = res["g"]
			var all_done := true
			var turns := []
			for p in g.players:
				all_done = all_done and p.done
				turns.append(p.turn)
				t.check(p.mis == 0, "bot never misses")
			t.check(g.over and all_done, "%dx%d with %d players finishes (guard %d)" % [n, n, k, res["guard"]])
			print("  %dx%d %d players: turns %s" % [n, n, k, turns])
