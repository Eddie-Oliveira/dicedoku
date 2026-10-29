class_name DRng
extends RefCounted
## Mulberry32 PRNG, bit-exact with the web prototype's rng() so the same seed gives the same puzzle and shop.

const M := 0xFFFFFFFF
var a: int

func _init(seed_value: int) -> void:
	a = seed_value & M

static func imul(x: int, y: int) -> int:
	x &= M
	y &= M
	return ((((x * (y >> 16)) & 0xFFFF) << 16) + x * (y & 0xFFFF)) & M

func next_u32() -> int:
	a = (a + 0x6D2B79F5) & M
	var t := imul(a ^ (a >> 15), 1 | a)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) ^ t) & M
	return (t ^ (t >> 14)) & M

func next_float() -> float:
	return float(next_u32()) / 4294967296.0

## Fisher-Yates exactly like the prototype's shuf(a, r).
static func shuf(arr: Array, r: DRng) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := int(floor(r.next_float() * float(i + 1)))
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out

static func seq(n: int) -> Array:
	var out := []
	for i in n:
		out.append(i)
	return out
