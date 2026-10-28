extends Node
## Save/load persistence: one JSON dictionary at user://save.json.
## SaveGame autoload — callers build and apply the data; this file only
## reads and writes it. Any unreadable or wrong-version file reads back
## as an empty Dictionary so the game always boots clean.
##
## Hardened (issue 169): writes are atomic (temp file + rename) so a
## crash or browser refresh mid-save can never leave a truncated file,
## and every good save rotates the previous one to save.json.bak. If
## the primary file is ever unreadable, the backup still loads.

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.bak"
const TMP_PATH := "user://save.json.tmp"
const VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	var payload := JSON.stringify(data, "\t")
	# Atomic swap: serialize fully into a temp file, then rename it over
	# the real save. A kill between the two leaves the OLD save intact.
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(payload)
		f.close()
		_rotate_backup()
		var dir := DirAccess.open("user://")
		if dir != null and dir.rename(TMP_PATH.get_file(), SAVE_PATH.get_file()) == OK:
			return true
	# Temp path unusable or rename refused — still try a direct write
	# rather than losing the save outright.
	return _direct_write(payload)


func read() -> Dictionary:
	var primary := _parse(SAVE_PATH)
	if not primary.is_empty():
		return primary
	# Primary missing/corrupt/wrong-version: fall back to the previous
	# good save rotated by the last successful write.
	return _parse(BACKUP_PATH)


func _direct_write(payload: String) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(payload)
	f.close()
	return true


func _rotate_backup() -> void:
	## The current good save becomes the backup; one generation is
	## enough to survive a single bad write.
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var from := SAVE_PATH.get_file()
	var to := BACKUP_PATH.get_file()
	if dir.file_exists(to):
		dir.remove(to)
	dir.rename(from, to)


func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
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
