class_name Bot
extends RefCounted
## Computer players. Each call returns the next action dictionary for Game.apply().
## easy: simple sudoku logic, sometimes risks a guess; normal: only proven placements, guesses after 3 stuck turns;
## hard: knows the solution. Bots never touch Game.rng (online replay needs identical dice on every device).

static var rng := RandomNumberGenerator.new()

static func units(g: Game) -> Array:
	var n := g.size
	var out := []
	for k in n:
		var r := []
		var c := []
		for j in n:
			r.append(k * n + j)
			c.append(j * n + k)
		out.append(r)
		out.append(c)
	for by in n / g.br:
		for bx in n / g.bc:
			var b := []
			for a in g.br:
				for d in g.bc:
					b.append((by * g.br + a) * n + bx * g.bc + d)
			out.append(b)
	return out

static func cands(g: Game, p: PlayerState, cell: int) -> Array:
	var out := []
	if p.grid[cell] != 0:
		return out
	for v in range(1, g.size + 1):
		if g.legal(p, cell, v):
			out.append(v)
	return out

## Cells where v is proven: the cell's only candidate (naked single) or v's only spot in a row, column or box (hidden single).
static func forced_cells(g: Game, p: PlayerState, v: int) -> Array:
	var n := g.size
	var out := []
	if v < 1 or v > n or g.count_value(p, v) == n:
		return out
	for c in n * n:
		if p.grid[c] == 0:
			var cs := cands(g, p, c)
			if cs.size() == 1 and cs[0] == v:
				out.append(c)
	for u in units(g):
		var has := false
		var spots := []
		for c in u:
			if p.grid[c] == v:
				has = true
				break
			if p.grid[c] == 0 and g.legal(p, c, v):
				spots.append(c)
		if not has and spots.size() == 1 and not out.has(spots[0]):
			out.append(spots[0])
	return out

static func die_values(g: Game, p: PlayerState, i: int) -> Array:
	return g.die_values(p, i)

## Best cell for die i at this level, or -1.
static func target(g: Game, p: PlayerState, i: int, level: String) -> int:
	if g.is_wild(p, i):
		var best := -1
		var most := -1
		for c in p.grid.size():
			if p.grid[c] == 0:
				var k := cands(g, p, c).size()
				if k > most:
					most = k
					best = c
		return best
	if level == "hard":
		for c in p.grid.size():
			if p.grid[c] == 0 and g.fits(p, i, c):
				return c
		return -1
	for v in die_values(g, p, i):
		var f := forced_cells(g, p, v)
		if not f.is_empty():
			return f[0]
	return -1

## A rule-legal cell with the fewest candidates for die i (may be wrong), or -1.
static func guess(g: Game, p: PlayerState, i: int) -> int:
	var best := -1
	var fewest := 99
	for v in die_values(g, p, i):
		for c in p.grid.size():
			if g.legal(p, c, v):
				var k := cands(g, p, c).size()
				if k < fewest:
					fewest = k
					best = c
	return best

static func useful(g: Game, p: PlayerState, i: int, level: String) -> bool:
	if p.dv[i] == 0 or g.is_dead(p, i) or g.is_useless(p, i):
		return false
	if g.is_wild(p, i):
		return true
	if level == "easy":
		for v in die_values(g, p, i):
			for c in p.grid.size():
				if g.legal(p, c, v):
					return true
		return false
	return target(g, p, i, level) >= 0

static func next_action(g: Game) -> Dictionary:
	var p := g.current()
	var level := p.bot if p.bot != "" else "normal"
	if p.dv.is_empty():
		return {"a": "roll"}
	if not p.lk:
		var cap := p.shk if p.shk > 0 else Rules.MAXH
		if p.rolls > 0:
			for i in p.df.size():
				if not p.dh[i] and p.held_count() < cap and useful(g, p, i, level):
					return {"a": "hold", "i": i}
			for i in p.df.size():
				if not p.dh[i] and not useful(g, p, i, level):
					return {"a": "roll"}
		return {"a": "lock"}
	for i in p.df.size():
		if not g.can_pick(i)["ok"]:
			continue
		var c := target(g, p, i, level)
		if c >= 0:
			return {"a": "place", "i": i, "c": c}
	if p.hints > 0:
		for i in p.df.size():
			if g.can_pick(i)["ok"]:
				for c in p.grid.size():
					if p.grid[c] == 0 and g.fits(p, i, c):
						return {"a": "hint", "i": i}
	var risky := (level == "easy" and rng.randf() < 0.3) or (level == "normal" and p.stall >= 3 and not p.used_any())
	if risky and p.mis < Rules.MAXMIS - 1:
		for i in p.df.size():
			if g.can_pick(i)["ok"]:
				var c := guess(g, p, i)
				if c >= 0:
					return {"a": "place", "i": i, "c": c}
	return shop_action(g, p, level)

static func shop_action(g: Game, p: PlayerState, level: String) -> Dictionary:
	var n := g.size
	for o in g.offers():
		var id: String = o["id"]
		if p.gold < o["c"] or (id != "whet" and p.bt.has(id)):
			continue
		if id == "whet":
			if n == 9:
				var lo := -1
				for k in p.df.size():
					if p.df[k] < 10 and (lo < 0 or p.df[k] < p.df[lo]):
						lo = k
				if lo >= 0:
					return {"a": "upg", "i": lo}
		elif o.has("x"):
			if level != "easy" and not g.rivals().is_empty() and p.gold >= o["c"] + 2:
				return {"a": "buy", "id": id, "t": -1}
		elif o.has("f"):
			var f: int = o["f"]
			if p.df.size() < 7 and (f <= n or (f == 10 and n == 9)):
				return {"a": "buy", "id": id, "t": -1}
	return {"a": "end"}
