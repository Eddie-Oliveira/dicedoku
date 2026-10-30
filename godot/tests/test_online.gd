extends RefCounted
# Two devices (and a late rejoin) in one room on an in-memory backend: same game everywhere, turn ownership enforced.

const Fake := preload("res://tests/fake_backend.gd")

## Lets every device catch up with the room.
func sync(devs: Array) -> void:
	for d in devs:
		await d.poll()

## Plays the match: whichever device may act does so (the bot brain stands in for humans).
func drive(devs: Array, t, limit: int = 20000) -> void:
	var guard := 0
	var g: Game = devs[0].game
	while not g.over and guard < limit:
		guard += 1
		var moved := false
		for d in devs:
			if d.my_turn():
				var a := Bot.next_action(d.game)
				var res: Dictionary = d.act(a)
				if not res["ok"]:
					var p: PlayerState = d.game.current()
					d.act({"a": "lock"} if not p.lk and not p.dv.is_empty() else ({"a": "roll"} if p.dv.is_empty() else {"a": "end"}))
				moved = true
				break
		await sync(devs)
		if not moved:
			t.fail("nobody can move (cur %d)" % g.cur)
			return

func same(t, a: Game, b: Game, what: String) -> void:
	t.check(a.cur == b.cur and a.over == b.over, what + ": turn")
	for k in a.players.size():
		var x: PlayerState = a.players[k]
		var y: PlayerState = b.players[k]
		t.check(x.grid == y.grid and x.gold == y.gold and x.mis == y.mis and x.turn == y.turn and x.df == y.df, "%s: seat %d" % [what, k])

func test_online_room(t) -> void:
	var fake = Fake.new()
	var host := Online.new(fake, "uA")
	var guest := Online.new(fake, "uB")
	var err: String = await host.create(6, "Ana", "cat")
	t.check(err == "" and host.code.length() == 5 and host.host, "host creates a room")
	err = await guest.join(host.code.to_lower(), "Bob", "cat")
	t.check(err == "" and not guest.host, "guest joins with a lower-case code")
	var bad: String = await Online.new(fake, "uX").join("ZZZZZ", "X", "fox")
	t.check(bad.begins_with("Room ZZZZZ not found"), "unknown code refused")
	await host.add_bot("hard")
	await sync([host, guest])
	var ss := guest.seats_sorted()
	t.check(ss.size() == 3 and ss[1]["name"] == "Bob" and ss[2]["bot"] == "hard" and ss[2]["cls"] != "" and Rules.BOT_NAMES.has(ss[2]["name"]), "seats in join order, bot added with a random hero and a name: %s" % [ss])
	t.check((await guest.start()) != "", "only the host can start")
	t.check((await host.start()) == "", "host starts")
	await sync([host, guest])
	t.check(host.game != null and guest.game != null and guest.my_seat == 1 and host.my_seat == 0, "both devices built the game (%s %s %d %d)" % [host.game != null, guest.game != null, guest.my_seat, host.my_seat])
	if host.game == null or guest.game == null:
		return
	t.check(host.game.players[0].sol == guest.game.players[0].sol and host.game.players[1].sol == guest.game.players[1].sol, "same puzzles on both devices")
	t.check(not guest.act({"a": "roll"})["ok"], "guest cannot act on the host's turn")
	await drive([host, guest], t)
	t.check(host.game.over, "online match finishes")
	same(t, host.game, guest.game, "host vs guest")
	# a third device rejoining as Bob after a reload replays the whole log
	var again := Online.new(fake, "uB-reload")
	err = await again.join(host.code, "Bob", "dog")
	t.check(err == "" and again.my_seat == 1, "reload rejoins Bob's seat by name")
	await again.poll()
	same(t, host.game, again.game, "host vs rejoined device")

func test_idle_seat_to_bot(t) -> void:
	var fake = Fake.new()
	var host := Online.new(fake, "uA")
	var guest := Online.new(fake, "uB")
	await host.create(4, "Ana", "cat")
	await guest.join(host.code, "Bob", "dog")
	await host.start()
	await sync([host, guest])
	host.act({"a": "roll"})
	host.act({"a": "end"})
	await sync([host, guest])
	t.check(guest.my_turn() and not host.can_replace_idle(), "Bob's turn, not idle yet")
	host.last_change -= Online.IDLE_MS + 1000
	t.check(host.can_replace_idle(), "idle after 90 s")
	t.check(host.replace_idle()["ok"] and host.game.players[1].bot == "normal", "host hands Bob's seat to a bot")
	await sync([host, guest])
	t.check(guest.game.players[1].bot == "normal", "guest sees the change")
	t.check(host.my_turn() and not guest.my_turn(), "host now drives that seat")

func test_host_edits_bots(t) -> void:
	var fake = Fake.new()
	var host := Online.new(fake, "uA")
	await host.create(6, "Ana", "cat")
	await host.add_bot("easy")
	await host.add_bot("hard")
	var keys := host.seat_keys_sorted()
	t.check(keys.size() == 3, "two bots added")
	t.check((await host.set_bot_level(keys[1], "normal")) == "" and host.seats_sorted()[1]["bot"] == "normal", "bot level changed")
	t.check((await host.remove_seat(keys[0])) == "Only bots can be removed", "host seat cannot be removed")
	t.check((await host.remove_seat(keys[2])) == "" and host.seats_sorted().size() == 2, "bot removed")
	var guest := Online.new(fake, "uB")
	await guest.join(host.code, "Bob", "fox")
	var gk := guest.seat_keys_sorted()
	t.check(guest.seats_sorted().size() == 3 and guest.seats_sorted()[1]["bot"] == "normal", "guest sees the edited seats")
	t.check((await guest.remove_seat(gk[1])) == "", "guest cannot remove (no-op)")
	await host.poll()
	t.check(host.seats_sorted().size() == 3, "seat still there after guest attempt")

func test_online_difficulty(t) -> void:
	var fake = Fake.new()
	var host := Online.new(fake, "uA")
	var guest := Online.new(fake, "uB")
	await host.create(9, "Ana", "cat", "wizard", 32, "even")
	await guest.join(host.code, "Bob", "dog", "knight")
	await host.start()
	await sync([host, guest])
	var a: PlayerState = host.game.players[0]
	var b: PlayerState = guest.game.players[1]
	t.check(Puzzle.filled(a.puz) == Puzzle.filled(b.puz) and Puzzle.filled(a.puz) <= 34, "both seats get the chosen difficulty (%d)" % Puzzle.filled(a.puz))
	t.check(Puzzle.digit_counts(a.puz, 9)[9] == Puzzle.digit_counts(b.puz, 9)[9], "same number of given 9s for both seats")
	t.check(host.game.players[1].puz == guest.game.players[1].puz, "devices agree")
