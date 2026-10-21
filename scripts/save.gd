extends Node
## Save/load persistence: one JSON dictionary at user://save.json.
## SaveGame autoload — callers build and apply the data; this file only
## reads and writes it. Any unreadable or wrong-version file reads back
## as an empty Dictionary so the game always boots clean.

const SAVE_PATH := "user://save.json"
const VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func read() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("version", 0)) != VERSION:
		return {}
	return parsed
