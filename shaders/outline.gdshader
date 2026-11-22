// Contorno preto de HQ (casco invertido), usado como next_pass.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform float width = 0.03;
uniform vec4 color : source_color = vec4(0.02, 0.02, 0.03, 1.0);

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
