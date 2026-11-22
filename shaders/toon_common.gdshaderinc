// Funções comuns: ruído e luz em faixas (cel shading com sombras em bloco).

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Luz em 3 faixas. Sol: sombra projetada cortada seco.
// Lâmpadas: poça de luz com borda suave e sem luz no lado de trás.
void toon_light(vec3 normal, vec3 light, vec3 light_color, float attenuation, bool directional, inout vec3 diffuse) {
	float ndl = dot(normal, light);
	if (directional) {
		float shadow = smoothstep(0.45, 0.55, attenuation);
		float lit = min(ndl, mix(-1.0, 1.0, shadow));
		float band = lit > 0.3 ? 1.0 : (lit > -0.15 ? 0.55 : 0.28);
		diffuse += light_color / PI * band;
	} else {
		float band = ndl > 0.3 ? 1.0 : (ndl > -0.1 ? 0.5 : 0.0);
		float pool = smoothstep(0.0, 0.5, attenuation);
		pool = pool > 0.66 ? 1.0 : (pool > 0.25 ? 0.6 : pool * 1.2);
		diffuse += light_color / PI * band * pool;
	}
}
