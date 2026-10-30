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

var game: Game
var screen := "lobby"
var sel := -1
var upgrade_mode := false
var target := -1
var shown_cur := -1
var lobby := {"size": 6, "count": 2, "names": ["Ana", "Bob", "Cy", "Di"], "pets": [0, 1, 2, 3]}
var body: VBoxContainer
var toast_panel: PanelContainer
var toast_label: Label
var toast_left := 0.0

func _ready() -> void:
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = C_PARCH
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
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
	return th

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
	body.add_child(lbl("Dicedoku", 48, C_WOOD))
	body.add_child(lbl("v0.9 test build - plain look, art coming next", 18, C_STONE))
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
		var le := LineEdit.new()
		le.text = lobby["names"][i]
		le.max_length = 12
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_changed.connect(func(t: String) -> void: lobby["names"][i] = t)
		pr.add_child(le)
		var op := OptionButton.new()
		for pet in Rules.PETS:
			op.add_item(pet_name(pet))
		op.select(lobby["pets"][i])
		op.item_selected.connect(func(ix: int) -> void: lobby["pets"][i] = ix)
		pr.add_child(op)
		v.add_child(pr)
	v.add_child(btn("Start adventure", start_from_lobby))
	var h := panel("How to play")
	h.add_child(lbl("Take turns on one device. On your turn roll your dice up to 3 times (tap dice to hold them), then lock. Tap a die, then a cell: it only counts if that number belongs there. 3 mistakes and you are out. Earn gold and shop at Rook's: whetstones (d4 > d6 > d8 > d10), extra dice with powers, and curses for your rivals. A d10 shows 0-9 and its 0 is wild. Lowest turns + 2 x mistakes wins.", 18))

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
		seats.append({"name": nm if nm != "" else "Player %d" % (i + 1), "pet": pet})
	start_game(lobby["size"], seats)

func start_game(n: int, seats: Array, seed_value: int = -1, dice_seed: int = -1) -> void:
	var s := seed_value if seed_value >= 0 else randi() % 2147483647
	game = Game.new(n, s, seats, dice_seed)
	sel = -1
	upgrade_mode = false
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
		target = -1
		if active_count() > 1:
			show_pass()
		else:
			show_game()
	else:
		show_game()

func after(res: Dictionary) -> void:
	toast(str(res.get("msg", "")))
	refresh()

func show_pass() -> void:
	screen = "pass"
	clear()
	var p := game.current()
	body.add_child(lbl("Pass the device to", 26, C_STONE))
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
	body.add_child(lbl("%s the %s  -  turn %d" % [p.name, pet_name(p.pet), p.turn], 28, C_WOOD))
	if not p.pending.is_empty() and not p.fxd:
		body.add_child(lbl("A curse will hit your first roll!", 20, C_CURSE))
	_board(p)
	_tracker(p)
	_dice(p)
	_shop(p)
	_players()
	body.add_child(btn("Quit to lobby", show_lobby))

func _phase(p: PlayerState) -> String:
	if upgrade_mode:
		return "Whetstone: tap a die to upgrade it"
	if p.lk:
		return "Tap a die, then a cell"
	if p.dv.is_empty():
		return "Roll your dice"
	return "Tap dice to hold, then Roll again or Lock"

func _board(p: PlayerState) -> void:
	var n := game.size
	var cc := CenterContainer.new()
	var grid := GridContainer.new()
	grid.columns = n
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	var px := int(min(78.0, 664.0 / n))
	var sv: int = p.dv[sel] if sel >= 0 and sel < p.dv.size() else 0
	for i in n * n:
		var v: int = p.grid[i]
		var given: bool = game.puz[i] != 0
		var y := i / n
		var x := i % n
		var b := Button.new()
		b.custom_minimum_size = Vector2(px, px)
		b.text = str(v) if v != 0 else ""
		var bgc := C_STONE.darkened(0.15) if given else C_STONE.lightened(0.55)
		if v == 0 and sv > 0 and game.legal(p, i, sv):
			bgc = C_TORCH.lightened(0.25)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bgc
		sb.border_color = C_INK
		sb.border_width_left = 4 if x % game.bc == 0 else 1
		sb.border_width_top = 4 if y % game.br == 0 else 1
		sb.border_width_right = 4 if x == n - 1 else 0
		sb.border_width_bottom = 4 if y == n - 1 else 0
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var fc := C_PARCH if given else C_GLOW
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(st, fc)
		b.add_theme_font_size_override("font_size", int(px * 0.55))
		b.pressed.connect(_on_cell.bind(i))
		grid.add_child(b)
	cc.add_child(grid)
	body.add_child(cc)

func _tracker(p: PlayerState) -> void:
	var cc := CenterContainer.new()
	var r := row()
	for k in range(1, game.size + 1):
		var full := game.count_value(p, k) == game.size
		var l := lbl(str(k), 22, C_STONE.lightened(0.2) if full else C_INK)
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if full:
			l.text = "(%d)" % k
		r.add_child(l)
	cc.add_child(r)
	body.add_child(cc)

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
		b.custom_minimum_size = Vector2(76, 88)
		var tag: String = KIND_TAGS.get(p.dk[i], "")
		var extra := ""
		if val > 0 and game.is_wild(p, i):
			extra = " wild"
		elif game.is_useless(p, i):
			extra = " done"
		b.text = "%s\nd%d%s%s" % [Rules.face_label(val, f), f, tag, extra]
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
		var sb := _box(col, 12, border, bw)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_font_size_override("font_size", 20)
		if i < p.du.size() and p.du[i]:
			b.modulate = Color(1, 1, 1, 0.3)
		b.pressed.connect(_on_die.bind(i))
		flow.add_child(b)
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
	r.add_child(btn("Roll", _on_roll, p.lk or p.rolls < 1))
	r.add_child(btn("Lock", _on_lock, not rolled or p.lk))
	r.add_child(btn("End turn", _on_end, not rolled))
	r.add_child(btn("Hint", _on_hint, p.hints < 1 or not p.lk or sel < 0))
	v.add_child(r)

func _shop(p: PlayerState) -> void:
	var v := panel("Rook the Raccoon's shop")
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
		v.add_child(lbl(s, 18, C_CURSE if not q.pending.is_empty() else C_INK))

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
		v.add_child(lbl(s, 22))
		place += 1
	body.add_child(btn("New game", show_lobby))

# ---------- input ----------

func _on_roll() -> void:
	sel = -1
	after(game.roll())

func _on_lock() -> void:
	after(game.lock())

func _on_end() -> void:
	sel = -1
	after(game.end_turn())

func _on_hint() -> void:
	var i := sel
	sel = -1
	after(game.hint(i))

func _on_die(i: int) -> void:
	var p := game.current()
	if upgrade_mode:
		upgrade_mode = false
		after(game.upgrade(i))
		return
	if not p.lk:
		after(game.hold(i))
		return
	var chk := game.can_pick(i)
	if not chk["ok"]:
		toast(str(chk.get("msg", "")))
		return
	sel = -1 if sel == i else i
	show_game()

func _on_cell(i: int) -> void:
	if game == null or screen != "game":
		return
	if sel < 0:
		if game.current().lk:
			toast("Pick a die first")
		return
	var d := sel
	sel = -1
	after(game.place(d, i))

func _on_buy(id: String) -> void:
	if id == "whet":
		if not upgrade_mode and game.current().gold < Rules.WHET:
			toast("Not enough gold")
			return
		upgrade_mode = not upgrade_mode
		show_game()
		return
	after(game.buy(id, target))
