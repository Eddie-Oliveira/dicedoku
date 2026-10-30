extends RefCounted
# Talks to the real Firebase database when FIREBASE_URL is set (CI). Skipped otherwise.

func test_live_room(t) -> void:
	var url := OS.get_environment("FIREBASE_URL")
	if url == "":
		print("  live Firebase test skipped (no FIREBASE_URL)")
		return
	var fb := Firebase.new(url)
	t.root.add_child(fb)
	var path := "rooms/CI%d" % (randi() % 1000000)
	var w: Dictionary = await fb.req(HTTPClient.METHOD_PUT, path + "/cfg", {"probe": 1})
	t.check(w["ok"], "live write (code %d, %s)" % [w["code"], fb.last_error])
	var r: Dictionary = await fb.req(HTTPClient.METHOD_GET, path + "/cfg")
	t.check(r["ok"] and r["data"] is Dictionary and int(r["data"]["probe"]) == 1, "live read back")
	await fb.req(HTTPClient.METHOD_DELETE, path)
	# full online flow on the real database
	var host := Online.new(fb, "ciA")
	var guest := Online.new(fb, "ciB")
	t.root.add_child(host)
	t.root.add_child(guest)
	host.set_process(false)
	guest.set_process(false)
	t.check((await host.create(4, "Ana", "kitten_wizard")) == "", "live create")
	t.check((await guest.join(host.code, "Bob", "puppy_knight")) == "", "live join")
	t.check((await host.start()) == "", "live start")
	await guest.poll()
	host.act({"a": "roll"})
	host.act({"a": "lock"})
	host.act({"a": "end"})
	await t.create_timer(3.0).timeout
	await guest.poll()
	t.check(guest.applied == 3 and guest.game.cur == 1 and guest.my_turn(), "guest received the host's turn (%d actions)" % guest.applied)
	await fb.req(HTTPClient.METHOD_DELETE, "rooms/" + host.code)
	print("  live Firebase round trip ok, room %s cleaned up" % host.code)
