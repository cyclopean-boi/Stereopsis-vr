// Le rovine (training 0.5, mondo 2): il random-dot del test con due rotelle che sfumano.
// Coordinate in "gradi-tangente" (tan(angolo) * 180/pi) con origine al centro del quad.
//
// Il campo è lo stesso di stereo.gdshader 0.5, formato normale: quattro regioni (alto, destra,
// basso, sinistra), una davanti (disparità crociata) e tre dietro, stessa |d|. I punti sono un
// processo di Poisson con composizione additiva, assegnati alle regioni per il CENTRO: l'unione
// dei punti dello sfondo (centri fuori dalle aperture) e delle regioni (centri dentro) è ancora
// Poisson, quindi a un occhio solo le regioni non si vedono. Con le rotelle a zero (le sonde) lo
// stimolo coincide con quello del test: stessi grigi, stessa cornice, stessa croce.
//
// Rotelle:
// - SCAGLIE: un secondo processo di Poisson, rado (1 per grado quadrato) e fatto di macchie
//   chiare dal bordo morbido (raggio 0,2°), costruito come i punti (assegnato per centro, stessa disparità della
//   superficie su cui cade). Sono poche e grandi, quindi si accoppiano fra i due occhi una per
//   una, con la stereopsi locale. Non disegnano la sagoma delle creature e a un occhio solo non
//   dicono niente. scale_c ne regola il contrasto, fino a 0.
// - MOVIMENTO: parallasse di movimento. Con la testa che si sposta di lato, ogni regione scorre
//   in proporzione alla propria profondità (parallax_deg per la regione davanti, l'opposto per
//   quelle dietro, uguale nei due occhi). È un indizio di profondità vero anche a un occhio solo
//   (Rogers e Graham 1979): è un'impalcatura, e sfuma fino a 0.
//
// - MOSAICO (0.5.6): nessuna rotella nello shader. Il mosaico cambia solo i parametri del test
//   (disparità, grana dei punti, grandezza ed eccentricità delle regioni): lo stimolo resta il
//   random-dot del test, con la stessa costruzione e senza indizi a un occhio solo.
// - POLARITÀ (0.5.6): polarity_mode 1 fa tutti i punti scuri, 2 tutti chiari (0 = misti, come
//   il test). Il processo di Poisson è lo stesso: cambia solo il segno dei punti, ovunque uguale.
//
// Fuori dalla cornice del test c'è il portale di pietra, identico nei due occhi (disparità nulla
// rispetto al muro). Dopo la risposta, il riscontro mostra la creatura: un anello e un'incisione
// alla profondità della regione giusta.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, blend_mix, depth_draw_never;

uniform float field_half = 13.0;         // semiampiezza del quad
uniform int mode = 0;                    // 0 muro vuoto con la croce, 1 random-dot
uniform float disparity_deg = 0.0;       // |d| di ciascuna regione rispetto allo sfondo
uniform int target_index = 0;            // 0 alto, 1 destra, 2 basso, 3 sinistra
uniform int seed_bg = 1;
uniform int seed_rg = 2;
uniform int eye_override = -1;           // desktop: 0/1 fisso; VR: -1 = VIEW_INDEX
uniform vec3 fix_color : source_color = vec3(1.0);
uniform vec2 eye_contrast = vec2(1.0);   // contrasto per occhio (sinistro, destro): resta 1 nella fase 1
uniform float rds_ecc = 3.2;
uniform float region_r = 1.4;
uniform float cell = 0.2;
uniform float dot_r = 0.075;
uniform float field_extent = 6.0;
uniform int polarity_mode = 0;           // 0.5.6: 0 punti misti (test), 1 solo scuri, 2 solo chiari
uniform float portal_scale = 1.0;        // 0.5.6: il portale si allarga con il campo del formato grande
// rotelle
uniform float scale_c = 0.0;             // contrasto delle scaglie, 0-1
uniform float scale_cell = 1.0;          // cella del processo delle scaglie (1 scaglia per cella in media)
uniform float scale_r = 0.2;             // raggio della scaglia (gradi), con bordo morbido di ±SCALE_SOFT
uniform int seed_sc = 3;
uniform float parallax_deg = 0.0;
// riscontro
uniform int reveal_index = -1;           // regione da mostrare (la creatura davanti)
uniform int wrong_index = -1;            // regione scelta per sbaglio
uniform float reveal_t = 0.0;            // 0-1: intensità dell'animazione
uniform vec3 reveal_color : source_color = vec3(1.0, 0.8, 0.45);
uniform sampler2D creature_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool show_creature = false;
// aspetto
uniform vec3 tint = vec3(1.0);           // tinta calda della pietra, a luminanza 1 (Rec. 709)
uniform float time_s = 0.0;

const float DOTS_PER_CELL = 1.0;
const int MAX_DOTS = 8;
const float DOT_WHITE = 0.6;
const float DOT_BLACK = 0.214;
const float FRAME_W = 0.08;
const float GREY = 0.2140;
const float SCALE_AMP = 0.8;             // luce additiva di una scaglia a contrasto 1 (luce lineare)
const float SCALE_SOFT = 0.07;
const float PORTAL_W = 10.4;             // semilarghezza del portale
const float PORTAL_B = 10.2;             // base del portale, sotto il centro
const float PORTAL_T = 7.4;              // imposta dell'arco
const float PORTAL_AY = 0.5;             // arco ribassato

uint pcg(uint v) {
	uint s = v * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	return (w >> 22u) ^ w;
}

uint hash_cell(ivec2 c, int seed) {
	return pcg(uint(c.x + 8192) + pcg(uint(c.y + 8192) + pcg(uint(seed))));
}

float u01(uint h) {
	return (float(h >> 8u) + 0.5) / 16777216.0;
}

int poisson_count(float u) {
	float p = exp(-DOTS_PER_CELL);
	float cdf = p;
	int k = 0;
	while (u > cdf && k < MAX_DOTS) {
		k += 1;
		p *= DOTS_PER_CELL / float(k);
		cdf += p;
	}
	return k;
}

float edge(float signed_inside, float px) {
	return clamp(signed_inside / px + 0.5, 0.0, 1.0);
}

vec2 rds_pos(int k) {
	if (k == 0) return vec2(0.0, rds_ecc);
	if (k == 1) return vec2(rds_ecc, 0.0);
	if (k == 2) return vec2(0.0, -rds_ecc);
	return vec2(-rds_ecc, 0.0);
}

float half_shift(int eye, float sign_) {
	float h = 0.5 * disparity_deg * sign_;
	return eye == 0 ? h : -h;  // crociata: l'occhio sinistro la vede spostata a destra
}

// Regione k: tessitura e apertura si spostano insieme (come nel test). Alla disparità si somma
// la parallasse, uguale nei due occhi e di segno opposto per davanti e dietro.
void region_geometry(int k, int eye, out vec2 aperture, out vec2 texture_shift) {
	float s = k == target_index ? 1.0 : -1.0;
	texture_shift = vec2(half_shift(eye, s) + s * parallax_deg, 0.0);
	aperture = rds_pos(k) + texture_shift;
}

bool keep_center(vec2 center_eye, int selector, int eye) {
	if (selector < 0) {
		for (int k = 0; k < 4; k++) {
			vec2 ap;
			vec2 ts;
			region_geometry(k, eye, ap, ts);
			if (length(center_eye - ap) < region_r) {
				return false;
			}
		}
		return true;
	}
	vec2 ap;
	vec2 ts;
	region_geometry(selector, eye, ap, ts);
	return length(center_eye - ap) < region_r;
}

// Punti del test (stereo.gdshader 0.5), invariati.
float dots(vec2 q, vec2 to_eye, int seed, int selector, int eye, float px) {
	float acc = 0.0;
	ivec2 base = ivec2(floor(q / cell));
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 c = base + ivec2(i, j);
			uint h = hash_cell(c, seed);
			int n = poisson_count(u01(h));
			for (int m = 0; m < MAX_DOTS; m++) {
				if (m >= n) {
					break;
				}
				uint hx = pcg(h + uint(3 * m + 1));
				uint hy = pcg(h + uint(3 * m + 2));
				uint hp = pcg(h + uint(3 * m + 3));
				vec2 center = (vec2(c) + vec2(u01(hx), u01(hy))) * cell;
				vec2 center_eye = center + to_eye;
				if (abs(center_eye.x) > field_extent || abs(center_eye.y) > field_extent) {
					continue;
				}
				if (keep_center(center_eye, selector, eye)) {
					bool white = polarity_mode == 0 ? (hp & 1u) == 1u : polarity_mode == 2;
					float pol = white ? DOT_WHITE : -DOT_BLACK;
					acc += pol * edge(dot_r - length(q - center), px);
				}
			}
		}
	}
	return acc;
}

// Scaglie: stesso schema, cella più grande e dischi chiari dal bordo morbido.
float scales(vec2 q, vec2 to_eye, int seed, int selector, int eye) {
	float acc = 0.0;
	ivec2 base = ivec2(floor(q / scale_cell));
	float cut = scale_r + SCALE_SOFT;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 c = base + ivec2(i, j);
			uint h = hash_cell(c, seed);
			int n = poisson_count(u01(h));
			for (int m = 0; m < MAX_DOTS; m++) {
				if (m >= n) {
					break;
				}
				uint hx = pcg(h + uint(3 * m + 1));
				uint hy = pcg(h + uint(3 * m + 2));
				vec2 center = (vec2(c) + vec2(u01(hx), u01(hy))) * scale_cell;
				float d = length(q - center);
				if (d > cut) {
					continue;
				}
				vec2 center_eye = center + to_eye;
				if (abs(center_eye.x) > field_extent || abs(center_eye.y) > field_extent) {
					continue;
				}
				if (keep_center(center_eye, selector, eye)) {
					acc += smoothstep(scale_r + SCALE_SOFT, scale_r - SCALE_SOFT, d);
				}
			}
		}
	}
	return acc;
}

float cross_cov(vec2 p, float px) {
	vec2 a = abs(p);
	float h = min(edge(0.035 - a.y, px), edge(0.25 - a.x, px));
	float v = min(edge(0.035 - a.x, px), edge(0.25 - a.y, px));
	return max(h, v);
}

// Rumore di valore per la pietra (identico nei due occhi).
float vnoise(vec2 p, int seed) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = u01(hash_cell(ivec2(i), seed));
	float b = u01(hash_cell(ivec2(i) + ivec2(1, 0), seed));
	float c = u01(hash_cell(ivec2(i) + ivec2(0, 1), seed));
	float d = u01(hash_cell(ivec2(i) + ivec2(1, 1), seed));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Distanza con segno dal bordo del portale (positiva dentro).
float portal_sd(vec2 p) {
	float side = PORTAL_W - abs(p.x);
	float bottom = p.y + PORTAL_B;
	float top = p.y <= PORTAL_T ? 1e3 : (PORTAL_W - length(vec2(p.x, (p.y - PORTAL_T) / PORTAL_AY))) * PORTAL_AY;
	return min(min(side, bottom), top);
}

vec3 stone(vec2 p, float px, float sd) {
	float row_h = 1.25;
	float r = floor(p.y / row_h);
	float bw = 2.2;
	float off = mod(r, 2.0) * 1.1;
	float c = floor((p.x + off) / bw);
	vec2 local = vec2((p.x + off) - c * bw, p.y - r * row_h);
	float jd = min(min(local.x, bw - local.x), min(local.y, row_h - local.y));
	float base = 0.045 + 0.05 * u01(hash_cell(ivec2(int(c), int(r)), 911));
	float n = 0.55 * vnoise(p * 2.3, 17) + 0.3 * vnoise(p * 6.1, 29) + 0.15 * vnoise(p * 14.0, 41);
	float joint = smoothstep(0.03, 0.13, jd);
	float bevel = smoothstep(0.0, 0.22, row_h - local.y) * (1.0 - smoothstep(0.22, 0.4, row_h - local.y));
	float lum = base * (0.65 + 0.7 * n) * mix(0.3, 1.0, joint) + 0.012 * bevel * joint;
	vec3 col = lum * vec3(1.0, 0.93, 0.82);
	// muschio luminoso, più fitto in basso e sui giunti
	float moss_zone = clamp((-p.y + 2.0) / 12.0, 0.0, 1.0) * 0.8 + (1.0 - joint) * 0.4;
	float moss = smoothstep(0.72, 0.9, vnoise(p * 4.0, 53) * 0.7 + vnoise(p * 11.0, 67) * 0.3) * moss_zone;
	float pulse = 0.85 + 0.15 * sin(time_s * 0.7 + p.x * 0.9 + p.y * 0.4);
	col += vec3(0.01, 0.05, 0.04) * moss * pulse;
	// ombra verso il bordo esterno
	col *= mix(0.45, 1.0, smoothstep(0.0, 1.6, sd));
	return col;
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0 * field_half;
	float px = max(length(fwidth(p)) * 0.70710678, 1e-5);
	int eye = eye_override >= 0 ? eye_override : int(VIEW_INDEX);

	float lum = GREY;
	if (mode == 1) {
		float acc = dots(p, vec2(0.0), seed_bg, -1, eye, px);
		for (int k = 0; k < 4; k++) {
			vec2 ap;
			vec2 ts;
			region_geometry(k, eye, ap, ts);
			if (length(p - rds_pos(k)) < region_r + abs(ts.x) + dot_r + 0.1) {
				acc += dots(p - ts, ts, seed_rg + 7919 * k, k, eye, px);
			}
		}
		if (scale_c > 0.0) {
			float sc = scales(p, vec2(0.0), seed_sc, -1, eye);
			for (int k = 0; k < 4; k++) {
				vec2 ap;
				vec2 ts;
				region_geometry(k, eye, ap, ts);
				if (length(p - rds_pos(k)) < region_r + abs(ts.x) + scale_r + SCALE_SOFT + 0.1) {
					sc += scales(p - ts, ts, seed_sc + 104729 + 7919 * k, k, eye);
				}
			}
			acc += scale_c * SCALE_AMP * sc;
		}
		float kc = eye == 0 ? eye_contrast.x : eye_contrast.y;
		lum = clamp(GREY + kc * acc, 0.0, 1.0);
	}
	float fd = max(abs(p.x), abs(p.y));
	float frame = field_extent + 0.3;
	lum = mix(lum, 0.0, edge(FRAME_W * 0.5 - abs(fd - frame), px));
	float r0 = length(p);
	lum = mix(lum, GREY, edge(0.4 - r0, px));
	vec3 col = vec3(lum) * tint;
	col = mix(col, fix_color, cross_cov(p, px));

	// riscontro: anello e incisione alla profondità della regione
	if (mode == 1 && reveal_t > 0.0) {
		if (wrong_index >= 0) {
			vec2 ap;
			vec2 ts;
			region_geometry(wrong_index, eye, ap, ts);
			float d = length(p - ap);
			col += vec3(0.25, 0.3, 0.45) * exp(-pow((d - region_r) / 0.06, 2.0)) * reveal_t;
		}
		if (reveal_index >= 0) {
			vec2 ap;
			vec2 ts;
			region_geometry(reveal_index, eye, ap, ts);
			float d = length(p - ap);
			col += reveal_color * exp(-pow((d - region_r) / 0.07, 2.0)) * reveal_t;
			if (show_creature && d < region_r) {
				vec2 uv = vec2(p.x - ap.x, ap.y - p.y) / (2.0 * region_r * 0.86) + 0.5;
				vec4 cr = texture(creature_tex, uv);
				col = mix(col, col * 0.55, cr.a * reveal_t * 0.6);
				col += reveal_color * cr.a * reveal_t * 0.75;
			}
		}
	}

	// portale di pietra oltre la cornice del test
	float alpha = 1.0;
	if (fd > frame + FRAME_W * 0.5 + 0.08) {
		float sd = portal_sd(p / portal_scale) * portal_scale;
		alpha = edge(sd, px);
		float inner = edge(fd - (frame + FRAME_W * 0.5 + 0.12), px);
		col = mix(col, stone(p, px, sd), inner);
	}
	ALBEDO = col;
	ALPHA = alpha;
}
