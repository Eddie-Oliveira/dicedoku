extends RefCounted
## In-memory stand-in for Firebase's REST API (GET/PUT/PATCH/DELETE, orderBy $key + startAt).

var tree := {}
var calls := 0

func _walk(parts: PackedStringArray, create: bool) -> Variant:
	var node: Variant = tree
	for p in parts:
		if not (node is Dictionary):
			return null
		if not node.has(p):
			if not create:
				return null
			node[p] = {}
		node = node[p]
	return node

func req(method: int, path: String, body: Variant = null, query: String = "") -> Dictionary:
	calls += 1
	var parts := path.split("/", false)
	var leaf := parts[parts.size() - 1]
	var parent_parts := parts.slice(0, parts.size() - 1)
	match method:
		HTTPClient.METHOD_GET:
			var v: Variant = _walk(parts, false)
			if v is Dictionary and query.contains("startAt="):
				var start := query.split("startAt=%22")[1].split("%22")[0]
				var out := {}
				for k in v.keys():
					if str(k) >= start:
						out[k] = v[k]
				v = out
			return {"ok": true, "code": 200, "data": _copy(v)}
		HTTPClient.METHOD_PUT:
			var par: Dictionary = _walk(parent_parts, true)
			par[leaf] = _copy(body)
		HTTPClient.METHOD_PATCH:
			var node: Dictionary = _walk(parts, true)
			for k in body.keys():
				node[k] = _copy(body[k])
		HTTPClient.METHOD_DELETE:
			var par2: Variant = _walk(parent_parts, false)
			if par2 is Dictionary:
				par2.erase(leaf)
	return {"ok": true, "code": 200, "data": _copy(body)}

func _copy(v: Variant) -> Variant:
	if v == null:
		return null
	return JSON.parse_string(JSON.stringify(v))
