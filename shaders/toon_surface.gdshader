// Superfície com cel shading: cor base, variação por ruído, tábuas opcionais e
// mato/sujeira por altura. Usada em madeira, metal, concreto e folhagem.
shader_type spatial;
render_mode specular_disabled;
#include "res://shaders/toon_common.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.5);
uniform float variation = 0.18;
uniform float noise_scale = 1.5;
// > 0 desenha tábuas (largura em metros) ao longo do eixo X do mundo.
uniform float plank_width = 0.0;
uniform vec3 moss_color : source_color = vec3(0.27, 0.38, 0.2);
uniform float moss_amount = 0.0;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
// Textura (opcional): tex_amount > 0 troca a cor procedural pela foto.
uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tex_amount = 0.0;
// Metros cobertos por uma repetição da textura (largura, altura).
uniform vec2 tex_size = vec2(2.0);
uniform vec3 tex_tint : source_color = vec3(1.0);
uniform float tex_contrast = 0.85;
uniform float normal_strength = 0.6;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = abs(wnorm.y) > 0.6 ? wpos.xz : (abs(wnorm.x) > abs(wnorm.z) ? wpos.zy : wpos.xy);
	float n = fbm(uv * noise_scale);
	vec3 col = base_color * (1.0 - variation + 2.0 * variation * n);
	if (tex_amount > 0.0) {
		vec2 tuv = box_uv(wpos, wnorm) / tex_size;
		col = mix(col, tex_color(albedo_tex, tuv, tex_tint, tex_contrast), tex_amount);
		vec3 nw = box_normal(texture(normal_tex, tuv).rgb, wnorm, normal_strength);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	} else if (plank_width > 0.0) {
		float p = uv.y / plank_width;
		float id = floor(p);
		float edge = smoothstep(0.0, 0.06, fract(p)) * smoothstep(1.0, 0.94, fract(p));
		col *= (0.82 + 0.3 * hash21(vec2(id, 7.0))) * mix(0.55, 1.0, edge);
		col *= 0.9 + 0.2 * vnoise(vec2(uv.x * 0.8, id * 3.0) * 4.0);
	}
	float moss = moss_amount * smoothstep(0.55, 0.7, fbm(uv * 1.1 + 5.0)) * (abs(wnorm.y) > 0.6 ? 1.0 : 1.0 - smoothstep(0.0, 1.2, wpos.y));
	col = mix(col, moss_color * (0.85 + 0.3 * n), clamp(moss, 0.0, 1.0));
	ALBEDO = col;
	EMISSION = emission_color * emission_energy;
}

void light() {
	toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, DIFFUSE_LIGHT);
}
