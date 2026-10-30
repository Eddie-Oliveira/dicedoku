class_name Game
extends RefCounted
## A local (pass-and-play) match. Every action works on the current seat and returns {"ok": bool, "msg": String}.
## Port of the web prototype v0.8.1 rules, minus the d20. UI, bots and online replay all act through apply().

var size: int
var game_seed: int
var br: int
var bc: int
var players: Array = []
var cur := 0
var over := false
var finish_seq := 0
var rng := RandomNumberGenerator.new()
## Visual/sound events produced by the last apply() (for animations); cleared on every apply().
var fx: Array = []

func _fx(t: String, data: Dictionary = {}) -> void:
	var e := data.duplicate()
	e["t"] = t
	e["seat"] = cur
	fx.append(e)

## seats: Array of {"name": String, "pet": race id, "cls": class id, "bot": level or ""}. dice_seed >= 0 makes dice rolls reproducible (tests).
## Puzzle settings: givens (-1 = grid default) and quota mode (see Puzzle.generate).
var givens := -1
var mode := ""

func _init(n: int, seed_value: int, seats: Array, dice_seed: int = -1, givens_: int = -1, mode_: String = "") -> void:
	givens = givens_
	mode = mode_
	size = n
	game_seed = seed_value
	br = Puzzle.GRIDS[n]["br"]
	bc = Puzzle.GRIDS[n]["bc"]
	var base := Puzzle.generate(n, game_seed, givens, mode)
	var used := [base["sol"]]
	for k in seats.size():
		var s: Dictionary = seats[k]
		var mine := base
		if k > 0:
			# small grids have few fair variations: retry until this seat's board differs from every other seat's
			for attempt in 24:
				mine = Puzzle.transform(base["sol"], base["puz"], n, br, bc, DRng.new(game_seed * 31 + 7919 * k + 104729 * attempt))
				if not used.has(mine["sol"]):
					break
			used.append(mine["sol"])
		var ps := PlayerState.new(s["name"], s["pet"], mine["sol"], mine["puz"], Rules.START_DICE[n])
		ps.bot = str(s.get("bot", ""))
		ps.cls = str(s.get("cls", ""))
		players.append(ps)
	if dice_seed >= 0:
		rng.seed = dice_seed
	else:
		rng.randomize()

## Single entry point for every player action (UI, bots and, later, online replay use the same dictionaries).
## {"a": "roll"} {"a": "hold", "i"} {"a": "lock"} {"a": "place", "i", "c"} {"a": "hint", "i"}
## {"a": "buy", "id", "t"} {"a": "upg", "i"} {"a": "end"}
func apply(act: Dictionary) -> Dictionary:
	fx = []
	var res := _apply(act)
	res["fx"] = fx.duplicate()
	return res

func _apply(act: Dictionary) -> Dictionary:
	match str(act.get("a", "")):
		"roll":
			return roll()
		"hold":
			return hold(int(act["i"]))
		"lock":
			return lock()
		"place":
			return place(int(act["i"]), int(act["c"]))
		"hint":
			return hint(int(act["i"]))
		"buy":
			return buy(str(act["id"]), int(act.get("t", -1)))
		"upg":
			return upgrade(int(act["i"]))
		"end":
			return end_turn()
		"memo":
			return memo(int(act["c"]))
		"botify":
			var s := int(act["s"])
			if s < 0 or s >= players.size() or players[s].bot != "":
				return _r(false)
			players[s].bot = "normal"
			return _r(true, "%s's seat is now played by a bot" % players[s].name)
	return _r(false)

static func _r(ok: bool, msg: String = "") -> Dictionary:
	return {"ok": ok, "msg": msg}

func current() -> PlayerState:
	return players[cur]

func offers() -> Array:
	return Rules.offers(game_seed, current().turn)

func count_value(p: PlayerState, v: int) -> int:
	var c := 0
	for x in p.grid:
		if x == v:
			c += 1
	return c

func is_wild(p: PlayerState, i: int) -> bool:
	return i < p.dv.size() and Rules.is_wild(p.dv[i], p.df[i])

func is_dead(p: PlayerState, i: int) -> bool:
	return i < p.dv.size() and p.dv[i] > 0 and Rules.is_dead(p.dv[i], p.df[i], size)

## The die shows a number whose cells are all filled (a Mirror die stays useful while its mirror number is open).
func is_useless(p: PlayerState, i: int) -> bool:
	if i >= p.dv.size():
		return false
	var v: int = p.dv[i]
	if v == 0 or Rules.is_wild(v, p.df[i]) or v > size:
		return false
	for w in die_values(p, i):
		if count_value(p, w) < size:
			return false
	return true

## Numbers die i may stand for: its value, or value -1 / value / value +1 for a Mirror die.
func die_values(p: PlayerState, i: int) -> Array:
	var v: int = p.dv[i]
	if v < 1 or v > size:
		return []
	if p.dk[i] != "mirror":
		return [v]
	var out := []
	for w in [v - 1, v, v + 1]:
		if w >= 1 and w <= size:
			out.append(w)
	return out

## Cells where value v is legal by sudoku rules (for highlighting).
func legal(p: PlayerState, cell: int, v: int) -> bool:
	return p.grid[cell] == 0 and Puzzle.ok(p.grid, size, br, bc, cell / size, cell % size, v)

func fits(p: PlayerState, i: int, cell: int) -> bool:
	var v: int = p.dv[i]
	if Rules.is_wild(v, p.df[i]):
		return true
	if v > size:
		return false
	return die_values(p, i).has(p.sol[cell])

func _need(p: PlayerState, faces: int, x: int) -> bool:
	if Rules.is_wild(x, faces):
		return p.grid.has(0)
	if x > size:
		return false
	for j in p.grid.size():
		if p.grid[j] == 0 and p.sol[j] == x:
			return true
	return false

func _roll_die(p: PlayerState, i: int) -> int:
	var f: int = p.df[i]
	var v := rng.randi_range(1, f)
	if p.dk[i] == "loaded":
		var w := rng.randi_range(1, f)
		if not _need(p, f, v) and _need(p, f, w):
			v = w
	return v

static func _b(a: Array, i: int) -> bool:
	return i < a.size() and bool(a[i])

func _apply_curses(p: PlayerState) -> Dictionary:
	var res := {"hex": 0, "bl": 0, "sh": 0, "msgs": []}
	for c in p.pending:
		var nm: String = Rules.CURSES.get(c["k"], "Curse")
		if p.ward > 0:
			p.ward -= 1
			res["msgs"].append("Ward blocked %s from %s" % [nm, c["from"]])
			_fx("ward", {"k": c["k"]})
			continue
		_fx("curse", {"k": c["k"], "from": c["from"]})
		match c["k"]:
			"hex":
				res["hex"] += 1
			"blight":
				p.blight += 2
			"shackle":
				res["sh"] = 1
		res["msgs"].append("%s from %s!" % [nm, c["from"]])
	p.pending = []
	return res

func roll() -> Dictionary:
	var p := current()
	if not p.active() or p.lk or p.rolls < 1:
		return _r(false)
	var rolls := p.rolls
	var msgs := []
	if not p.fxd:
		p.fxd = true
		var e := _apply_curses(p)
		rolls = maxi(1, rolls - e["hex"])
		p.shk = e["sh"]
		msgs = e["msgs"]
	var n := p.df.size()
	var dv := []
	var du := []
	var dh := []
	var rolled := []
	for i in n:
		var keep: bool = _b(p.dv, i) and p.dv[i] != 0 and (_b(p.dh, i) or _b(p.du, i))
		dv.append(p.dv[i] if keep else _roll_die(p, i))
		if not keep:
			rolled.append(i)
		du.append(_b(p.du, i))
		dh.append(_b(p.dh, i))
	p.dv = dv
	p.du = du
	p.dh = dh
	p.rolls = rolls - 1
	_fx("roll", {"dice": rolled})
	if p.rolls < 1:
		var lm := _on_lock(p)
		if lm != "":
			msgs.append(lm)
	return _r(true, " · ".join(PackedStringArray(msgs)))

## Locking: unused rolls pay 1 gold each, then a pending Blight turns 2 random unplaced dice into 1s.
func _on_lock(p: PlayerState) -> String:
	p.lk = true
	var msgs := []
	_fx("lock")
	if p.rolls > 0:
		p.gold += p.rolls
		_fx("gold", {"n": p.rolls, "why": "unused rolls"})
		msgs.append("+%d gold for %d unused roll%s" % [p.rolls, p.rolls, "s" if p.rolls > 1 else ""])
		p.rolls = 0
	if p.blight > 0:
		var free := []
		for i in p.dv.size():
			if p.dv[i] != 0 and not p.du[i]:
				free.append(i)
		for k in range(free.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var t = free[k]
			free[k] = free[j]
			free[j] = t
		for i in free.slice(0, p.blight):
			p.dv[i] = 1
		_fx("blight", {"dice": free.slice(0, p.blight)})
		msgs.append("Blight! %d dice turned into 1s" % mini(p.blight, free.size()))
		p.blight = 0
	return " · ".join(PackedStringArray(msgs))

func lock() -> Dictionary:
	var p := current()
	if p.dv.is_empty() or p.lk or not p.active():
		return _r(false)
	var m := _on_lock(p)
	return _r(true, m if m != "" else "Dice locked")

func hold(i: int) -> Dictionary:
	var p := current()
	if not p.active() or p.lk or i >= p.dv.size() or _b(p.du, i) or p.dv[i] == 0 or p.rolls == 0:
		return _r(false)
	var cap := p.shk if p.shk > 0 else Rules.MAXH
	if not p.dh[i]:
		if is_useless(p, i):
			return _r(false, "Number complete: reroll it")
		if p.held_count() >= cap:
			return _r(false, ("Shackled: hold only %d" % cap) if p.shk > 0 else ("Hold limit: %d dice" % cap))
	p.dh[i] = not p.dh[i]
	_fx("hold", {"i": i, "on": p.dh[i]})
	return _r(true)

func can_pick(i: int) -> Dictionary:
	var p := current()
	if not p.active():
		return _r(false)
	if not p.lk:
		return _r(false, "Lock your dice first")
	if i >= p.dv.size() or p.dv[i] == 0 or p.du[i]:
		return _r(false)
	if is_dead(p, i):
		return _r(false, "Dead face: cannot be placed")
	if is_useless(p, i):
		return _r(false, "Number complete: cannot be placed")
	return _r(true)

## Place die i on cell. Returns {"ok", "msg", "hit", "turn_over"}.
func place(i: int, cell: int) -> Dictionary:
	var p := current()
	var chk := can_pick(i)
	if not chk["ok"]:
		return chk
	if cell < 0 or cell >= p.grid.size() or p.grid[cell] != 0:
		return _r(false)
	var res := _r(true)
	p.du[i] = true
	var hit := fits(p, i, cell)
	res["hit"] = hit
	if hit:
		p.grid[cell] = p.sol[cell]
		p.plc += 1
		var earned := 1 + (2 if p.dk[i] == "golden" else 0)
		p.gold += earned
		res["msg"] = "Correct! +%d gold%s" % [earned, " (Golden die)" if earned > 1 else ""]
		_fx("hit", {"c": cell, "gold": earned, "i": i})
		if is_wild(p, i):
			res["msg"] = "Wild! Placed anywhere, +%d gold" % earned
	elif p.dk[i] == "safe":
		res["msg"] = "Safe die: no mistake"
		_fx("safe", {"c": cell})
	else:
		p.mis += 1
		res["msg"] = "Wrong spot: +1 mistake"
		_fx("miss", {"c": cell})
		if p.mis >= Rules.MAXMIS:
			p.lost = true
			res["msg"] = "Third mistake: %s is out!" % p.name
			_fx("out")
	if not p.grid.has(0):
		p.done = true
		finish_seq += 1
		p.fin = finish_seq
		res["msg"] = "%s cleared the dungeon!" % p.name
		_fx("win")
	res["turn_over"] = not p.active()
	if res["turn_over"]:
		_advance()
	return res

func end_turn() -> Dictionary:
	var p := current()
	if p.dv.is_empty() or not p.active():
		return _r(false)
	var b := Rules.combo(p.dv, size)
	var pity := 0 if p.used_any() else 1
	p.stall = 0 if p.used_any() else p.stall + 1
	var parts := []
	if b > 0:
		parts.append("Combo! +%d hint%s" % [b, "s" if b > 1 else ""])
	if not p.lk and p.rolls > 0:
		parts.append("+%d gold for %d unused roll%s" % [p.rolls, p.rolls, "s" if p.rolls > 1 else ""])
		p.gold += p.rolls
	if pity > 0:
		parts.append("+1 gold: Rook tips you for a turn with no placements")
	var msg := " · ".join(PackedStringArray(parts))
	var paid := pity + (p.rolls if not p.lk else 0)
	if paid > 0:
		_fx("gold", {"n": paid, "why": "end of turn"})
	if b > 0:
		_fx("combo", {"n": b})
	p.hints += b
	p.gold += pity
	p.blight = 0
	p.turn += 1
	p.bt = []
	p.lk = false
	p.fxd = false
	p.shk = 0
	p.dv = []
	p.du = []
	p.dh = []
	p.rolls = Rules.ROLLS
	_advance()
	return _r(true, msg)

func hint(i: int) -> Dictionary:
	var p := current()
	if p.hints < 1:
		return _r(false)
	var chk := can_pick(i)
	if not chk["ok"]:
		return chk
	var c := -1
	for j in p.grid.size():
		if p.grid[j] == 0 and fits(p, i, j):
			c = j
			break
	if c < 0:
		return _r(false, "That die fits nowhere")
	p.hints -= 1
	return place(i, c)

func rivals() -> Array:
	var out := []
	for j in players.size():
		if j != cur and players[j].active():
			out.append(j)
	return out

func next_rival() -> int:
	var n := players.size()
	for k in range(1, n):
		var j := (cur + k) % n
		if players[j].active():
			return j
	return -1

## Buy an offer by id. Curses go to target (seat index) or the next rival. The Whetstone is bought through upgrade().
func buy(id: String, target: int = -1) -> Dictionary:
	var p := current()
	if not p.active():
		return _r(false)
	var it: Dictionary = {}
	for o in offers():
		if o["id"] == id:
			it = o
	if it.is_empty() or id == "whet":
		return _r(false)
	if p.gold < it["c"]:
		return _r(false, "Not enough gold")
	if p.bt.has(id):
		return _r(false, "Sold out this turn")
	if id == "roll" and p.lk:
		return _r(false, "Dice are locked")
	var msg := "Bought: %s" % it["n"]
	if it.has("x"):
		var rv := rivals()
		if rv.is_empty():
			return _r(false, "No rival to curse")
		var to := target if rv.has(target) else next_rival()
		players[to].pending.append({"k": it["x"], "from": p.name})
		_fx("cast", {"k": it["x"], "to": to})
		msg = "%s sent to %s" % [it["n"], players[to].name]
	elif it.has("f"):
		if p.df.size() >= Rules.MAXP:
			return _r(false, "Dice pool is full (%d)" % Rules.MAXP)
		p.df.append(it["f"])
		p.dk.append(it["k"])
		if not p.dv.is_empty():
			p.dv.append(0)
			p.du.append(false)
			p.dh.append(false)
	elif id == "hint":
		p.hints += 1
	elif id == "roll":
		p.rolls += 1
	elif id == "ward":
		p.ward += 1
	elif id == "scribe":
		p.scribe += 3
	p.gold -= it["c"]
	p.bt.append(id)
	if not it.has("x"):
		_fx("buy", {"id": id})
	return _r(true, msg)

## Scribe quill: show the possible numbers on an empty tile (uses one charge).
func memo(cell: int) -> Dictionary:
	var p := current()
	if not p.active() or p.scribe < 1 or cell < 0 or cell >= p.grid.size() or p.grid[cell] != 0 or p.memo.has(cell):
		return _r(false)
	p.memo.append(cell)
	p.scribe -= 1
	_fx("memo", {"c": cell})
	return _r(true, "Memo written (%d left)" % p.scribe)

## Rule-legal numbers for an empty tile (what a memo shows).
func candidates(p: PlayerState, cell: int) -> Array:
	var out := []
	if p.grid[cell] != 0:
		return out
	for v in range(1, size + 1):
		if legal(p, cell, v):
			out.append(v)
	return out

## Whetstone: upgrade die i one step along d4 > d6 > d8 > d10.
func upgrade(i: int) -> Dictionary:
	var p := current()
	if not p.active() or i < 0 or i >= p.df.size():
		return _r(false)
	if p.gold < Rules.WHET:
		return _r(false, "Not enough gold")
	var k := Rules.UPGRADES.find(p.df[i])
	if k < 0 or k >= Rules.UPGRADES.size() - 1:
		return _r(false, "Already the strongest die (d10)")
	var old: int = p.df[i]
	p.df[i] = Rules.UPGRADES[k + 1]
	p.gold -= Rules.WHET
	_fx("upgrade", {"i": i})
	return _r(true, "d%d upgraded to d%d" % [old, p.df[i]])

func _advance() -> void:
	var n := players.size()
	for k in range(1, n + 1):
		var j := (cur + k) % n
		if players[j].active():
			cur = j
			return
	over = true

## Seats ordered for the results screen: finished first (by score, then finish order), then playing, then out.
func ranking() -> Array:
	var idx := DRng.seq(players.size())
	idx.sort_custom(_rank_less)
	return idx

func _rank_group(p: PlayerState) -> int:
	return 0 if p.done else (2 if p.lost else 1)

func _rank_less(a: int, b: int) -> bool:
	var pa: PlayerState = players[a]
	var pb: PlayerState = players[b]
	if _rank_group(pa) != _rank_group(pb):
		return _rank_group(pa) < _rank_group(pb)
	if pa.done:
		if pa.score() != pb.score():
			return pa.score() < pb.score()
		return pa.fin < pb.fin
	return Puzzle.filled(pa.grid) > Puzzle.filled(pb.grid)
