// Parede de tijolo com reboco descascado, sujeira no pé e hera.
shader_type spatial;
render_mode specular_disabled;
#include "res://shaders/toon_common.gdshaderinc"

uniform vec3 brick_color : source_color = vec3(0.56, 0.4, 0.31);
uniform vec3 mortar_color : source_color = vec3(0.33, 0.32, 0.3);
uniform vec3 plaster_color : source_color = vec3(0.66, 0.64, 0.58);
uniform float plaster_amount = 0.5;
uniform vec3 moss_color : source_color = vec3(0.3, 0.42, 0.2);
uniform float moss_amount = 0.6;
uniform vec3 top_color : source_color = vec3(0.13, 0.14, 0.15);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (wnorm.y > 0.6) {
		ALBEDO = top_color * (0.85 + 0.3 * fbm(wpos.xz * 2.0));
	} else {
		vec2 uv = abs(wnorm.x) > abs(wnorm.z) ? wpos.zy : wpos.xy;
		vec2 b = uv * vec2(4.0, 8.0);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		vec2 f = fract(b);
		vec2 id = floor(b);
		float mortar = clamp(step(f.x, 0.07) + step(f.y, 0.12), 0.0, 1.0);
		vec3 col = mix(brick_color * (0.75 + 0.45 * hash21(id)), mortar_color, mortar);
		float n = fbm(uv * 0.55);
		float plaster = smoothstep(1.0 - plaster_amount - 0.02, 1.0 - plaster_amount + 0.02, n);
		col = mix(col, plaster_color * (0.88 + 0.24 * fbm(uv * 3.0)), plaster);
		col *= mix(0.55, 1.0, smoothstep(0.0, 1.6, wpos.y));
		float streak = smoothstep(0.62, 0.8, vnoise(vec2(uv.x * 3.0, uv.y * 0.15)));
		col *= 1.0 - 0.25 * streak;
		float ivy = moss_amount * smoothstep(0.58, 0.72, fbm(uv * 0.9 + 3.7)) * (0.6 + 0.4 * smoothstep(3.0, 0.0, wpos.y));
		col = mix(col, moss_color * (0.75 + 0.5 * vnoise(uv * 9.0)), clamp(ivy, 0.0, 1.0));
		ALBEDO = col;
	}
}

void light() {
	toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, DIFFUSE_LIGHT);
}
