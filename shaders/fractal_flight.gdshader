shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec3 camera_position = vec3(0.0);
uniform vec3 camera_forward = vec3(0.0, 0.0, -1.0);
uniform vec3 camera_right = vec3(1.0, 0.0, 0.0);
uniform vec3 camera_up = vec3(0.0, 1.0, 0.0);
uniform float elapsed_time = 0.0;

uniform int max_steps : hint_range(24, 112, 1) = 72;
uniform int detail_iterations : hint_range(2, 7, 1) = 5;
uniform float max_distance : hint_range(24.0, 120.0, 1.0) = 72.0;
uniform float safe_radius : hint_range(0.8, 4.0, 0.1) = 1.7;
uniform float corridor_length : hint_range(4.0, 18.0, 0.5) = 10.0;
uniform bool reduced_motion = false;

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

float world_sdf(vec3 point) {
	float region_wave = sin(point.x * 0.060) * 0.18 + cos(point.z * 0.052) * 0.16;
	float gyroid = abs(
		sin(point.x * 0.58) * cos(point.y * 0.58)
		+ sin(point.y * 0.58) * cos(point.z * 0.58)
		+ sin(point.z * 0.58) * cos(point.x * 0.58)
	) / 0.58 - (0.44 + region_wave);
	float folded = fractal_fold(point);
	float structure = min(gyroid, folded);

	vec3 corridor_end = camera_position + camera_forward * corridor_length;
	float corridor = capsule_sdf(
		point,
		camera_position - camera_forward * 0.7,
		corridor_end,
		safe_radius
	);
	return max(structure, -corridor);
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
	vec3 light_direction = normalize(vec3(0.45, 0.75, -0.35));
	float diffuse = 0.25 + 0.75 * max(dot(normal, light_direction), 0.0);
	float rim = pow(1.0 - abs(dot(normal, -camera_forward)), 2.0);
	return base * diffuse + base * rim * 0.45;
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

	float star_noise = fract(sin(dot(floor(pixel * 0.18), vec2(12.9898, 78.233))) * 43758.5453);
	float starfield = pow(star_noise, 32.0);
	color += vec3(0.30, 0.45, 0.90) * starfield * 0.12;
	color += vec3(0.08, 0.18, 0.36) * min(glow_accumulator, 1.2);
	color = color / (color + vec3(1.0));
	color = pow(color, vec3(0.86));

	COLOR = vec4(color, 1.0);
}
