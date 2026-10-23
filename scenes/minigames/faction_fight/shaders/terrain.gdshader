shader_type spatial;

uniform vec4 earth_color : source_color = vec4(0.27, 0.20, 0.32, 1.0);
uniform vec4 fleck_color : source_color = vec4(0.50, 0.39, 0.52, 1.0);
uniform float pattern_scale : hint_range(0.2, 4.0) = 1.0;
uniform float detail_strength : hint_range(0.0, 0.5) = 0.16;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float cell_noise(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float south = mix(cell_noise(cell), cell_noise(cell + vec2(1.0, 0.0)), blend.x);
	float north = mix(cell_noise(cell + vec2(0.0, 1.0)), cell_noise(cell + vec2(1.0, 1.0)), blend.x);
	return mix(south, north, blend.y);
}

void fragment() {
	vec2 p = world_position.xz * pattern_scale;
	float broad = sin(p.x * 0.48 + sin(p.y * 0.23)) * sin(p.y * 0.37);
	float grain = smooth_noise(p * 1.8);
	float seams = smoothstep(0.96, 0.995, sin(p.x * 1.35 + sin(p.y * 0.55) * 0.6));
	float variation = broad * detail_strength + (grain - 0.5) * detail_strength * 0.7;
	ALBEDO = earth_color.rgb * (1.0 + variation) + fleck_color.rgb * seams * detail_strength * 0.16;
	ROUGHNESS = 0.91;
}
