class_name CorridorOpeningController
extends RefCounted

const MAX_RADIUS := 0.70
const MIN_EXTRA_RADIUS := 0.18
const ENGAGE_TIME := 0.08
const RELEASE_TIME := 0.25


func update(state: WorldState, safety: TravelerSafetyController, rig: PlayerFlightRig, delta: float) -> void:
	var target := clampf(safety.corridor_risk, 0.0, 1.0)
	var time_constant := ENGAGE_TIME if target > state.corridor_strength else RELEASE_TIME
	var alpha := 1.0 - exp(-maxf(delta, 0.0) / time_constant)
	state.corridor_strength = lerpf(state.corridor_strength, target, alpha)
	if state.corridor_strength < 0.001:
		state.clear_corridor()
		return
	state.corridor_active = true
	state.corridor_radius = minf(
		safety.collision_radius + MIN_EXTRA_RADIUS + state.corridor_strength * 0.30,
		MAX_RADIUS
	)
	state.corridor_start = rig.position - rig.forward() * safety.collision_radius
	state.corridor_mid = safety.projected_path_mid
	state.corridor_end = safety.projected_path_end
