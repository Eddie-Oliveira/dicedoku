class_name Game
extends RefCounted
## A local (pass-and-play) match. Every action works on the current seat and returns {"ok": bool, "msg": String}.
## Port of the web prototype v0.8.1 rules, minus the d20.

var size: int
var game_seed: int
var br: int
var bc: int
var sol: Array
var puz: Array
var players: Array = []
var cur := 0
var over := false
var finish_seq := 0
var rng := RandomNumberGenerator.new()

## seats: Array of {"name": String, "pet": String}. dice_seed >= 0 makes dice rolls reproducible (tests).
func _init(n: int, seed_value: int, seats: Array, dice_seed: int = -1) -> void:
	size = n
	game_seed = seed_value
	br = Puzzle.GRIDS[n]["br"]
	bc = Puzzle.GRIDS[n]["bc"]
	var p := Puzzle.generate(n, game_seed)
	sol = p["sol"]
	puz = p["puz"]
	for s in seats:
		players.append(PlayerState.new(s["name"], s["pet"], puz, Rules.START_DICE[n]))
	if dice_seed >= 0:
		rng.seed = dice_seed
	else:
		rng.randomize()

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
	return count_value(p, v) == size and not (p.dk[i] == "mirror" and count_value(p, size + 1 - v) < size)

## Cells where value v is legal by sudoku rules (for highlighting).
func legal(p: PlayerState, cell: int, v: int) -> bool:
	return p.grid[cell] == 0 and Puzzle.ok(p.grid, size, br, bc, cell / size, cell % size, v)

func fits(p: PlayerState, i: int, cell: int) -> bool:
	var v: int = p.dv[i]
	if Rules.is_wild(v, p.df[i]):
		return true
	if v > size:
		return false
	return v == sol[cell] or (p.dk[i] == "mirror" and size + 1 - v == sol[cell])

func _need(p: PlayerState, faces: int, x: int) -> bool:
	if Rules.is_wild(x, faces):
		return p.grid.has(0)
	if x > size:
		return false
	for j in p.grid.size():
		if p.grid[j] == 0 and sol[j] == x:
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
			continue
		match c["k"]:
			"hex":
				res["hex"] += 1
			"blight":
				res["bl"] += 2
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
	var bl := 0
	var msgs := []
	if not p.fxd:
		p.fxd = true
		var e := _apply_curses(p)
		rolls = maxi(1, rolls - e["hex"])
		bl = e["bl"]
		p.shk = e["sh"]
		msgs = e["msgs"]
	var n := p.df.size()
	var dv := []
	var du := []
	var dh := []
	for i in n:
		var keep := _b(p.dv, i) and p.dv[i] != 0 and (_b(p.dh, i) or _b(p.du, i))
		dv.append(p.dv[i] if keep else _roll_die(p, i))
		du.append(_b(p.du, i))
		dh.append(_b(p.dh, i))
	if bl > 0:
		var free := []
		for i in n:
			if not (dh[i] or du[i]):
				free.append(i)
		for k in range(free.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var t = free[k]
			free[k] = free[j]
			free[j] = t
		for i in free.slice(0, bl):
			dv[i] = 1
	p.dv = dv
	p.du = du
	p.dh = dh
	p.rolls = rolls - 1
	p.lk = p.rolls < 1
	return _r(true, " · ".join(PackedStringArray(msgs)))

func lock() -> Dictionary:
	var p := current()
	if p.dv.is_empty() or p.lk or not p.active():
		return _r(false)
	p.lk = true
	return _r(true, "Dice locked")

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
		p.grid[cell] = sol[cell]
		p.plc += 1
		p.gold += 1 + (2 if p.dk[i] == "golden" else 0)
		if is_wild(p, i):
			res["msg"] = "Wild! Placed anywhere"
	elif p.dk[i] == "safe":
		res["msg"] = "Safe die: no mistake"
	else:
		p.mis += 1
		res["msg"] = "Wrong spot: +1 mistake"
		if p.mis >= Rules.MAXMIS:
			p.lost = true
			res["msg"] = "Third mistake: %s is out!" % p.name
	if not p.grid.has(0):
		p.done = true
		finish_seq += 1
		p.fin = finish_seq
		res["msg"] = "%s cleared the dungeon!" % p.name
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
	var msg := ""
	if b > 0:
		msg = "Combo! +%d hint%s" % [b, "s" if b > 1 else ""]
	elif pity > 0:
		msg = "No placements: Rook tips you 1 gold"
	p.hints += b
	p.gold += pity
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
	p.gold -= it["c"]
	p.bt.append(id)
	return _r(true, msg)

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
	return _r(true, "d%d → d%d" % [old, p.df[i]])

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
