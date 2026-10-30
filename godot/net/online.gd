class_name Online
extends Node
## Online room on Firebase. The room keeps the seats and an ordered action log (acts/a000000, a000001, ...).
## Every device builds the same Game from the room settings and applies the same actions, so all screens agree.
## Only the seat whose turn it is may add actions; bots act from the host's device.

signal changed

const GET := HTTPClient.METHOD_GET
const PUT := HTTPClient.METHOD_PUT
const PATCH := HTTPClient.METHOD_PATCH
const MAX_SEATS := 4
const IDLE_MS := 90000

var db               # Firebase or a test double with the same req()
var uid := ""
var code := ""
var host := false
var room: Dictionary = {}
var game: Game
var my_seat := -1
var applied := 0
var last_change := 0
var poll_every := 1.2
var _t := 0.0
var _polling := false
var _send_q: Array = []
var _sending := false
var error := ""

func _init(backend = null, user_id: String = "") -> void:
	db = backend
	uid = user_id

func _process(delta: float) -> void:
	if code == "" or _polling:
		return
	_t -= delta
	if _t <= 0.0:
		_t = poll_every
		poll()

static func new_code() -> String:
	var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ"
	var s := ""
	for i in 5:
		s += letters[randi() % letters.length()]
	return s

static func act_key(i: int) -> String:
	return "a%06d" % i

static func seat_key() -> String:
	return "j%013d%03d" % [int(Time.get_unix_time_from_system() * 1000.0), randi() % 1000]

## A seat key that sorts after every seat already in the room (join order = seat order).
func next_seat_key() -> String:
	var k := seat_key()
	var seats: Dictionary = room.get("seats", {})
	var keys := seats.keys()
	keys.sort()
	if not keys.is_empty() and k <= str(keys[-1]):
		var last := str(keys[-1])
		k = "j%016d" % (int(last.substr(1)) + 1)
	return k

func seats_sorted() -> Array:
	var seats: Dictionary = room.get("seats", {})
	var keys := seats.keys()
	keys.sort()
	var out := []
	for k in keys:
		out.append(seats[k])
	return out

func seat_keys_sorted() -> Array:
	var keys: Array = room.get("seats", {}).keys()
	keys.sort()
	return keys

## Host only, before the start: remove a bot seat.
func remove_seat(key: String) -> String:
	if not host or started():
		return ""
	var seat: Dictionary = room.get("seats", {}).get(key, {})
	if seat.get("bot", "") == "":
		return "Only bots can be removed"
	var w: Dictionary = await db.req(HTTPClient.METHOD_DELETE, "rooms/%s/seats/%s" % [code, key])
	if not w["ok"]:
		return "Could not remove the bot"
	room["seats"].erase(key)
	changed.emit()
	return ""

## Host only, before the start: change a bot seat's level.
func set_bot_level(key: String, level: String) -> String:
	if not host or started():
		return ""
	var seat: Dictionary = room.get("seats", {}).get(key, {})
	if seat.get("bot", "") == "":
		return ""
	var w: Dictionary = await db.req(PATCH, "rooms/%s/seats/%s" % [code, key], {"bot": level})
	if not w["ok"]:
		return "Could not change the bot"
	room["seats"][key]["bot"] = level
	changed.emit()
	return ""

func started() -> bool:
	return bool(room.get("started", false))

## Creates a room and seats the host. Returns "" or an error message.
func create(size: int, pname: String, pet: String) -> String:
	for attempt in 4:
		var c := new_code()
		var r: Dictionary = await db.req(GET, "rooms/" + c + "/cfg")
		if not r["ok"]:
			return "Can't reach the server"
		if r["data"] == null:
			code = c
			break
	if code == "":
		return "Could not find a free room code"
	var cfg := {"size": size, "seed": randi() % 2147483647, "dice_seed": randi() % 2147483647, "host": uid,
		"created": int(Time.get_unix_time_from_system())}
	room = {"cfg": cfg, "started": false, "seats": {seat_key(): {"name": pname, "pet": pet, "uid": uid, "bot": ""}}}
	var w: Dictionary = await db.req(PUT, "rooms/" + code, room)
	if not w["ok"]:
		code = ""
		return "Could not create the room"
	host = true
	changed.emit()
	return ""

## Joins (or rejoins) a room. Returns "" or an error message.
func join(c: String, pname: String, pet: String) -> String:
	c = c.strip_edges().to_upper()
	var r: Dictionary = await db.req(GET, "rooms/" + c)
	if not r["ok"]:
		return "Can't reach the server"
	if r["data"] == null or not (r["data"] is Dictionary) or not r["data"].has("cfg"):
		return "Room %s not found" % c
	room = r["data"]
	code = c
	host = room["cfg"]["host"] == uid
	for s in seats_sorted():
		if s.get("uid", "") == uid:
			_maybe_start()
			changed.emit()
			return ""
	if started():
		# rejoin after a reload or from another device: take back the human seat with the same name
		var seats_d: Dictionary = room.get("seats", {})
		for k in seats_d.keys():
			var s: Dictionary = seats_d[k]
			if s.get("bot", "") == "" and str(s.get("name", "")).to_lower() == pname.to_lower():
				var w0: Dictionary = await db.req(PATCH, "rooms/%s/seats/%s" % [code, k], {"uid": uid})
				if not w0["ok"]:
					code = ""
					return "Could not rejoin"
				s["uid"] = uid
				_maybe_start()
				changed.emit()
				return ""
		code = ""
		return "That game has already started"
	var seats := seats_sorted()
	if seats.size() >= MAX_SEATS:
		code = ""
		return "Room is full"
	var used := []
	for s in seats:
		used.append(s.get("pet", ""))
	if used.has(pet):
		for p in Rules.PETS:
			if not used.has(p):
				pet = p
				break
	var k := next_seat_key()
	var seat := {"name": pname, "pet": pet, "uid": uid, "bot": ""}
	var w: Dictionary = await db.req(PUT, "rooms/%s/seats/%s" % [code, k], seat)
	if not w["ok"]:
		code = ""
		return "Could not join the room"
	room["seats"][k] = seat
	changed.emit()
	return ""

func add_bot(level: String) -> String:
	if not host or started():
		return ""
	var r: Dictionary = await db.req(GET, "rooms/" + code)
	if r["ok"] and r["data"] is Dictionary:
		room = r["data"]
	var seats := seats_sorted()
	if seats.size() >= MAX_SEATS:
		return "Room is full"
	var used := []
	for s in seats:
		used.append(s.get("pet", ""))
	var pet := ""
	for p in Rules.PETS:
		if not used.has(p):
			pet = p
			break
	var seat := {"name": "%s bot" % Rules.PET_NAMES[pet].split(" ")[0], "pet": pet, "uid": "bot", "bot": level}
	var k := next_seat_key()
	var w: Dictionary = await db.req(PUT, "rooms/%s/seats/%s" % [code, k], seat)
	if not w["ok"]:
		return "Could not add a bot"
	room["seats"][k] = seat
	changed.emit()
	return ""

func start() -> String:
	if not host:
		return "Only the host can start"
	var r: Dictionary = await db.req(GET, "rooms/" + code)
	if r["ok"] and r["data"] is Dictionary:
		room = r["data"]
	if seats_sorted().size() < 2:
		return "Need at least 2 players"
	var w: Dictionary = await db.req(PATCH, "rooms/" + code, {"started": true})
	if not w["ok"]:
		return "Could not start"
	room["started"] = true
	_maybe_start()
	changed.emit()
	return ""

func _maybe_start() -> void:
	if game != null or not started():
		return
	var cfg: Dictionary = room["cfg"]
	var seats := []
	my_seat = -1
	var ss := seats_sorted()
	for i in ss.size():
		seats.append({"name": ss[i]["name"], "pet": ss[i]["pet"], "bot": ss[i].get("bot", "")})
		if ss[i].get("uid", "") == uid:
			my_seat = i
	game = Game.new(int(cfg["size"]), int(cfg["seed"]), seats, int(cfg["dice_seed"]))
	applied = 0
	last_change = Time.get_ticks_msec()

## True when this device may act now: my seat's turn, or a bot's turn on the host.
func my_turn() -> bool:
	if game == null or game.over:
		return false
	var p := game.current()
	return (p.bot == "" and game.cur == my_seat) or (p.bot != "" and host)

## Apply locally, then send. Refused actions are not sent.
func act(a: Dictionary) -> Dictionary:
	if not my_turn():
		return {"ok": false, "msg": "Wait for your turn"}
	var res := game.apply(a)
	if res["ok"]:
		_send_q.append([applied, a])
		applied += 1
		last_change = Time.get_ticks_msec()
		_flush()
	return res

func _flush() -> void:
	if _sending:
		return
	_sending = true
	while not _send_q.is_empty():
		var item: Array = _send_q[0]
		var w: Dictionary = await db.req(PUT, "rooms/%s/acts/%s" % [code, act_key(item[0])], item[1])
		if not w["ok"]:
			error = "Connection problem: retrying"
			await get_tree().create_timer(1.5).timeout
			continue
		error = ""
		_send_q.pop_front()
	_sending = false

## Lobby: refresh the room. Game: fetch actions after the ones already applied and apply them in order.
func poll() -> void:
	if code == "" or _polling:
		return
	_polling = true
	if game == null:
		var r: Dictionary = await db.req(GET, "rooms/" + code)
		if r["ok"] and r["data"] is Dictionary:
			room = r["data"]
			_maybe_start()
			changed.emit()
	elif _send_q.is_empty():
		var q := "orderBy=%%22%%24key%%22&startAt=%%22%s%%22" % act_key(applied)
		var r: Dictionary = await db.req(GET, "rooms/%s/acts" % code, null, q)
		if r["ok"] and r["data"] is Dictionary:
			var keys: Array = r["data"].keys()
			keys.sort()
			var any := false
			for k in keys:
				if k != act_key(applied):
					continue
				game.apply(r["data"][k])
				applied += 1
				any = true
			if any:
				last_change = Time.get_ticks_msec()
				changed.emit()
	_polling = false

## Someone else's human seat has been idle a long time: the host may hand it to a bot.
func can_replace_idle() -> bool:
	return host and game != null and not game.over and game.current().bot == "" and game.cur != my_seat \
		and Time.get_ticks_msec() - last_change > IDLE_MS

func replace_idle() -> Dictionary:
	if not can_replace_idle():
		return {"ok": false}
	var res := game.apply({"a": "botify", "s": game.cur})
	if res["ok"]:
		_send_q.append([applied, {"a": "botify", "s": game.cur}])
		applied += 1
		_flush()
	return res

func leave() -> void:
	code = ""
	game = null
	room = {}
	host = false
	my_seat = -1
	_send_q.clear()
