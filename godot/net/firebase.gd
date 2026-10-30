class_name Firebase
extends Node
## Minimal Firebase Realtime Database REST client (works on web and desktop). req() must be awaited.
## Returns {"ok": bool, "code": int, "data": Variant}. Retries network errors and 5xx up to 3 times.

var base := ""

func _init(url: String = "") -> void:
	base = url.rstrip("/")

func req(method: int, path: String, body: Variant = null, query: String = "") -> Dictionary:
	var url := "%s/%s.json" % [base, path]
	if query != "":
		url += "?" + query
	var data := "" if body == null else JSON.stringify(body)
	for attempt in 3:
		var h := HTTPRequest.new()
		h.timeout = 12.0
		add_child(h)
		var err := h.request(url, PackedStringArray(["Content-Type: application/json"]), method, data)
		if err != OK:
			h.queue_free()
			continue
		var res: Array = await h.request_completed
		h.queue_free()
		var code: int = res[1]
		if res[0] != HTTPRequest.RESULT_SUCCESS or code >= 500:
			continue
		var txt: String = (res[3] as PackedByteArray).get_string_from_utf8()
		var parsed: Variant = null
		if txt != "" and txt != "null":
			parsed = JSON.parse_string(txt)
		return {"ok": code >= 200 and code < 300, "code": code, "data": parsed}
	return {"ok": false, "code": 0, "data": null}
