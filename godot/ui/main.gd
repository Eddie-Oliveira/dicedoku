extends Control
## Dicedoku v0.9 interface: lobby, pass-the-device, game, results. Built in code; plain look until the art pass.
## Every action calls the Game rules engine and rebuilds the current screen.

const C_PARCH := Color("#F1E3C6")
const C_PARCH_DARK := Color("#E2CFA5")
const C_INK := Color("#3B2A1A")
const C_WOOD := Color("#6B4426")
const C_STONE := Color("#8A8580")
const C_TORCH := Color("#FFB347")
const C_GLOW := Color("#B86E00")
const C_CURSE := Color("#8E44AD")
const C_GOLD := Color("#E2B33C")
const C_RED := Color("#B5442C")
const C_OK := Color("#4E8A3E")
const DIE_COLORS := {4: Color("#2A9D8F"), 6: Color("#C0392B"), 8: Color("#2E5EAA"), 10: Color("#7D3C98")}
const KIND_TAGS := {"mirror": " Mirror", "safe": " Safe", "golden": " Gold", "loaded": " Loaded"}
const SIZES := [4, 9]
## Lobby modes: Blitz 4x4, or 9x9 with how many numbers start on the board (quota spreads them evenly over the digits).
const MODES := [
	{"name": "Blitz 4x4", "size": 4, "givens": -1, "q": ""},
	{"name": "9x9 Cozy (42 numbers shown)", "size": 9, "givens": 42, "q": "even"},
	{"name": "9x9 Adventurer (36 shown)", "size": 9, "givens": 36, "q": "even"},
	{"name": "9x9 Hero (32 shown)", "size": 9, "givens": 32, "q": "even"},
	{"name": "9x9 Legend (28 shown)", "size": 9, "givens": 28, "q": "even"},
]
const HOW_TO := [
	["Goal", "Fill your sudoku board before your rivals. Everyone gets the same puzzle, shuffled so the numbers sit in different places. Lowest turns + 2 x mistakes wins."],
	["Your turn", "Roll your dice up to 3 times. Tap dice to hold them between rolls. Lock when you like your dice (it locks by itself after the last roll)."],
	["Placing", "Tap a die, then an empty tile. Glowing tiles are allowed by sudoku rules. A right number stays; a wrong one is a mistake. 3 mistakes and you are out."],
	["Gold", Rules.GOLD_RULES],
	["Rook's shop", "Whetstones upgrade a die (d4 > d6 > d8 > d10; 9x9 needs d10s for 7, 8, 9). Extra dice: Mirror (value -1, value or +1), Safe (misses are free), Golden (+2 gold), Loaded (rerolls useless faces). Scribe's quill memos the possible numbers on tiles. A d10 shows 0-9: its 0 is wild."],
	["Curses", "Hex: rival loses a roll. Blight: 2 of the rival's dice turn into 1s when they lock. Shackle: rival holds only 1 die. A Ward blocks one curse."],
]
const A := "res://assets/"
const FIREBASE_URL := "https://dicedoku-ac99f-default-rtdb.firebaseio.com"
var online: Online = null
var online_backend = null   # tests inject a fake backend here
var join_code := ""
var _idle_shown := false
var _tex_cache := {}

var game: Game
var screen := "lobby"
var sel := -1
var upgrade_mode := false
var memo_mode := false
var target := -1
var shown_cur := -1
var lobby := {"mode": 2, "count": 2, "names": ["Ana", "Bob", "Cy", "Di"], "pets": [0, 1, 2, 3], "classes": [0, 1, 2, 3], "types": [0, 0, 0, 0]}
const SEAT_TYPES := ["Human", "Bot (easy)", "Bot (normal)", "Bot (hard)"]
const BOT_LEVELS := ["", "easy", "normal", "hard"]
const BOT_DELAY := 0.65
var bot_wait := 0.0
var bot_fails := 0
var body: VBoxContainer
## Where panel() adds new panels (body, or an open drawer).
var panel_parent: Control = null
var tabbar: HBoxContainer
var drawer: PanelContainer
var drawer_box: VBoxContainer
var drawer_open := ""
var toast_panel: PanelContainer
var toast_label: Label
var toast_left := 0.0

func _ready() -> void:
	build()

## Builds the permanent nodes once; safe to call before the node is in a running tree (tests).
func build() -> void:
	if body != null:
		return
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = C_PARCH
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if tex("board/dungeon_map.svg") != null:
		var map := TextureRect.new()
		map.texture = tex("board/dungeon_map.svg")
		map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		map.set_anchors_preset(Control.PRESET_FULL_RECT)
		map.modulate = Color(1, 1, 1, 0.6)
		map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(map)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.offset_top = -110
	toast_panel.offset_bottom = -40
	toast_panel.offset_left = -330
	toast_panel.offset_right = 330
	toast_panel.add_theme_stylebox_override("panel", _box(C_INK, 14, C_INK, 0))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = Label.new()
	toast_label.add_theme_color_override("font_color", C_PARCH)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)
	toast_panel.visible = false
	_build_drawer()
	_build_fx()
	add_child(toast_panel)
	show_lobby()

func _process(delta: float) -> void:
	if is_online() and screen == "game" and online.can_replace_idle() != _idle_shown:
		_idle_shown = online.can_replace_idle()
		show_game()
	if is_bot_turn() and (screen == "game" or screen == "pass") and (not is_online() or online.host):
		bot_wait -= delta
		if bot_wait <= 0.0:
			bot_wait = BOT_DELAY
			bot_step()
	if toast_left > 0.0:
		toast_left -= delta
		if toast_left <= 0.0:
			toast_panel.visible = false

# ---------- helpers ----------

func _box(bg: Color, radius: int = 8, border: Color = C_INK, bw: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 22
	th.set_color("font_color", "Label", C_INK)
	th.set_stylebox("normal", "Button", _box(C_WOOD))
	th.set_stylebox("hover", "Button", _box(C_WOOD.lightened(0.15)))
	th.set_stylebox("pressed", "Button", _box(C_WOOD.darkened(0.2)))
	th.set_stylebox("disabled", "Button", _box(C_STONE.lightened(0.3)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(c, "Button", C_PARCH)
	th.set_color("font_disabled_color", "Button", C_PARCH.darkened(0.15))
	th.set_stylebox("normal", "LineEdit", _box(Color.WHITE, 6, C_WOOD, 2))
	th.set_color("font_color", "LineEdit", C_INK)
	th.set_stylebox("normal", "OptionButton", _box(C_WOOD))
	th.set_stylebox("hover", "OptionButton", _box(C_WOOD.lightened(0.15)))
	th.set_stylebox("pressed", "OptionButton", _box(C_WOOD.darkened(0.2)))
	th.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	th.set_color("font_color", "OptionButton", C_PARCH)
	th.set_color("font_hover_color", "OptionButton", C_PARCH)
	th.set_stylebox("panel", "PanelContainer", _box(C_PARCH_DARK, 12, C_WOOD, 2))
	th.set_constant("icon_max_width", "OptionButton", 32)
	th.set_constant("icon_max_width", "PopupMenu", 32)
	var parch := tbox("ui/parchment_panel.svg", 32, 22)
	if parch != null:
		th.set_stylebox("panel", "PanelContainer", parch)
	var wood := tbox("ui/wood_bar.svg", 22, 18)
	if wood != null:
		th.set_stylebox("normal", "Button", wood)
		th.set_stylebox("hover", "Button", tbox("ui/wood_bar.svg", 22, 18, Color(1.15, 1.1, 1.0)))
		th.set_stylebox("pressed", "Button", tbox("ui/wood_bar.svg", 22, 18, Color(0.8, 0.75, 0.7)))
		th.set_stylebox("disabled", "Button", tbox("ui/wood_bar.svg", 22, 18, Color(0.75, 0.75, 0.75, 0.55)))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			th.set_color(c, "Button", C_PARCH)
		th.set_color("font_outline_color", "Button", C_INK)
		th.set_constant("outline_size", "Button", 4)
	return th

## Loads an asset if present (missing art falls back to the plain look).
func tex(rel: String) -> Texture2D:
	if not _tex_cache.has(rel):
		var path := A + rel
		_tex_cache[rel] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[rel]

func tbox(rel: String, margin: int, content: int, mod: Color = Color.WHITE) -> StyleBoxTexture:
	var t := tex(rel)
	if t == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content * 0.6
	sb.content_margin_bottom = content * 0.6
	sb.modulate_color = mod
	return sb

## Character portrait: class layer stacked on the race body (same 256 px template); falls back to older art.
func portrait(race: String, cls: String, px: int) -> Control:
	var body_t := tex("characters/race_%s.svg" % race)
	if body_t == null:
		var old := tex("characters/pet_%s.svg" % Rules.LEGACY_PORTRAIT.get(race, race))
		if old == null:
			var l := lbl("", 1)
			l.custom_minimum_size = Vector2(1, 1)
			return l
		return _layer(old, px)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := _layer(body_t, px)
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(b)
	var ct := tex("characters/class_%s.svg" % cls)
	if ct != null:
		var c := _layer(ct, px)
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(c)
	return holder

func _layer(t: Texture2D, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func hero(q: PlayerState) -> String:
	return Rules.hero_title(q.pet, q.cls)

func img(rel: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(rel)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	return r

func clear() -> void:
	if tabbar != null:
		tabbar.visible = false
		drawer.visible = false
		drawer_open = ""
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()

func lbl(text: String, size: int = 22, color: Color = C_INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func btn(text: String, cb: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(cb)
	return b

func row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	return r

func panel(title: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	(panel_parent if panel_parent != null else body).add_child(pc)
	if title != "":
		v.add_child(lbl(title, 24, C_WOOD))
	return v

func toast(msg: String) -> void:
	if msg == "":
		return
	toast_label.text = msg
	toast_panel.visible = true
	toast_left = 2.8

func pet_name(pet: String) -> String:
	return Rules.PET_NAMES.get(pet, pet)

# ---------- lobby ----------

func show_lobby() -> void:
	screen = "lobby"
	game = null
	clear()
	var title := row()
	if tex("ui/logo_dice.svg") != null:
		title.add_child(img("ui/logo_dice.svg", 96))
	title.add_child(lbl("Dicedoku", 52, C_WOOD))
	body.add_child(title)
	body.add_child(lbl("v0.10", 18, C_STONE))
	var v := panel("New game")
	var r := row()
	r.add_child(lbl("Mode"))
	var og := OptionButton.new()
	for m in MODES:
		og.add_item(m["name"])
	og.select(lobby["mode"])
	og.item_selected.connect(func(ix: int) -> void: lobby["mode"] = ix)
	r.add_child(og)
	v.add_child(r)
	var r2 := row()
	r2.add_child(lbl("Players"))
	var oc := OptionButton.new()
	for k in range(1, 5):
		oc.add_item(str(k), k)
	oc.select(lobby["count"] - 1)
	oc.item_selected.connect(_on_count)
	r2.add_child(oc)
	v.add_child(r2)
	for i in lobby["count"]:
		var seat := VBoxContainer.new()
		var pr := row()
		pr.add_child(portrait(Rules.PETS[lobby["pets"][i]], Rules.CLASSES[lobby["classes"][i]], 72))
		var le := LineEdit.new()
		le.text = lobby["names"][i]
		le.max_length = 12
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_changed.connect(func(t: String) -> void: lobby["names"][i] = t)
		pr.add_child(le)
		var ot := OptionButton.new()
		for st in SEAT_TYPES:
			ot.add_item(st)
		ot.select(lobby["types"][i])
		ot.item_selected.connect(func(ix: int) -> void: lobby["types"][i] = ix)
		pr.add_child(ot)
		seat.add_child(pr)
		var pr2 := row()
		pr2.add_child(lbl("Race", 18, C_STONE))
		var op := OptionButton.new()
		for race in Rules.PETS:
			var pt := tex("characters/race_%s.svg" % race)
			if pt != null:
				op.add_icon_item(pt, pet_name(race))
			else:
				op.add_item(pet_name(race))
		op.select(lobby["pets"][i])
		op.item_selected.connect(_on_pet.bind(i))
		pr2.add_child(op)
		pr2.add_child(lbl("Class", 18, C_STONE))
		var oc2 := OptionButton.new()
		for c in Rules.CLASSES:
			oc2.add_item(Rules.CLASS_NAMES[c])
		oc2.select(lobby["classes"][i])
		oc2.item_selected.connect(_on_class.bind(i))
		pr2.add_child(oc2)
		seat.add_child(pr2)
		v.add_child(seat)
	v.add_child(btn("Start adventure", start_from_lobby))
	var o := panel("Play online")
	o.add_child(lbl("Uses the first player's name, race and class. Bots can be added in the room.", 16, C_STONE))
	o.add_child(btn("Create online room", _on_create_online))
	var jr := row()
	var ce := LineEdit.new()
	ce.placeholder_text = "Room code"
	ce.max_length = 5
	ce.text = join_code
	ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ce.text_changed.connect(func(t: String) -> void: join_code = t)
	jr.add_child(ce)
	jr.add_child(btn("Join", _on_join_online))
	o.add_child(jr)
	body.add_child(btn("Dice number tuner", show_tuner))
	var h := panel("How to play")
	for sec in HOW_TO:
		h.add_child(lbl(sec[0], 20, C_WOOD))
		h.add_child(lbl(sec[1], 17))

func _on_class(ix: int, seat: int) -> void:
	lobby["classes"][seat] = ix
	show_lobby()

func _on_pet(ix: int, seat: int) -> void:
	lobby["pets"][seat] = ix
	show_lobby()

func _on_count(ix: int) -> void:
	lobby["count"] = ix + 1
	show_lobby()

func start_from_lobby() -> void:
	var seats := []
	for i in lobby["count"]:
		var pet: String = Rules.PETS[lobby["pets"][i]]
		var nm: String = str(lobby["names"][i]).strip_edges()
		seats.append({"name": nm if nm != "" else "Player %d" % (i + 1), "pet": pet, "cls": Rules.CLASSES[lobby["classes"][i]], "bot": BOT_LEVELS[lobby["types"][i]]})
	var m: Dictionary = MODES[lobby["mode"]]
	start_game(m["size"], seats, -1, -1, m["givens"], m["q"])

func start_game(n: int, seats: Array, seed_value: int = -1, dice_seed: int = -1, givens: int = -1, qmode: String = "") -> void:
	var s := seed_value if seed_value >= 0 else randi() % 2147483647
	game = Game.new(n, s, seats, dice_seed, givens, qmode)
	sel = -1
	upgrade_mode = false
	memo_mode = false
	target = -1
	shown_cur = -1
	refresh()

# ---------- flow ----------

func active_count() -> int:
	var c := 0
	for p in game.players:
		if p.active():
			c += 1
	return c

## Show the right screen after any action.
func refresh() -> void:
	if game == null:
		show_lobby()
	elif game.over:
		show_results()
	elif game.cur != shown_cur:
		shown_cur = game.cur
		sel = -1
		upgrade_mode = false
		memo_mode = false
		target = -1
		if not is_online() and not is_bot_turn() and human_count() > 1:
			show_pass()
		else:
			show_game()
			announce_turn()
	else:
		show_game()

func after(res: Dictionary) -> void:
	toast(str(res.get("msg", "")))
	refresh()
	play_fx(res.get("fx", []))

## Every human or bot action goes through here (online play will also send it to the room).
func act(a: Dictionary) -> Dictionary:
	if is_online():
		return online.act(a)
	return game.apply(a)

func is_online() -> bool:
	return online != null and online.code != ""

## Human input allowed now: offline = not a bot's turn; online = my own seat's turn.
func can_input() -> bool:
	if game == null or game.over:
		return false
	if is_online():
		return online.my_turn() and game.current().bot == ""
	return not is_bot_turn()

func is_bot_turn() -> bool:
	return game != null and not game.over and game.current().bot != ""

func human_count() -> int:
	var c := 0
	for p in game.players:
		if p.active() and p.bot == "":
			c += 1
	return c

## One bot action. If the game refuses it (should not happen), fall back to lock / end so a bot can never stall.
func bot_step() -> void:
	if not is_bot_turn():
		return
	var p := game.current()
	var a := Bot.next_action(game)
	if bot_fails >= 2:
		a = {"a": "lock"} if not p.lk and not p.dv.is_empty() else ({"a": "roll"} if p.dv.is_empty() else {"a": "end"})
	var res := act(a)
	bot_fails = 0 if res.get("ok", false) else bot_fails + 1
	var m := str(res.get("msg", ""))
	if a["a"] in ["place", "buy", "end"] or "from" in m:
		toast(("%s: " % p.name) + m if m != "" else "")
	refresh()
	play_fx(res.get("fx", []))

func show_pass() -> void:
	screen = "pass"
	clear()
	var p := game.current()
	body.add_child(lbl("Pass the device to", 26, C_STONE))
	var pc := CenterContainer.new()
	pc.add_child(portrait(p.pet, p.cls, 240))
	body.add_child(pc)
	body.add_child(lbl(p.name, 52, C_WOOD))
	body.add_child(lbl("the " + hero(p), 26))
	if not p.pending.is_empty():
		var names := []
		for c in p.pending:
			names.append("%s from %s" % [Rules.CURSES.get(c["k"], "Curse"), c["from"]])
		body.add_child(lbl("Curses waiting for you: " + ", ".join(PackedStringArray(names)), 22, C_CURSE))
	body.add_child(btn("I'm ready", _on_ready))

# ---------- game ----------

func show_game() -> void:
	screen = "game"
	clear()
	var p := game.current()
	var who := "%s the %s  -  turn %d" % [p.name, hero(p), p.turn]
	if p.bot != "":
		who += "  (bot, %s)" % p.bot
	var banner := row()
	banner.add_child(portrait(p.pet, p.cls, 80))
	banner.add_child(lbl(who, 28, C_WOOD))
	body.add_child(banner)
	if is_online():
		var me_name: String = game.players[online.my_seat].name if online.my_seat >= 0 else "?"
		var line := "Online room %s  ·  you are %s" % [online.code, me_name]
		if not online.my_turn():
			line += "  ·  waiting for %s..." % p.name
		if online.error != "":
			line += "  ·  " + online.error
		body.add_child(lbl(line, 18, C_CURSE if online.error != "" else C_STONE))
		if online.can_replace_idle():
			body.add_child(btn("%s seems away: let a bot play their seat" % p.name, _on_replace_idle))
	if not p.pending.is_empty() and not p.fxd:
		body.add_child(lbl("A curse will hit your first roll!", 20, C_CURSE))
	_board(p)
	_tracker(p)
	_dice(p)
	_fill_drawer()
	var bottom := row()
	bottom.add_child(btn("Sound: off" if muted else "Sound: on", _on_mute))
	bottom.add_child(btn("Quit to lobby", _leave_online))
	body.add_child(bottom)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 96)
	body.add_child(spacer)

func _phase(p: PlayerState) -> String:
	if memo_mode:
		return "Scribe: tap an empty tile to memo its possible numbers"
	if p.bot != "":
		return "%s is thinking..." % p.name
	if upgrade_mode:
		return "Whetstone: tap a die to upgrade it"
	if p.lk:
		return "Tap a die, then a cell"
	if p.dv.is_empty():
		return "Roll your dice"
	return "Tap dice to hold, then Roll again or Lock"

## Board = dark frame; boxes are separated by thick gaps and cells by thin gaps, so the lines are the
## background showing through. Gaps of 3/7 px survive any screen scaling (1 px borders vanished on phones).
func _board(p: PlayerState) -> void:
	var n := game.size
	var thin := 3
	var thick := 7
	var px := int(min(74.0, (660.0 - thick * (n / game.bc + 1) - thin * n) / n))
	var svs := []
	if sel >= 0 and sel < p.dv.size():
		svs = [10] if game.is_wild(p, sel) else game.die_values(p, sel)
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = C_INK
	fsb.set_corner_radius_all(6)
	fsb.content_margin_left = thick
	fsb.content_margin_right = thick
	fsb.content_margin_top = thick
	fsb.content_margin_bottom = thick
	frame.add_theme_stylebox_override("panel", fsb)
	var boxes := GridContainer.new()
	boxes.columns = n / game.bc
	boxes.add_theme_constant_override("h_separation", thick)
	boxes.add_theme_constant_override("v_separation", thick)
	for by in n / game.br:
		for bx in n / game.bc:
			var box := GridContainer.new()
			box.columns = game.bc
			box.add_theme_constant_override("h_separation", thin)
			box.add_theme_constant_override("v_separation", thin)
			for a in game.br:
				for c in game.bc:
					box.add_child(_cell(p, (by * game.br + a) * n + bx * game.bc + c, px, svs))
			boxes.add_child(box)
	frame.add_child(boxes)
	var cc := CenterContainer.new()
	cc.name = "board"
	cc.add_child(frame)
	body.add_child(cc)

func _cell(p: PlayerState, i: int, px: int, svs: Array) -> Button:
	var v: int = p.grid[i]
	var given: bool = p.puz[i] != 0
	var b := Button.new()
	b.name = "cell_%d" % i
	b.custom_minimum_size = Vector2(px, px)
	b.text = str(v) if v != 0 else ""
	var memo_txt := ""
	if v == 0 and p.memo.has(i):
		var cs := []
		for w in game.candidates(p, i):
			cs.append(str(w))
		memo_txt = " ".join(PackedStringArray(cs))
		b.text = memo_txt
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bgc := C_STONE.darkened(0.15) if given else C_STONE.lightened(0.55)
	var lit := false
	for w in svs:
		if v == 0 and game.legal(p, i, w):
			lit = true
	if lit:
		bgc = C_TORCH.lightened(0.25)
	var sb: StyleBox = StyleBoxFlat.new()
	sb.bg_color = bgc
	var tile := tbox("board/stone_tile_given.svg" if given else "board/stone_tile.svg", 0, 0)
	if tile != null:
		tile.content_margin_top = 0
		tile.content_margin_bottom = 0
		tile.modulate_color = C_TORCH.lightened(0.35) if bgc == C_TORCH.lightened(0.25) else Color.WHITE
		sb = tile
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_outline_color", C_INK if not given else Color(0, 0, 0, 0))
	b.add_theme_constant_override("outline_size", 0 if given else 5)
	var fc := C_PARCH if given else C_TORCH
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, fc)
	b.add_theme_font_size_override("font_size", int(px * 0.55) if memo_txt == "" else maxi(11, int(px * 0.2)))
	if memo_txt != "":
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(st, C_INK)
		b.add_theme_constant_override("outline_size", 0)
	b.pressed.connect(_on_cell.bind(i))
	return b

func _tracker(p: PlayerState) -> void:
	var parts := []
	for k in range(1, game.size + 1):
		parts.append("[%d]" % k if game.count_value(p, k) == game.size else str(k))
	var l := lbl("Numbers:  " + "   ".join(PackedStringArray(parts)) + "    ([n] = complete)", 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)

func _dice(p: PlayerState) -> void:
	var v := panel("")
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for i in p.df.size():
		var f: int = p.df[i]
		var val: int = p.dv[i] if i < p.dv.size() else 0
		var b := Button.new()
		b.name = "die_%d" % i
		b.custom_minimum_size = Vector2(92, 92)
		var tag: String = KIND_TAGS.get(p.dk[i], "")
		var extra := ""
		if val > 0 and game.is_wild(p, i):
			extra = " wild"
		elif game.is_useless(p, i):
			extra = " done"
		b.text = Rules.face_label(val, f)
		var col: Color = DIE_COLORS.get(f, C_WOOD)
		if game.is_dead(p, i) or game.is_useless(p, i):
			col = C_STONE
		var border := C_INK
		var bw := 2
		if i < p.dh.size() and p.dh[i] and not p.lk:
			border = C_GOLD
			bw = 6
		if i == sel:
			border = C_OK
			bw = 6
		var sb: StyleBox = _box(col, 12, border, bw)
		var gem := tbox("dice/gem_d%d.svg" % f, 0, 0, Color(0.55, 0.55, 0.55) if col == C_STONE else Color.WHITE)
		if gem != null:
			sb = gem
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		style_die_number(b, sb, f)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color.WHITE)
		b.add_theme_color_override("font_outline_color", C_INK)
		b.add_theme_constant_override("outline_size", 6)
		if i < p.du.size() and p.du[i]:
			b.modulate = Color(1, 1, 1, 0.3)
		b.pressed.connect(_on_die.bind(i))
		# ring shows held (gold) and selected (green)
		var ring := PanelContainer.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0, 0, 0, 0)
		rs.border_color = border if bw > 2 else Color(0, 0, 0, 0)
		rs.set_border_width_all(4)
		rs.set_corner_radius_all(14)
		rs.set_content_margin_all(3)
		ring.add_theme_stylebox_override("panel", rs)
		var dv := VBoxContainer.new()
		dv.add_theme_constant_override("separation", 0)
		dv.add_child(b)
		var cap := lbl("d%d%s%s" % [f, tag, extra], 15, C_INK)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dv.add_child(cap)
		ring.add_child(dv)
		flow.add_child(ring)
	flow.name = "dice_row"
	v.add_child(flow)
	v.add_child(lbl(_phase(p), 20, C_WOOD))
	var info := "Rolls left %d  ·  Mistakes %d/%d  ·  Hints %d  ·  Gold %d" % [p.rolls, p.mis, Rules.MAXMIS, p.hints, p.gold]
	if p.ward > 0:
		info += "  ·  Wards %d" % p.ward
	if p.shk > 0:
		info += "  ·  Shackled (hold %d)" % p.shk
	var info_l := lbl(info, 18)
	info_l.name = "gold_info"
	v.add_child(info_l)
	var r := row()
	var rolled := not p.dv.is_empty()
	var bt := p.bot != ""
	r.add_child(btn("Roll", _on_roll, bt or p.lk or p.rolls < 1))
	r.add_child(btn("Lock", _on_lock, bt or not rolled or p.lk))
	r.add_child(btn("End turn", _on_end, bt or not rolled))
	r.add_child(btn("Hint", _on_hint, bt or p.hints < 1 or not p.lk or sel < 0))
	if p.scribe > 0 or memo_mode:
		r.add_child(btn("Done" if memo_mode else "Scribe (%d)" % p.scribe, _on_scribe, bt))
	v.add_child(r)

func _shop(p: PlayerState) -> void:
	var v := panel("")
	var head := row()
	if tex("characters/merchant_raccoon.svg") != null:
		head.add_child(img("characters/merchant_raccoon.svg", 96))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(lbl("Rook the Raccoon's shop", 26, C_WOOD))
	hv.add_child(lbl("How to earn gold: " + Rules.GOLD_RULES, 16, C_WOOD))
	head.add_child(hv)
	v.add_child(head)
	var rv := game.rivals()
	var offers := game.offers()
	var has_curse := false
	for o in offers:
		if o.has("x"):
			has_curse = true
	if has_curse and rv.size() > 1:
		var r := row()
		r.add_child(lbl("Curse target", 20))
		var op := OptionButton.new()
		var pick := 0
		for k in rv.size():
			op.add_item(game.players[rv[k]].name, rv[k])
			if rv[k] == target:
				pick = k
		op.select(pick)
		target = rv[pick]
		op.item_selected.connect(func(ix: int) -> void: target = rv[ix])
		r.add_child(op)
		v.add_child(r)
	for o in offers:
		var r := row()
		var sold: bool = o["id"] != "whet" and p.bt.has(o["id"])
		var text := "%s - %s" % [o["n"], o["d"]]
		if o.has("x") and rv.size() == 1:
			text += " (to %s)" % game.players[rv[0]].name
		var col := C_CURSE if (o.has("x") or o["id"] == "ward") else C_INK
		if tex("icons/%s.svg" % o.get("icon", "")) != null:
			r.add_child(img("icons/%s.svg" % o["icon"], 40))
		r.add_child(lbl(text, 18, col))
		var off: bool = p.gold < o["c"] or sold or (o["id"] == "roll" and p.lk) or (o.has("x") and rv.is_empty())
		var label := "Sold" if sold else "%dg" % o["c"]
		if o["id"] == "whet" and upgrade_mode:
			label = "Cancel"
			off = false
		var b := btn(label, _on_buy.bind(o["id"]), off)
		b.custom_minimum_size = Vector2(96, 0)
		r.add_child(b)
		v.add_child(r)

func _players() -> void:
	var v := panel("Party")
	var n := game.size * game.size
	for j in game.players.size():
		var q: PlayerState = game.players[j]
		var s := "%s%s the %s  -  %d/%d cells  ·  mistakes %d" % ["> " if j == game.cur else "", q.name, hero(q), Puzzle.filled(q.grid), n, q.mis]
		if q.done:
			s += "  ·  cleared!"
		if q.lost:
			s += "  ·  out"
		if not q.pending.is_empty():
			s += "  ·  %d curse(s) waiting" % q.pending.size()
		var pr := row()
		pr.add_child(portrait(q.pet, q.cls, 52))
		pr.add_child(lbl(s, 18, C_CURSE if not q.pending.is_empty() else C_INK))
		v.add_child(pr)

# ---------- results ----------

func show_results() -> void:
	screen = "results"
	clear()
	body.add_child(lbl("The dungeon is quiet", 40, C_WOOD))
	var v := panel("Results")
	var place := 1
	for j in game.ranking():
		var q: PlayerState = game.players[j]
		var s := "%d. %s the %s" % [place, q.name, hero(q)]
		if q.done:
			s += "  -  score %d (%d turns, %d mistakes)" % [q.score(), q.turn, q.mis]
		elif q.lost:
			s += "  -  out after 3 mistakes"
		var rr := row()
		rr.add_child(portrait(q.pet, q.cls, 64))
		rr.add_child(lbl(s, 22))
		v.add_child(rr)
		place += 1
	body.add_child(btn("New game", _leave_online))

# ---------- slide-up tabs: Rook's shop and the party ----------

func _build_drawer() -> void:
	drawer = PanelContainer.new()
	drawer.name = "drawer"
	drawer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	drawer.offset_top = -760
	drawer.offset_bottom = -84
	drawer.visible = false
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 640)
	drawer_box = VBoxContainer.new()
	drawer_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_box.add_theme_constant_override("separation", 10)
	sc.add_child(drawer_box)
	drawer.add_child(sc)
	add_child(drawer)
	tabbar = HBoxContainer.new()
	tabbar.name = "tabbar"
	tabbar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tabbar.offset_top = -80
	tabbar.offset_bottom = -8
	tabbar.offset_left = 12
	tabbar.offset_right = -12
	tabbar.add_theme_constant_override("separation", 10)
	tabbar.visible = false
	add_child(tabbar)

func _fill_drawer() -> void:
	var p := game.current()
	for c in tabbar.get_children():
		tabbar.remove_child(c)
		c.queue_free()
	var bs := btn("Rook's shop  ·  %d gold" % p.gold, toggle_drawer.bind("shop"))
	bs.name = "tab_shop"
	bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tex("icons/gold_coin.svg") != null:
		bs.icon = tex("icons/gold_coin.svg")
		bs.expand_icon = false
		bs.add_theme_constant_override("icon_max_width", 34)
	var bp := btn("Party (%d)" % game.players.size(), toggle_drawer.bind("party"))
	bp.name = "tab_party"
	bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabbar.add_child(bs)
	tabbar.add_child(bp)
	tabbar.visible = true
	for c in drawer_box.get_children():
		drawer_box.remove_child(c)
		c.queue_free()
	panel_parent = drawer_box
	var head := row()
	head.add_child(lbl("Rook's shop" if drawer_open == "shop" else "Party", 24, C_WOOD))
	head.add_child(btn("Close", toggle_drawer.bind(drawer_open)))
	drawer_box.add_child(head)
	if drawer_open == "shop":
		_shop(p)
	elif drawer_open == "party":
		_players()
	panel_parent = null
	drawer.visible = drawer_open != ""

func toggle_drawer(which: String) -> void:
	var opening := drawer_open != which
	drawer_open = which if opening else ""
	if game == null or screen != "game":
		return
	_fill_drawer()
	if opening:
		drawer.pivot_offset = Vector2(drawer.size.x / 2, drawer.size.y)
		drawer.position.y += 120
		drawer.modulate.a = 0.0
		var tw := drawer.create_tween()
		tw.set_parallel(true)
		tw.tween_property(drawer, "position:y", drawer.position.y - 120, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(drawer, "modulate:a", 1.0, 0.18)

func open_drawer(which: String) -> void:
	drawer_open = ""
	toggle_drawer(which)

# ---------- dice number tuner ----------

## Number position on each gem: [x offset, y offset, font size]. Eddie's tuned values go here.
const DIE_TUNE_DEFAULT := {4: [0, -6, 40], 6: [0, -6, 40], 8: [0, -6, 40], 10: [0, -6, 40]}
var die_tune := {}
const TUNE_PATH := "user://dice_tune.cfg"

func tune_for(f: int) -> Array:
	if die_tune.is_empty():
		die_tune = DIE_TUNE_DEFAULT.duplicate(true)
		var cf := ConfigFile.new()
		if cf.load(TUNE_PATH) == OK:
			for k in die_tune:
				die_tune[k] = cf.get_value("dice", "d%d" % k, die_tune[k])
	return die_tune.get(f, [0, -6, 40])

## Applies the tuned number position/size to a die button that uses the gem stylebox.
func style_die_number(b: Button, sb: StyleBox, f: int) -> void:
	var t := tune_for(f)
	if sb is StyleBoxTexture:
		sb.content_margin_left = maxi(0, 2 * int(t[0]))
		sb.content_margin_right = maxi(0, -2 * int(t[0]))
		sb.content_margin_top = maxi(0, 2 * int(t[1]))
		sb.content_margin_bottom = maxi(0, -2 * int(t[1]))
	b.add_theme_font_size_override("font_size", int(t[2]))

func tune_code() -> String:
	var parts := []
	for k in [4, 6, 8, 10]:
		var t := tune_for(k)
		parts.append("d%d=%d,%d,%d" % [k, t[0], t[1], t[2]])
	return ";".join(PackedStringArray(parts))

var _tune_previews := {}
var _tune_code_edit: LineEdit

func show_tuner() -> void:
	screen = "tuner"
	clear()
	_tune_previews = {}
	body.add_child(lbl("Dice number tuner", 40, C_WOOD))
	body.add_child(lbl("Move each number until it sits in the middle of its gem. Your settings are saved on this device. Then tap Copy and send the code to Claudio so everyone gets them.", 18))
	for f in [4, 6, 8, 10]:
		var v := panel("d%d" % f)
		var r := row()
		var previews := []
		for val in [Rules.face_label(f, f), "8" if f >= 8 else "3"]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(92, 92)
			b.text = str(val)
			_paint_die(b, f)
			r.add_child(b)
			previews.append(b)
		var big := Button.new()
		big.custom_minimum_size = Vector2(184, 184)
		big.text = "5" if f >= 6 else "2"
		_paint_die(big, f, 2.0)
		r.add_child(big)
		previews.append(big)
		_tune_previews[f] = previews
		v.add_child(r)
		var t := tune_for(f)
		var names := ["Left / right", "Up / down", "Size"]
		var ranges := [[-20, 20], [-24, 24], [20, 60]]
		for k in 3:
			var sr := row()
			sr.add_child(lbl(names[k], 18))
			var sl := HSlider.new()
			sl.min_value = ranges[k][0]
			sl.max_value = ranges[k][1]
			sl.step = 1
			sl.value = t[k]
			sl.custom_minimum_size = Vector2(320, 40)
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var val_l := lbl(str(t[k]), 18)
			val_l.size_flags_horizontal = Control.SIZE_SHRINK_END
			sl.value_changed.connect(_on_tune.bind(f, k, val_l))
			sr.add_child(sl)
			sr.add_child(val_l)
			v.add_child(sr)
	var cv := panel("Code to send")
	_tune_code_edit = LineEdit.new()
	_tune_code_edit.text = tune_code()
	_tune_code_edit.editable = true
	cv.add_child(_tune_code_edit)
	var br := row()
	br.add_child(btn("Copy code", _on_tune_copy))
	br.add_child(btn("Reset", _on_tune_reset))
	br.add_child(btn("Back", show_lobby))
	cv.add_child(br)

func _paint_die(b: Button, f: int, scale_k: float = 1.0) -> void:
	var gem := tbox("dice/gem_d%d.svg" % f, 0, 0)
	var sb: StyleBox = gem if gem != null else _box(DIE_COLORS.get(f, C_WOOD), 12)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_outline_color", C_INK)
	b.add_theme_constant_override("outline_size", int(6 * scale_k))
	style_die_number(b, sb, f)
	if scale_k != 1.0:
		var t := tune_for(f)
		if sb is StyleBoxTexture:
			sb.content_margin_left *= scale_k
			sb.content_margin_right *= scale_k
			sb.content_margin_top *= scale_k
			sb.content_margin_bottom *= scale_k
		b.add_theme_font_size_override("font_size", int(t[2] * scale_k))

func _on_tune(value: float, f: int, k: int, val_l: Label) -> void:
	var t: Array = tune_for(f).duplicate()
	t[k] = int(value)
	die_tune[f] = t
	val_l.text = str(int(value))
	for b in _tune_previews.get(f, []):
		_paint_die(b, f, 2.0 if b.custom_minimum_size.x > 100 else 1.0)
	_tune_code_edit.text = tune_code()
	var cf := ConfigFile.new()
	for kk in die_tune:
		cf.set_value("dice", "d%d" % kk, die_tune[kk])
	cf.save(TUNE_PATH)

func _on_tune_copy() -> void:
	DisplayServer.clipboard_set(tune_code())
	_tune_code_edit.select_all()
	toast("Code copied: paste it in the chat with Claudio")

func _on_tune_reset() -> void:
	die_tune = DIE_TUNE_DEFAULT.duplicate(true)
	var cf := ConfigFile.new()
	for kk in die_tune:
		cf.set_value("dice", "d%d" % kk, die_tune[kk])
	cf.save(TUNE_PATH)
	show_tuner()

# ---------- effects (animations + sound) ----------

var fx_layer: Control
var sfx_players := {}
var muted := false
const SFX := ["roll", "hold", "lock", "hit", "miss", "coin", "curse", "ward", "buy", "win", "turn", "memo"]

func _build_fx() -> void:
	fx_layer = Control.new()
	fx_layer.name = "fx_layer"
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	for n in SFX:
		var path := A + "sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			var pl := AudioStreamPlayer.new()
			pl.stream = load(path)
			pl.volume_db = -6.0
			add_child(pl)
			sfx_players[n] = pl

func sfx(n: String) -> void:
	if not muted and sfx_players.has(n):
		sfx_players[n].play()

func _on_mute() -> void:
	muted = not muted
	show_game()

func _on_ready() -> void:
	show_game()
	announce_turn()

func _node(nm: String) -> Control:
	return find_child(nm, true, false) as Control

func _center(c: Control) -> Vector2:
	if c == null or not is_instance_valid(c):
		return size / 2
	return c.get_global_rect().get_center() - fx_layer.get_global_rect().position

func float_text(text: String, at: Vector2, color: Color, fsize: int = 28) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", C_INK)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(420, fsize * 1.6)
	l.position = at - l.size / 2
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 80, 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)

func burst(rel: String, at: Vector2, px: int, color: Color = Color.WHITE, dur: float = 0.6) -> void:
	var t := tex(rel)
	if t == null:
		return
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = Vector2(px, px)
	r.position = at - r.size / 2
	r.pivot_offset = r.size / 2
	r.modulate = color
	r.scale = Vector2(0.3, 0.3)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(r)
	var tw := r.create_tween()
	tw.set_parallel(true)
	tw.tween_property(r, "scale", Vector2(1.15, 1.15), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "rotation", randf_range(-0.4, 0.4), dur)
	tw.tween_property(r, "modulate:a", 0.0, dur * 0.6).set_delay(dur * 0.5)
	tw.chain().tween_callback(r.queue_free)

func sparkles(at: Vector2, count: int, spread: float) -> void:
	for k in count:
		burst("effects/sparkle.svg", at + Vector2(randf_range(-spread, spread), randf_range(-spread, spread)), randi_range(26, 54), Color.WHITE, randf_range(0.45, 0.9))

func pop(c: Control, s: float = 1.25, dur: float = 0.3) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.pivot_offset = c.size / 2
	c.scale = Vector2(s, s)
	c.create_tween().tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func flash(c: Control, color: Color, dur: float = 0.6) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.modulate = color
	c.create_tween().tween_property(c, "modulate", Color.WHITE, dur)

func shake(c: Control) -> void:
	if c == null or not is_instance_valid(c):
		return
	var x0 := c.position.x
	var tw := c.create_tween()
	for k in 6:
		tw.tween_property(c, "position:x", x0 + (12.0 if k % 2 == 0 else -12.0) * (1.0 - k / 6.0), 0.045)
	tw.tween_property(c, "position:x", x0, 0.045)

func screen_flash(color: Color, dur: float = 0.7) -> void:
	var cr := ColorRect.new()
	cr.color = color
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(cr)
	var tw := cr.create_tween()
	tw.tween_property(cr, "color:a", 0.0, dur)
	tw.tween_callback(cr.queue_free)

func roll_dice_anim(idx: Array) -> void:
	for i in idx:
		var d := _node("die_%d" % int(i)) as Button
		if d == null:
			continue
		var final := d.text
		d.pivot_offset = d.size / 2
		d.rotation = randf_range(-0.9, 0.9)
		d.scale = Vector2(0.55, 0.55)
		var tw := d.create_tween()
		tw.set_parallel(true)
		tw.tween_property(d, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var flick := d.create_tween()
		for k in 4:
			flick.tween_callback(_set_text.bind(d, str(randi_range(1, 9))))
			flick.tween_interval(0.07)
		flick.tween_callback(_set_text.bind(d, final))

func _set_text(b: Button, txt: String) -> void:
	if is_instance_valid(b):
		b.text = txt

## Ribbon announcing whose turn it is.
func announce_turn() -> void:
	if game == null or game.over or fx_layer == null:
		return
	var p := game.current()
	sfx("turn")
	var text := "%s's turn" % p.name
	if is_online() and online.my_turn() and p.bot == "":
		text = "Your turn, %s!" % p.name
	var box := Control.new()
	box.size = Vector2(560, 104)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rt := tex("effects/banner_ribbon.svg")
	if rt != null:
		var r := _layer(rt, 104)
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = box.size
		box.add_child(r)
	else:
		var pc := Panel.new()
		pc.size = box.size
		pc.add_theme_stylebox_override("panel", _box(C_RED, 12, C_GOLD, 3))
		box.add_child(pc)
	var l := Label.new()
	l.text = text
	l.size = box.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", C_PARCH)
	l.add_theme_color_override("font_outline_color", C_INK)
	l.add_theme_constant_override("outline_size", 8)
	box.add_child(l)
	fx_layer.add_child(box)
	var mid := Vector2((size.x - box.size.x) / 2, size.y * 0.32)
	box.position = Vector2(-box.size.x, mid.y)
	var tw := box.create_tween()
	tw.tween_property(box, "position", mid, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_property(box, "position:x", size.x + 20, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(box.queue_free)

## Plays the events of the last action(s) on the freshly rebuilt screen.
func play_fx(list: Array) -> void:
	if list.is_empty() or fx_layer == null or not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var mid := size / 2
	for e in list:
		var t := str(e.get("t", ""))
		match t:
			"roll":
				sfx("roll")
				roll_dice_anim(e.get("dice", []))
			"hold":
				sfx("hold")
				pop(_node("die_%d" % int(e["i"])), 1.18)
			"lock":
				sfx("lock")
				pop(_node("dice_row"), 1.05)
				burst("effects/lock.svg", _center(_node("dice_row")), 90)
			"gold":
				sfx("coin")
				var at := _center(_node("gold_info"))
				float_text("+%d gold (%s)" % [int(e["n"]), str(e.get("why", ""))], at, C_GOLD, 26)
				burst("effects/coin_pop.svg", at + Vector2(-140, 0), 56)
			"hit":
				sfx("hit")
				var c := _node("cell_%d" % int(e["c"]))
				pop(c, 1.4)
				var at2 := _center(c)
				burst("effects/hit_glow.svg", at2, 150, Color(1, 1, 1, 0.9))
				sparkles(at2, 4, 34)
				float_text("+%d gold" % int(e.get("gold", 1)), at2 - Vector2(0, 30), C_GOLD, 28)
			"miss":
				sfx("miss")
				var c2 := _node("cell_%d" % int(e["c"]))
				flash(c2, Color(1, 0.3, 0.3))
				burst("effects/miss_crack.svg", _center(c2), 120)
				shake(_node("board"))
				float_text("Mistake!", _center(c2) - Vector2(0, 30), C_RED, 30)
			"safe":
				sfx("ward")
				var c3 := _node("cell_%d" % int(e["c"]))
				flash(c3, Color(0.6, 0.8, 1.0))
				float_text("Safe!", _center(c3) - Vector2(0, 30), Color("#4A7FB5"), 30)
			"curse", "blight":
				sfx("curse")
				screen_flash(Color(C_CURSE, 0.45))
				burst("effects/curse_burst.svg", mid, 380, Color.WHITE, 1.0)
				var nm := "Blight" if t == "blight" else str(Rules.CURSES.get(e.get("k", ""), "Curse"))
				float_text(nm + "!", mid, C_CURSE, 56)
				for i in e.get("dice", []):
					flash(_node("die_%d" % int(i)), Color(0.75, 0.4, 1.0), 1.0)
			"ward":
				sfx("ward")
				burst("icons/ward.svg", mid, 300, Color.WHITE, 0.9)
				float_text("Ward blocked %s!" % Rules.CURSES.get(e.get("k", ""), "a curse"), mid, Color("#4A7FB5"), 40)
			"cast":
				sfx("curse")
				burst("effects/curse_burst.svg", mid, 220, Color.WHITE, 0.7)
				float_text("%s sent to %s!" % [Rules.CURSES.get(e.get("k", ""), "Curse"), game.players[int(e["to"])].name], mid, C_CURSE, 36)
			"buy", "upgrade":
				sfx("buy")
				if t == "upgrade":
					pop(_node("die_%d" % int(e["i"])), 1.3)
					sparkles(_center(_node("die_%d" % int(e["i"]))), 3, 30)
			"memo":
				sfx("memo")
				pop(_node("cell_%d" % int(e["c"])), 1.2)
			"combo":
				sfx("win")
				sparkles(mid, 10, 160)
				float_text("Combo! +%d hint%s" % [int(e["n"]), "s" if int(e["n"]) > 1 else ""], mid, C_GOLD, 44)
			"win":
				sfx("win")
				sparkles(mid, 26, 260)
				float_text("Dungeon cleared!", mid, C_GOLD, 56)
			"out":
				sfx("miss")
				screen_flash(Color(C_RED, 0.35))

# ---------- online ----------

func ensure_online() -> Online:
	if online == null:
		var backend = online_backend
		if backend == null:
			backend = Firebase.new(FIREBASE_URL)
		online = Online.new(backend, "u%d%06d" % [int(Time.get_unix_time_from_system()), randi() % 1000000])
		if backend is Node:
			online.add_child(backend)
		add_child(online)
		online.changed.connect(_on_online_changed)
	return online

func _me() -> Array:
	var nm: String = str(lobby["names"][0]).strip_edges()
	return [nm if nm != "" else "Player", Rules.PETS[lobby["pets"][0]], Rules.CLASSES[lobby["classes"][0]]]

func _on_create_online() -> void:
	toast("Opening a room...")
	var me := _me()
	var err: String = await ensure_online().create(MODES[lobby["mode"]]["size"], me[0], me[1], me[2], MODES[lobby["mode"]]["givens"], MODES[lobby["mode"]]["q"])
	if err != "":
		toast(err)
		return
	show_online_lobby()

func _on_join_online() -> void:
	if join_code.strip_edges().length() != 5:
		toast("Room codes have 5 letters")
		return
	toast("Joining...")
	var me := _me()
	var err: String = await ensure_online().join(join_code, me[0], me[1], me[2])
	if err != "":
		toast(err)
		return
	_on_online_changed()

func _on_online_changed() -> void:
	if not is_online():
		return
	if online.game != null:
		if game != online.game:
			game = online.game
			shown_cur = -1
		if screen == "game" or screen == "online_lobby" or screen == "results" or screen == "lobby":
			refresh()
			play_fx(online.take_fx())
	elif screen == "online_lobby" or screen == "lobby":
		show_online_lobby()

func show_online_lobby() -> void:
	screen = "online_lobby"
	clear()
	body.add_child(lbl("Room code", 24, C_STONE))
	body.add_child(lbl(online.code, 72, C_WOOD))
	body.add_child(lbl("Share this code. Friends open the same link, pick a name, race and class, and tap Join.", 18))
	var v := panel("Players")
	var seats := online.seats_sorted()
	var keys := online.seat_keys_sorted()
	for k in keys.size():
		var s: Dictionary = seats[k]
		var r := row()
		r.add_child(portrait(s.get("pet", ""), s.get("cls", ""), 56))
		var tag := ""
		var is_bot: bool = s.get("bot", "") != ""
		if is_bot:
			tag = "  (bot)" if online.host else "  (bot, %s)" % s["bot"]
		elif s.get("uid", "") == online.room.get("cfg", {}).get("host", ""):
			tag = "  (host)"
		r.add_child(lbl(str(s.get("name", "?")) + tag, 22))
		if is_bot and online.host:
			var lv := OptionButton.new()
			for name_lv in ["easy", "normal", "hard"]:
				lv.add_item(name_lv)
			lv.select(["easy", "normal", "hard"].find(s["bot"]))
			lv.item_selected.connect(_on_bot_level.bind(keys[k]))
			r.add_child(lv)
			r.add_child(btn("Remove", _on_remove_bot.bind(keys[k])))
		v.add_child(r)
	if online.host:
		if seats.size() < Online.MAX_SEATS:
			var br := row()
			for lv in ["easy", "normal", "hard"]:
				br.add_child(btn("+ Bot (%s)" % lv, _on_add_bot.bind(lv)))
			v.add_child(br)
		v.add_child(btn("Start the game", _on_start_online, seats.size() < 2))
	else:
		v.add_child(lbl("Waiting for the host to start...", 20, C_STONE))
	body.add_child(btn("Leave room", _leave_online))

func _on_add_bot(level: String) -> void:
	var err: String = await online.add_bot(level)
	toast(err)
	if screen == "online_lobby":
		show_online_lobby()

func _on_bot_level(ix: int, key: String) -> void:
	var err: String = await online.set_bot_level(key, ["easy", "normal", "hard"][ix])
	toast(err)
	if screen == "online_lobby":
		show_online_lobby()

func _on_remove_bot(key: String) -> void:
	var err: String = await online.remove_seat(key)
	toast(err)
	if screen == "online_lobby":
		show_online_lobby()

func _on_start_online() -> void:
	var err: String = await online.start()
	if err != "":
		toast(err)
		return
	_on_online_changed()

func _on_replace_idle() -> void:
	after(online.replace_idle())

func _leave_online() -> void:
	if online != null:
		online.leave()
	show_lobby()

# ---------- input ----------

func _on_roll() -> void:
	if not can_input():
		return
	sel = -1
	after(act({"a": "roll"}))

func _on_lock() -> void:
	if not can_input():
		return
	after(act({"a": "lock"}))

func _on_end() -> void:
	if not can_input():
		return
	sel = -1
	after(act({"a": "end"}))

func _on_hint() -> void:
	if not can_input():
		return
	var i := sel
	sel = -1
	after(act({"a": "hint", "i": i}))

func _on_die(i: int) -> void:
	if not can_input():
		return
	var p := game.current()
	if upgrade_mode:
		upgrade_mode = false
		after(act({"a": "upg", "i": i}))
		return
	if not p.lk:
		after(act({"a": "hold", "i": i}))
		return
	var chk := game.can_pick(i)
	if not chk["ok"]:
		toast(str(chk.get("msg", "")))
		return
	sel = -1 if sel == i else i
	show_game()

func _on_cell(i: int) -> void:
	if game == null or screen != "game" or not can_input():
		return
	if memo_mode:
		after(act({"a": "memo", "c": i}))
		if game.current().scribe < 1:
			memo_mode = false
			show_game()
		return
	if sel < 0:
		if game.current().lk:
			toast("Pick a die first")
		return
	var d := sel
	sel = -1
	after(act({"a": "place", "i": d, "c": i}))

func _on_scribe() -> void:
	if not can_input():
		return
	memo_mode = not memo_mode
	upgrade_mode = false
	show_game()

func _on_buy(id: String) -> void:
	if not can_input():
		return
	if id == "whet":
		if not upgrade_mode and game.current().gold < Rules.WHET:
			toast("Not enough gold")
			return
		upgrade_mode = not upgrade_mode
		show_game()
		return
	after(act({"a": "buy", "id": id, "t": target}))
