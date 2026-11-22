// Papel do mapa da mesa: tom envelhecido, rio, estradas e manchas.
shader_type spatial;
render_mode specular_disabled;
#include "res://shaders/toon_common.gdshaderinc"

void fragment() {
	vec2 uv = UV;
	vec3 col = vec3(0.85, 0.78, 0.6) * (0.85 + 0.25 * fbm(uv * 8.0));
	float river = 1.0 - smoothstep(0.0, 0.025, abs(uv.y - 0.4 - 0.12 * sin(uv.x * 7.0)));
	col = mix(col, vec3(0.45, 0.58, 0.62), river * 0.7);
	float road = 1.0 - smoothstep(0.0, 0.006, abs(uv.y - 0.7 + 0.15 * sin(uv.x * 4.0 + 1.0)));
	road *= step(0.5, fract(uv.x * 30.0));
	col = mix(col, vec3(0.4, 0.32, 0.22), road);
	float hills = smoothstep(0.6, 0.62, fbm(uv * 5.0 + 3.0)) - smoothstep(0.64, 0.66, fbm(uv * 5.0 + 3.0));
	col = mix(col, vec3(0.5, 0.42, 0.3), hills * 0.8);
	col *= 1.0 - 0.35 * smoothstep(0.35, 0.5, length(uv - 0.5));
	ALBEDO = col;
}

void light() {
	toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, DIFFUSE_LIGHT);
}
