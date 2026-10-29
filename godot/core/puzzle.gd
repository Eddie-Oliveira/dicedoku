class_name Puzzle
extends RefCounted
## Sudoku generator and checks. Same algorithm and random calls as the web prototype's gen().

const GRIDS := {
	4: {"br": 2, "bc": 2, "givens": 6},
	6: {"br": 2, "bc": 3, "givens": 14},
	9: {"br": 3, "bc": 3, "givens": 34},
}

## True if value v may go at (y, x) by row/column/box rules.
static func ok(g: Array, n: int, br: int, bc: int, y: int, x: int, v: int) -> bool:
	for k in n:
		if g[y * n + k] == v or g[k * n + x] == v:
			return false
	var y0 := y - y % br
	var x0 := x - x % bc
	for a in br:
		for b in bc:
			if g[(y0 + a) * n + x0 + b] == v:
				return false
	return true

## Number of solutions, capped at lim (bitmask solver; the capped count does not depend on search order).
static func count(g: Array, n: int, br: int, bc: int, lim: int) -> int:
	var rows := []
	var cols := []
	var boxes := []
	for i in n:
		rows.append(0)
		cols.append(0)
		boxes.append(0)
	var empties := []
	var work := g.duplicate()
	for i in n * n:
		var v: int = work[i]
		if v == 0:
			empties.append(i)
			continue
		var y := i / n
		var x := i % n
		var bit := 1 << v
		if (rows[y] & bit) or (cols[x] & bit) or (boxes[_box(y, x, n, br, bc)] & bit):
			return 0
		rows[y] |= bit
		cols[x] |= bit
		boxes[_box(y, x, n, br, bc)] |= bit
	return _solve(work, n, br, bc, rows, cols, boxes, empties, lim)

static func _box(y: int, x: int, n: int, br: int, bc: int) -> int:
	return (y / br) * (n / bc) + x / bc

static func _pop(m: int) -> int:
	var c := 0
	while m:
		m &= m - 1
		c += 1
	return c

static func _solve(g: Array, n: int, br: int, bc: int, rows: Array, cols: Array, boxes: Array, empties: Array, lim: int) -> int:
	var full := (1 << (n + 1)) - 2
	var best := -1
	var best_mask := 0
	var best_cnt := 99
	for i in empties:
		if g[i] != 0:
			continue
		var y: int = i / n
		var x: int = i % n
		var m: int = full & ~(rows[y] | cols[x] | boxes[_box(y, x, n, br, bc)])
		var c := _pop(m)
		if c < best_cnt:
			best_cnt = c
			best = i
			best_mask = m
			if c <= 1:
				break
	if best == -1:
		return 1
	if best_cnt == 0:
		return 0
	var total := 0
	var by: int = best / n
	var bx: int = best % n
	var bb := _box(by, bx, n, br, bc)
	for v in range(1, n + 1):
		if total >= lim:
			break
		var bit := 1 << v
		if best_mask & bit:
			g[best] = v
			rows[by] |= bit
			cols[bx] |= bit
			boxes[bb] |= bit
			total += _solve(g, n, br, bc, rows, cols, boxes, empties, lim - total)
			g[best] = 0
			rows[by] &= ~bit
			cols[bx] &= ~bit
			boxes[bb] &= ~bit
	return total

## Returns {"sol": Array, "puz": Array}. 0 = empty cell.
static func generate(n: int, seed_value: int) -> Dictionary:
	var cfg: Dictionary = GRIDS[n]
	var br: int = cfg["br"]
	var bc: int = cfg["bc"]
	var givens: int = cfg["givens"]
	var r := DRng.new(seed_value)
	var rows := []
	for grp in DRng.shuf(DRng.seq(n / br), r):
		for x in DRng.shuf(DRng.seq(br), r):
			rows.append(grp * br + x)
	var cols := []
	for grp in DRng.shuf(DRng.seq(n / bc), r):
		for x in DRng.shuf(DRng.seq(bc), r):
			cols.append(grp * bc + x)
	var d := []
	for x in DRng.shuf(DRng.seq(n), r):
		d.append(x + 1)
	var sol := []
	for y in rows:
		for x in cols:
			sol.append(d[(bc * (y % br) + y / br + x) % n])
	var puz := sol.duplicate()
	for i in DRng.shuf(DRng.seq(n * n), r):
		if filled(puz) <= givens:
			break
		var v: int = puz[i]
		puz[i] = 0
		if count(puz, n, br, bc, 2) != 1:
			puz[i] = v
	return {"sol": sol, "puz": puz}

static func filled(g: Array) -> int:
	var c := 0
	for v in g:
		if v != 0:
			c += 1
	return c
