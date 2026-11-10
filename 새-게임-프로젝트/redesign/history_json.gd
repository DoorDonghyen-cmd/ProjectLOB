extends RefCounted
## Keep ordinary, complete JSON saves. Only unchanged history entries reuse
## their encoding; value snapshots detect edits, replacement, truncation and load.
var snapshots: Array = []
var encoded := PackedStringArray()

func stringify(state: Dictionary) -> String:
	if not state.get("history") is Array: return JSON.stringify(state)
	var history: Array = state.history
	snapshots.resize(history.size())
	encoded.resize(history.size())
	for i in history.size():
		if encoded[i].is_empty() or snapshots[i] != history[i]:
			encoded[i] = JSON.stringify(history[i])
			snapshots[i] = history[i].duplicate(true) if history[i] is Dictionary or history[i] is Array else history[i]
	var live := state.duplicate()
	live.erase("history")
	return JSON.stringify(live).trim_suffix("}") + ("," if not live.is_empty() else "") + "\"history\":[" + ",".join(encoded) + "]}"
