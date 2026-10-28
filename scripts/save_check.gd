extends Node
## Scripted save/load hardening gate — issue 169.
##
## Exercises the SaveGame autoload the way a real crash would: round-trip
## a full save, corrupt the primary file mid-write style, feed it
## garbage and a future version, and make sure the previous good save
## (save.json.bak) still loads. Exits nonzero on the first failed
## expectation so a save-regression PR cannot land green.
##
## Usage:
##   godot --headless --path . res://scenes/save_check.tscn

const SAVE := "user://save.json"
const BACKUP := "user://save.json.bak"
const TMP := "user://save.json.tmp"

var _fails := 0


func _ready() -> void:
	# Deterministic start: wipe every save artifact this check touches.
	_remove(SAVE)
	_remove(BACKUP)
	_remove(TMP)

	_check("empty state reads as no-save", SaveGame.read().is_empty())
	_check("empty state has_save false", not SaveGame.has_save())

	# --- 1. Full round-trip with nested per-character data.
	var data := {
		"character": "riya",
		"cash": 1450,
		"hp": 82.5,
		"pos": [12.5, 1.0, -30.25],
		"heading": 1.5708,
		"day_t": 0.62,
		"missions_completed": {"chai_run": 3, "tiffin_dash": 1},
		"chars": {
			"riya": {"hp": 82.5, "cash": 1450, "heading": 1.5708, "pos": [12.5, 1.0, -30.25]},
			"monty": {"hp": 64.0, "cash": 210, "heading": 0.0, "pos": [-4.0, 1.0, 8.0]},
		},
	}
	_check("write reports success", SaveGame.write(data.duplicate()))
	var back := SaveGame.read()
	_check("has_save true after write", SaveGame.has_save())
	_check("round-trip cash", int(back.get("cash", -1)) == 1450)
	_check("round-trip character", String(back.get("character", "")) == "riya")
	_check("round-trip hp float", is_equal_approx(float(back.get("hp", 0.0)), 82.5))
	_check("round-trip pos array", (back.get("pos", []) as Array).size() == 3)
	_check("round-trip missions dict", (back.get("missions_completed", {}) as Dictionary).size() == 2)
	_check("round-trip chars nested", (back.get("chars", {}) as Dictionary).size() == 2)
	_check("write stamps version", int(back.get("version", 0)) == SaveGame.VERSION)
	_check("temp file cleaned up", not FileAccess.file_exists(TMP))

	# --- 2. Backup rotation: a second good save demotes the first to .bak.
	data["cash"] = 9999
	_check("second write succeeds", SaveGame.write(data.duplicate()))
	_check("primary has new cash", int(SaveGame.read().get("cash", -1)) == 9999)
	_check("backup holds previous save", FileAccess.file_exists(BACKUP))

	# --- 3. Crash simulation: primary truncated to garbage.
	# The read must fall back to the rotated backup (cash 1450).
	_write_raw(SAVE, "{\"cash\": 9999, \"vers")
	_check("corrupt primary falls back to backup", int(SaveGame.read().get("cash", -1)) == 1450)

	# --- 4. Future version must not load as playable state.
	_write_raw(SAVE, "{\"version\": 99, \"cash\": 7}")
	# Still returns the backup here — the previous GOOD save survives.
	_check("future-version primary defers to backup", int(SaveGame.read().get("cash", -1)) == 1450)

	# --- 5. Everything unreadable: clean empty state, never a crash.
	_remove(BACKUP)
	_check("all saves unreadable reads empty", SaveGame.read().is_empty())

	# --- 6. Garbage-only primary, no backup: empty state again.
	_write_raw(SAVE, "not json at all")
	_check("garbage primary reads empty", SaveGame.read().is_empty())

	# --- 7. Recovery: a fresh good write replaces the garbage.
	_check("recovery write succeeds", SaveGame.write(data.duplicate()))
	_check("recovery read", int(SaveGame.read().get("cash", -1)) == 9999)

	# Leave a clean slate for other checks on this machine.
	_remove(SAVE)
	_remove(BACKUP)
	_remove(TMP)

	if _fails == 0:
		print("save_check: all %d expectations met" % _total)
		print("verdict=PASS")
		get_tree().quit(0)
	else:
		print("verdict=FAIL (%d of %d expectations failed)" % [_fails, _total])
		get_tree().quit(1)


var _total := 0

func _check(what: String, ok: bool) -> void:
	_total += 1
	print("  %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _remove(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove(path.get_file())


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
