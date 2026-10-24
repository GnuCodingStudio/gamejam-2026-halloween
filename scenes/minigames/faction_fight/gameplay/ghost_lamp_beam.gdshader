shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 near_color : source_color = vec4(0.34, 0.96, 1.0, 1.0);
uniform vec4 middle_color : source_color = vec4(0.31, 0.66, 1.0, 1.0);
uniform vec4 end_color : source_color = vec4(0.64, 0.34, 1.0, 1.0);
uniform float beam_length : hint_range(0.1, 20.0) = 8.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.18;
uniform float impulse : hint_range(0.0, 1.0) = 0.0;

varying float beam_progress;

void vertex() {
	beam_progress = clamp(VERTEX.y / beam_length + 0.5, 0.0, 1.0);
}

void fragment() {
	float progress = beam_progress;
	float source_fade = smoothstep(0.0, 0.035, progress);
	float end_fade = 1.0 - smoothstep(0.58, 1.0, progress);
	float soft_contour = smoothstep(0.04, 0.72, abs(dot(normalize(NORMAL), normalize(VIEW))));
	float slow_flow = 0.5 + 0.5 * sin(progress * 18.0 - mod(TIME, 120.0) * 1.15 + UV.x * 7.0);
	float pulse = 0.94 + 0.06 * sin(mod(TIME, 120.0) * 2.1);
	vec3 first_gradient = mix(near_color.rgb, middle_color.rgb, smoothstep(0.0, 0.55, progress));
	vec3 spectral_color = mix(first_gradient, end_color.rgb, smoothstep(0.48, 1.0, progress));
	float source_energy = mix(1.35, 0.62, progress);
	float alpha = base_alpha * source_fade * end_fade * (0.14 + soft_contour * 0.86);
	alpha *= (0.82 + slow_flow * 0.18) * (pulse + impulse * 0.9);

	ALBEDO = spectral_color;
	EMISSION = spectral_color * source_energy * (1.65 + slow_flow * 0.35 + impulse * 1.4);
	ALPHA = alpha;
}
