shader_type spatial;
render_mode cull_disabled;

uniform vec4 syrup_color : source_color = vec4(0.72, 0.08, 0.40, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.30, 0.62, 1.0);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.55;

void fragment() {
	float stripe = sin((UV.y - TIME * flow_speed) * 28.0 + sin(UV.x * 11.0));
	float shine = smoothstep(0.60, 0.96, stripe * 0.5 + 0.5);
	ALBEDO = mix(syrup_color.rgb, highlight_color.rgb, shine * 0.38);
	ROUGHNESS = 0.24;
	METALLIC = 0.08;
	EMISSION = highlight_color.rgb * shine * 0.22;
}

