shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform vec4 inner_color : source_color = vec4(0.30, 0.04, 0.72, 1.0);
uniform vec4 outer_color : source_color = vec4(0.86, 0.20, 1.0, 1.0);
uniform float swirl_speed : hint_range(0.0, 3.0) = 0.8;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float radius = length(centered) * 2.0;
	float angle = atan(centered.y, centered.x);
	float spiral = sin(angle * 5.0 - radius * 13.0 + TIME * swirl_speed * 5.0);
	float core = smoothstep(1.0, 0.08, radius);
	float edge = smoothstep(1.0, 0.68, radius);
	vec3 color = mix(inner_color.rgb, outer_color.rgb, spiral * 0.5 + 0.5);
	ALBEDO = color;
	EMISSION = color * (1.6 + core * 1.4);
	ALPHA = edge * (0.82 + spiral * 0.12);
}

