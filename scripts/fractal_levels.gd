class_name FractalLevels
extends RefCounted

enum Type { FOLD = 0, MANDELBOX = 1, MANDELBULB = 2, KIFS = 3, MENGER = 4, MIXED = 5 }

const REGION_SIZE := 64.0
const MIXED_OPTIONS := [Type.MANDELBOX, Type.MANDELBULB, Type.KIFS, Type.MENGER]

static func display_name(level: int) -> String:
	match level:
		Type.FOLD: return "Kalei Fold (Classic)"
		Type.MANDELBOX: return "Mandelbox"
		Type.MANDELBULB: return "Mandelbulb"
		Type.KIFS: return "Kaleidoscopic IFS"
		Type.MENGER: return "Menger Sponge"
		Type.MIXED: return "Mixed Drift"
		_: return "Kalei Fold (Classic)"

static func description(level: int) -> String:
	match level:
		Type.FOLD: return "Mirrored crystal corridors with gentle motion."
		Type.MANDELBOX: return "Geometric folded chambers and sharp passages."
		Type.MANDELBULB: return "Organic bulb-like forms with branching detail."
		Type.KIFS: return "Symmetric recursive crystals and mirrored halls."
		Type.MENGER: return "Structured voxel-like tunnels and openings."
		Type.MIXED: return "A predictable new form in each region."
		_: return "Mirrored crystal corridors with gentle motion."

static func for_region(level: int, region_id: int, journey_seed: int) -> int:
	if level != Type.MIXED:
		return level
	var value := int(abs(journey_seed) ^ (region_id * 1103515245 + 12345))
	var index := posmod(value, MIXED_OPTIONS.size())
	if region_id > 0:
		var previous := for_region(level, region_id - 1, journey_seed)
		if MIXED_OPTIONS[index] == previous:
			index = posmod(index + 1, MIXED_OPTIONS.size())
	return MIXED_OPTIONS[index]

static func region_info(level: int, position_z: float, journey_seed: int) -> Dictionary:
	var coordinate := (position_z + REGION_SIZE) / REGION_SIZE
	var region_id := floori(coordinate)
	var fraction := coordinate - floorf(coordinate)
	var boundary_distance := minf(fraction, 1.0 - fraction)
	return {"id": region_id, "active": for_region(level, region_id, journey_seed), "blend": 1.0 - smoothstep(0.0, 0.16, boundary_distance)}
