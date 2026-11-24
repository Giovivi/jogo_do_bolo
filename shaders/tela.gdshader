shader_type spatial;
render_mode unshaded, cull_back;
// Tela de monitor da base (fase 1): fundo azul escuro, grade, gráficos que
// correm e um radar. "seed" muda o desenho de cada tela.

uniform float seed = 0.0;
uniform vec3 cor : source_color = vec3(0.35, 0.75, 1.0);
uniform float brilho = 1.6;

float hash(float n) { return fract(sin(n * 91.37 + seed * 17.13) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.6 + seed * 10.0;
	vec3 c = vec3(0.01, 0.03, 0.06) + cor * 0.05 * (1.0 - uv.y);
	// Grade fina.
	vec2 g = abs(fract(uv * vec2(16.0, 9.0)) - 0.5);
	c += cor * 0.05 * step(0.47, max(g.x, g.y));
	int kind = int(mod(seed, 3.0));
	if (kind == 0) {
		// Gráfico de linha que corre.
		float y = 0.5 + 0.18 * sin(uv.x * 9.0 + t * 2.0) + 0.08 * sin(uv.x * 23.0 - t * 3.0 + seed);
		c += cor * smoothstep(0.012, 0.0, abs(uv.y - y)) * 1.2;
		c += cor * 0.12 * step(uv.y, y);
	} else if (kind == 1) {
		// Radar.
		vec2 p = (uv - 0.5) * vec2(16.0 / 9.0, 1.0);
		float r = length(p);
		float a = atan(p.y, p.x);
		float sweep = mod(a - t * 1.5, 6.2832);
		c += cor * smoothstep(0.012, 0.0, abs(fract(r * 4.0) - 0.5) - 0.48) * step(r, 0.45) * 0.5;
		c += cor * exp(-sweep * 2.5) * step(r, 0.45) * 0.8;
		float blip = step(0.985, hash(floor(uv.x * 20.0) + floor(uv.y * 12.0) * 31.0));
		c += vec3(1.0, 0.55, 0.2) * blip * step(r, 0.45) * (0.5 + 0.5 * sin(t * 4.0));
	} else {
		// Barras e linhas de texto.
		float col = floor(uv.x * 12.0);
		float h = 0.15 + 0.7 * fract(hash(col) + 0.15 * sin(t + col));
		c += cor * 0.6 * step(uv.y, h) * step(0.15, fract(uv.x * 12.0)) * step(uv.x, 0.5);
		float row = floor(uv.y * 14.0);
		float len = 0.55 + 0.4 * hash(row + 7.0);
		c += cor * 0.35 * step(0.55, uv.x) * step(uv.x, len) * step(0.35, fract(uv.y * 14.0)) * step(fract(uv.y * 14.0), 0.7);
	}
	// Linhas de varredura e cantos escuros.
	c *= 0.85 + 0.15 * sin(uv.y * 300.0);
	vec2 e = min(uv, 1.0 - uv);
	c *= smoothstep(0.0, 0.04, min(e.x, e.y));
	ALBEDO = c * brilho;
}
