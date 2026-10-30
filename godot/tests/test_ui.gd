extends RefCounted
# Drives the real interface (main.tscn) through whole games using only its button handlers.

func make_ui(t):
	var ui = load("res://ui/main.tscn").instantiate()
	t.root.add_child(ui)
	ui.build()
	return ui

func seats(k: int) -> Array:
	var out := []
	for i in k:
		out.append({"name": ["Ana", "Bob", "Cy", "Di"][i], "pet": Rules.PETS[i], "cls": Rules.CLASSES[i]})
	return out

func fit_cell(g: Game, p: PlayerState, i: int) -> int:
	for j in p.grid.size():
		if p.grid[j] == 0 and g.fits(p, i, j):
			return j
	return -1

## Plays one turn through the UI handlers like a careful player.
func ui_turn(ui) -> void:
	if ui.is_bot_turn():
		ui.bot_step()
		return
	if ui.screen == "pass":
		ui.show_game()
	var g: Game = ui.game
	var p := g.current()
	for r in 3:
		if p.lk:
			break
		ui._on_roll()
		if p.lk:
			break
		for i in p.df.size():
			if p.dv[i] != 0 and not p.dh[i] and not g.is_dead(p, i) and not g.is_useless(p, i) and fit_cell(g, p, i) >= 0:
				ui._on_die(i)
	if not p.lk:
		ui._on_lock()
	for i in p.df.size():
		if g.players[g.cur] != p or not p.active():
			return
		if not g.can_pick(i)["ok"]:
			continue
		var c := fit_cell(g, p, i)
		if c >= 0:
			ui._on_die(i)
			ui._on_cell(c)
	if g.players[g.cur] != p or not p.active():
		return
	if g.size == 9:
		for k in p.df.size():
			if p.df[k] < 10 and p.gold >= Rules.WHET:
				ui._on_buy("whet")
				ui._on_die(k)
	ui._on_end()

func test_lobby(t) -> void:
	var ui = make_ui(t)
	t.check(ui.screen == "lobby" and ui.body.get_child_count() > 0, "lobby shown")
	ui.lobby["count"] = 2
	ui.lobby["pets"] = [1, 1, 2, 3]
	ui.lobby["classes"] = [5, 0, 1, 2]
	ui.start_from_lobby()
	t.check(ui.screen == "pass" and ui.game.players.size() == 2, "game starts with pass screen")
	t.check(ui.game.players[0].pet == "dog" and ui.game.players[0].cls == "ranger" and ui.game.players[1].pet == "dog", "race and class from the lobby (same race allowed)")
	ui.queue_free()

func test_ui_controls(t) -> void:
	var ui = make_ui(t)
	ui.start_game(6, seats(2), 42, 7)
	ui.show_game()
	var g: Game = ui.game
	var p := g.current()
	ui._on_cell(0)
	t.check(ui.screen == "game", "cell tap before rolling is ignored")
	ui._on_roll()
	t.check(p.dv.size() == 5 and p.rolls == 2, "roll button")
	ui._on_die(0)
	t.check(p.dh[0] or g.is_useless(p, 0), "tap holds while rolling")
	ui._on_lock()
	t.check(p.lk, "lock button")
	ui._on_cell(0)
	t.check(ui.toast_label.text == "Pick a die first", "cell before die")
	p.gold = 10
	ui._on_buy("whet")
	t.check(ui.upgrade_mode, "whetstone arms upgrade")
	var f0: int = p.df[1]
	ui._on_die(1)
	t.check(not ui.upgrade_mode and p.df[1] == Rules.UPGRADES[Rules.UPGRADES.find(f0) + 1], "upgrade via tap")
	ui._on_end()
	t.check(ui.screen == "pass" and g.cur == 1, "end turn shows pass screen for next player")
	ui.queue_free()

func test_full_games_through_ui(t) -> void:
	for cfg in [[4, 1], [6, 2], [9, 3]]:
		var ui = make_ui(t)
		ui.start_game(cfg[0], seats(cfg[1]), 500 + cfg[0], 9)
		var guard := 0
		while ui.screen != "results" and guard < 1500:
			guard += 1
			ui_turn(ui)
		t.check(ui.screen == "results", "%dx%d with %d players reaches results (guard %d)" % [cfg[0], cfg[0], cfg[1], guard])
		print("  UI game %dx%d, %d players: %d turns taken" % [cfg[0], cfg[0], cfg[1], guard])
		ui.queue_free()

func test_board_layout(t) -> void:
	# Every cell button sits in the box it belongs to, in reading order (cell index = row * n + col).
	for n in [4, 6, 9]:
		var ui = make_ui(t)
		ui.start_game(n, seats(1), 3, 3)
		ui.show_game()
		var g: Game = ui.game
		var found := 0
		for i in n * n:
			var b: Button = ui.find_child("cell_%d" % i, true, false)
			if b == null:
				continue
			found += 1
			var box: GridContainer = b.get_parent()
			var k := b.get_index()
			var y: int = i / n
			var x: int = i % n
			t.check(k == (y % g.br) * g.bc + (x % g.bc), "%dx%d cell %d in wrong spot inside its box" % [n, n, i])
			t.check(box.get_index() == (y / g.br) * (n / g.bc) + x / g.bc, "%dx%d cell %d in wrong box" % [n, n, i])
		t.check(found == n * n, "%dx%d: all %d cells present (%d)" % [n, n, n * n, found])
		ui.queue_free()

func test_human_with_bots(t) -> void:
	var ui = make_ui(t)
	ui.lobby["count"] = 3
	ui.lobby["mode"] = 0
	ui.lobby["types"] = [0, 2, 3, 0]
	ui.start_from_lobby()
	t.check(ui.screen == "game", "one human: no pass screen")
	t.check(ui.game.players[1].bot == "normal" and ui.game.players[2].bot == "hard", "bot levels from lobby")
	var g: Game = ui.game
	ui._on_roll()
	ui._on_roll()
	ui._on_roll()
	ui._on_end()
	t.check(ui.is_bot_turn(), "bot's turn after the human")
	var before: int = g.players[1].turn
	ui._on_roll()
	t.check(g.players[1].dv.is_empty(), "human input ignored on bot turn")
	var guard := 0
	while ui.is_bot_turn() and guard < 500:
		guard += 1
		ui.bot_step()
	t.check(g.cur == 0 and g.players[1].turn == before + 1 and g.players[2].turn == 2, "both bots played one turn each, back to the human")
	guard = 0
	while ui.screen != "results" and guard < 3000:
		guard += 1
		ui_turn(ui)
	t.check(ui.screen == "results", "human + bots game reaches results")
	ui.queue_free()

func test_modes_drawer_tuner(t) -> void:
	var ui = make_ui(t)
	t.check(ui.MODES.size() == 5 and ui.MODES[0]["size"] == 4, "blitz + four 9x9 levels, no 6x6")
	ui.lobby["count"] = 1
	ui.lobby["mode"] = 4
	ui.start_from_lobby()
	t.check(ui.game.size == 9 and Puzzle.filled(ui.game.players[0].puz) <= 30, "Legend starts with about 28 numbers (%d)" % Puzzle.filled(ui.game.players[0].puz))
	t.check(ui.screen == "game" and ui.tabbar.visible and not ui.drawer.visible, "tabs shown, drawer closed")
	t.check(ui.find_child("cell_0", true, false) != null, "board visible")
	ui.toggle_drawer("shop")
	t.check(ui.drawer.visible and ui.drawer_open == "shop" and ui.drawer_box.get_child_count() >= 2, "shop drawer opens")
	ui.game.current().gold = 30
	ui._on_buy("ward")
	t.check(ui.drawer.visible and ui.drawer_open == "shop", "shop stays open after buying")
	ui.toggle_drawer("party")
	t.check(ui.drawer.visible and ui.drawer_open == "party", "switch to party")
	ui.toggle_drawer("party")
	t.check(not ui.drawer.visible, "tap again closes")
	ui.show_tuner()
	t.check(ui.screen == "tuner" and ui._tune_previews.size() == 4, "tuner shows all four dice")
	ui._on_tune(-9.0, 6, 1, Label.new())
	t.check(ui.tune_for(6)[1] == -9 and "d6=1,-9,39" in ui.tune_code(), "slider changes the d6 code")
	ui._on_tune_reset()
	t.check(ui.tune_for(6) == [1, 0, 39] and ui.tune_code() == "d4=0,6,40;d6=1,0,39;d8=0,0,40;d10=0,-3,40", "reset to Eddie's tuned defaults")
	ui.show_lobby()
	t.check(ui.find_child("tab_shop", true, false) == null and ui.find_child("tab_howto", true, false) != null, "lobby shows only the How to play tab")
	ui.queue_free()

func test_lobby_howto_tab_and_tiles(t) -> void:
	var ui = make_ui(t)
	t.check(ui.screen == "lobby" and ui.tabbar.visible and ui.find_child("tab_howto", true, false) != null, "How to play is a tab on the lobby")
	t.check(not ui.drawer.visible, "instructions hidden until tapped")
	ui.toggle_drawer("howto")
	t.check(ui.drawer.visible and ui.drawer_box.get_child_count() >= 2, "How to play slides up")
	ui.toggle_drawer("howto")
	t.check(not ui.drawer.visible, "and closes")
	ui.start_game(9, seats(2), 7, 7, 36, "even")
	var p0: PlayerState = ui.game.players[0]
	var a: String = ui.tile_path(p0, 10, false)
	t.check(a == ui.tile_path(p0, 10, false), "tile choice is stable")
	var kinds := {}
	for i in 81:
		kinds[ui.tile_path(p0, i, false)] = true
	t.check(kinds.size() == 1 or kinds.size() >= 4, "variants spread over the board when present (%d kinds)" % kinds.size())
	ui.queue_free()

func test_bots_random_heroes(t) -> void:
	var seen := {}
	for k in 12:
		var ui = make_ui(t)
		ui.lobby["count"] = 4
		ui.lobby["types"] = [0, 1, 2, 3]
		ui.lobby["pets"] = [0, 0, 0, 0]
		ui.lobby["classes"] = [0, 0, 0, 0]
		ui.start_from_lobby()
		var combos := {}
		for p in ui.game.players:
			combos["%s/%s" % [p.pet, p.cls]] = true
			if p.bot != "":
				seen["%s/%s" % [p.pet, p.cls]] = true
		t.check(combos.size() == 4, "every seat has a different race+class combo")
		t.check(ui.game.players[0].pet == "cat" and ui.game.players[0].cls == "wizard", "human keeps the chosen hero")
		ui.queue_free()
	t.check(seen.size() >= 8, "bots spread over many combos (%d)" % seen.size())
	t.check(Rules.random_hero([]).size() == 2, "random_hero returns race and class")

func test_tutorial_on_rails(t) -> void:
	var ui = make_ui(t)
	ui.start_tutorial()
	var g: Game = ui.game
	var p: PlayerState = g.current()
	t.check(ui.tut == 0 and ui.find_child("tut_panel", true, false) != null, "tutorial starts with its panel")
	ui._on_roll()
	t.check(p.dv.is_empty(), "rolling is blocked on the welcome step")
	ui._on_tut_next()
	ui._on_lock()
	t.check(not p.lk, "lock blocked while the tutorial asks for Roll")
	ui._on_roll()
	t.check(ui.tut == 2 and p.dv[0] == p.sol[ui.tut_cell], "scripted first die fits the tutorial tile")
	ui._on_die(3)
	t.check(not p.dh[3], "only the first die may be held")
	ui._on_die(0)
	t.check(p.dh[0] and ui.tut == 3, "hold step")
	var keep: int = p.dv[0]
	ui._on_roll()
	t.check(p.dv[0] == keep and ui.tut == 4, "held die kept on the second roll")
	var g0 := p.gold
	ui._on_lock()
	t.check(p.lk and p.gold == g0 + 1 and ui.tut == 5, "lock pays 1 gold for the unused roll")
	ui._on_die(0)
	t.check(ui.sel == 0 and ui.tut == 6, "pick step")
	var wrong := -1
	for j in 16:
		if p.grid[j] == 0 and j != ui.tut_cell:
			wrong = j
			break
	ui._on_cell(wrong)
	t.check(p.grid[wrong] == 0 and p.mis == 0, "a wrong tile is blocked in the tutorial")
	ui._on_cell(ui.tut_cell)
	t.check(p.grid[ui.tut_cell] != 0 and p.mis == 0 and ui.tut == 7, "placed on the tutorial tile")
	ui._on_tut_next()
	ui.toggle_drawer("party")
	t.check(not ui.drawer.visible, "party tab blocked when the shop is asked")
	ui.toggle_drawer("shop")
	t.check(ui.drawer.visible and ui.tut == 9, "shop opened")
	ui._on_tut_next()
	t.check(not ui.drawer.visible and ui.tut == 10, "next closes the shop")
	ui._on_end()
	t.check(ui.tut == 11 and p.turn == 2, "end turn step")
	ui._on_tut_finish()
	t.check(ui.tut == -1 and ui.screen == "lobby", "finish returns to the lobby")
	ui.queue_free()

func test_language_switch(t) -> void:
	var ui = make_ui(t)
	for c in Lang.LANGS:
		Lang.set_lang(c)
		t.check(Lang.code == c, "set %s" % c)
		ui.show_lobby()
		t.check(ui.find_child("lang_picker", true, false) != null, "picker on the home screen (%s)" % c)
	Lang.set_lang("pt_BR")
	t.check(Lang.f("{0} cleared the dungeon!", ["Ana"]).contains("Ana"), "placeholders survive translation")
	Lang.set_lang("en")
	t.check(Lang.t("Roll") == "Roll" and Lang.f("HERO_TITLE", ["Cat", "Wizard"]) == "Cat Wizard", "English and keyed strings")
	t.check(Lang.from_locale("pt_PT") == "pt_BR" and Lang.from_locale("zh_TW") == "zh_CN" and Lang.from_locale("de_DE") == "en", "device locale mapping")
	ui.queue_free()
