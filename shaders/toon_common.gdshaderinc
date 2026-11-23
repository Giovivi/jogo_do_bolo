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

// Texturas (ambientCG, CC0) projetadas pelo eixo dominante da normal: as peças
// são caixas alinhadas ao mundo, então cada face recebe a textura de pé.
vec2 box_uv(vec3 p, vec3 n) {
	if (abs(n.y) > 0.6) {
		return p.xz;
	}
	return abs(n.x) > abs(n.z) ? vec2(p.z, -p.y) : vec2(p.x, -p.y);
}

// Normal do mapa (padrão OpenGL) levada para o mundo na mesma projeção.
vec3 box_normal(vec3 nmap, vec3 n, float strength) {
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 1.0, 0.0);
	if (abs(n.y) > 0.6) {
		b = vec3(0.0, 0.0, -1.0);
	} else if (abs(n.x) > abs(n.z)) {
		t = vec3(0.0, 0.0, 1.0);
	}
	vec3 d = nmap * 2.0 - 1.0;
	d.xy *= strength;
	return normalize(t * d.x + b * d.y + n * max(d.z, 0.2));
}

// Cor da textura com contraste reduzido (o cel shading pede manchas largas).
vec3 tex_color(sampler2D tex, vec2 uv, vec3 tint, float contrast) {
	vec3 c = texture(tex, uv).rgb;
	vec3 avg = textureLod(tex, uv, 10.0).rgb;
	return mix(avg, c, contrast) * tint;
}
