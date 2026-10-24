// Stimoli per la stereoacuità, generati per occhio (0.5).
// Coordinate in "gradi-tangente" (tan(angolo) * 180/pi) con origine al centro del quad:
// per angoli di pochi gradi coincidono con i gradi visivi entro lo 0,3%.
//
// Compito di ordinamento in profondità: tutte le regioni hanno la stessa disparità
// orizzontale |d|; il bersaglio è crociato (davanti), le altre non crociate (dietro).
// Sdoppiamento e lustro hanno la stessa grandezza e la stessa direzione ovunque:
// cambia solo il segno, cioè l'ordine in profondità.
//
// Random-dot: i punti sono un processo di Poisson (numero di punti per cella di Poisson,
// posizioni uniformi), invariante per traslazione: spostare una regione non lascia traccia
// nella statistica monoculare. I punti si sommano in modo additivo (bianchi +0,6, neri -0,214
// in luce lineare: contrasto pieno sul grigio), così l'ordine dei punti sovrapposti non conta.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform float field_half = 7.035;       // semiampiezza del quad
uniform int mode = 0;                    // 0 vuoto, 1 random-dot, 2 anelli, 3 controllo degli occhi
uniform float disparity_deg = 0.0;       // |d|: disparità di ciascuna regione rispetto allo sfondo
uniform int target_index = 0;            // random-dot: 0 alto, 1 destra, 2 basso, 3 sinistra; anelli: 0 alto, 1 basso
uniform int seed_bg = 1;
uniform int seed_rg = 2;
uniform vec2 ring_jitter[2];             // spostamento comune ai due occhi degli anelli (alto, basso)
uniform int eye_override = -1;           // desktop: 0/1 fisso; VR: -1 = VIEW_INDEX
uniform int mono_source = -1;            // controllo: entrambi gli occhi vedono l'immagine di quest'occhio
uniform bool show_nonius = false;
uniform vec3 fix_color : source_color = vec3(1.0);
uniform float progress = -1.0;           // barra di avanzamento 0-1; negativa = nascosta
uniform vec2 eye_contrast = vec2(1.0);   // contrasto degli stimoli per occhio (sinistro, destro); 1 = pieno
// Geometria del random-dot (0.5): formato normale 3,2 / 1,4 / 0,2 / 0,075 / 6,0; formato grande
// (dischi e punti doppi, bordo interno a 3,2° dal centro) 6,0 / 2,8 / 0,4 / 0,15 / 9,6.
// Scalare insieme cella e punto conserva la copertura e la natura di Poisson del campo.
uniform float rds_ecc = 3.2;             // eccentricità dei centri delle regioni
uniform float region_r = 1.4;            // raggio delle regioni
uniform float cell = 0.2;                // cella del processo di Poisson (1 punto per cella in media)
uniform float dot_r = 0.075;             // raggio dei punti
uniform float field_extent = 6.0;        // semilato del campo di punti; la cornice sta 0,3° fuori

const float ECC_RINGS = 3.6;
const float DOTS_PER_CELL = 1.0;  // intensità del processo di Poisson (punti per cella)
const int MAX_DOTS = 8;           // P(più di 8 | 1) ~ 1e-6
const float DOT_WHITE = 0.6;      // contributo additivo di un punto bianco (luce lineare)
const float DOT_BLACK = 0.214;    // contributo sottrattivo di un punto nero: da grigio a nero
const float FRAME_W = 0.08;
const float RING_R = 1.1;
const float RING_W = 0.12;
const float GREY = 0.2140;        // 0,5 sRGB in luce lineare

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
	// copertura antialiasata con rampa di 1 pixel: conserva la posizione sub-pixel
	return clamp(signed_inside / px + 0.5, 0.0, 1.0);
}

vec2 rds_pos(int k) {
	if (k == 0) return vec2(0.0, rds_ecc);
	if (k == 1) return vec2(rds_ecc, 0.0);
	if (k == 2) return vec2(0.0, -rds_ecc);
	return vec2(-rds_ecc, 0.0);
}

// Spostamento orizzontale, per quest'occhio, di una superficie a disparità crociata (+1) o non crociata (-1).
float half_shift(int eye, float sign_) {
	float h = 0.5 * disparity_deg * sign_;
	return eye == 0 ? h : -h;  // crociata: l'occhio sinistro la vede spostata a destra
}

// Regione k del random-dot: un disco la cui tessitura e il cui contorno si spostano insieme,
// davanti (disparità crociata) per il bersaglio, dietro (non crociata) per le altre. La costruzione
// è la stessa per tutte (come negli stereogrammi di Julesz): ogni regione ha tutta la tessitura
// accoppiabile alla propria disparità. Con finestre fisse per le regioni dietro, a disparità grandi
// la tessitura visibile nei due occhi non si sovrappone più, e le regioni dietro diventerebbero
// più rivali del bersaglio: un indizio binoculare che non richiede la profondità.
void region_geometry(int k, int eye, out vec2 aperture, out vec2 texture_shift) {
	texture_shift = vec2(half_shift(eye, k == target_index ? 1.0 : -1.0), 0.0);
	aperture = rds_pos(k) + texture_shift;
}

// Somma i punti di un campo di Poisson attorno a q (riferimento della tessitura; to_eye porta
// nel riferimento dell'occhio). selector: -1 = sfondo, nascosto dentro qualunque apertura;
// k >= 0 = regione k, solo dentro la propria apertura. Decide sul centro del punto.
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
				bool keep = true;
				if (selector < 0) {
					for (int k = 0; k < 4; k++) {
						vec2 ap;
						vec2 ts;
						region_geometry(k, eye, ap, ts);
						if (length(center_eye - ap) < region_r) {
							keep = false;
						}
					}
				} else {
					vec2 ap;
					vec2 ts;
					region_geometry(selector, eye, ap, ts);
					keep = length(center_eye - ap) < region_r;
				}
				if (keep) {
					float pol = ((hp & 1u) == 1u) ? DOT_WHITE : -DOT_BLACK;
					acc += pol * edge(dot_r - length(q - center), px);
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

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0 * field_half;
	float px = max(length(fwidth(p)) * 0.70710678, 1e-5);
	int eye = eye_override >= 0 ? eye_override : int(VIEW_INDEX);
	if (mono_source >= 0) {
		eye = mono_source;
	}

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
		float kc = eye == 0 ? eye_contrast.x : eye_contrast.y;
		lum = clamp(GREY + kc * acc, 0.0, 1.0);
	} else if (mode == 2) {
		for (int k = 0; k < 2; k++) {
			float y = k == 0 ? ECC_RINGS : -ECC_RINGS;
			float s = half_shift(eye, k == target_index ? 1.0 : -1.0);
			vec2 c = vec2(0.0, y) + ring_jitter[k] + vec2(s, 0.0);
			float kc = eye == 0 ? eye_contrast.x : eye_contrast.y;
			lum = mix(lum, GREY * (1.0 - kc), edge(RING_W * 0.5 - abs(length(p - c) - RING_R), px));
		}
	}
	float fd = max(abs(p.x), abs(p.y));
	float frame = field_extent + 0.3;
	lum = mix(lum, 0.0, edge(FRAME_W * 0.5 - abs(fd - frame), px));

	float r0 = length(p);
	vec3 col = vec3(mix(lum, GREY, edge(0.4 - r0, px)));
	if (mode == 3) {
		// dicottico, senza sovrapposizione: cerchio rosso solo all'occhio sinistro (a sinistra),
		// quadrato verde solo al destro (a destra).
		if (eye == 0) {
			col = mix(col, vec3(0.75, 0.04, 0.03), edge(1.0 - length(p - vec2(-2.4, 0.0)), px));
		} else {
			vec2 a = abs(p - vec2(2.4, 0.0));
			col = mix(col, vec3(0.03, 0.55, 0.08), min(edge(0.88 - a.x, px), edge(0.88 - a.y, px)));
		}
	}
	if (show_nonius) {
		// lineette nonius: sopra solo nell'occhio sinistro, sotto solo nel destro. Nella 0.5 sono
		// larghe 0,14° (~2 pixel di render a 224″) e lunghe 0,5°: nella 0.4 erano larghe 0,06°,
		// circa un pixel, e un occhio con meno acuità o contrasto poteva non vederle (review, N7).
		float side = eye == 0 ? 1.0 : -1.0;
		float line = min(edge(0.07 - abs(p.x), px), edge(0.25 - abs(p.y * side - 0.45), px));
		float centre = edge(0.06 - r0, px);
		col = mix(col, fix_color, max(line, centre));
	} else {
		col = mix(col, fix_color, cross_cov(p, px));
	}
	if (progress >= 0.0) {
		// barra di avanzamento sotto la cornice, identica nei due occhi
		float bar = min(edge(6.0 - abs(p.x), px), edge(0.09 - abs(p.y + frame + 0.4), px));
		float filled = edge(-6.0 + 12.0 * progress - p.x, px);
		col = mix(col, vec3(mix(0.06, 0.55, filled)), bar);
	}
	ALBEDO = col;
}
