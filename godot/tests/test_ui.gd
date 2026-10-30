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
	ui.toggle_drawer("party")
	t.check(ui.drawer.visible and ui.drawer_open == "party", "switch to party")
	ui.toggle_drawer("party")
	t.check(not ui.drawer.visible, "tap again closes")
	ui.show_tuner()
	t.check(ui.screen == "tuner" and ui._tune_previews.size() == 4, "tuner shows all four dice")
	ui._on_tune(-9.0, 6, 1, Label.new())
	t.check(ui.tune_for(6)[1] == -9 and "d6=0,-9,40" in ui.tune_code(), "slider changes the d6 code")
	ui._on_tune_reset()
	t.check(ui.tune_for(6) == [0, -6, 40], "reset")
	ui.show_lobby()
	t.check(not ui.tabbar.visible, "tabs hidden outside the game")
	ui.queue_free()
