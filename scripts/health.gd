extends Node
## Player health pool: damage, delayed regen, death signal.
## HUD and respawn flow live in main.gd; this node owns the numbers only.

signal changed(hp: float, max_hp: float)
signal damaged(amount: float)
signal died

const MAX_HP := 100.0
const REGEN_DELAY := 6.0
const REGEN_RATE := 4.0

var hp := MAX_HP
var invulnerable := false

var _dead := false
var _since_hit := 0.0


func is_dead() -> bool:
	return _dead


func damage(amount: float) -> void:
	if _dead or invulnerable or amount <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_since_hit = 0.0
	damaged.emit(amount)
	changed.emit(hp, MAX_HP)
	if hp <= 0.0:
		_dead = true
		died.emit()


func heal(amount: float) -> void:
	if _dead:
		return
	hp = minf(hp + amount, MAX_HP)
	changed.emit(hp, MAX_HP)


func respawn_reset() -> void:
	hp = MAX_HP
	_dead = false
	_since_hit = 0.0
	changed.emit(hp, MAX_HP)


func restore(saved_hp: float) -> void:
	## Load-from-save entry point: never restore a dead state.
	hp = clampf(saved_hp, 1.0, MAX_HP)
	_dead = false
	_since_hit = 0.0
	changed.emit(hp, MAX_HP)


func _process(delta: float) -> void:
	if _dead or hp >= MAX_HP:
		return
	_since_hit += delta
	if _since_hit >= REGEN_DELAY:
		hp = minf(hp + REGEN_RATE * delta, MAX_HP)
		changed.emit(hp, MAX_HP)
