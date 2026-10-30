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
const SIZES := [4, 6, 9]
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
var lobby := {"size": 6, "count": 2, "names": ["Ana", "Bob", "Cy", "Di"], "pets": [0, 1, 2, 3], "types": [0, 0, 0, 0]}
const SEAT_TYPES := ["Human", "Bot (easy)", "Bot (normal)", "Bot (hard)"]
const BOT_LEVELS := ["", "easy", "normal", "hard"]
const BOT_DELAY := 0.45
var bot_wait := 0.0
var bot_fails := 0
var body: VBoxContainer
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

func portrait(pet: String, px: int) -> Control:
	var t := tex("characters/pet_%s.svg" % pet)
	if t == null:
		var l := lbl("", 1)
		l.custom_minimum_size = Vector2(1, 1)
		return l
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	return r

func img(rel: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(rel)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	return r

func clear() -> void:
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
	body.add_child(pc)
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
	body.add_child(lbl("v0.10-dev - next version in progress", 18, C_STONE))
	var v := panel("New game")
	var r := row()
	r.add_child(lbl("Grid"))
	var og := OptionButton.new()
	for n in SIZES:
		og.add_item("%dx%d" % [n, n], n)
	og.select(SIZES.find(lobby["size"]))
	og.item_selected.connect(func(ix: int) -> void: lobby["size"] = SIZES[ix])
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
		var pr := row()
		pr.add_child(portrait(Rules.PETS[lobby["pets"][i]], 48))
		var le := LineEdit.new()
		le.text = lobby["names"][i]
		le.max_length = 12
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_changed.connect(func(t: String) -> void: lobby["names"][i] = t)
		pr.add_child(le)
		var op := OptionButton.new()
		for pet in Rules.PETS:
			var pt := tex("characters/pet_%s.svg" % pet)
			if pt != null:
				op.add_icon_item(pt, pet_name(pet))
			else:
				op.add_item(pet_name(pet))
		op.select(lobby["pets"][i])
		op.item_selected.connect(_on_pet.bind(i))
		pr.add_child(op)
		var ot := OptionButton.new()
		for st in SEAT_TYPES:
			ot.add_item(st)
		ot.select(lobby["types"][i])
		ot.item_selected.connect(func(ix: int) -> void: lobby["types"][i] = ix)
		pr.add_child(ot)
		v.add_child(pr)
	v.add_child(btn("Start adventure", start_from_lobby))
	var o := panel("Play online")
	o.add_child(lbl("Uses the first player's name and pet. Bots can be added in the room.", 16, C_STONE))
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
	var h := panel("How to play")
	h.add_child(lbl("Take turns on one device. On your turn roll your dice up to 3 times (tap dice to hold them), then lock. Tap a die, then a cell: it only counts if that number belongs there. 3 mistakes and you are out. Earn gold and shop at Rook's: whetstones (d4 > d6 > d8 > d10), extra dice with powers, and curses for your rivals. A d10 shows 0-9 and its 0 is wild. Lowest turns + 2 x mistakes wins.", 18))

func _on_pet(ix: int, seat: int) -> void:
	lobby["pets"][seat] = ix
	show_lobby()

func _on_count(ix: int) -> void:
	lobby["count"] = ix + 1
	show_lobby()

func start_from_lobby() -> void:
	var seats := []
	var used := []
	for i in lobby["count"]:
		var pet: String = Rules.PETS[lobby["pets"][i]]
		if used.has(pet):
			toast("Each player needs a different pet")
			return
		used.append(pet)
		var nm: String = str(lobby["names"][i]).strip_edges()
		seats.append({"name": nm if nm != "" else "Player %d" % (i + 1), "pet": pet, "bot": BOT_LEVELS[lobby["types"][i]]})
	start_game(lobby["size"], seats)

func start_game(n: int, seats: Array, seed_value: int = -1, dice_seed: int = -1) -> void:
	var s := seed_value if seed_value >= 0 else randi() % 2147483647
	game = Game.new(n, s, seats, dice_seed)
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
	else:
		show_game()

func after(res: Dictionary) -> void:
	toast(str(res.get("msg", "")))
	refresh()

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

func show_pass() -> void:
	screen = "pass"
	clear()
	var p := game.current()
	body.add_child(lbl("Pass the device to", 26, C_STONE))
	var pc := CenterContainer.new()
	pc.add_child(portrait(p.pet, 220))
	body.add_child(pc)
	body.add_child(lbl(p.name, 52, C_WOOD))
	body.add_child(lbl("the " + pet_name(p.pet), 26))
	if not p.pending.is_empty():
		var names := []
		for c in p.pending:
			names.append("%s from %s" % [Rules.CURSES.get(c["k"], "Curse"), c["from"]])
		body.add_child(lbl("Curses waiting for you: " + ", ".join(PackedStringArray(names)), 22, C_CURSE))
	body.add_child(btn("I'm ready", show_game))

# ---------- game ----------

func show_game() -> void:
	screen = "game"
	clear()
	var p := game.current()
	var who := "%s the %s  -  turn %d" % [p.name, pet_name(p.pet), p.turn]
	if p.bot != "":
		who += "  (bot, %s)" % p.bot
	var banner := row()
	banner.add_child(portrait(p.pet, 64))
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
	_shop(p)
	_players()
	body.add_child(btn("Quit to lobby", _leave_online))

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
			gem.content_margin_top = 0
			gem.content_margin_bottom = 12
			sb = gem
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_size_override("font_size", 40)
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
	v.add_child(flow)
	v.add_child(lbl(_phase(p), 20, C_WOOD))
	var info := "Rolls left %d  ·  Mistakes %d/%d  ·  Hints %d  ·  Gold %d" % [p.rolls, p.mis, Rules.MAXMIS, p.hints, p.gold]
	if p.ward > 0:
		info += "  ·  Wards %d" % p.ward
	if p.shk > 0:
		info += "  ·  Shackled (hold %d)" % p.shk
	v.add_child(lbl(info, 18))
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
		var s := "%s%s the %s  -  %d/%d cells  ·  mistakes %d" % ["> " if j == game.cur else "", q.name, pet_name(q.pet), Puzzle.filled(q.grid), n, q.mis]
		if q.done:
			s += "  ·  cleared!"
		if q.lost:
			s += "  ·  out"
		if not q.pending.is_empty():
			s += "  ·  %d curse(s) waiting" % q.pending.size()
		var pr := row()
		pr.add_child(portrait(q.pet, 44))
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
		var s := "%d. %s the %s" % [place, q.name, pet_name(q.pet)]
		if q.done:
			s += "  -  score %d (%d turns, %d mistakes)" % [q.score(), q.turn, q.mis]
		elif q.lost:
			s += "  -  out after 3 mistakes"
		var rr := row()
		rr.add_child(portrait(q.pet, 56))
		rr.add_child(lbl(s, 22))
		v.add_child(rr)
		place += 1
	body.add_child(btn("New game", _leave_online))

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
	return [nm if nm != "" else "Player", Rules.PETS[lobby["pets"][0]]]

func _on_create_online() -> void:
	toast("Opening a room...")
	var me := _me()
	var err: String = await ensure_online().create(lobby["size"], me[0], me[1])
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
	var err: String = await ensure_online().join(join_code, me[0], me[1])
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
	elif screen == "online_lobby" or screen == "lobby":
		show_online_lobby()

func show_online_lobby() -> void:
	screen = "online_lobby"
	clear()
	body.add_child(lbl("Room code", 24, C_STONE))
	body.add_child(lbl(online.code, 72, C_WOOD))
	body.add_child(lbl("Share this code. Friends open the same link, pick a name and pet, and tap Join.", 18))
	var v := panel("Players")
	var seats := online.seats_sorted()
	var keys := online.seat_keys_sorted()
	for k in keys.size():
		var s: Dictionary = seats[k]
		var r := row()
		r.add_child(portrait(s.get("pet", ""), 48))
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
