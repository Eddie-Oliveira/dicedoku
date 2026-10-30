class_name Rules
extends RefCounted
## Game constants and pure rule helpers (v0.9: no d20; the d10's zero is the only wild).

const UPGRADES := [4, 6, 8, 10]
const START_DICE := {4: [4, 4, 4, 4, 4], 6: [6, 6, 6, 6, 6], 9: [6, 6, 6, 6, 6]}
const ROLLS := 3
const WHET := 3
const MAXP := 9
const MAXH := 5
const MAXMIS := 3
## Races (animals). Seats keep the race id in the "pet" field; the class is in "cls" (skills come later).
const PETS := ["cat", "dog", "fox", "bunny", "bear", "mouse"]
const PET_NAMES := {"cat": "Cat", "dog": "Dog", "fox": "Fox", "bunny": "Bunny", "bear": "Bear", "mouse": "Mouse"}
const CLASSES := ["wizard", "knight", "rogue", "bard", "cleric", "ranger"]
const CLASS_NAMES := {"wizard": "Wizard", "knight": "Knight", "rogue": "Rogue", "bard": "Bard", "cleric": "Cleric", "ranger": "Ranger"}
## Older single-image portraits used when the layered art is missing.
const LEGACY_PORTRAIT := {"cat": "kitten_wizard", "dog": "puppy_knight", "fox": "fox_rogue", "bunny": "bunny_bard"}

static func hero_title(race: String, cls: String) -> String:
	return ("%s %s" % [PET_NAMES.get(race, race), CLASS_NAMES.get(cls, "")]).strip_edges()
const CURSES := {"hex": "Hex", "blight": "Blight", "shackle": "Shackle"}
const GOLD_RULES := "+1 per correct number (Golden die: +2 more)  ·  +1 per unused roll when you lock or end your turn  ·  +1 for a turn with no placements"

const WHETSTONE := {"id": "whet", "n": "Whetstone", "d": "Upgrade a die one step (up to d10)", "c": WHET, "icon": "whetstone"}
## Same ids, prices and order as the web prototype (offer parity depends on the order).
const SHOP := [
	{"id": "d4", "n": "Extra d4", "d": "Adds a d4 to your pool", "c": 2, "f": 4, "k": "std", "icon": "extra_die"},
	{"id": "d6", "n": "Extra d6", "d": "Adds a d6 to your pool", "c": 4, "f": 6, "k": "std", "icon": "extra_die"},
	{"id": "d8", "n": "Extra d8", "d": "Adds a d8 to your pool", "c": 6, "f": 8, "k": "std", "icon": "extra_die"},
	{"id": "d10", "n": "Extra d10", "d": "Adds a d10 to your pool", "c": 8, "f": 10, "k": "std", "icon": "extra_die"},
	{"id": "mir", "n": "Mirror d6", "d": "Can be placed as its value, value -1 or value +1", "c": 6, "f": 6, "k": "mirror", "icon": "mirror"},
	{"id": "safe", "n": "Safe d6", "d": "A miss costs no mistake", "c": 5, "f": 6, "k": "safe", "icon": "safe"},
	{"id": "gold", "n": "Golden d6", "d": "+2 gold per hit", "c": 5, "f": 6, "k": "golden", "icon": "golden"},
	{"id": "load", "n": "Loaded d6", "d": "Rolls twice, keeps a useful face", "c": 7, "f": 6, "k": "loaded", "icon": "loaded"},
	{"id": "hint", "n": "Hint scroll", "d": "+1 hint", "c": 6, "icon": "hint_scroll"},
	{"id": "roll", "n": "Extra roll", "d": "One more roll this turn", "c": 3, "icon": "extra_roll"},
	{"id": "scribe", "n": "Scribe's quill", "d": "Memo the possible numbers on 3 tiles of your choice", "c": 4, "icon": "hint_scroll"},
]
const VERSUS := [
	{"id": "hex", "n": "Hex", "d": "Rival loses 1 roll next turn", "c": 4, "x": "hex", "icon": "hex"},
	{"id": "blight", "n": "Blight", "d": "When the rival locks next turn, 2 of their dice turn into 1s", "c": 5, "x": "blight", "icon": "blight"},
	{"id": "shackle", "n": "Shackle", "d": "Rival can hold only 1 die next turn", "c": 10, "x": "shackle", "icon": "shackle"},
	{"id": "ward", "n": "Ward", "d": "Blocks the next curse aimed at you", "c": 3, "icon": "ward"},
]

## Merchant stock for a turn: Whetstone, one versus item, then 1-3 random items. Same for every player on that turn.
static func offers(seed_value: int, turn: int) -> Array:
	var r := DRng.new(seed_value * 31 + turn)
	var out := [WHETSTONE]
	out.append(DRng.shuf(VERSUS, r)[0])
	var s := DRng.shuf(SHOP, r)
	var k := 1 + int(r.next_float() * 3.0)
	out.append_array(s.slice(0, k))
	return out

## Hints earned by a final roll: first five rolled dice; five of a kind = 2, run of 4 = 1, on 9x9 a triple = 1.
static func combo(dv: Array, n: int) -> int:
	var d := []
	for v in dv:
		if v > 0:
			d.append(v)
	d = d.slice(0, 5)
	var c := {}
	var mx := 0
	for v in d:
		c[v] = c.get(v, 0) + 1
		mx = maxi(mx, c[v])
	if mx >= 5:
		return 2
	var u := []
	for v in d:
		if v <= n and not u.has(v):
			u.append(v)
	u.sort()
	var best := 1
	var run := 1
	for i in range(1, u.size()):
		run = run + 1 if u[i] == u[i - 1] + 1 else 1
		best = maxi(best, run)
	return 1 if best >= 4 or (n >= 9 and mx >= 3) else 0

## A d10 shows 0-9; its zero (stored as 10) is wild.
static func is_wild(v: int, faces: int) -> bool:
	return v == 10 and faces == 10

static func is_dead(v: int, faces: int, n: int) -> bool:
	return v > n and not is_wild(v, faces)

static func face_label(v: int, faces: int) -> String:
	if v == 0:
		return "-"
	return "0" if is_wild(v, faces) else str(v)
