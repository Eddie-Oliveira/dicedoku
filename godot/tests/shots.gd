# Renders key screens to PNG for visual review. Needs a display:
#   xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tests/shots.gd
extends SceneTree

var out_dir := ""
var ui

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func snap(name: String, scroll_to: int = 0) -> void:
	var sc: ScrollContainer = ui.get_child(1)
	await process_frame
	sc.scroll_vertical = scroll_to
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)

func _run() -> void:
	ui = load("res://ui/main.tscn").instantiate()
	root.add_child(ui)
	ui.build()
	await snap("01_lobby")
	var seats := [{"name": "Ana", "pet": "cat", "cls": "wizard"}, {"name": "Bob", "pet": "dog", "cls": "knight"}, {"name": "Cy", "pet": "fox", "cls": "rogue"}]
	ui.start_game(9, seats, 1582125694, 3, 32, "even")
	await snap("02_pass")
	ui.show_game()
	var g: Game = ui.game
	var p := g.current()
	p.gold = 12
	ui._on_roll()
	ui._on_die(0)
	ui._on_die(2)
	await snap("03_rolling")
	ui._on_lock()
	for i in p.df.size():
		if g.can_pick(i)["ok"]:
			ui._on_die(i)
			break
	await snap("04_placing")
	ui.open_drawer("shop")
	await snap("05_shop")
	ui.open_drawer("party")
	await snap("06_party")
	ui.toggle_drawer("party")
	# phone-sized window: every grid line must still show
	root.size = Vector2i(390, 844)
	await snap("08_board_phone")
	root.size = Vector2i(720, 1280)
	ui.show_tuner()
	await snap("09_tuner")
	# every language on the home screen, and a game screen + tutorial in Chinese (checks the CJK font)
	for c in Lang.LANGS:
		Lang.set_lang(c)
		ui.show_lobby()
		await snap("10_lobby_%s" % c)
	Lang.set_lang("zh_CN")
	ui.start_tutorial()
	ui._on_tut_next()
	ui._on_roll()
	await snap("11_tutorial_zh_CN")
	Lang.set_lang("pt_BR")
	ui.show_game()
	await snap("12_tutorial_pt_BR")
	ui.tut = -1
	Lang.set_lang("en")
	ui.game = g
	ui.show_game()
	ui.show_game()
	g.over = true
	g.players[0].done = true
	g.players[0].turn = 18
	g.players[2].lost = true
	ui.refresh()
	await snap("07_results")
	quit(0)
