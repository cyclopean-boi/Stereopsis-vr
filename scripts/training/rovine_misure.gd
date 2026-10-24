extends RefCounted
## Misure delle rovine (training 0.5.1–0.5.6, protocolli r2–r4): gradini dei sentieri, conteggio delle
## sonde, storia ricalcolata dai CSV validati e restauro.
## 0.5.6 (protocollo r4, 5/10): il sentiero del VENTO esce dalla rotazione e al suo posto c'è il
## sentiero del MOSAICO: una scala di 10 gradini che parte dal random-dot nel formato grande a 3981″
## (lo stimolo della verifica del 4/10, 29/40) e arriva alla pietra nuda (formato normale, 1000″).
## Ogni gradino gira UNA sola manopola, a turno: disparità, grana dei punti (punti e celle
## insieme), grandezza ed eccentricità delle regioni. Dove la scala si ferma dice quale manopola
## costa di più. Una prova del mosaico su quattro è una prova di POLARITÀ al gradino corrente, fuori
## dalla scala: punti solo scuri o solo chiari, per verificare un'impressione del 4/10
## (i punti neri sembravano più facili). I file r2 e r3 restano leggibili.
## Le prove si dividono in modo netto:
## - SONDE: random-dot puro, identico al test (nessuna rotella), 1 prova su 5. È il vero
##   bersaglio: si contano giuste su risposte. Dalla 0.5.1 il bersaglio di OGNI prova è estratto
##   a caso, indipendente dalle prove precedenti (review RV1: con i sacchetti di 4 della r1 il
##   riscontro rendeva prevedibile il bersaglio, 52% senza guardare lo stimolo). Così, senza
##   informazione nello stimolo, P(giusta | tutta la storia) = 1/4 esattamente, qualunque strategia;
## - SENTIERI: prove con una rotella (scaglie o vento) che sfuma con una scala 3/1. Dicono fin dove
##   serve l'aiuto, non se c'è stereopsi globale. Le prove dei sentieri che arrivano al gradino puro
##   si contano a parte e non entrano mai nelle sonde.
## Restauro (review RV2, RV3):
## - pezzi dei sentieri: un gradino raggiunto in due sessioni CONSECUTIVE con esito informativo
##   (punto del ponte interno sotto il limite, oppure "al puro"). Sono tappe dell'aiuto, non prove
##   di stereopsi globale;
## - portale e torre: regola sequenziale valida anche guardando dopo ogni sessione, per sempre
##   (e-process per scommessa, vedi e_process). Rischio complessivo di falso restauro <= ALPHA.
##   La finestra delle ultime 100 sonde resta solo una descrizione dell'andamento recente.
## 0.5.13 (19/10, protocollo r5): il mosaico prosegue OLTRE la pietra nuda. Il 15, 16 e 19/10 la scala
## stava al gradino 9 (la pietra nuda, 22/29 e 26/31 nelle prove del sentiero arrivate lì) e le sonde
## all'83%: la scala era al soffitto. Dodici gradini nuovi, tutti nel formato del test, girano solo la
## disparità: da 1000″ a 251″ in passi di 0,05 in log10 (−11% a gradino), cioè sulla stessa griglia della
## Psi del test (10^(1 + 0,05 k)). Sonde, gradini 0–9 e polarità identici: la r4 resta valida e le sonde si
## sommano. Quattro pezzi nuovi, l'OSSERVATORIO, sui gradini 11, 13, 15 e 17 (794, 631, 501 e 398″).

const Stats := preload("res://scripts/stats.gd")
const Ponte := preload("res://scripts/training/ponte.gd")

const PROTOCOL := "r5"
## Protocolli leggibili: la r2 ha sonde e scaglie identiche alla r3 e restano valide; solo il vento
## della r2 (saturazione a 1 cm e soglia sul movimento della testa) è escluso dal suo sentiero. La r4
## ha sonde e scaglie identiche alla r3, e il mosaico al posto del vento. La r5 ha lo stesso schema
## della r4 e il mosaico più lungo: 22 gradini invece di 10 (i primi 10 identici).
const ACCEPTED := ["r2", "r3", "r4", "r5"]
const SCHEMA_MOSAICO := ["r4", "r5"]                         # protocolli con le colonne del mosaico
const VERSION_PREFIX := "training-0.5"
const SCALE_LEVELS := [1.0, 0.63, 0.4, 0.25, 0.16, 0.1, 0.063, 0.04, 0.025, 0.0]   # contrasto delle scaglie
const MOVE_LEVELS := [0.8, 0.5, 0.32, 0.2, 0.13, 0.08, 0.05, 0.032, 0.02, 0.0]     # vento: spostamento massimo (gradi)
## Mosaico: il valore di un gradino è il numero di passi che mancano alla pietra nuda (negativo oltre
## la pietra nuda, dalla r5). La r4 si ferma alla pietra nuda (10 gradini), la r5 prosegue fino a 251″.
const MOSAIC_LEVELS_R4 := [9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0]
const MOSAIC_LEVELS := [9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0,
	-1.0, -2.0, -3.0, -4.0, -5.0, -6.0, -7.0, -8.0, -9.0, -10.0, -11.0, -12.0]
const PIETRA_NUDA := 9                                       # indice del gradino identico alla sonda
## Gradini del mosaico: log10 della disparità, grana (punti e celle, 1 = test normale, 2 = formato
## grande) e t delle regioni (0 = formato grande: raggio 2,8°, centro a 6°; 1 = normale: 1,4° a 3,2°).
## Ogni gradino gira una sola manopola, a turno: disparità, grana, regioni. Dal gradino 10 (r5) solo la
## disparità, a passi di 0,05 in log10: 891, 794, 708, 631, 562, 501, 447, 398, 355, 316, 282, 251″.
const MOSAIC_STEPS := [
	[3.6, 2.0, 0.0], [3.4, 2.0, 0.0], [3.4, 1.5874, 0.0], [3.4, 1.5874, 0.3333],
	[3.2, 1.5874, 0.3333], [3.2, 1.2599, 0.3333], [3.2, 1.2599, 0.6667],
	[3.0, 1.2599, 0.6667], [3.0, 1.0, 0.6667], [3.0, 1.0, 1.0],
	[2.95, 1.0, 1.0], [2.9, 1.0, 1.0], [2.85, 1.0, 1.0], [2.8, 1.0, 1.0], [2.75, 1.0, 1.0], [2.7, 1.0, 1.0],
	[2.65, 1.0, 1.0], [2.6, 1.0, 1.0], [2.55, 1.0, 1.0], [2.5, 1.0, 1.0], [2.45, 1.0, 1.0], [2.4, 1.0, 1.0]]
const MOSAIC_KNOBS := ["", "disparità", "grana", "regioni", "disparità", "grana", "regioni", "disparità", "grana", "regioni",
	"disparità", "disparità", "disparità", "disparità", "disparità", "disparità",
	"disparità", "disparità", "disparità", "disparità", "disparità", "disparità"]
const GEOMETRY_NORMAL := {"rds_ecc": 3.2, "region_r": 1.4, "cell": 0.2, "dot_r": 0.075, "field_extent": 6.0}   # formato normale del test
const GEOMETRY_LARGE := {"rds_ecc": 6.0, "region_r": 2.8, "cell": 0.4, "dot_r": 0.15, "field_extent": 9.6}    # formato grande del test
const PROBE_ARCSEC := 1000.0
const CHANCE := 0.25
const OVERHEAD_S := 2.4          # croce 0,5 + riscontro 1,6 + intervallo 0,3 s, oltre al tempo di risposta
const NIGHT_MIN := 10.0
const SESSIONS_NEEDED := 2
const PROBE_WINDOW := 100
const ALPHA := 0.01              # rischio complessivo di falso restauro per portale e torre
const BET_PRIOR := 20.0          # pseudo-prove al valore nullo nella stima della puntata
const NAMES := ["alto", "destra", "basso", "sinistra"]
const KINDS := ["sonda", "scaglie", "movimento", "mosaico", "polarita"]
const KINDS_R3 := ["sonda", "scaglie", "movimento"]          # r2 e r3
const KINDS_R4 := ["sonda", "scaglie", "mosaico", "polarita"]
const PATHS := ["scaglie", "movimento", "mosaico"]           # sentieri con una scala
const POLARITIES := ["misti", "scuri", "chiari"]             # punti bianchi e neri (come il test), solo scuri, solo chiari
const OUTCOMES := ["risposta", "timeout", "pausa"]
## r4 (0.5.6): lo schema della 0.5.4 più tre colonne del mosaico. disparity_arcsec ora varia nel
## mosaico (nelle sonde e nelle scaglie resta 1000).
const HEADER := ["session", "participant", "version", "protocol", "mode", "trial", "night", "kind",
	"level_index", "scale_c", "parallax_amp_deg", "disparity_arcsec", "target", "response", "correct",
	"outcome", "rt_s", "seed_bg", "seed_rg", "seed_sc", "sway_max_mm", "parallax_max_deg", "cue_ok",
	"head_rot_deg", "ipd_m", "px_arcsec", "dir", "reversal", "level_after", "creature", "hand", "sicuro",
	"head_roll_deg", "head_roll_resp_deg", "head_pitch_deg", "grain", "region_t", "polarity"]
const MOSAIC_COLS := ["grain", "region_t", "polarity"]
## r3 dalla 0.5.4 (con la postura della testa).
const HEADER_054 := ["session", "participant", "version", "protocol", "mode", "trial", "night", "kind",
	"level_index", "scale_c", "parallax_amp_deg", "disparity_arcsec", "target", "response", "correct",
	"outcome", "rt_s", "seed_bg", "seed_rg", "seed_sc", "sway_max_mm", "parallax_max_deg", "cue_ok",
	"head_rot_deg", "ipd_m", "px_arcsec", "dir", "reversal", "level_after", "creature", "hand", "sicuro",
	"head_roll_deg", "head_roll_resp_deg", "head_pitch_deg"]
## Schemi precedenti del protocollo r3, ancora validi: 0.5.3 (senza la postura della testa)
## e 0.5.2 (senza neanche "sicuro").
const HEADER_053 := ["session", "participant", "version", "protocol", "mode", "trial", "night", "kind",
	"level_index", "scale_c", "parallax_amp_deg", "disparity_arcsec", "target", "response", "correct",
	"outcome", "rt_s", "seed_bg", "seed_rg", "seed_sc", "sway_max_mm", "parallax_max_deg", "cue_ok",
	"head_rot_deg", "ipd_m", "px_arcsec", "dir", "reversal", "level_after", "creature", "hand", "sicuro"]
const HEADER_052 := ["session", "participant", "version", "protocol", "mode", "trial", "night", "kind",
	"level_index", "scale_c", "parallax_amp_deg", "disparity_arcsec", "target", "response", "correct",
	"outcome", "rt_s", "seed_bg", "seed_rg", "seed_sc", "sway_max_mm", "parallax_max_deg", "cue_ok",
	"head_rot_deg", "ipd_m", "px_arcsec", "dir", "reversal", "level_after", "creature", "hand"]
const POSE_COLS := ["head_roll_deg", "head_roll_resp_deg", "head_pitch_deg"]
## Dalla 0.5.4 (stesso protocollo r3) ci sono tre colonne di postura della testa: rollio alla comparsa
## e alla risposta (positivo = testa inclinata verso la spalla destra) e beccheggio alla comparsa
## (positivo = verso l'alto). Sono annotazioni: non entrano in scale, sonde né restauro.
## Dalla 0.5.3 (stesso protocollo r3) c'è la colonna "sicuro": 1 se nella prova il grilletto è stato
## premuto prima della risposta o insieme, cioè "questa l'ho vista davvero". È un'annotazione: non
## cambia stimoli, scale né regole di restauro. I file della 0.5.2 (senza la colonna) restano validi.

## 0.5.10 (12/10): le scaglie escono dal blocco (scelta di progetto). I tre pezzi delle scaglie restano
## raggiungibili con la loro regola di prima (nei file che hanno scaglie) OPPURE con il mosaico ("alt"):
## la scala al gradino 4 o oltre, l'arco al 7, l'affresco all'8. La fontana resta al 6.
const PEZZI := [
	{"id": "scala", "nome": "The Well Stairs", "tipo": "scaglie", "limite": 0.4, "alt": {"tipo": "mosaico", "limite": 5.0},
		"storia": "The help fades, and still you find the creatures. Under the moss a stone stairway comes back to light: it leads down to the well."},
	{"id": "pozzo", "nome": "The Well of the Wind", "tipo": "movimento", "limite": 0.2,
		"storia": "The wind rising from the well stirs the creatures when you move your head. Now a breath is all you need: the wellhead stands once more."},
	{"id": "arco", "nome": "The Arch of Two Eyes", "tipo": "scaglie", "limite": 0.16, "alt": {"tipo": "mosaico", "limite": 2.0},
		"storia": "Two pillars and a keystone: the arch holds only if they push together. The Keeper called it the arch of two eyes."},
	{"id": "lanterne", "nome": "The Cloister Lanterns", "tipo": "movimento", "limite": 0.08,
		"storia": "In the cloister the lanterns light up again, one after another. The creatures barely move now, and you find them all the same."},
	{"id": "affresco", "nome": "The Creature Fresco", "tipo": "scaglie", "limite": 0.063, "alt": {"tipo": "mosaico", "limite": 1.0},
		"storia": "A fresco of carvings comes back to light on the wall: deer, snakes, birds. They are the creatures you found among the tiniest tiles."},
	# 0.5.6: il vento esce dalla rotazione (pozzo e lanterne erano già restaurati); la fontana passa al mosaico
	{"id": "fontana", "nome": "The Fountain", "tipo": "mosaico", "limite": 3.0,
		"storia": "Water flows in the fountain again, and on its floor a mosaic of tiny tiles pieces itself together. The creatures no longer need to make themselves big: you find them among the fine tiles, near the center."},
	{"id": "portale", "nome": "The Portal", "tipo": "sonde_caso", "p0": 0.25,
		"storia": "The portal opens. In the bare stone, with no scales and no wind, the creatures let you find them more often than chance: two eyes together have seen what one alone cannot."},
	{"id": "torre", "nome": "The Moon Tower", "tipo": "sonde_meta", "p0": 0.5,
		"storia": "The Moon Tower lights up. In the bare stone you find the creatures more than one time in two. The Keeper used to say that from up there you can see the whole forest."},
	# 0.5.13 (r5): l'osservatorio, oltre la pietra nuda. Quattro pezzi sul sentiero del mosaico, ai gradini
	# 11, 13, 15 e 17 (794, 631, 501 e 398″), con la regola degli altri: due sessioni di fila. Un pezzo più
	# difficile non arriva prima di uno più facile (una sessione sotto 631″ è anche sotto 794″).
	{"id": "basamento", "nome": "The Observatory Base", "tipo": "mosaico", "limite": -2.0, "gruppo": "osservatorio",
		"storia": "Beyond the bare stone, under the brambles, a round base comes back to light, its stones cut with a precision found nowhere else in the Ruins. The Keeper called it the observatory: from there the stars were measured."},
	{"id": "tamburo", "nome": "The Observatory Drum", "tipo": "mosaico", "limite": -4.0, "gruppo": "osservatorio",
		"storia": "The drum stands again, with its narrow slits. Each one frames a single star, and the stars do not all lie at the same distance."},
	{"id": "cupola", "nome": "The Observatory Dome", "tipo": "mosaico", "limite": -6.0, "gruppo": "osservatorio",
		"storia": "The dome closes over the drum once more, and its slit opens to the sky. The creatures now hide at depths you once could not have told apart."},
	{"id": "cannocchiale", "nome": "The Telescope", "tipo": "mosaico", "limite": -8.0, "gruppo": "osservatorio",
		"storia": "The telescope returns to the slit in the dome. Near stars and far stars no longer sit on the same flat sheet: the sky has depth again."},
]


## Gradini di un sentiero. Il mosaico ha 10 gradini nella r4 e 22 dalla r5 (i primi 10 identici).
static func levels_for(kind: String, protocol := PROTOCOL) -> Array:
	if kind == "scaglie":
		return SCALE_LEVELS
	if kind in ["mosaico", "polarita"]:
		return MOSAIC_LEVELS if protocol == "r5" else MOSAIC_LEVELS_R4
	return MOVE_LEVELS


## Ultimo gradino del mosaico (21 dalla r5).
static func last_rung() -> int:
	return MOSAIC_STEPS.size() - 1


## Disparità del mosaico a un indice frazionario dalla pietra nuda in poi (interpolata in log10); 0 prima
## della pietra nuda, dove i gradini girano anche grana e regioni.
static func rung_arcsec(fi: float) -> float:
	if fi < PIETRA_NUDA - 1e-9:
		return 0.0
	var f := clampf(fi, 0.0, float(last_rung()))
	var i := mini(int(floor(f)), last_rung() - 1)
	var t := f - i
	return pow(10.0, lerpf(float(MOSAIC_STEPS[i][0]), float(MOSAIC_STEPS[i + 1][0]), t))


## Un gradino del mosaico: disparità, grana, t delle regioni e la geometria per lo shader.
## Gli estremi usano le geometrie del test esatte (formato grande e normale), senza arrotondamenti.
static func mosaic_rung(i: int) -> Dictionary:
	var st: Array = MOSAIC_STEPS[clampi(i, 0, MOSAIC_STEPS.size() - 1)]
	var lg: float = st[0]
	var grain: float = st[1]
	var t: float = st[2]
	var g := {}
	if t <= 0.0:
		g = GEOMETRY_LARGE.duplicate()
	elif t >= 1.0:
		g = GEOMETRY_NORMAL.duplicate()
	else:
		for key in ["rds_ecc", "region_r", "field_extent"]:
			g[key] = lerpf(float(GEOMETRY_LARGE[key]), float(GEOMETRY_NORMAL[key]), t)
	if grain >= 2.0:
		g["cell"] = GEOMETRY_LARGE["cell"]
		g["dot_r"] = GEOMETRY_LARGE["dot_r"]
	elif grain <= 1.0:
		g["cell"] = GEOMETRY_NORMAL["cell"]
		g["dot_r"] = GEOMETRY_NORMAL["dot_r"]
	else:                      # punti e celle insieme: stessa copertura, punti più grandi e più radi
		g["cell"] = float(GEOMETRY_NORMAL["cell"]) * grain
		g["dot_r"] = float(GEOMETRY_NORMAL["dot_r"]) * grain
	g["disparity_arcsec"] = PROBE_ARCSEC if lg == 3.0 else pow(10.0, lg)
	g["grain"] = grain
	g["region_t"] = t
	return g


## Geometria di una prova: sonde e scaglie nel formato normale a 1000″ (come il test); mosaico e
## polarità al loro gradino.
static func trial_geometry(kind: String, li: int) -> Dictionary:
	if kind in ["mosaico", "polarita"]:
		return mosaic_rung(li)
	var g := GEOMETRY_NORMAL.duplicate()
	g["disparity_arcsec"] = PROBE_ARCSEC
	g["grain"] = 1.0
	g["region_t"] = 1.0
	return g


static func _deg_it(v: float) -> String:
	return "%.1f" % v


## Descrizione di un gradino del mosaico (indice 0–9).
## Descrizione di un gradino del mosaico (indice 0–21). Dalla 0.5.13 i gradini sono 21 (prima 9).
static func fmt_rung(i: int) -> String:
	if i == PIETRA_NUDA:
		return "bare stone (1000″, dots and creatures as in the test)"
	var g := mosaic_rung(i)
	if i > PIETRA_NUDA:
		return "bare stone at %d″ (step %d of %d)" % [roundi(float(g["disparity_arcsec"])), i, last_rung()]
	return "step %d of %d: %d″, dots ×%s, creatures at %s°" % [i, last_rung(), roundi(float(g["disparity_arcsec"])),
		("%.2f" % float(g["grain"])).rstrip("0").rstrip("."), _deg_it(float(g["rds_ecc"]))]


static func _num(v: float) -> String:
	return ("%.3f" % v).rstrip("0").rstrip(".")


static func fmt_level(kind: String, v: float) -> String:
	if kind in ["mosaico", "polarita"]:
		return fmt_rung(roundi(9.0 - v))          # 0.5.13: oltre la pietra nuda il valore è negativo
	if v <= 0.0:
		return "pure random-dot"
	if kind == "scaglie":
		return "scales at %s%%" % (_num(v * 100.0) if v < 0.1 else str(roundi(v * 100.0)))
	return "wind %s°" % _num(v)


static func fmt_path(kind: String, e: Dictionary) -> String:
	match e.get("esito", "insufficiente"):
		"interno":
			if kind == "mosaico":
				var fi := float(e["indice"])
				var arc := rung_arcsec(fi)
				return "~step %s of %d%s (%d reversals)" % [_num(snappedf(fi, 0.1)), last_rung(),
					(", bare stone at ~%d″" % roundi(arc)) if arc > 0.0 else "", int(e["inversioni"])]
			return "~%s (%d reversals)" % [fmt_level(kind, float(e["valore"])), int(e["inversioni"])]
		"al_puro":
			if kind == "mosaico":
				return "stopped at the last step, %s: %d right out of %d" % [fmt_rung(roundi(float(e["indice"]))), int(e["puro"][0]), int(e["puro"][1])]
			return "at pure random-dot: %d right out of %d on the step with no help" % [int(e["puro"][0]), int(e["puro"][1])]
		"al_pieno":
			var k := int(e["pieno"][0])
			var n := int(e["pieno"][1])
			var p := Stats.binom_upper(k, n, CHANCE)
			return "with full help %d of %d: %s, but under the 80%% needed to move down a step" % [k, n,
				"above chance (p = %s)" % ("%.3f" % p) if p < 0.05 else "at chance"]
	return "point not yet stable (%d reversals)" % int(e.get("inversioni", 0))


static func hint(piece: Dictionary) -> String:
	match piece["tipo"]:
		"scaglie":
			if piece.has("alt"):
				return "Rises again when, in two sessions in a row, the mosaic path settles at step %d or beyond (or reaches the bare stone). The scales path also counts, at %s contrast or less." % [
					roundi(9.0 - float(piece["alt"]["limite"])), ("%s%%" % _num(piece["limite"] * 100.0)) if piece["limite"] < 0.1 else "%d%%" % roundi(piece["limite"] * 100.0)]
			return "Rises again when, in two sessions in a row, the scales path settles at %s contrast or less (or reaches the bare stone)." % (("%s%%" % _num(piece["limite"] * 100.0)) if piece["limite"] < 0.1 else "%d%%" % roundi(piece["limite"] * 100.0))
		"movimento":
			return "Rises again when, in two sessions in a row, the wind path settles at %s° of drift or less (or reaches the bare stone). The wind path is no longer in the rotation." % _num(piece["limite"])
		"mosaico":
			var li := roundi(9.0 - float(piece["limite"]))
			if li > PIETRA_NUDA:
				return "Rises again when, in two sessions in a row, the mosaic path settles beyond the bare stone, at %d″ or less (step %d of %d or beyond)." % [
					roundi(float(mosaic_rung(li)["disparity_arcsec"])), li, last_rung()]
			return "Rises again when, in two sessions in a row, the mosaic path settles at step %d or beyond (or reaches the bare stone)." % li
		"sonde_caso":
			return "Opens when the probes in the bare stone, taken all together and read continuously, give enough evidence of being above chance: 100-to-1 evidence, with under 1% risk of a false restoration, however often you look."
		"sonde_meta":
			return "Lights up when the probes give enough evidence of being right more than one time in two: 100-to-1 evidence, the same check as the portal."
	return ""


## Giuste su risposte, con intervallo esatto al 95% e p unilaterale contro il caso.
## Descrittivo: valido per un campione fissato, non per decisioni ripetute (vedi e_process).
static func probes(k: int, n: int) -> Dictionary:
	if n <= 0:
		return {"k": 0, "n": 0, "quota": 0.0, "ic": [0.0, 1.0], "p_caso": 1.0}
	var lo := Stats.beta_quantile(float(k), float(n - k + 1), 0.025) if k > 0 else 0.0
	var hi := Stats.beta_quantile(float(k + 1), float(n - k), 0.975) if k < n else 1.0
	return {"k": k, "n": n, "quota": float(k) / n, "ic": [lo, hi], "p_caso": Stats.binom_upper(k, n, CHANCE)}


static func fmt_probes(s: Dictionary) -> String:
	if int(s.get("n", 0)) == 0:
		return "no probes"
	return "%d of %d (%d%%, interval %d–%d%%; chance 25%%)" % [s["k"], s["n"], roundi(100.0 * s["quota"]),
		roundi(100.0 * s["ic"][0]), roundi(100.0 * s["ic"][1])]


## Prove segnate "viste davvero" (grilletto) contro le altre, per tipo: solo descrittivo. Serve a
## vedere se le prove in cui il giocatore sente di vedere vanno meglio delle altre; l'analisi vera
## (per posizione, con le preferenze di risposta) si fa sui CSV.
static func fmt_seen(seen: Dictionary, kind: String) -> String:
	var a: Array = seen[kind]
	return "%d/%d marked, %d/%d unmarked" % [a[0][0], a[0][1], a[1][0], a[1][1]]


static func all_seen(history: Array) -> Dictionary:
	var out := {"con_segno": false, "sessioni": 0}
	for kd in KINDS:
		out[kd] = [[0, 0], [0, 0]]
	for s in history:
		if not s.get("con_segno", false):
			continue
		out["con_segno"] = true
		out["sessioni"] = int(out["sessioni"]) + 1
		for kd in KINDS:
			for j in 2:
				for q in 2:
					out[kd][j][q] += int(s["viste"][kd][j][q])
	return out


# ---------------------------------------------------------------- regola sequenziale (RV2)

static func _lae(a: float, b: float) -> float:
	if a == -INF:
		return b
	if b == -INF:
		return a
	var m := maxf(a, b)
	return m + log(exp(a - m) + exp(b - m))


## E-process per scommessa contro H0: P(giusta | passato) <= p0, su tutte le sonde delle
## sessioni valide, in ordine. Per ogni sonda un fattore f = 1 + lambda (X - p0), con lambda
## scelto SOLO dalle sonde precedenti (metà della puntata di Kelly per la quota delle ultime 100,
## ristretta verso p0 con BET_PRIOR pseudo-prove, fra 0 e lmax). Sotto H0 ogni fattore ha valore
## atteso <= 1. Il processo è una miscela di scommesse che cominciano all'inizio di ciascuna
## sessione k, con peso 1/(k(k+1)) (le componenti non ancora cominciate valgono 1): una
## supermartingala non negativa che parte da 1. Disuguaglianza di Ville: la probabilità che
## superi 1/ALPHA, in qualunque momento e per sempre, è al più ALPHA. La miscela lascia vedere
## anche un miglioramento tardivo. Calibrazione: verifica/training-0.5.1/restauro_sequenziale.py.
static func e_process(history: Array, p0: float) -> Dictionary:
	var lmax := 2.0 if p0 < 0.4 else 1.0
	var var0 := p0 * (1.0 - p0)
	var log_l := 0.0
	var log_s := -INF
	var log_e := 0.0
	var best := 0.0
	var win: Array = []
	var k_win := 0.0
	var k := 0
	var n := 0
	for s in history:
		if not s.get("valida", true):
			continue
		k += 1
		log_s = _lae(log_s, log(1.0 / (k * (k + 1))) - log_l)
		var log_tail := log(1.0 / (k + 1))
		for x in s["sonde_seq"]:
			var p_hat := (k_win + BET_PRIOR * p0) / (win.size() + BET_PRIOR)
			var lam := clampf(0.5 * (p_hat - p0) / var0, 0.0, lmax)
			var xv := 1.0 if x else 0.0
			log_l += log(1.0 + lam * (xv - p0))
			win.append(xv)
			k_win += xv
			if win.size() > PROBE_WINDOW:
				k_win -= float(win.pop_front())
			log_e = _lae(log_l + log_s, log_tail)
			best = maxf(best, log_e)
			n += 1
	return {"e": exp(log_e), "log_e": log_e, "max_e": exp(best), "superato": best >= log(1.0 / ALPHA), "sonde": n, "p0": p0}


# ---------------------------------------------------------------- storia dai CSV

static func active_seconds(rows: Array) -> float:
	var s := 0.0
	for r in rows:
		if r.get("outcome", "") in ["risposta", "timeout"]:
			s += str(r.get("rt_s", "0")).to_float() + OVERHEAD_S
	return s


static func _median(v: Array) -> float:
	if v.is_empty():
		return NAN
	var a := v.duplicate()
	a.sort()
	var n := a.size()
	return float(a[n / 2]) if n % 2 == 1 else 0.5 * (float(a[n / 2 - 1]) + float(a[n / 2]))


## Riassunto di una sessione dalle sue righe (stessa funzione per il gioco e per il diario).
static func summarize(rows: Array) -> Dictionary:
	# 0.5.13: i gradini del mosaico dipendono dal protocollo del file (10 nella r4, 22 dalla r5)
	var proto := str(rows[0].get("protocol", PROTOCOL)) if not rows.is_empty() else PROTOCOL
	var probe_seq := []
	var probe_resp := {"alto": 0, "destra": 0, "basso": 0, "sinistra": 0}
	var revs := {}
	var pure := {}
	var easy := {}
	var paths := {}
	for kd in PATHS:
		revs[kd] = []
		pure[kd] = [0, 0]
		easy[kd] = [0, 0]
		paths[kd] = [0, 0]
	var timeouts := {}
	for kd in KINDS:
		timeouts[kd] = 0
	var by_pos := {}                 # tipo -> posizione del bersaglio -> [giuste, risposte]
	for kd in KINDS:
		by_pos[kd] = {}
		for nm in NAMES:
			by_pos[kd][nm] = [0, 0]
	var seen := {}                   # tipo -> [[giuste, risposte] segnate "viste", [giuste, risposte] non segnate]
	for kd in KINDS:
		seen[kd] = [[0, 0], [0, 0]]
	var polar := {"scuri": [0, 0], "chiari": [0, 0], "per_gradino": {}}   # 0.5.6: prove di polarità
	var mosaic_max := -1             # gradino più alto raggiunto dal mosaico in una prova con risposta
	var bare := {}                   # 0.5.13: prove del mosaico dalla pietra nuda in su, per gradino: [giuste, risposte]
	var path_max := {}               # 0.5.9: gradino più alto raggiunto in ciascun sentiero (per il grafico)
	for kd in PATHS:
		path_max[kd] = -1
	var marked := false
	var still := 0
	var sway := []
	var nights := {}
	for r in rows:
		var n := maxi(1, str(r.get("night", "1")).to_int())
		if not nights.has(n):
			nights[n] = []
		nights[n].append(r)
		var kind: String = r.get("kind", "")
		if r.get("outcome", "") == "timeout" and timeouts.has(kind):
			timeouts[kind] += 1
		if r.get("outcome", "") != "risposta":
			continue
		var ok: bool = str(r.get("correct", "0")) == "1"
		var tg: String = r.get("target", "")
		var mv_out: bool = kind == "movimento" and (r.get("protocol", PROTOCOL) not in ["r3"] or str(r.get("cue_ok", "1")) != "1")
		if by_pos.has(kind) and by_pos[kind].has(tg) and not mv_out:
			by_pos[kind][tg][1] += 1
			by_pos[kind][tg][0] += 1 if ok else 0
		var sv := str(r.get("sicuro", ""))
		if seen.has(kind) and sv in ["0", "1"] and not mv_out:
			marked = true
			var j := 0 if sv == "1" else 1
			seen[kind][j][1] += 1
			seen[kind][j][0] += 1 if ok else 0
		if kind == "sonda":
			probe_seq.append(ok)
			var resp: String = r.get("response", "")
			if probe_resp.has(resp):
				probe_resp[resp] += 1
		elif kind == "polarita":
			var pol := str(r.get("polarity", ""))
			if polar.has(pol):
				polar[pol][1] += 1
				polar[pol][0] += 1 if ok else 0
				var gk := str(r.get("level_index", ""))
				if not polar["per_gradino"].has(gk):
					polar["per_gradino"][gk] = {"scuri": [0, 0], "chiari": [0, 0]}
				polar["per_gradino"][gk][pol][1] += 1
				polar["per_gradino"][gk][pol][0] += 1 if ok else 0
		elif kind in PATHS:
			if kind == "movimento":
				if r.get("protocol", PROTOCOL) != "r3":
					continue            # vento della r2: calibrazione diversa, fuori dal sentiero
				sway.append(str(r.get("sway_max_mm", "0")).to_float())
				if str(r.get("cue_ok", "1")) != "1":
					still += 1
					continue            # vento non arrivato: fuori dalla scala e dalla stima (RV4)
			paths[kind][1] += 1
			paths[kind][0] += 1 if ok else 0
			var li := str(r.get("level_index", "0")).to_int()
			if kind == "mosaico":
				mosaic_max = maxi(mosaic_max, li)
				if li >= PIETRA_NUDA:
					var bk := str(li)
					if not bare.has(bk):
						bare[bk] = [0, 0]
					bare[bk][1] += 1
					bare[bk][0] += 1 if ok else 0
			path_max[kind] = maxi(int(path_max[kind]), li)
			if str(r.get("reversal", "0")) == "1":
				revs[kind].append(li)
			if li == levels_for(kind, proto).size() - 1:
				pure[kind][1] += 1
				pure[kind][0] += 1 if ok else 0
			elif li == 0:
				easy[kind][1] += 1
				easy[kind][0] += 1 if ok else 0
	var k := 0
	for b in probe_seq:
		k += 1 if b else 0
	var minutes := active_seconds(rows) / 60.0
	var complete := 0
	for n in nights:
		if active_seconds(nights[n]) / 60.0 >= NIGHT_MIN:
			complete += 1
	var out := {"sonde": probes(k, probe_seq.size()), "sonde_seq": probe_seq, "risposte_sonde": probe_resp,
		"puro": pure, "sentieri": paths, "scadute": timeouts, "vento_fermo": still, "per_posizione": by_pos,
		"viste": seen, "con_segno": marked, "polarita": polar, "mosaico_max": mosaic_max, "gradino_max": path_max,
		"pietra_mosaico": bare, "oscillazione_mm": _median(sway), "minuti": minutes, "notti": nights.size(), "notti_complete": complete}
	for kd in PATHS:
		out[kd] = Ponte.estimate_from(levels_for(kd, proto), revs[kd], pure[kd], easy[kd])
	return out


## 0.5.13: prove del mosaico dalla pietra nuda in su, per disparità ("1000″ 22/29, 891″ 10/12"). Non sono sonde.
static func fmt_bare(bare: Dictionary) -> String:
	var keys := []
	for k in bare:
		keys.append(int(k))
	keys.sort()
	var parts := []
	for k in keys:
		var kn: Array = bare[str(k)]
		parts.append("%d″ %d/%d" % [roundi(float(mosaic_rung(k)["disparity_arcsec"])), int(kn[0]), int(kn[1])])
	return ", ".join(parts)


## Prove di polarità in una storia: scuri e chiari, in tutto e per gradino (solo descrittivo; il
## confronto vero, a parità di gradino, si fa sui CSV).
static func all_polarity(history: Array) -> Dictionary:
	var out := {"scuri": [0, 0], "chiari": [0, 0], "sessioni": 0}
	for s in history:
		var pz: Dictionary = s.get("polarita", {})
		var any := false
		for pol in ["scuri", "chiari"]:
			var kn: Array = pz.get(pol, [0, 0])
			out[pol][0] += int(kn[0])
			out[pol][1] += int(kn[1])
			any = any or int(kn[1]) > 0
		out["sessioni"] += 1 if any else 0
	return out


static func fmt_polarity(pz: Dictionary) -> String:
	return "dark dots %d/%d, light %d/%d" % [int(pz["scuri"][0]), int(pz["scuri"][1]), int(pz["chiari"][0]), int(pz["chiari"][1])]


static func _close(a: float, b: float) -> bool:
	return absf(a - b) <= 0.0015


## Motivi di esclusione come si mostrano nel diario. validate() resta com'è (i test e il confronto con
## "nessuna prova" lo leggono): la traduzione si fa solo sul testo mostrato, in quest'ordine.
const REASONS_EN := [
	["schema diverso da quello della ", "schema differs from that of "],
	["(protocollo r1 o file estraneo)", "(protocol r1 or a foreign file)"],
	["schema e protocollo non corrispondono", "schema and protocol do not match"],
	["diverso dalla prima riga", "differs from the first row"],
	["tipo di prova sconosciuto", "unknown trial kind"],
	["esito sconosciuto", "unknown outcome"],
	["notte non valida", "invalid night"],
	["bersaglio non valido", "invalid target"],
	["numero non valido", "invalid number"],
	["una sonda con un aiuto o un gradino", "a probe with an aid or a step"],
	["gradino mancante", "missing step"],
	["gradino fuori scala", "step out of range"],
	["contrasto delle scaglie diverso dal gradino", "scale contrast differs from the step"],
	["vento diverso dal gradino", "wind differs from the step"],
	["mosaico con scaglie o vento", "mosaic with scales or wind"],
	["scala non leggibile", "staircase not readable"],
	["una prova di polarità ha mosso la scala", "a polarity trial moved the staircase"],
	["risposta non valida", "invalid response"],
	["\"correct\" non coerente con bersaglio e risposta", "\"correct\" inconsistent with target and response"],
	["segno \"vista davvero\" non valido", "invalid \"really seen\" mark"],
	["postura della testa non valida", "invalid head pose"],
	["polarità diversa dai punti misti fuori dalle prove di polarità", "non-mixed dots outside the polarity trials"],
	["una prova di polarità con i punti misti", "a polarity trial with mixed dots"],
	["polarità non valida", "invalid polarity"],
	["disparità diversa dal gradino", "disparity differs from the step"],
	["grana o regioni diverse dal gradino", "grain or regions differ from the step"],
	[" non valido", " invalid"],
	["protocollo ", "protocol "],
	["versione ", "version "],
	["riga ", "row "],
]


static func reason_en(why: String) -> String:
	var out := why
	for p in REASONS_EN:
		out = out.replace(str(p[0]), str(p[1]))
	return out


## Controlla un file intero (review RV5). Restituisce "" se valido, altrimenti il motivo.
## Schemi: r4 (0.5.6, con le colonne del mosaico) solo col protocollo r4; 0.5.4, 0.5.3 e 0.5.2 solo
## con r2 e r3.
## r4 e r5 (0.5.13) hanno lo stesso schema; la r5 ha il mosaico più lungo.
static func validate(header: PackedStringArray, rows: Array) -> String:
	var h := Array(header)
	var is_r4 := h == HEADER                      # schema col mosaico (r4 o r5)
	var has_pose := is_r4 or h == HEADER_054
	var has_sure := has_pose or h == HEADER_053
	if not has_sure and h != HEADER_052:     # 0.5.2: senza "sicuro"
		return "schema diverso da quello della %s (protocollo r1 o file estraneo)" % PROTOCOL
	if rows.is_empty():
		return "nessuna prova"
	var first: Dictionary = rows[0]
	for i in rows.size():
		var r: Dictionary = rows[i]
		var at := "riga %d: " % (i + 2)
		if r["protocol"] not in ACCEPTED or r["protocol"] != first["protocol"]:
			return at + "protocollo %s" % r["protocol"]
		if is_r4 != (r["protocol"] in SCHEMA_MOSAICO):
			return at + "schema e protocollo non corrispondono (%s)" % r["protocol"]
		for key in ["session", "participant", "mode", "version"]:
			if r[key] != first[key]:
				return at + "%s diverso dalla prima riga" % key
		if not str(r["version"]).begins_with(VERSION_PREFIX):
			return at + "versione %s" % r["version"]
		if r["kind"] not in (KINDS_R4 if is_r4 else KINDS_R3):
			return at + "tipo di prova sconosciuto"
		if r["outcome"] not in OUTCOMES:
			return at + "esito sconosciuto"
		if not str(r["night"]).is_valid_int() or str(r["night"]).to_int() < 1:
			return at + "notte non valida"
		if r["target"] not in NAMES:
			return at + "bersaglio non valido"
		if not str(r["rt_s"]).is_valid_float() or not str(r["scale_c"]).is_valid_float() or not str(r["parallax_amp_deg"]).is_valid_float():
			return at + "numero non valido"
		var sc := str(r["scale_c"]).to_float()
		var pa := str(r["parallax_amp_deg"]).to_float()
		if r["kind"] == "sonda":
			if sc != 0.0 or pa != 0.0 or str(r["level_index"]) != "" or str(r["cue_ok"]) != "1":
				return at + "una sonda con un aiuto o un gradino"
		else:
			if not str(r["level_index"]).is_valid_int():
				return at + "gradino mancante"
			var li := str(r["level_index"]).to_int()
			var lv := levels_for(r["kind"], str(r["protocol"]))
			if li < 0 or li >= lv.size():
				return at + "gradino fuori scala"
			var expected := float(lv[li])
			if r["kind"] == "scaglie" and (not _close(sc, expected) or pa != 0.0):
				return at + "contrasto delle scaglie diverso dal gradino"
			if r["kind"] == "movimento" and (not _close(pa, expected) or sc != 0.0):
				return at + "vento diverso dal gradino"
			if r["kind"] in ["mosaico", "polarita"] and (sc != 0.0 or pa != 0.0):
				return at + "mosaico con scaglie o vento"
			if str(r["reversal"]) not in ["0", "1"] or str(r["dir"]) not in ["-1", "0", "1"]:
				return at + "scala non leggibile"
			if r["kind"] == "polarita" and (str(r["dir"]) != "0" or str(r["reversal"]) != "0" or str(r["level_after"]) != str(li)):
				return at + "una prova di polarità ha mosso la scala"
		if is_r4:
			var why := _mosaic_problem(r)
			if why != "":
				return at + why
		if r["outcome"] == "risposta":
			if r["response"] not in NAMES:
				return at + "risposta non valida"
			var should := "1" if r["response"] == r["target"] else "0"
			if str(r["correct"]) != should:
				return at + "\"correct\" non coerente con bersaglio e risposta"
		if has_sure and str(r.get("sicuro", "")) not in (["0", "1"] if r["outcome"] == "risposta" else ["", "0"]):
			return at + "segno \"vista davvero\" non valido"
		if has_pose:
			for key in POSE_COLS:
				var v := str(r.get(key, ""))
				if v != "" and (not v.is_valid_float() or absf(v.to_float()) > 90.0):
					return at + "postura della testa non valida (%s)" % key
	return ""


## r4: disparità, grana, regioni e polarità coerenti col tipo di prova e col gradino.
static func _mosaic_problem(r: Dictionary) -> String:
	for key in ["disparity_arcsec", "grain", "region_t"]:
		if not str(r.get(key, "")).is_valid_float():
			return "%s non valido" % key
	var pol := str(r.get("polarity", ""))
	if pol not in POLARITIES:
		return "polarità non valida"
	var li := str(r["level_index"]).to_int() if str(r["level_index"]).is_valid_int() else -1
	var g := trial_geometry(r["kind"], li)
	if absf(str(r["disparity_arcsec"]).to_float() - float(g["disparity_arcsec"])) > 0.15:
		return "disparità diversa dal gradino"
	if absf(str(r["grain"]).to_float() - float(g["grain"])) > 0.0015 or absf(str(r["region_t"]).to_float() - float(g["region_t"])) > 0.0015:
		return "grana o regioni diverse dal gradino"
	if r["kind"] == "polarita":
		if pol == "misti":
			return "una prova di polarità con i punti misti"
	elif pol != "misti":
		return "polarità diversa dai punti misti fuori dalle prove di polarità"
	return ""


static func read_csv(path: String) -> Dictionary:
	var rows := []
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return {"header": PackedStringArray(), "rows": rows}
	var header := fa.get_csv_line()
	while not fa.eof_reached():
		var line := fa.get_csv_line()
		if line.size() == 1 and line[0] == "":
			continue
		if line.size() != header.size():
			rows.append({"__rotta": true})
			continue
		var r := {}
		for i in header.size():
			r[header[i]] = line[i]
		rows.append(r)
	return {"header": header, "rows": rows}


## Sessioni delle rovine di una cartella, dalla più vecchia, e file esclusi con il motivo.
## Entrano nelle misure solo i file validi per intero (validate).
static func load_history_full(dir: String) -> Dictionary:
	var out := []
	var excluded := []
	if not DirAccess.dir_exists_absolute(dir):
		return {"sessioni": out, "esclusi": excluded}
	var files := []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("rovine_") and f.ends_with(".csv"):
			files.append(f)
	files.sort()
	for f in files:
		var parts: PackedStringArray = str(f).get_basename().split("_")
		if parts.size() < 3 or parts[1].length() != 8 or parts[2].length() != 6:
			excluded.append({"file": f, "motivo": "file name not recognized"})
			continue
		var csvd := read_csv(dir.path_join(f))
		var rows: Array = csvd["rows"]
		var broken := false
		for r in rows:
			if r.has("__rotta"):
				broken = true
		var why := "a row with the wrong number of fields" if broken else validate(csvd["header"], rows)
		if why == "nessuna prova":
			continue
		if why != "":
			excluded.append({"file": f, "motivo": reason_en(why)})
			continue
		var d: String = parts[1]
		var t: String = parts[2]
		var s := summarize(rows)
		s["sessione"] = "_".join(parts.slice(1))
		s["file"] = f
		s["data"] = "%s-%s-%s" % [d.substr(0, 4), d.substr(4, 2), d.substr(6, 2)]
		s["ora"] = t.substr(0, 2).to_float() + t.substr(2, 2).to_float() / 60.0
		s["fine_ora"] = float(s["ora"]) + float(s["minuti"]) / 60.0
		s["versione"] = rows[0]["version"]
		s["protocollo"] = rows[0]["protocol"]
		s["valida"] = true
		out.append(s)
	return {"sessioni": out, "esclusi": excluded}


static func load_history(dir: String) -> Array:
	return load_history_full(dir)["sessioni"]


## Sonde delle ultime PROBE_WINDOW risposte (descrizione dell'andamento recente, non decisione).
static func recent_probes(history: Array) -> Dictionary:
	var seq := []
	for s in history:
		seq.append_array(s["sonde_seq"])
	var tail := seq.slice(maxi(0, seq.size() - PROBE_WINDOW))
	var k := 0
	for b in tail:
		k += 1 if b else 0
	return probes(k, tail.size())


static func all_probes(history: Array) -> Dictionary:
	var k := 0
	var n := 0
	for s in history:
		k += int(s["sonde"]["k"])
		n += int(s["sonde"]["n"])
	return probes(k, n)


## Una sessione soddisfa un pezzo di un sentiero se il suo esito è informativo e sotto il limite.
## 0.5.13: "al puro" vale fino all'ultimo gradino di quel file (la pietra nuda nella r4, 251″ nella r5): una
## sessione r4 ferma alla pietra nuda non dice niente sui gradini dell'osservatorio, che stanno oltre.
static func _path_ok(e: Dictionary, limit: float) -> bool:
	match e.get("esito", ""):
		"al_puro", "interno":
			return float(e["valore"]) <= limit + 1e-9
	return false


## Serie in corso e serie migliore di sessioni consecutive, fra quelle con un esito informativo per il
## sentiero, che soddisfano il limite: [in corso, migliore]. (0.5.10, prima dentro evaluate_pieces.)
static func _path_run(history: Array, kind: String, limit: float) -> Array:
	var run := 0
	var best := 0
	for s in history:
		var e: Dictionary = s.get(kind, {})
		if e.get("esito", "insufficiente") == "insufficiente":
			continue
		run = run + 1 if _path_ok(e, limit) else 0
		best = maxi(best, run)
	return [run, best]


## Esito del restauro per ogni pezzo: {id: {"ok", "cur", "max", ...}}.
static func evaluate_pieces(history: Array) -> Dictionary:
	var out := {}
	for pz in PEZZI:
		match pz["tipo"]:
			"scaglie", "movimento", "mosaico":
				# due sessioni consecutive fra quelle con un esito informativo per questo sentiero;
				# dalla 0.5.10 un pezzo può avere una seconda via ("alt", sul mosaico): basta una delle due
				var a := _path_run(history, str(pz["tipo"]), float(pz["limite"]))
				var ok: bool = int(a[1]) >= SESSIONS_NEEDED
				var cur := int(a[0])
				if pz.has("alt"):
					var b := _path_run(history, str(pz["alt"]["tipo"]), float(pz["alt"]["limite"]))
					ok = ok or int(b[1]) >= SESSIONS_NEEDED
					cur = maxi(cur, int(b[0]))
				out[pz["id"]] = {"ok": ok, "cur": mini(cur, SESSIONS_NEEDED), "max": SESSIONS_NEEDED}
			"sonde_caso", "sonde_meta":
				var ep := e_process(history, float(pz["p0"]))
				out[pz["id"]] = {"ok": ep["superato"], "cur": 1 if ep["superato"] else 0, "max": 1,
					"e": ep["e"], "max_e": ep["max_e"], "sonde": ep["sonde"]}
	return out


## Aggiorna i pezzi restaurati nel profilo (con la data); restituisce quelli nuovi.
static func update_pieces(profile: Dictionary, results: Dictionary, today: String) -> Array:
	migrate(profile)
	var rv: Dictionary = profile["rovine"]
	if not rv.has("pezzi") or not rv["pezzi"] is Dictionary:
		rv["pezzi"] = {}
	var got: Dictionary = rv["pezzi"]
	var fresh := []
	for pz in PEZZI:
		if results.get(pz["id"], {}).get("ok", false) and not got.has(pz["id"]):
			got[pz["id"]] = today
			fresh.append(pz)
	return fresh


## Profilo di un protocollo precedente: scale e pezzi di un altro disegno non valgono nella r2
## (review RV1–RV4). Si conservano a parte, alla voce "rovine_<protocollo>".
static func migrate(profile: Dictionary) -> bool:
	if not profile.has("rovine") or not profile["rovine"] is Dictionary:
		profile["rovine"] = {"protocollo": PROTOCOL}
		return true
	var rv: Dictionary = profile["rovine"]
	var proto: String = str(rv.get("protocollo", "r1"))
	if proto == PROTOCOL:
		return false
	if proto in ACCEPTED:
		# r2/r3 -> r4: pezzi e scaglie restano; il vento esce (dalla r4 non è più in rotazione,
		# e già dalla r3 ripartiva dal primo gradino); il mosaico parte dal primo gradino.
		# r4 -> r5 (0.5.13): tutto resta, anche il gradino del mosaico (i primi 10 gradini sono identici)
		rv.erase("movimento")
		rv["protocollo"] = PROTOCOL
		return true
	profile["rovine_" + proto] = rv
	profile["rovine"] = {"protocollo": PROTOCOL}
	return true


static func restored_ids(profile: Dictionary) -> Array:
	var rv: Dictionary = profile.get("rovine", {})
	if str(rv.get("protocollo", "r1")) not in ACCEPTED:
		return []
	var got: Dictionary = rv.get("pezzi", {})
	var out := []
	for pz in PEZZI:
		if got.has(pz["id"]):
			out.append(pz["id"])
	return out
