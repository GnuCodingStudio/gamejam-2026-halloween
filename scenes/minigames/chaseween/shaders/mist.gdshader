shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 mist_color : source_color = vec4(0.34, 0.25, 0.48, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float oval = length(p * vec2(1.0, 1.35));
	float drift = sin(p.x * 8.0 + TIME * 0.45) * 0.025;
	float edge = 1.0 - smoothstep(0.25, 0.95, oval + drift);
	ALBEDO = mist_color.rgb;
	ALPHA = edge * 0.13;
}
