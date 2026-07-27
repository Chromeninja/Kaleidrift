class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal depleted

@export var maximum_health: int = 5
@export var invulnerability_seconds: float = 1.25

var current_health: int = 5
var invulnerability_remaining: float = 0.0


func reset() -> void:
	current_health = maximum_health
	invulnerability_remaining = 0.0
	health_changed.emit(current_health, maximum_health)


func tick(delta: float) -> void:
	invulnerability_remaining = maxf(invulnerability_remaining - delta, 0.0)


func grant_invulnerability(seconds: float) -> void:
	invulnerability_remaining = maxf(invulnerability_remaining, seconds)


func take_damage(amount: int = 1) -> bool:
	if amount <= 0 or current_health <= 0 or invulnerability_remaining > 0.0:
		return false
	current_health = maxi(current_health - amount, 0)
	invulnerability_remaining = invulnerability_seconds
	damaged.emit(amount)
	health_changed.emit(current_health, maximum_health)
	if current_health == 0:
		depleted.emit()
	return true


func is_invulnerable() -> bool:
	return invulnerability_remaining > 0.0
