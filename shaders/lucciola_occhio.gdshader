// Lucciola vista da un occhio solo (training 0.3, misura del contrasto fra gli occhi).
// Stesso aspetto delle lucciole del bosco: nucleo pieno fino a 0,62 del raggio e sfumato fino a 1,
// alone lineare fino a HALO volte il raggio. La luce è in spazio lineare (niente source_color):
// il rapporto fra le luci di due lucciole è il rapporto delle luminanze sullo schermo.
// eye: 0 = solo occhio sinistro, 1 = solo destro, -1 = entrambi (desktop). VIEW_INDEX 0 è
// l'occhio sinistro, come nello shader del test (verificato col nonius nel visore).
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled, shadows_disabled;

uniform int eye = -1;
uniform vec3 light = vec3(0.35);
uniform float halo = 3.2;

void fragment() {
	if (eye >= 0 && int(VIEW_INDEX) != eye) {
		discard;
	}
	float r = length(UV - vec2(0.5)) * 2.0 * halo;   // in raggi del nucleo
	float core = r < 0.62 ? 1.0 : clamp((1.0 - r) / 0.38, 0.0, 1.0);
	float glow = clamp(1.0 - r / halo, 0.0, 1.0);
	ALBEDO = light;
	ALPHA = clamp(0.9 * core + 0.3 * glow, 0.0, 1.0);
}
