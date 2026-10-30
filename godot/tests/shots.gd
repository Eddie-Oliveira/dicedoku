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
	var seats := [{"name": "Ana", "pet": "kitten_wizard"}, {"name": "Bob", "pet": "puppy_knight"}, {"name": "Cy", "pet": "fox_rogue"}]
	ui.start_game(9, seats, 1582125694, 3)
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
	await snap("05_shop", 1000)
	await snap("06_party", 4000)
	# phone-sized window: every grid line must still show
	root.size = Vector2i(390, 844)
	await snap("08_board_phone")
	root.size = Vector2i(720, 1280)
	g.over = true
	g.players[0].done = true
	g.players[0].turn = 18
	g.players[2].lost = true
	ui.refresh()
	await snap("07_results")
	quit(0)
