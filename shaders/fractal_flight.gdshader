shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec3 camera_position = vec3(0.0);
uniform vec3 camera_forward = vec3(0.0, 0.0, -1.0);
uniform vec3 camera_right = vec3(1.0, 0.0, 0.0);
uniform vec3 camera_up = vec3(0.0, 1.0, 0.0);
uniform float elapsed_time = 0.0;
uniform int fractal_type : hint_range(0, 5, 1) = 0;
uniform int fractal_iterations : hint_range(3, 12, 1) = 6;

uniform int max_steps : hint_range(24, 112, 1) = 72;
uniform int detail_iterations : hint_range(2, 7, 1) = 5;
uniform float max_distance : hint_range(24.0, 120.0, 1.0) = 72.0;
uniform float safe_radius : hint_range(0.8, 4.0, 0.1) = 1.7;
uniform float corridor_length : hint_range(3.0, 12.0, 0.5) = 6.0;
uniform float corridor_start : hint_range(0.0, 3.0, 0.1) = 1.1;
uniform float corridor_trigger_distance : hint_range(0.5, 6.0, 0.25) = 2.5;
uniform bool reduced_motion = false;
uniform bool survival_mode = false;
uniform vec4 survival_obstacles[8];
uniform float output_max_linear_value = 1.0;
uniform float reference_white = 1.0;
uniform float highlight_intensity = 1.0;
uniform float gamut_intensity = 1.0;
uniform int tone_map_mode = 0;

const float EPSILON = 0.0025;

mat2 rotate_2d(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat2(vec2(c, -s), vec2(s, c));
}

float capsule_sdf(vec3 point, vec3 start, vec3 end, float radius) {
	vec3 pa = point - start;
	vec3 ba = end - start;
	float projection = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * projection) - radius;
}

float fractal_fold(vec3 point) {
	vec3 p = mod(point + 4.0, 8.0) - 4.0;
	float scale = 1.0;
	float angle = reduced_motion ? 0.20 : 0.20 + sin(elapsed_time * 0.08) * 0.08;

	for (int iteration = 0; iteration < 7; iteration++) {
		if (iteration >= detail_iterations) {
			break;
		}
		p = abs(p) - vec3(1.12, 0.96, 1.06);
		p.xy = rotate_2d(angle + float(iteration) * 0.18) * p.xy;
		p.yz = rotate_2d(-0.31 + float(iteration) * 0.11) * p.yz;
		p *= 1.34;
		scale *= 1.34;
	}

	return length(p) / scale - 0.24;
}

float mandelbox_sdf(vec3 point) {
	vec3 p = mod(point + 4.0, 8.0) - 4.0;
	float scale = 1.0;
	float radius = 1.0;
	for (int iteration = 0; iteration < 12; iteration++) {
		if (iteration >= fractal_iterations) { break; }
		p = clamp(p, -1.0, 1.0) * 2.0 - p;
		float r2 = dot(p, p);
		float fold_scale = clamp(max(0.25, 1.0 / max(r2, 0.25)), 0.25, 1.0);
		p *= fold_scale;
		scale *= fold_scale;
		p = p * 1.42 + vec3(0.08, -0.04, 0.03);
		scale *= 1.42;
	}
	return (length(p) - radius) / max(abs(scale), 0.001) * 0.62;
}

float mandelbulb_sdf(vec3 point) {
	// Tile the bounded bulb into navigable flight cells instead of rendering
	// one isolated object followed by an empty ray.
	vec3 tiled_point = mod(point + vec3(4.0), vec3(8.0)) - vec3(4.0);
	vec3 z = tiled_point * 0.72;
	float dr = 1.0;
	float radius = 0.0;
	for (int iteration = 0; iteration < 12; iteration++) {
		if (iteration >= fractal_iterations) { break; }
		radius = length(z);
		if (radius > 2.4) { break; }
		float theta = asin(clamp(z.z / max(radius, 0.001), -1.0, 1.0));
		float phi = atan(z.y, z.x);
		float power = 7.0;
		float zr = pow(max(radius, 0.001), power);
		dr = pow(max(radius, 0.001), power - 1.0) * power * dr + 1.0;
		theta *= power;
		phi *= power;
		z = zr * vec3(cos(theta) * cos(phi), cos(theta) * sin(phi), sin(theta)) + tiled_point * 0.72;
	}
	return 0.5 * log(max(radius, 0.001)) * radius / max(dr, 0.001) - 0.035;
}

float kifs_sdf(vec3 point) {
	vec3 p = (mod(point + vec3(4.0), vec3(8.0)) - vec3(4.0)) * 0.82;
	float scale = 1.0;
	for (int iteration = 0; iteration < 12; iteration++) {
		if (iteration >= fractal_iterations) { break; }
		p = abs(p);
		if (p.x < p.y) { p.xy = p.yx; }
		if (p.x < p.z) { p.xz = p.zx; }
		p = p * 2.0 - vec3(1.12, 1.04, 0.96);
		scale *= 2.0;
	}
	return (length(max(abs(p) - vec3(0.32), vec3(0.0))) + min(max(p.x, max(p.y, p.z)), 0.0)) / scale - 0.035;
}

float menger_sdf(vec3 point) {
	vec3 p = mod(point + 4.0, 8.0) - 4.0;
	float scale = 1.0;
	float distance_value = 1.0;
	for (int iteration = 0; iteration < 12; iteration++) {
		if (iteration >= fractal_iterations) { break; }
		p = abs(p);
		if (p.x < p.y) { p.xy = p.yx; }
		if (p.x < p.z) { p.xz = p.zx; }
		float hole = max(p.x - 1.0, max(p.y - 1.0, p.z - 1.0));
		distance_value = min(distance_value, hole / scale);
		p = p * 3.0 - vec3(2.0);
		scale *= 3.0;
	}
	return distance_value * 0.48;
}

float fractal_sdf(vec3 point) {
	if (fractal_type == 1) { return mandelbox_sdf(point); }
	if (fractal_type == 2) { return mandelbulb_sdf(point); }
	if (fractal_type == 3) { return kifs_sdf(point); }
	if (fractal_type == 4) { return menger_sdf(point); }
	return fractal_fold(point);
}

float gyroid_sdf(vec3 point) {
	float region_wave = sin(point.x * 0.060) * 0.18 + cos(point.z * 0.052) * 0.16;
	return abs(
		sin(point.x * 0.58) * cos(point.y * 0.58)
		+ sin(point.y * 0.58) * cos(point.z * 0.58)
		+ sin(point.z * 0.58) * cos(point.x * 0.58)
	) / 0.58 - (0.44 + region_wave);
}

float survival_world_sdf(vec3 point) {
	float structure = gyroid_sdf(point);
	float obstacle_distance = 10000.0;
	for (int obstacle_index = 0; obstacle_index < 8; obstacle_index++) {
		vec4 obstacle = survival_obstacles[obstacle_index];
		if (obstacle.w > 0.0) {
			float axial_lower_bound = abs(point.z - obstacle.z) - obstacle.w;
			if (axial_lower_bound < obstacle_distance) {
				obstacle_distance = min(
					obstacle_distance,
					length(point - obstacle.xyz) - obstacle.w
				);
			}
		}
	}
	return min(structure, obstacle_distance);
}

float world_sdf_base(vec3 point) {
	float folded = fractal_sdf(point);
	if (fractal_type != 0) {
		return folded;
	}
	return min(gyroid_sdf(point), folded);
}

float world_sdf(vec3 point) {
	if (survival_mode) {
		return survival_world_sdf(point);
	}

	float structure = world_sdf_base(point);
	// Keep the opening local to the player's intended line of travel. The old
	// camera-to-10-unit capsule was always active and made the world look hollow
	// long before the player was close enough to need an opening.
	float forward_clearance = world_sdf_base(camera_position + camera_forward * corridor_start);
	float corridor_activation = 1.0 - smoothstep(
		0.0,
		corridor_trigger_distance,
		max(forward_clearance, 0.0)
	);
	vec3 corridor_start_point = camera_position + camera_forward * corridor_start;
	vec3 corridor_end = camera_position + camera_forward * (corridor_start + corridor_length);
	float corridor = capsule_sdf(
		point,
		corridor_start_point,
		corridor_end,
		safe_radius * 0.72
	);
	float opened_structure = max(structure, -corridor);
	return mix(structure, opened_structure, corridor_activation);
}

vec3 estimate_normal(vec3 point) {
	vec2 e = vec2(EPSILON, -EPSILON);
	return normalize(
		e.xyy * world_sdf(point + e.xyy)
		+ e.yyx * world_sdf(point + e.yyx)
		+ e.yxy * world_sdf(point + e.yxy)
		+ e.xxx * world_sdf(point + e.xxx)
	);
}

vec3 palette(float value, vec3 a, vec3 b, vec3 c, vec3 d) {
	return a + b * cos(2.0 * PI * (c * value + d));
}

vec3 region_color(vec3 point, float travel_distance, vec3 normal) {
	float region = floor((point.z + 64.0) / 64.0);
	float transition = smoothstep(0.15, 0.85, fract((point.z + 64.0) / 64.0));
	float phase_a = region * 0.173;
	float phase_b = (region + 1.0) * 0.173;
	float detail = travel_distance * 0.028 + dot(point, vec3(0.031, 0.047, 0.037));
	vec3 a = palette(detail + phase_a, vec3(0.46), vec3(0.44), vec3(1.0), vec3(0.00, 0.14, 0.31));
	vec3 b = palette(detail + phase_b, vec3(0.46), vec3(0.44), vec3(1.0), vec3(0.48, 0.06, 0.73));
	vec3 base = mix(a, b, transition);
	if (fractal_type == 1) { base *= vec3(0.72, 0.92, 1.18); }
	if (fractal_type == 2) { base *= vec3(1.20, 0.72, 0.88); }
	if (fractal_type == 3) { base *= vec3(0.82, 1.18, 1.02); }
	if (fractal_type == 4) { base *= vec3(1.12, 0.92, 0.62); }
	if (survival_mode) {
		float folded_ridge = exp(-abs(fractal_fold(point)) * 4.5);
		vec3 folded_color = palette(
			detail * 1.7,
			vec3(0.46),
			vec3(0.38),
			vec3(1.0),
			vec3(0.16, 0.42, 0.78)
		);
		base = mix(base, base * 1.18 + folded_color * 0.22, folded_ridge * 0.42);
	}
	vec3 light_direction = normalize(vec3(0.45, 0.75, -0.35));
	float diffuse = 0.25 + 0.75 * max(dot(normal, light_direction), 0.0);
	float rim = pow(1.0 - abs(dot(normal, -camera_forward)), 2.0);
	return base * diffuse + base * rim * 0.45;
}

vec3 apply_gamut(vec3 color) {
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(luminance), color, gamut_intensity);
}

vec3 apply_tone_map(vec3 color) {
	float hdr_headroom = max(output_max_linear_value, 1.0);
	color *= highlight_intensity / max(reference_white, 0.001);
	if (tone_map_mode == 2) {
		return min(color, vec3(hdr_headroom));
	}
	if (tone_map_mode == 1) {
		vec3 x = max(color, vec3(0.0));
		return x / (x + vec3(0.155)) * 1.155;
	}
	return color / (color + vec3(1.0)) * hdr_headroom;
}

void fragment() {
	vec2 pixel = UV * viewport_size;
	vec2 screen = (pixel * 2.0 - viewport_size) / max(viewport_size.y, 1.0);
	float focal_length = 1.15;
	vec3 ray_direction = normalize(
		camera_forward * focal_length
		+ camera_right * screen.x
		- camera_up * screen.y
	);

	float distance_traveled = 0.02;
	float glow_accumulator = 0.0;
	bool hit = false;
	vec3 point = camera_position;

	for (int step_index = 0; step_index < 112; step_index++) {
		if (step_index >= max_steps || distance_traveled >= max_distance) {
			break;
		}
		point = camera_position + ray_direction * distance_traveled;
		float distance_to_surface = world_sdf(point);
		glow_accumulator += exp(-abs(distance_to_surface) * 2.4) * 0.006;
		if (distance_to_surface < EPSILON * max(1.0, distance_traveled * 0.10)) {
			hit = true;
			break;
		}
		distance_traveled += max(distance_to_surface * 0.72, 0.008);
	}

	vec3 background_top = vec3(0.014, 0.008, 0.050);
	vec3 background_bottom = vec3(0.002, 0.003, 0.012);
	vec3 color = mix(background_bottom, background_top, clamp(UV.y, 0.0, 1.0));

	if (hit) {
		vec3 normal = estimate_normal(point);
		color = region_color(point, distance_traveled, normal);
		float fog = 1.0 - exp(-distance_traveled * 0.032);
		color = mix(color, background_top, fog);
	}

	color += vec3(0.08, 0.18, 0.36) * min(glow_accumulator, 1.2) * highlight_intensity;
	color = apply_gamut(color);
	color = apply_tone_map(color);
	color = max(color, vec3(0.0));

	COLOR = vec4(color, 1.0);
}
