// Piso de ladrilho xadrez, rachado, com sujeira e mato entre as peças.
shader_type spatial;
render_mode specular_disabled;
#include "res://shaders/toon_common.gdshaderinc"

uniform vec3 tile_a : source_color = vec3(0.55, 0.52, 0.46);
uniform vec3 tile_b : source_color = vec3(0.32, 0.3, 0.28);
uniform float tile_size = 0.5;
uniform vec3 grass_color : source_color = vec3(0.28, 0.4, 0.2);
uniform float grass_amount = 0.35;
uniform vec3 dirt_color : source_color = vec3(0.22, 0.19, 0.15);
// Textura (opcional): tex_amount > 0 troca o xadrez procedural pela foto.
uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tex_amount = 0.0;
uniform vec2 tex_size = vec2(2.0);
uniform vec3 tex_tint : source_color = vec3(1.0);
uniform float tex_contrast = 0.85;
uniform float normal_strength = 0.6;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz;
	vec2 t = uv / tile_size;
	vec2 id = floor(t);
	vec2 f = fract(t);
	float checker = mod(id.x + id.y, 2.0);
	vec3 col = mix(tile_a, tile_b, checker) * (0.85 + 0.25 * hash21(id));
	float grout = clamp(step(f.x, 0.05) + step(f.y, 0.05), 0.0, 1.0);
	col = mix(col, dirt_color, grout * 0.8);
	if (tex_amount > 0.0) {
		vec2 tuv = uv / tex_size;
		col = mix(col, tex_color(albedo_tex, tuv, tex_tint, tex_contrast), tex_amount);
		vec3 nw = box_normal(texture(normal_tex, tuv).rgb, vec3(0.0, 1.0, 0.0), normal_strength);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	float crack = 1.0 - smoothstep(0.0, 0.025, abs(vnoise(uv * 1.7) - 0.5));
	crack *= step(0.55, fbm(uv * 0.4 + 9.0)) * (1.0 - tex_amount);
	col = mix(col, dirt_color * 0.6, crack);
	float dirt = smoothstep(0.45, 0.75, fbm(uv * 0.3));
	col = mix(col, dirt_color, dirt * 0.55);
	float grass = grass_amount * smoothstep(0.55, 0.7, fbm(uv * 0.5 + 2.0));
	col = mix(col, grass_color * (0.75 + 0.5 * vnoise(uv * 12.0)), clamp(grass, 0.0, 1.0));
	ALBEDO = col;
}

void light() {
	toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, DIFFUSE_LIGHT);
}
