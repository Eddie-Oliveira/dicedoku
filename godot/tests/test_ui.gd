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
		out.append({"name": ["Ana", "Bob", "Cy", "Di"][i], "pet": Rules.PETS[i]})
	return out

func fit_cell(g: Game, p: PlayerState, i: int) -> int:
	for j in p.grid.size():
		if p.grid[j] == 0 and g.fits(p, i, j):
			return j
	return -1

## Plays one turn through the UI handlers like a careful player.
func ui_turn(ui) -> void:
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
	ui.start_from_lobby()
	t.check(ui.screen == "lobby" and ui.toast_label.text == "Each player needs a different pet", "duplicate pets refused")
	ui.lobby["pets"] = [0, 1, 2, 3]
	ui.start_from_lobby()
	t.check(ui.screen == "pass" and ui.game.players.size() == 2, "game starts with pass screen")
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
