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
## givens < 0 uses the grid default. mode "" (legacy, matches the web prototype) or "random" removes cells in random order;
## "even" spreads the givens evenly over the digits (extras go to the highest digits); "boost" also gives the 9s and 8s
## extra givens taken from the lowest digits (high numbers need d8/d10 dice).
static func generate(n: int, seed_value: int, givens: int = -1, mode: String = "") -> Dictionary:
	var cfg: Dictionary = GRIDS[n]
	var br: int = cfg["br"]
	var bc: int = cfg["bc"]
	if givens < 0:
		givens = cfg["givens"]
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
	if mode == "even" or mode == "boost":
		return _generate_quota(sol, n, br, bc, givens, quotas(n, givens, mode), r)
	var puz := sol.duplicate()
	for i in DRng.shuf(DRng.seq(n * n), r):
		if filled(puz) <= givens:
			break
		var v: int = puz[i]
		puz[i] = 0
		if count(puz, n, br, bc, 2) != 1:
			puz[i] = v
	return {"sol": sol, "puz": puz, "attempts": 1}

## Givens per digit (index 1..n).
static func quotas(n: int, givens: int, mode: String) -> Array:
	var q := [0]
	for d in n:
		q.append(givens / n)
	for k in givens % n:
		q[n - k] += 1
	if mode == "boost" and n >= 9:
		for pair in [[9, 1], [9, 2], [8, 3]]:
			if q[pair[1]] > 1 and q[pair[0]] < n:
				q[pair[0]] += 1
				q[pair[1]] -= 1
	return q

## Removes cells while keeping the puzzle unique and never dropping a digit below its quota.
## Retries with a new removal order; returns the attempt closest to the target.
static func _generate_quota(sol: Array, n: int, br: int, bc: int, givens: int, q: Array, r: DRng) -> Dictionary:
	var best: Array = []
	var tries := 0
	for attempt in 40:
		tries += 1
		var puz := sol.duplicate()
		var cnt := [0]
		for d in n:
			cnt.append(n)
		var left := n * n
		for i in DRng.shuf(DRng.seq(n * n), r):
			if left <= givens:
				break
			var d: int = sol[i]
			if cnt[d] <= q[d]:
				continue
			puz[i] = 0
			if count(puz, n, br, bc, 2) != 1:
				puz[i] = d
			else:
				cnt[d] -= 1
				left -= 1
		if best.is_empty() or filled(puz) < filled(best):
			best = puz
		if left <= givens:
			break
	return {"sol": sol, "puz": best, "attempts": tries}

## Dice class of a digit: the smallest die that can roll it (1-4 any die, 5-6 d6+, 7-8 d8+, 9 d10).
static func dice_class(d: int) -> int:
	for k in Rules.UPGRADES.size():
		if d <= Rules.UPGRADES[k]:
			return k
	return Rules.UPGRADES.size()

static func digit_counts(g: Array, n: int) -> Array:
	var c := []
	for d in n + 1:
		c.append(0)
	for v in g:
		c[v] += 1
	c[0] = 0
	return c

static func filled(g: Array) -> int:
	var c := 0
	for v in g:
		if v != 0:
			c += 1
	return c

## A different-looking but equally hard copy: digits relabelled, rows shuffled within bands and bands shuffled,
## columns within stacks and stacks shuffled, and (square boxes only) maybe transposed. Uniqueness is preserved.
## fair = true only swaps digits that need the same dice and have the same number of givens, so every seat
## keeps the same amount of given 7s, 8s and 9s (fair = false is the v0.10 behaviour, kept for the balance study).
static func transform(sol: Array, puz: Array, n: int, br: int, bc: int, r: DRng, fair: bool = true) -> Dictionary:
	var rows := []
	for band in DRng.shuf(DRng.seq(n / br), r):
		for y in DRng.shuf(DRng.seq(br), r):
			rows.append(band * br + y)
	var cols := []
	for stack in DRng.shuf(DRng.seq(n / bc), r):
		for x in DRng.shuf(DRng.seq(bc), r):
			cols.append(stack * bc + x)
	var digits := [0]
	if fair:
		for d in n:
			digits.append(d + 1)
		var cnt := digit_counts(puz, n)
		var groups := {}
		for d in range(1, n + 1):
			var key := "%d:%d" % [dice_class(d), cnt[d]]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(d)
		for key in groups:
			var src: Array = groups[key]
			var dst := DRng.shuf(src, r)
			for k in src.size():
				digits[src[k]] = dst[k]
	else:
		for d in DRng.shuf(DRng.seq(n), r):
			digits.append(d + 1)
	var flip := br == bc and r.next_float() < 0.5
	var s2 := []
	var p2 := []
	for y in n:
		for x in n:
			var src: int = rows[x] * n + cols[y] if flip else rows[y] * n + cols[x]
			s2.append(digits[sol[src]])
			p2.append(digits[puz[src]] if puz[src] != 0 else 0)
	return {"sol": s2, "puz": p2}
