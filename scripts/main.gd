extends Node3D
## Stereopsi VR 0.5 — stereoacuità con un compito di ordinamento in profondità.
## Random-dot (globale): quattro dischi, uno davanti e tre dietro, stessa |disparità|.
## Anelli (locale): due anelli, uno davanti e uno dietro; limite dichiarato: il contorno
## visibile porta con sé un indizio monoculare residuo, misurato dalle prove di controllo.
## Quattro tipi di sessione: standard (Psi adattivo, con prove a fasce fisse), anelli a livelli
## fissi, grossolana e mappa (stimoli costanti). I dati sono separati per partecipante,
## protocollo, modalità, impostazione e contrasto per occhio.
## 0.6: si entra anche dalla capanna del training (un'unica app: niente riavvii di SteamVR fra
## un test e l'altro) e a fine sessione si torna lì; tenendo premuto B o Y si interrompe.
## Accanto al CSV, in postura/, il rollio della testa a ogni prova (solo registrazione).
## 0.6.3: verifica a 1000″ (--mille): 40 prove fisse nel formato normale, al posto dei dischi grandi
## nella suite (regola fissata il 15/10, scattata il 17/10 con 38/40). I dischi grandi restano
## lanciabili (--grande) ma escono dalla pagina del test.

const Paths := preload("res://scripts/paths.gd")
const VERSION := "0.6.3"
const PROTOCOL := "p6"    # cambia quando cambia il compito o lo stimolo: le sessioni si sommano solo a parità di protocollo
const Psi := preload("res://scripts/psi.gd")
const Geometry := preload("res://scripts/training/geometry.gd")
const Stats := preload("res://scripts/stats.gd")
const StereoShader := preload("res://shaders/stereo.gdshader")

const VIEW_DISTANCE := 1.5            # m: quad solidale con la testa
const FIELD_HALF_DEG := 10.5          # semiampiezza angolare del quad (contiene il formato grande)
const TEXT_HALF_DEG := 7.0            # testo sopra il campo del formato normale
const SESSION_TYPES := {
	"standard": ["rds", "rings"],          # Psi adattivo
	"anelli": ["rings_fixed"],             # anelli a livelli fissi (--anelli, 0.6)
	"grossolana": ["rds_coarse"],          # stimoli costanti a disparità molto grandi (--grossolana)
	"mappa": ["rds_mappa", "rds_grande"],  # stimoli costanti su tutta la gamma, due formati (--mappa)
	"grande": ["rds_grande_40"],           # verifica dell'ipotesi del 4/10 sui dischi grandi (--grande, 0.6.1)
	"mille": ["rds_1000_40"],              # verifica a 1000″ nel formato normale (--mille, 0.6.3)
}
const CONDITIONS := ["rds", "rings"]
const COARSE_CONDITIONS := ["rds_coarse"]
const MAP_CONDITIONS := ["rds_mappa", "rds_grande"]
const FIXED_RING_CONDITIONS := ["rings_fixed"]
const GEOMETRY := {
	"normale": {"rds_ecc": 3.2, "region_r": 1.4, "cell": 0.2, "dot_r": 0.075, "field_extent": 6.0},
	# dischi e punti doppi; bordo interno a 3,2° dal centro, fuori dalla zona centrale
	"grande": {"rds_ecc": 6.0, "region_r": 2.8, "cell": 0.4, "dot_r": 0.15, "field_extent": 9.6},
}
const RDS_CHOICES := ["alto", "destra", "basso", "sinistra"]
const COND := {
	"rds": {"label": "Random-dot (global)", "mode": 1, "n_alt": 4, "level_max": 3.5, "main": 60,
		# 12 delle 60 prove principali a fasce fisse, 3 per livello: il Psi presume una curva
		# crescente e, se le risposte sono al caso, lascerebbe scoperte le fasce intermedie (N1)
		"coverage_levels": [2.0, 2.4, 2.8, 3.2], "coverage_per_level": 3,
		"control_levels": [3.4, 3.0, 2.6], "control_n": 8, "practice": [3.5, 3.4, 3.2],
		"leak_limit": 0.45, "choices": RDS_CHOICES},
	"rings": {"label": "Rings (local)", "mode": 2, "n_alt": 2, "level_max": 3.0, "main": 70,
		"control_levels": [3.0, 2.8], "control_n": 24, "practice": [3.0, 3.0, 2.8],
		"leak_limit": 0.65, "choices": ["alto", "basso"]},
	# 0.6: anelli a livelli fissi. Con una curva piatta (circa 70% fra 35 e 350″ nelle sessioni
	# del 29/9 e del 4/10) la soglia del Psi dipende da dove il Psi va a cercare: per confrontare
	# le sessioni servono le stesse disparità ogni volta. Stimolo e compito identici agli anelli.
	"rings_fixed": {"label": "Rings at fixed levels", "short": "Fixed rings", "mode": 2, "n_alt": 2, "level_max": 3.0, "fixed": true,
		"levels": [1.7, 2.0, 2.3, 2.6, 2.9], "per_level": 16,
		"control_levels": [2.9, 2.6], "control_n": 8, "practice": [3.0, 2.9, 2.6],
		"leak_limit": 0.65, "choices": ["alto", "basso"]},
	# Stereopsi grossolana: random-dot a disparità molto grandi (0,9°-2,5°), a stimoli costanti,
	# perché oltre il limite di fusione la curva non è necessariamente monotona.
	"rds_coarse": {"label": "Coarse random-dot", "short": "Coarse", "mode": 1, "n_alt": 4, "level_max": 3.95, "fixed": true,
		"levels": [3.51, 3.67, 3.81, 3.95], "per_level": 14,
		"control_levels": [3.67, 3.95], "control_n": 8, "practice": [3.95, 3.81, 3.67],
		"leak_limit": 0.45, "choices": RDS_CHOICES},
	# Mappa: random-dot a stimoli costanti dove le sessioni standard non avevano guardato
	# (100-1600″), e lo stesso compito in formato grande, più in periferia (N1).
	"rds_mappa": {"label": "Random-dot, normal discs", "short": "Normal discs", "mode": 1, "n_alt": 4, "level_max": 3.2, "fixed": true,
		"levels": [2.0, 2.4, 2.8, 3.2], "per_level": 10,
		"control_levels": [3.2, 2.4], "control_n": 4, "practice": [3.2, 2.8],
		"leak_limit": 0.45, "choices": RDS_CHOICES},
	"rds_grande": {"label": "Random-dot, large discs farther out", "short": "Large discs", "mode": 1, "n_alt": 4, "level_max": 3.6,
		"fixed": true, "geometry": "grande", "levels": [2.4, 2.8, 3.2, 3.6], "per_level": 10,
		"control_levels": [3.6, 2.8], "control_n": 4, "practice": [3.6, 3.2],
		"leak_limit": 0.45, "choices": RDS_CHOICES},
	# 0.6.1: verifica dell'ipotesi dichiarata il 4/10 (dopo 6/10 nella mappa di quella sera): stesso
	# stimolo della casella a 3981″ del formato grande, ma 40 prove su quella sola casella, con il
	# criterio fissato prima di raccogliere i dati (almeno 16 su 40: p = 0,026 al caso).
	"rds_grande_40": {"label": "Random-dot, large discs at 3981″ (check)", "short": "Large-disc check", "mode": 1, "n_alt": 4, "level_max": 3.6,
		"fixed": true, "geometry": "grande", "levels": [3.6], "per_level": 40, "criterion": 16, "criterion_date": "4/10",
		"control_levels": [3.6], "control_n": 4, "practice": [3.6, 3.6],
		"leak_limit": 0.45, "choices": RDS_CHOICES},
	# 0.6.3: verifica a 1000″, sul modello dei dischi grandi, nel formato normale: lo stimolo della
	# standard (e della mappa e delle sonde delle rovine) a 1000″, 40 prove su quella sola casella.
	# Criterio fissato il 17/10, prima dei dati: almeno 16 su 40 (p = 0,026 al caso).
	"rds_1000_40": {"label": "Random-dot, normal discs at 1000″ (check)", "short": "Normal-format check", "mode": 1, "n_alt": 4, "level_max": 3.0,
		"fixed": true, "levels": [3.0], "per_level": 40, "criterion": 16, "criterion_date": "17/10",
		"control_levels": [3.0], "control_n": 4, "practice": [3.0, 3.0],
		"leak_limit": 0.45, "choices": RDS_CHOICES},
}
const ALPHA := 0.05                   # errore complessivo per ogni famiglia di confronti (Holm)
const ANCHOR_P := 0.12                # quota di prove adattive al livello alto (log10 max - 0,1)
const RING_JITTER := Vector2(2.0, 0.3)  # spostamento comune ai due occhi: maschera la posizione monoculare
const RESERVED_NAMES := ["desktop", "autotest"]
const EYECHECK_ANSWERS := ["entrambi, fissi", "solo il quadrato verde (occhio destro)", "vanno e vengono", "solo il cerchio rosso (occhio sinistro)"]
const NONIUS_ANSWERS := ["solo quella sopra (occhio sinistro)", "vanno e vengono", "solo quella sotto (occhio destro)", "tutte e due"]
const NONIUS_STEPS := ["nonius_sx", "nonius_dx", "nonius"]
# solo per lo schermo: nel CSV e nel JSON restano i valori italiani qui sopra
const SHOW_CHECK := {
	"entrambi, fissi": "both, steady", "solo il quadrato verde (occhio destro)": "only the green square (right eye)",
	"vanno e vengono": "they come and go", "solo il cerchio rosso (occhio sinistro)": "only the red circle (left eye)",
	"solo quella sopra (occhio sinistro)": "only the top one (left eye)",
	"solo quella sotto (occhio destro)": "only the bottom one (right eye)", "tutte e due": "both",
	"sì": "yes", "no": "no", "saltato": "skipped", "non data": "not given",
}
const SHOW_NONIUS_READING := {
	"verifica a un occhio non fatta: la risposta a occhi aperti da sola non distingue soppressione e visibilità":
		"one-eye check not done: the both-eyes answer alone can't tell suppression from visibility",
	"almeno una lineetta non si vede neppure con l'altro occhio chiuso: limite di visibilità (ottica, contrasto, risoluzione), non soppressione":
		"at least one line isn't visible even with the other eye closed: a visibility limit (optics, contrast, resolution), not suppression",
	"entrambe visibili, anche a occhi aperti": "both visible, also with both eyes open",
	"ogni lineetta si vede da sola ma non sempre a occhi aperti: compatibile con una soppressione, da verificare dall'ortottista":
		"each line is visible on its own but not always with both eyes open: compatible with suppression, worth checking with an orthoptist",
	"risposta a occhi aperti mancante": "both-eyes answer missing",
}
const SHOW_SESSION := {"standard": "standard", "anelli": "fixed rings", "grossolana": "coarse", "mappa": "map",
	"grande": "large-disc check", "mille": "1000″ check"}
const ABORT_HOLD_S := 2.0            # B o Y tenuto premuto: si interrompe la sessione
const POSTURE_HEADER := ["session", "trial", "block", "condition", "correct", "head_roll_deg", "head_roll_resp_deg", "head_pitch_deg",
	"head_roll_min_deg", "head_roll_max_deg"]   # 0.6.2: minimo e massimo durante lo stimolo (la testa si inclina e si raddrizza)
const LEVEL_RULES := ["practice", "psi", "anchor", "coverage", "fixed", "control"]
const HEADER := ["session", "participant", "protocol", "version", "mode", "setting", "trial", "block",
	"condition", "n_alternatives", "log10_disparity", "disparity_arcsec", "level_rule", "target", "response",
	"correct", "rt_s", "mono_source", "trial_seed", "seed_bg", "seed_rg", "ring_jitter", "contrast_lr",
	"px_arcsec", "alpha_q50", "alpha_q025", "alpha_q975", "pmax_mean"]
const COLOR_NEUTRAL := Color(1, 1, 1)
const COLOR_OK := Color(0.35, 1.0, 0.45)
const COLOR_KO := Color(1.0, 0.35, 0.3)

enum S { EYECHECK, NONIUS, INTRO, PRETRIAL, STIMULUS, FEEDBACK, PAUSE, DONE, ERROR }

var state := S.EYECHECK
var timer := 0.0
var iti := 0.7
var feedback_time := 0.35
var xr_active := false
var vr_requested := false
var autotest := false
var sim := {"rds": 2.5, "rings": 2.0, "rings_fixed": 2.0, "rds_coarse": 3.7, "rds_mappa": 2.6, "rds_grande": 3.0, "rds_grande_40": 3.0, "rds_1000_40": 2.8}
var sim_lapse := 0.02
var materials: Array[ShaderMaterial] = []
var quads: Array[MeshInstance3D] = []
var label: Label3D
var label_home := Vector3.ZERO
var label_top := Vector3.ZERO
var controllers: Array[XRController3D] = []
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var stick_armed := {}
var trigger_prev := {}
var by_held := 0.0
var from_capanna := false        # 0.6: avviato dalla capanna, a fine sessione si torna lì
var posture: FileAccess
var posture_path := ""
var posture_rolls := []
var posture_ranges := []         # 0.6.2: escursione del rollio durante lo stimolo, per prova
var schedule: Array = []
var trial_i := -1
var cur := {}
var psis := {}
var controls := {}              # condizione -> per occhio sorgente: [[giuste, prove], [giuste, prove]]
var fixed_counts := {}          # condizioni a stimoli costanti: livello -> [giuste, prove]
var coverage_counts := {}       # prove a fasce fisse nella sessione standard: livello -> [giuste, prove]
var session_type := "standard"
var session_conds: Array = CONDITIONS
var session_override := ""      # per i test: "standard", "grossolana" o "mappa"
var participant := "anonimo"
var setting := "base"           # impostazione dichiarata (--condizione=): fa parte della chiave di somma
var session_id := ""
var mode_name := "desktop"
var results_dir := ""
var csv: FileAccess
var csv_path := ""
var trial_counter := 0
var n_trials_total := 0
var n_trials_done := 0
var stimulus_on_ms := 0
var pixel_arcsec := -1.0
var eye_separation_m := -1.0
var render_size := Vector2.ZERO
var intro_text := ""
var checks := {"eyecheck": "non data", "nonius_sx": "non data", "nonius_dx": "non data", "nonius": "non data"}
var nonius_step := 0
var eye_contrast := Vector2(1.0, 1.0)   # contrasto degli stimoli per occhio (sinistro, destro); 1 = pieno
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	autotest = "--autotest" in args
	# 0.6: opzioni passate dalla capanna (tipo di sessione, partecipante), consumate qui
	var opts: Dictionary = {}
	if get_tree().root.has_meta("test_opts"):
		opts = get_tree().root.get_meta("test_opts")
		get_tree().root.remove_meta("test_opts")
		from_capanna = bool(opts.get("da_capanna", false))
	if not session_override.is_empty():
		session_type = session_override
	elif SESSION_TYPES.has(str(opts.get("tipo", ""))):
		session_type = str(opts["tipo"])
	elif "--grossolana" in args:
		session_type = "grossolana"
	elif "--mappa" in args:
		session_type = "mappa"
	elif "--anelli" in args:
		session_type = "anelli"
	elif "--grande" in args:
		session_type = "grande"
	elif "--mille" in args:
		session_type = "mille"
	session_conds = SESSION_TYPES[session_type]
	for a in args:
		if a.begins_with("--partecipante="):
			participant = a.split("=")[1]
		elif a.begins_with("--condizione="):
			setting = a.split("=")[1]
		elif a.begins_with("--sim-mappa="):
			sim["rds_mappa"] = a.split("=")[1].to_float()
		elif a.begins_with("--sim-grande="):
			sim["rds_grande"] = a.split("=")[1].to_float()
			sim["rds_grande_40"] = sim["rds_grande"]
		elif a.begins_with("--sim-mille="):
			sim["rds_1000_40"] = a.split("=")[1].to_float()
		elif a.begins_with("--sim-rds="):
			sim["rds"] = a.split("=")[1].to_float()
		elif a.begins_with("--sim-rings="):
			sim["rings"] = a.split("=")[1].to_float()
			sim["rings_fixed"] = sim["rings"]
		elif a.begins_with("--sim-coarse="):
			sim["rds_coarse"] = a.split("=")[1].to_float()
		elif a.begins_with("--sim-lapse="):
			sim_lapse = a.split("=")[1].to_float()
		elif a.begins_with("--contrasto-sx="):
			eye_contrast.x = clampf(a.split("=")[1].to_float(), 0.0, 1.0)
		elif a.begins_with("--contrasto-dx="):
			eye_contrast.y = clampf(a.split("=")[1].to_float(), 0.0, 1.0)
	if opts.has("partecipante"):
		participant = str(opts["partecipante"])
	participant = sanitize_name(participant)
	setting = sanitize_name(setting, false)
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	vr_requested = "--vr" in args
	xr_active = xr != null and xr.is_initialized() and not autotest
	mode_name = "autotest" if autotest else ("vr" if xr_active else "desktop")
	if autotest:
		iti = 0.0
		feedback_time = 0.0
	_build_world(xr)
	for c in COND:
		psis[c] = Psi.new(1.0 / COND[c]["n_alt"], COND[c]["level_max"])
		fixed_counts[c] = {}
		coverage_counts[c] = {}
		controls[c] = [[0, 0], [0, 0]]
	if "--capture" in args:
		await _capture(args[args.find("--capture") + 1])
		get_tree().quit()
		return
	if "--capture-heldout" in args:
		var i := args.find("--capture-heldout")
		var hc: String = args[i + 3] if args.size() > i + 3 and COND.has(args[i + 3]) else "rds"
		var only := args[i + 4].to_float() if args.size() > i + 4 else 0.0
		await _capture_heldout(args[i + 1], int(args[i + 2]), hc, only)
		get_tree().quit()
		return
	if not _open_results():
		return
	var intro := "STEREOPSIS TEST (%s)\n\nIn each trial only one shape is IN FRONT and the others are BEHIND. They may all shimmer or look doubled in the same way: all that matters is which one is in front.\n\nRandom-dot: four discs hidden among the dots. Point to the front one with the thumbstick (up, right, down, left).\nRings: two rings, above and below. Point to the front one, up or down.\n\nFeel free to move your eyes. If you see nothing, take a guess.\n\nTrigger (or Space): 6 practice trials." % [participant]
	if session_type == "mappa":
		intro = "STEREOPSIS TEST (%s) - RANDOM-DOT MAP\n\nRandom-dot only, at fixed levels, in two mixed formats: normal discs near the center, and large discs farther out (the frame gets wider). One region is IN FRONT, three BEHIND: point to it with the thumbstick.\n\nMany trials are hard on purpose: if you see nothing, take a guess. Feel free to move your eyes.\n\nTrigger (or Space): 4 practice trials." % [participant]
	elif session_type == "anelli":
		intro = "STEREOPSIS TEST (%s) - RINGS AT FIXED LEVELS\n\nRings only, at five fixed disparities, mixed: the same every time, so sessions can be compared. Two rings, above and below the cross: one is IN FRONT. Point to it with the thumbstick, up or down.\n\nMany trials are hard on purpose: if you see nothing, take a guess. About 6 minutes.\n\nTrigger (or Space): 3 practice trials." % [participant]
	elif session_type == "grande":
		intro = "STEREOPSIS TEST (%s) - LARGE-DISC CHECK\n\nRandom-dot only, in the large format, always at the same disparity (3981″, about 1.1°): 40 trials. One region is IN FRONT, three BEHIND: point to it with the thumbstick. It checks an earlier impression against a criterion set in advance.\n\nIf you see nothing, take a guess. About 6 minutes.\n\nTrigger (or Space): 2 practice trials." % [participant]
	elif session_type == "mille":
		intro = "STEREOPSIS TEST (%s) - CHECK AT 1000″\n\nRandom-dot only, in the normal format (the one in the standard test and in the Ruins probes), always at the same disparity (1000″, about 0.28°): 40 trials. One region is IN FRONT, three BEHIND: point to it with the thumbstick. The criterion was set before the data.\n\nIf you see nothing, take a guess. About 5 minutes.\n\nTrigger (or Space): 2 practice trials." % [participant]
	elif session_type == "grossolana":
		intro = "STEREOPSIS TEST (%s) - COARSE SESSION\n\nRandom-dot only, at very large disparities (from about 1° to 2.5°). One region is IN FRONT, three BEHIND. All the shapes may look doubled or shimmer: still look for the one in front, even if you see it double.\n\nPoint to it with the thumbstick (up, right, down, left). Feel free to move your eyes. If you see nothing, take a guess.\n\nTrigger (or Space): 3 practice trials." % [participant]
	if vr_requested and not xr_active and not autotest:
		intro = "VR NOT ACTIVE: connect the headset, check SteamVR, then close the app and reopen it with Start Stereopsis VR.cmd.\n\n" + intro
	elif not xr_active and not autotest:
		intro = "DESKTOP MODE (development, not a measurement): fuse the two images with parallel eyes.\n\n" + intro
	if xr_active:
		intro += "\n\nTo stop: hold B or Y for two seconds%s." % (" (back to the hut)" if from_capanna else "")
	intro_text = intro
	if autotest:
		checks = {"eyecheck": "autotest", "nonius_sx": "autotest", "nonius_dx": "autotest", "nonius": "autotest"}
		state = S.INTRO
		_show_text(intro)
		_confirm()
		return
	_show_eyecheck()


static func sanitize_name(raw: String, is_participant := true) -> String:
	var out := ""
	for ch in raw.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
	if out.is_empty():
		out = "anonimo" if is_participant else "base"
	if is_participant and (out in RESERVED_NAMES or out.begins_with("prova-")):
		out = "p_" + out
	return out


# ---------------------------------------------------------------- scena

func _build_world(xr: OpenXRInterface) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.05, 0.05)
	add_child(env)
	var width := 2.0 * VIEW_DISTANCE * tan(deg_to_rad(FIELD_HALF_DEG))
	var field_half := rad_to_deg(tan(deg_to_rad(FIELD_HALF_DEG)))
	var text_y := VIEW_DISTANCE * tan(deg_to_rad(TEXT_HALF_DEG))
	label = Label3D.new()
	label.font_size = 44
	label.outline_size = 8
	label.pixel_size = 0.0005
	label.no_depth_test = true
	label.double_sided = true
	label.modulate = Color(0.95, 0.95, 0.95)
	label.outline_modulate = Color(0, 0, 0)
	if xr_active:
		# metodo legato al nodo (non una lambda): la connessione cade col nodo al cambio di scena (0.6)
		for event_name in ["session_begun", "session_visible", "session_focussed", "session_stopping"]:
			xr.connect(event_name, _on_xr_event.bind(event_name))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		var origin := XROrigin3D.new()
		add_child(origin)
		origin.current = true
		xr_origin = origin
		var cam := XRCamera3D.new()
		cam.near = 0.05
		cam.far = 50.0
		origin.add_child(cam)
		cam.current = true
		xr_camera = cam
		for hand in ["left_hand", "right_hand"]:
			var ctrl := XRController3D.new()
			ctrl.tracker = StringName(hand)
			ctrl.pose = &"aim"
			origin.add_child(ctrl)
			controllers.append(ctrl)
			# 0.6: arrivando dalla capanna il grilletto (o la levetta) può essere ancora premuto:
			# serve un rilascio prima che conti, altrimenti salterebbe il controllo degli occhi
			stick_armed[ctrl] = false
			trigger_prev[ctrl] = true
		var quad := _make_quad(width, field_half, -1)
		quad.position = Vector3(0, 0, -VIEW_DISTANCE)
		cam.add_child(quad)
		label_home = Vector3(0, 0, -VIEW_DISTANCE + 0.1)
		label_top = Vector3(0, text_y + 0.02, -VIEW_DISTANCE + 0.1)
		label.position = label_home
		cam.add_child(label)
	else:
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = width * 1.7
		cam.position = Vector3(0, 0, 3)
		add_child(cam)
		cam.current = true
		var gap := width * 0.04
		for eye in 2:
			var quad := _make_quad(width, field_half, eye)
			quad.position = Vector3((-1 if eye == 0 else 1) * (width + gap) * 0.5, 0, 0)
			add_child(quad)
		label.pixel_size = 0.00022
		label_home = Vector3(0, 0, 0.5)
		label_top = Vector3(0, text_y + 0.01, 0.5)
		label.position = label_home
		add_child(label)


func _on_xr_event(event_name: String) -> void:
	print("STEREOPSI_XR " + event_name)


func _make_quad(width: float, field_half: float, eye: int) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, width)
	var mat := ShaderMaterial.new()
	mat.shader = StereoShader
	mat.set_shader_parameter("field_half", field_half)
	mat.set_shader_parameter("eye_override", eye)
	mat.set_shader_parameter("ring_jitter", PackedVector2Array([Vector2.ZERO, Vector2.ZERO]))
	mat.set_shader_parameter("progress", -1.0)
	mat.set_shader_parameter("eye_contrast", eye_contrast)
	for key in GEOMETRY["normale"]:
		mat.set_shader_parameter(key, GEOMETRY["normale"][key])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	materials.append(mat)
	quads.append(mi)
	return mi


func _set_param(param: String, value: Variant) -> void:
	for m in materials:
		m.set_shader_parameter(param, value)


func _set_geometry(cond: String) -> void:
	var g: Dictionary = GEOMETRY[COND[cond].get("geometry", "normale")] if cond != "" else GEOMETRY["normale"]
	for key in g:
		_set_param(key, g[key])


func _show_text(text: String, wrap_width := 46) -> void:
	label.position = label_home
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = _wrap(text, wrap_width)
	label.visible = true
	for q in quads:
		q.visible = false


func _show_text_over_field(text: String) -> void:
	label.position = label_top
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.text = _wrap(text, 50)
	label.visible = true


## A capo manuale: Label3D elimina le righe vuote fra i paragrafi.
static func _wrap(text: String, width: int) -> String:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			if line.length() > 0 and line.length() + 1 + word.length() > width:
				out.append(line)
				line = word
			else:
				line = word if line.is_empty() else line + " " + word
		# Label3D collassa le righe vuote: il separatore fra paragrafi è un puntino
		out.append(line if not line.is_empty() else "·")
	return "\n".join(out)


func _show_field(mode: int, nonius: bool, color: Color) -> void:
	label.visible = false
	for q in quads:
		q.visible = true
	_set_param("mode", mode)
	_set_param("show_nonius", nonius)
	_set_param("fix_color", color)


# ---------------------------------------------------------------- controlli iniziali

func _show_eyecheck() -> void:
	state = S.EYECHECK
	_set_geometry("")
	_show_field(3, false, COLOR_NEUTRAL)
	_set_param("mono_source", -1)
	_set_param("progress", -1.0)
	_show_text_over_field("EYE CHECK\nClose one eye at a time: the left eye sees a red circle, the right eye a green square. Then, with both eyes open and looking at the cross, what do you see?\nUp: both, steady. Down: they come and go.\nLeft: only the circle. Right: only the square.")


## Lineette in tre passi (0.5, review N7): prima ciascuna con l'altro occhio chiuso, per sapere
## se quell'occhio la vede da solo; poi a occhi aperti. Solo se un occhio la vede da solo e la
## perde a occhi aperti il dato è compatibile con una soppressione (da verificare dall'ortottista).
func _show_nonius_check(step := 0) -> void:
	state = S.NONIUS
	nonius_step = step
	_set_geometry("")
	_show_field(0, true, COLOR_NEUTRAL)
	_set_param("mono_source", -1)
	_set_param("progress", -1.0)
	var texts := [
		"LITTLE LINES (1 of 3)\nClose your RIGHT eye and look at the dot in the center. Do you see a little line ABOVE the dot?\nUp: yes. Down: no.",
		"LITTLE LINES (2 of 3)\nNow close your LEFT eye and look at the dot. Do you see a little line BELOW the dot?\nUp: yes. Down: no.",
		"LITTLE LINES (3 of 3)\nWith both eyes open, looking at the dot: how many little lines do you see?\nUp: only the top one. Down: only the bottom one.\nLeft: both. Right: they come and go.",
	]
	_show_text_over_field(texts[step])


func _nonius_answer(direction: int) -> void:
	var key: String = NONIUS_STEPS[nonius_step]
	var answer: String
	if nonius_step < 2:
		if direction != 0 and direction != 2:
			return
		answer = "sì" if direction == 0 else "no"
	else:
		answer = NONIUS_ANSWERS[direction]
	if not _record_check(key, answer):
		return
	if nonius_step < 2:
		_show_nonius_check(nonius_step + 1)
	else:
		state = S.INTRO
		_show_text(intro_text)


func _skip_nonius() -> void:
	for i in range(nonius_step, NONIUS_STEPS.size()):
		if not _record_check(NONIUS_STEPS[i], "saltato"):
			return
	state = S.INTRO
	_show_text(intro_text)


## Lettura delle lineette, con prudenza: descrive, non diagnostica.
static func nonius_reading(c: Dictionary) -> String:
	var sx: String = c.get("nonius_sx", "")
	var dx: String = c.get("nonius_dx", "")
	var both: String = c.get("nonius", "")
	if sx not in ["sì", "no"] or dx not in ["sì", "no"]:
		return "verifica a un occhio non fatta: la risposta a occhi aperti da sola non distingue soppressione e visibilità"
	if sx == "no" or dx == "no":
		return "almeno una lineetta non si vede neppure con l'altro occhio chiuso: limite di visibilità (ottica, contrasto, risoluzione), non soppressione"
	if both.begins_with("tutte"):
		return "entrambe visibili, anche a occhi aperti"
	if both.begins_with("solo") or both.begins_with("vanno"):
		return "ogni lineetta si vede da sola ma non sempre a occhi aperti: compatibile con una soppressione, da verificare dall'ortottista"
	return "risposta a occhi aperti mancante"


func _record_check(kind: String, answer: String) -> bool:
	checks[kind] = answer
	return _write_row({"trial": 0, "block": "check", "condition": kind, "response": answer})


# ---------------------------------------------------------------- sequenza

func _build_schedule() -> void:
	schedule.clear()
	var n_practice := 0
	var practice_len := 0
	for c in session_conds:
		practice_len = maxi(practice_len, COND[c]["practice"].size())
	for i in practice_len:
		for c in session_conds:
			if i < COND[c]["practice"].size():
				schedule.append({"block": "practice", "cond": c, "level": COND[c]["practice"][i], "rule": "practice"})
				n_practice += 1
	var main := []
	var seconds := 0.0
	for c in session_conds:
		if COND[c].get("fixed", false):
			for lv in COND[c]["levels"]:
				for i in COND[c]["per_level"]:
					main.append({"block": "main", "cond": c, "level": lv, "rule": "fixed"})
		else:
			var n_cov := 0
			for lv in COND[c].get("coverage_levels", []):
				for i in COND[c]["coverage_per_level"]:
					main.append({"block": "main", "cond": c, "level": lv, "rule": "coverage"})
					n_cov += 1
			for i in COND[c]["main"] - n_cov:
				main.append({"block": "main", "cond": c, "rule": "psi"})
		# controlli: occhio sorgente alternato (bilanciato per costruzione), livelli a rotazione
		var levels: Array = COND[c]["control_levels"]
		for i in COND[c]["control_n"]:
			main.append({"block": "control", "cond": c, "level": levels[(i >> 1) % levels.size()],
				"mono": i % 2, "rule": "control"})
	for item in main:
		seconds += trial_seconds(item["cond"])
	_shuffle(main)
	schedule.append({"block": "pause", "text": "End of practice. If you saw nothing, that's fine.\n\nNow %d trials, with a break halfway: about %d minutes.\n\nTrigger (or Space) to start." % [main.size(), maxi(1, roundi(seconds / 60.0))]})
	n_trials_total = n_practice + main.size()
	for i in main.size():
		if i == main.size() >> 1:
			schedule.append({"block": "pause", "text": "Break: you're halfway. Close your eyes for a few seconds.\n\nTrigger (or Space) to continue."})
		schedule.append(main[i])


## Durata tipica di una prova, dalle sessioni del 28/9 (risposta + pausa + riscontro).
static func trial_seconds(cond: String) -> float:
	return 7.0 if COND[cond]["n_alt"] == 4 else 4.0


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Parametri casuali di una prova, ricavati solo dal suo seme (replay esatto dal CSV).
## L'occhio sorgente dei controlli non è casuale: lo fissa la sequenza, alternato (0.5, review N3).
static func trial_params(trial_seed: int, cond: String) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = trial_seed
	var n_alt: int = COND[cond]["n_alt"]
	var out := {"target": r.randi_range(0, n_alt - 1), "seed_bg": r.randi_range(1, 1 << 24),
		"seed_rg": r.randi_range(1, 1 << 24), "mono": -1}
	var jit := PackedVector2Array()
	for k in 2:
		jit.append(Vector2(r.randf_range(-1.0, 1.0) * RING_JITTER.x, r.randf_range(-1.0, 1.0) * RING_JITTER.y))
	out["jitter"] = jit
	return out


func _next_trial() -> void:
	trial_i += 1
	if trial_i >= schedule.size():
		_finish()
		return
	var item: Dictionary = schedule[trial_i]
	if item["block"] == "pause":
		state = S.PAUSE
		_show_text(item["text"])
		if autotest:
			_confirm()
		return
	var cond: String = item["cond"]
	var rule: String = item["rule"]
	var level: float
	var li := -1
	var psi: Psi = psis[cond]
	if rule == "psi":
		if rng.randf() < ANCHOR_P:
			li = psi.level_index(COND[cond]["level_max"] - 0.1)
			rule = "anchor"
		else:
			li = psi.next_level_index()
		level = psi.levels[li]
	else:
		level = item["level"]
		if rule == "coverage":
			li = psi.level_index(level)
	var seed_ := rng.randi()
	cur = trial_params(seed_, cond)
	cur.merge({"block": item["block"], "cond": cond, "level": level, "li": li, "rule": rule, "seed": seed_}, true)
	cur["mono"] = item.get("mono", -1)
	state = S.PRETRIAL
	timer = iti
	_set_param("mono_source", -1)
	_set_param("progress", float(n_trials_done) / maxf(n_trials_total, 1.0))
	_set_geometry(cond)
	_show_field(0, true, COLOR_NEUTRAL)


func _present_stimulus() -> void:
	if xr_active and pixel_arcsec < 0.0:
		_measure_display()
	_set_param("disparity_deg", pow(10.0, cur["level"]) / 3600.0)
	_set_param("target_index", cur["target"])
	_set_param("seed_bg", cur["seed_bg"])
	_set_param("seed_rg", cur["seed_rg"])
	_set_param("ring_jitter", cur["jitter"])
	_set_param("mono_source", cur["mono"])
	_set_geometry(cur["cond"])
	_show_field(COND[cur["cond"]]["mode"], false, COLOR_NEUTRAL)
	state = S.STIMULUS
	stimulus_on_ms = Time.get_ticks_msec()
	var hp := _head_pose()
	cur["roll"] = hp.x
	cur["pitch"] = hp.y
	cur["roll_min"] = hp.x
	cur["roll_max"] = hp.x


## Direzione della levetta -> alternativa scelta (-1 se non valida per la condizione).
static func choice_for(cond: String, direction: int) -> int:
	if COND[cond]["n_alt"] == 2:   # anelli (anche a livelli fissi): solo su e giù
		return 0 if direction == 0 else (1 if direction == 2 else -1)
	return direction


static func direction_for(cond: String, choice: int) -> int:
	if COND[cond]["n_alt"] == 2:
		return 0 if choice == 0 else 2
	return choice


func _respond(direction: int) -> void:
	match state:
		S.EYECHECK:
			if _record_check("eyecheck", EYECHECK_ANSWERS[direction]):
				_show_nonius_check()
			return
		S.NONIUS:
			_nonius_answer(direction)
			return
		S.STIMULUS:
			pass
		_:
			return
	var cond: String = cur["cond"]
	var choice := choice_for(cond, direction)
	if choice < 0:
		return
	var rt := (Time.get_ticks_msec() - stimulus_on_ms) / 1000.0
	var correct: bool = choice == cur["target"]
	var psi: Psi = psis[cond]
	var key := "%.2f" % cur["level"]
	if cur["block"] == "main" and COND[cond].get("fixed", false):
		_count(fixed_counts[cond], key, correct)
	elif cur["block"] == "main":
		psi.update(cur["li"], correct)
		if cur["rule"] == "coverage":
			_count(coverage_counts[cond], key, correct)
	elif cur["block"] == "control":
		controls[cond][cur["mono"]][0] += 1 if correct else 0
		controls[cond][cur["mono"]][1] += 1
	trial_counter += 1
	n_trials_done += 1
	var s: Dictionary = psi.summary()
	var jit: PackedVector2Array = cur["jitter"]
	var names: Array = COND[cond]["choices"]
	var ok := _write_row({"trial": trial_counter, "block": cur["block"], "condition": cond,
		"n_alternatives": COND[cond]["n_alt"], "log10_disparity": "%.3f" % cur["level"],
		"disparity_arcsec": "%.2f" % pow(10.0, cur["level"]), "level_rule": cur["rule"],
		"target": names[cur["target"]], "response": names[choice], "correct": 1 if correct else 0,
		"rt_s": "%.3f" % rt, "mono_source": cur["mono"], "trial_seed": cur["seed"],
		"seed_bg": cur["seed_bg"], "seed_rg": cur["seed_rg"],
		"ring_jitter": "%.4f;%.4f;%.4f;%.4f" % [jit[0].x, jit[0].y, jit[1].x, jit[1].y],
		"alpha_q50": "%.3f" % s.get("log_q50", NAN), "alpha_q025": "%.3f" % s.get("log_q025", NAN),
		"alpha_q975": "%.3f" % s.get("log_q975", NAN), "pmax_mean": "%.3f" % s.get("pmax_mean", NAN)})
	if not ok:
		return
	_write_posture({"trial": trial_counter, "block": cur["block"], "condition": cond, "correct": 1 if correct else 0,
		"head_roll_deg": _deg_txt(cur.get("roll", NAN)), "head_roll_resp_deg": _deg_txt(_head_pose().x),
		"head_pitch_deg": _deg_txt(cur.get("pitch", NAN)),
		"head_roll_min_deg": _deg_txt(cur.get("roll_min", NAN)), "head_roll_max_deg": _deg_txt(cur.get("roll_max", NAN))})
	if not is_nan(cur.get("roll_min", NAN)):
		posture_ranges.append(cur["roll_max"] - cur["roll_min"])
	if not is_nan(cur.get("roll", NAN)):
		posture_rolls.append(cur["roll"])
	_set_param("mono_source", -1)
	_set_param("progress", float(n_trials_done) / maxf(n_trials_total, 1.0))
	_show_field(0, false, COLOR_OK if correct else COLOR_KO)
	state = S.FEEDBACK
	timer = feedback_time


static func _count(store: Dictionary, key: String, correct: bool) -> void:
	var kn: Array = store.get(key, [0, 0])
	store[key] = [kn[0] + (1 if correct else 0), kn[1] + 1]


func _confirm() -> void:
	match state:
		S.EYECHECK:
			if _record_check("eyecheck", "saltato"):
				_show_nonius_check()
		S.NONIUS:
			_skip_nonius()
		S.INTRO:
			_build_schedule()
			trial_i = -1
			_next_trial()
		S.PAUSE:
			_next_trial()
		S.DONE, S.ERROR:
			_leave()


## Fine (0.6): si torna alla capanna se si è partiti da lì, altrimenti si chiude.
func _leave() -> void:
	if csv:
		csv.flush()
	if posture:
		posture.flush()
	if from_capanna:
		get_tree().root.set_meta("capanna_opts", {"partecipante": participant})
		get_tree().call_deferred("change_scene_to_file", "res://scenes/capanna.tscn")
	else:
		get_tree().quit()


## Interruzione a metà (B o Y tenuto premuto, 0.6). La sessione resta nel CSV con una riga
## "interrotta", ed è esclusa dalla somma: una sessione lasciata a metà (stanchezza, visore
## tolto) non si confonde con le altre. Il riepilogo JSON non viene scritto. Se non c'è ancora
## nessuna prova (test aperto per sbaglio), i file vengono tolti: non c'è niente da conservare.
func _abort() -> void:
	if state in [S.DONE, S.ERROR]:
		_leave()
		return
	if n_trials_done == 0:
		csv = null
		posture = null
		DirAccess.remove_absolute(csv_path)
		if not posture_path.is_empty():
			DirAccess.remove_absolute(posture_path)
	elif csv:
		_record_check("interrotta", "sì (dopo %d prove)" % n_trials_done)
	print("STEREOPSI_INTERROTTA %s (%d prove)" % [session_id, n_trials_done])
	_leave()


func _process(delta: float) -> void:
	_poll_controllers(delta)
	match state:
		S.PRETRIAL:
			timer -= delta
			if timer <= 0.0:
				_present_stimulus()
		S.STIMULUS:
			_track_roll()
			if autotest:
				_respond(_simulated_response())
		S.FEEDBACK:
			timer -= delta
			if timer <= 0.0:
				_next_trial()


# ---------------------------------------------------------------- input

func _poll_controllers(delta := 0.0) -> void:
	var by_any := false
	for ctrl in controllers:
		if not ctrl.get_is_active():
			continue
		by_any = by_any or ctrl.is_button_pressed("by_button")
		var v: Vector2 = ctrl.get_vector2("primary")
		if stick_armed[ctrl] and v.length() > 0.75:
			stick_armed[ctrl] = false
			if abs(v.y) >= abs(v.x):
				_respond(0 if v.y > 0 else 2)
			else:
				_respond(1 if v.x > 0 else 3)
		elif v.length() < 0.3:
			stick_armed[ctrl] = true
		var pressed := ctrl.is_button_pressed("trigger_click") or ctrl.is_button_pressed("ax_button")
		if pressed and not trigger_prev[ctrl]:
			_confirm()
		trigger_prev[ctrl] = pressed
	by_held = by_held + delta if by_any else 0.0
	if by_held >= ABORT_HOLD_S:
		by_held = -1000.0     # una volta sola
		_abort()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_UP, KEY_W, KEY_KP_8:
			_respond(0)
		KEY_RIGHT, KEY_D, KEY_KP_6:
			_respond(1)
		KEY_DOWN, KEY_S, KEY_KP_2:
			_respond(2)
		KEY_LEFT, KEY_A, KEY_KP_4:
			_respond(3)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_confirm()
		KEY_ESCAPE:
			_abort()


func _simulated_response() -> int:
	var cond: String = cur["cond"]
	var n_alt: int = COND[cond]["n_alt"]
	var psi: Psi = psis[cond]
	var p := 1.0 / n_alt
	if cur["block"] != "control":
		p = psi.p_correct(cur["level"], sim[cond], 2.0, sim_lapse)
	var choice: int = cur["target"]
	if rng.randf() >= p:
		choice = (choice + rng.randi_range(1, n_alt - 1)) % n_alt
	return direction_for(cond, choice)


# ---------------------------------------------------------------- dati

func _open_results() -> bool:
	var now := Time.get_datetime_string_from_system(false, false).replace("-", "").replace(":", "").replace("T", "_")
	session_id = "%s_%03d_%04x" % [now, Time.get_ticks_msec() % 1000, rng.randi() & 0xffff]
	var sub := participant + "/"
	if mode_name == "desktop":
		sub = "desktop/" + participant + "/"
	elif mode_name == "autotest":
		sub = "autotest/"
	results_dir = Paths.globalize("res://results/" + sub)
	var err := DirAccess.make_dir_recursive_absolute(results_dir)
	if err != OK and not DirAccess.dir_exists_absolute(results_dir):
		_fatal("Can't create the results folder:\n%s\n\nThe test can't start." % results_dir)
		return false
	csv_path = results_dir + "sessione_%s.csv" % session_id
	csv = FileAccess.open(csv_path, FileAccess.WRITE)
	if csv == null:
		_fatal("Can't write the results file:\n%s\n(%s)\n\nThe test can't start." % [csv_path, error_string(FileAccess.get_open_error())])
		return false
	csv.store_csv_line(PackedStringArray(HEADER))
	csv.flush()
	if csv.get_error() != OK:
		_fatal("Write error on %s. The test can't start." % csv_path)
		return false
	_open_posture()
	return true


## 0.6: postura della testa in un file a parte (risultati/<nome>/postura/), così lo schema del CSV
## delle prove non cambia e le sessioni si sommano come prima. È solo registrazione: lo stimolo è
## solidale con la testa, e inclinarla non cambia l'immagine. Se il file non si apre il test va
## avanti lo stesso (lo dice il riepilogo).
func _open_posture() -> void:
	var pdir := results_dir + "postura/"
	DirAccess.make_dir_recursive_absolute(pdir)
	posture_path = pdir + "sessione_%s.csv" % session_id
	posture = FileAccess.open(posture_path, FileAccess.WRITE)
	if posture == null:
		push_warning("postura non registrata: " + posture_path)
		posture_path = ""
		return
	posture.store_csv_line(PackedStringArray(POSTURE_HEADER))
	posture.flush()


func _write_posture(fields: Dictionary) -> void:
	if posture == null:
		return
	fields["session"] = session_id
	var row := PackedStringArray()
	for col in POSTURE_HEADER:
		row.append(str(fields.get(col, "")))
	posture.store_csv_line(row)
	posture.flush()


## Rollio e beccheggio della testa in gradi (0.6, solo registrazione), dagli occhi reali come nel
## bosco: rollio positivo con la testa inclinata verso la spalla destra. Fuori dal visore: NAN.
func _head_pose() -> Vector2:
	if not xr_active or xr_origin == null or XRServer.primary_interface == null:
		return Vector2(NAN, NAN)
	var xr := XRServer.primary_interface
	var ot := xr_origin.global_transform
	var el := xr.get_transform_for_view(0, ot).origin
	var er := xr.get_transform_for_view(1, ot).origin
	return Vector2(Geometry.head_roll_deg(el, er), Geometry.head_pitch_deg(-xr_camera.global_transform.basis.z))


## 0.6.2: il rollio a ogni frame dello stimolo, perché il giocatore può inclinare la testa durante la prova
## e la raddrizza prima di rispondere: comparsa e risposta da sole non lo vedono.
func _track_roll() -> void:
	if not xr_active or is_nan(cur.get("roll_min", NAN)):
		return
	var r := _head_pose().x
	if is_nan(r):
		return
	cur["roll_min"] = minf(cur["roll_min"], r)
	cur["roll_max"] = maxf(cur["roll_max"], r)


static func _deg_txt(v: float) -> String:
	return "" if is_nan(v) else "%.2f" % v


## Riassunto del rollio: mediana e 10°-90° percentile (gradi), o vuoto se non registrato.
static func roll_summary(rolls: Array) -> Dictionary:
	if rolls.is_empty():
		return {}
	var r := rolls.duplicate()
	r.sort()
	var q := func(p: float) -> float: return r[clampi(roundi(p * (r.size() - 1)), 0, r.size() - 1)]
	return {"n": r.size(), "rollio_mediano_deg": q.call(0.5), "rollio_q10_deg": q.call(0.1), "rollio_q90_deg": q.call(0.9)}


func _write_row(fields: Dictionary) -> bool:
	if csv == null:
		_fatal("The results file isn't open: the test stops.")
		return false
	var base := {"session": session_id, "participant": participant, "protocol": PROTOCOL,
		"version": VERSION, "mode": mode_name, "setting": setting, "contrast_lr": contrast_key(),
		"px_arcsec": "%.1f" % pixel_arcsec}
	base.merge(fields, true)
	var row := PackedStringArray()
	for col in HEADER:
		row.append(str(base.get(col, "")))
	csv.store_csv_line(row)
	csv.flush()
	if csv.get_error() != OK:
		_fatal("Write error on %s: the test stops. Trials already saved stay in the file." % csv_path)
		return false
	return true


func contrast_key() -> String:
	return "%.3f;%.3f" % [eye_contrast.x, eye_contrast.y]


func _fatal(message: String) -> void:
	push_error(message)
	print("STEREOPSI_ERROR " + message)
	state = S.ERROR
	_show_text("ERROR\n\n" + message + ("\n\nTrigger (or Space) to return to the hut." if from_capanna else "\n\nTrigger (or Space) to close."))
	if autotest:
		get_tree().quit(1)


func _measure_display() -> void:
	if not xr_active:
		return
	var xr := XRServer.primary_interface
	render_size = xr.get_render_target_size()
	if render_size.x > 0:
		var proj: Projection = xr.get_projection_for_view(0, render_size.x / render_size.y, 0.05, 50.0)
		pixel_arcsec = 2.0 / (proj.x.x * render_size.x) * 206264.8
	var e0: Transform3D = xr.get_transform_for_view(0, Transform3D.IDENTITY)
	var e1: Transform3D = xr.get_transform_for_view(1, Transform3D.IDENTITY)
	eye_separation_m = e0.origin.distance_to(e1.origin)


## Somma le sessioni compatibili: stesso partecipante, protocollo, modalità, impostazione e
## contrasto per occhio, e schema del CSV identico (N2). Ogni file è letto e validato per intero
## prima di entrare nella somma: un file escluso non lascia righe nel risultato (N4).
func pooled_summary(dir_path: String) -> Dictionary:
	var pooled := {}
	var per_session := []
	var excluded := []
	var ctrl := {}
	var fixed_pooled := {}
	var coverage_pooled := {}
	var sessions_by := {}
	var px_values := []
	for c in COND:
		pooled[c] = Psi.new(1.0 / COND[c]["n_alt"], COND[c]["level_max"])
		ctrl[c] = [[0, 0], [0, 0]]
		fixed_pooled[c] = {}
		coverage_pooled[c] = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return {"sessions": 0, "excluded": [], "per_session": [], "sessions_by_condition": {}}
	var files := dir.get_files()
	files.sort()
	var idx := {}
	for i in HEADER.size():
		idx[HEADER[i]] = i
	for f in files:
		if not (f.begins_with("sessione_") and f.ends_with(".csv")):
			continue
		var fa := FileAccess.open(dir_path + f, FileAccess.READ)
		if fa == null:
			excluded.append(f + ": non leggibile")
			continue
		var header := fa.get_csv_line()
		if Array(header) != HEADER:
			excluded.append(f + ": altro protocollo o schema")
			continue
		var rows := []
		var reason := ""
		while not fa.eof_reached():
			var row := fa.get_csv_line()
			if row.size() == 1 and row[0].strip_edges().is_empty():
				continue
			if row.size() != HEADER.size():
				reason = "riga malformata"
				break
			reason = _row_problem(row, idx)
			if not reason.is_empty():
				break
			if row[idx["block"]] == "check" and row[idx["condition"]] == "interrotta":
				reason = "sessione interrotta prima della fine"
				break
			rows.append(row)
		if not reason.is_empty():
			excluded.append(f + ": " + reason)
			continue
		# file valido: solo ora entra nella somma
		var session_psi := {}
		var session_fixed := {}
		var used_by := {}
		var px := -1.0
		for c in COND:
			session_psi[c] = Psi.new(1.0 / COND[c]["n_alt"], COND[c]["level_max"])
			session_fixed[c] = {}
		for row in rows:
			if row[idx["block"]] == "check":
				continue
			var c: String = row[idx["condition"]]
			var correct: bool = row[idx["correct"]] == "1"
			var lv: float = row[idx["log10_disparity"]].to_float()
			var key := "%.2f" % lv
			px = maxf(px, row[idx["px_arcsec"]].to_float())
			match row[idx["block"]]:
				"main":
					used_by[c] = true
					if COND[c].get("fixed", false):
						_count(fixed_pooled[c], key, correct)
						_count(session_fixed[c], key, correct)
					else:
						var p: Psi = pooled[c]
						p.update(p.level_index(lv), correct)
						var sp: Psi = session_psi[c]
						sp.update(sp.level_index(lv), correct)
						if row[idx["level_rule"]] == "coverage":
							_count(coverage_pooled[c], key, correct)
				"control":
					var src := int(row[idx["mono_source"]])
					ctrl[c][src][0] += 1 if correct else 0
					ctrl[c][src][1] += 1
		for c in used_by:
			sessions_by[c] = sessions_by.get(c, 0) + 1
		if not used_by.is_empty():
			var entry := {"file": f, "px_arcsec": px}
			for c in used_by:
				entry[c] = session_fixed[c] if COND[c].get("fixed", false) else session_psi[c].summary()
			per_session.append(entry)
			if px > 0.0:
				px_values.append(px)
	var out := {"sessions": per_session.size(), "sessions_by_condition": sessions_by, "excluded": excluded,
		"per_session": per_session, "controls": ctrl, "coverage": coverage_pooled, "px_arcsec": px_values}
	for c in COND:
		out[c] = fixed_pooled[c] if COND[c].get("fixed", false) else pooled[c].summary()
	return out


## Perché una riga non può entrare nella somma ("" se può).
func _row_problem(row: PackedStringArray, idx: Dictionary) -> String:
	if row[idx["protocol"]] != PROTOCOL:
		return "altro protocollo"
	if row[idx["participant"]] != participant:
		return "altro partecipante"
	if row[idx["mode"]] != mode_name:
		return "altra modalità"
	if row[idx["setting"]] != setting:
		return "altra impostazione (%s)" % row[idx["setting"]]
	if row[idx["contrast_lr"]] != contrast_key():
		return "altro contrasto per occhio (%s)" % row[idx["contrast_lr"]]
	var block := row[idx["block"]]
	if block == "check":
		return ""
	if block not in ["practice", "main", "control"]:
		return "blocco non valido"
	if not COND.has(row[idx["condition"]]):
		return "condizione sconosciuta"
	if row[idx["correct"]] not in ["0", "1"]:
		return "esito non valido"
	var lv := row[idx["log10_disparity"]]
	if not lv.is_valid_float() or lv.to_float() < 0.5 or lv.to_float() > 4.5:
		return "disparità non valida"
	if row[idx["level_rule"]] not in LEVEL_RULES:
		return "regola del livello non valida"
	if not row[idx["px_arcsec"]].is_valid_float():
		return "risoluzione non valida"
	var src := row[idx["mono_source"]]
	if block == "control" and src not in ["0", "1"]:
		return "controllo senza occhio sorgente"
	if block != "control" and src != "-1":
		return "occhio sorgente fuori dai controlli"
	return ""


## Quantile di una Beta(a, b): vedi stats.gd (stabile anche con conteggi grandi, N5).
static func beta_quantile(a: float, b: float, q: float) -> float:
	return Stats.beta_quantile(a, b, q)


static func _pct_ci(k: int, n: int) -> String:
	return "95%% CI %d–%d%%" % [roundi(100 * beta_quantile(k + 1.0, n - k + 1.0, 0.025)),
		roundi(100 * beta_quantile(k + 1.0, n - k + 1.0, 0.975))]


static func _p_eq(p: float) -> String:
	return "< 0.001" if p < 0.001 else "= %.3f" % p


static func fmt_disparity(log10_arcsec: float) -> String:
	var arcsec := pow(10.0, log10_arcsec)
	if arcsec < 3000.0:
		return "%d″" % roundi(arcsec)
	return "%.1f°" % (arcsec / 3600.0)


## Controlli monoculari: nel controllo entrambi gli occhi vedono l'immagine di un solo occhio
## (sorgente alternata). Negli anelli un indizio monoculare è sfruttabile solo conoscendo l'occhio
## (chi sopprime stabilmente un occhio lo "conosce"): per questo il conteggio è separato per
## sorgente. Famiglia dichiarata: totale, sorgente sinistra, sorgente destra; test binomiali
## esatti unilaterali contro il caso, corretti con Holm (errore complessivo 5%, N3).
static func describe_control(cond: String, counts: Array) -> String:
	var k: int = counts[0][0] + counts[1][0]
	var n: int = counts[0][1] + counts[1][1]
	if n == 0:
		return "no trials"
	var chance: float = 1.0 / COND[cond]["n_alt"]
	var limit: float = COND[cond]["leak_limit"]
	var txt := "%d/%d (%s, chance %d%%; left-eye image %d/%d, right-eye image %d/%d): " % [k, n, _pct_ci(k, n),
		roundi(100 * chance), counts[0][0], counts[0][1], counts[1][0], counts[1][1]]
	var ps := [Stats.binom_upper(k, n, chance)]
	for src in 2:
		if counts[src][1] > 0:
			ps.append(Stats.binom_upper(counts[src][0], counts[src][1], chance))
	var adj: Array = Stats.holm(ps)
	var p_min: float = adj.min()
	var all_below_limit := beta_quantile(k + 1.0, n - k + 1.0, 0.975) < limit
	for src in 2:
		var ks: int = counts[src][0]
		var ns: int = counts[src][1]
		if ns == 0 or beta_quantile(ks + 1.0, ns - ks + 1.0, 0.975) >= limit:
			all_below_limit = false
	if p_min < ALPHA:
		return txt + "above chance after correction (Holm p %s): a signal compatible with a non-stereo cue, to be checked with more control trials" % _p_eq(p_min)
	if all_below_limit:
		return txt + "no signal above chance (Holm p %s); a one-eye cue above %d%% is ruled out" % [_p_eq(p_min), roundi(100 * limit)]
	return txt + "no signal above chance (Holm p %s), but too few trials to rule out a cue above %d%%" % [_p_eq(p_min), roundi(100 * limit)]


## Stimoli costanti (e fasce fisse): una famiglia di caselle livello x condizione, dichiarata
## prima. Per ogni casella: prove giuste, p esatto unilaterale contro il caso e p di Holm
## sull'intera famiglia (N3). Le caselle vanno anche nel riepilogo JSON.
static func family_cells(conds: Array, counts_by_cond: Dictionary) -> Array:
	var cells := []
	for c in conds:
		var counts: Dictionary = counts_by_cond.get(c, {})
		var keys := counts.keys()
		keys.sort()
		for key in keys:
			var kn: Array = counts[key]
			if kn[1] > 0:
				cells.append({"condition": c, "log10_disparity": float(key), "correct": kn[0], "n": kn[1],
					"chance": 1.0 / COND[c]["n_alt"], "p": Stats.binom_upper(kn[0], kn[1], 1.0 / COND[c]["n_alt"])})
	var ps := []
	for cell in cells:
		ps.append(cell["p"])
	var adj: Array = Stats.holm(ps)
	for i in cells.size():
		cells[i]["p_holm"] = adj[i]
		cells[i]["above_chance"] = adj[i] < ALPHA
	return cells


## Righe da mostrare per una famiglia di caselle: accuratezza e IC95% per casella, poi la decisione.
static func describe_family(conds: Array, counts_by_cond: Dictionary, what := "level") -> Array:
	var cells := family_cells(conds, counts_by_cond)
	if cells.is_empty():
		return ["no data"]
	var lines := []
	var above := PackedStringArray()
	for c in conds:
		var parts := PackedStringArray()
		var hits := PackedStringArray()
		for cell in cells:
			if cell["condition"] != c:
				continue
			var lv := fmt_disparity(cell["log10_disparity"])
			parts.append("%s %d/%d (%s)" % [lv, cell["correct"], cell["n"], _pct_ci(cell["correct"], cell["n"])])
			if cell["above_chance"]:
				hits.append(lv)
		if not parts.is_empty():
			lines.append("%s (chance %d%%): %s" % [COND[c]["label"], roundi(100.0 / COND[c]["n_alt"]), "; ".join(parts)])
		if not hits.is_empty():
			above.append("%s at %s" % [COND[c].get("short", COND[c]["label"]).to_lower(), ", ".join(hits)])
	if above.is_empty():
		lines.append("No %s above chance after correcting for %d comparison%s (Holm): discrimination not shown at the levels tried. With few trials the intervals stay wide and don't rule out moderate performance." % [what, cells.size(), "" if cells.size() == 1 else "s"])
	else:
		lines.append("Above chance after correcting for %d comparison%s (Holm): %s." % [cells.size(), "" if cells.size() == 1 else "s", "; ".join(above)])
	return lines


const BAND_LABELS := ["<200″", "200–600″", "600–2000″", "≥2000″"]


static func describe_bands(s: Dictionary) -> String:
	var parts := PackedStringArray()
	var bands: Array = s.get("bands", [])
	for i in bands.size():
		if bands[i][1] > 0:
			parts.append("%s %d/%d" % [BAND_LABELS[i], bands[i][0], bands[i][1]])
	return "trials per band: " + ", ".join(parts)


static func describe(s: Dictionary) -> String:
	match s.get("outcome", "no_data"):
		"no_data":
			return "no data"
		"flat":
			return "not measurable: the data look more like constant accuracy than a curve (log10 BF = %.2f); %s" % [s["log10_bf_psychometric_vs_constant"], describe_bands(s)]
		"inconclusive":
			return "not measurable yet: weak evidence that performance depends on disparity (log10 BF = %.2f); %s" % [s["log10_bf_psychometric_vs_constant"], describe_bands(s)]
		"above":
			return "discrimination not shown at the levels tried (up to %d″). The model assumes performance rises with disparity, so it put most trials at the top: %s" % [roundi(s["level_max_arcsec"]), describe_bands(s)]
		"below":
			return "below the smallest disparity tried (%d″): the test doesn't go lower" % roundi(s["level_min_arcsec"])
	var txt := "threshold %d″ (95%% CI %d–%d″)" % [roundi(s["arcsec_q50"]), roundi(s["arcsec_q025"]), roundi(s["arcsec_q975"])]
	if s["outcome"] == "wide":
		txt = "provisional " + txt + ", too uncertain: more sessions needed"
	else:
		if s["upper_open"]:
			txt += ", upper bound beyond the largest disparity tried"
		if s["lower_open"]:
			txt += ", lower bound below the smallest disparity tried"
	txt += "; best accuracy ~%d%% (CI %d–%d%%, chance %d%%)" % [roundi(100 * s["pmax_mean"]),
		roundi(100 * s["pmax_q025"]), roundi(100 * s["pmax_q975"]), roundi(100 * s["gamma"])]
	return txt


## Fasce fisse della sessione standard. Una fascia sopra il caso è normale per chi discrimina:
## l'avviso di possibile non monotonicità scatta solo se il Psi NON ha trovato una curva
## (esiti "above", "flat", "inconclusive") e intanto una fascia fissa è sopra il caso, cioè se
## la procedura adattiva potrebbe aver mancato una fascia utile (0.5.1, review T6).
static func describe_coverage(cond: String, counts: Dictionary, outcome := "") -> String:
	if counts.is_empty():
		return ""
	var lines: Array = describe_family([cond], {cond: counts}, "fixed level")
	var txt := "  fixed bands: " + String(lines[0]).split(": ", true, 1)[1]
	var above := String(lines[-1]).begins_with("Above")
	if above and outcome in ["above", "flat", "inconclusive"]:
		txt += ". WARNING: " + lines[-1] + " The adaptive model found no curve, but a fixed band is above chance: performance may not rise with disparity, so the model's result shouldn't be read as no discrimination."
	elif above:
		txt += ". " + lines[-1]
	else:
		txt += ". No band above chance (Holm)."
	return txt


## Storia di una condizione a livelli fissi, sessione per sessione (0.6, per gli anelli fissi):
## le stesse disparità ogni volta, quindi i conteggi si confrontano direttamente.
static func describe_history(cond: String, per_session: Array) -> Array:
	var lines := []
	for e in per_session:
		if not e.has(cond):
			continue
		var counts: Dictionary = e[cond]
		var keys := counts.keys()
		keys.sort()
		var parts := PackedStringArray()
		var k := 0
		var n := 0
		for key in keys:
			parts.append("%s %d/%d" % [fmt_disparity(float(key)), counts[key][0], counts[key][1]])
			k += int(counts[key][0])
			n += int(counts[key][1])
		var f: String = e.get("file", "")
		var day := "%d/%d" % [f.substr(15, 2).to_int(), f.substr(13, 2).to_int()] if f.length() >= 17 else f
		lines.append("  %s: %s (total %d/%d)" % [day, ", ".join(parts), k, n])
	return lines.slice(maxi(0, lines.size() - 6))   # nel visore bastano le ultime sei


func _finish() -> void:
	state = S.DONE
	_measure_display()
	var summary := {
		"session": session_id, "participant": participant, "protocol": PROTOCOL, "version": VERSION,
		"mode": mode_name, "setting": setting, "session_type": session_type,
		"date": Time.get_datetime_string_from_system(),
		"checks": checks, "nonius_reading": nonius_reading(checks), "eye_contrast": [eye_contrast.x, eye_contrast.y],
		"pixel_arcsec_render": pixel_arcsec, "render_size": [render_size.x, render_size.y],
		"eye_separation_m": eye_separation_m, "view_distance_m": VIEW_DISTANCE,
		"threshold_definition": "alpha Weibull su log10 arcsec: 63,2% dell'ampiezza sopra il caso; IC = intervalli di credibilità bayesiani condizionati al modello",
		"decision_rule": "sopra il caso: test binomiali esatti unilaterali, Holm sulla famiglia dichiarata, alfa 0,05",
	}
	var lines := ["RESULTS (%s, %s session)" % [participant, SHOW_SESSION.get(session_type, session_type)], ""]
	var fixed_conds := []
	for c in session_conds:
		if COND[c].get("fixed", false):
			fixed_conds.append(c)
			summary[c] = fixed_counts[c]
		else:
			var s: Dictionary = psis[c].summary()
			summary[c] = s
			lines.append("%s: %s" % [COND[c]["label"], describe(s)])
			var cov := describe_coverage(c, coverage_counts[c], s.get("outcome", ""))
			if not cov.is_empty():
				summary[c + "_coverage"] = coverage_counts[c]
				lines.append(cov)
	if not fixed_conds.is_empty():
		summary["family"] = family_cells(fixed_conds, fixed_counts)
		lines.append_array(describe_family(fixed_conds, fixed_counts))
		for c in fixed_conds:
			if COND[c].has("criterion"):
				var kn := [0, 0]
				for key in fixed_counts[c]:
					kn[0] += int(fixed_counts[c][key][0])
					kn[1] += int(fixed_counts[c][key][1])
				var crit: int = COND[c]["criterion"]
				var passed: bool = kn[0] >= crit and kn[1] >= COND[c]["per_level"] * COND[c]["levels"].size()
				summary["criterion"] = {"condition": c, "required": crit, "correct": kn[0], "n": kn[1], "passed": passed}
				lines.append("Criterion set before these data: at least %d correct out of %d. This session: %d of %d, %s." % [
					crit, COND[c]["per_level"] * COND[c]["levels"].size(), kn[0], kn[1],
					"passed" if passed else ("not passed" if kn[1] >= COND[c]["per_level"] * COND[c]["levels"].size() else "session incomplete")])
	summary["control"] = {}
	lines.append("")
	for c in session_conds:
		summary["control"][c] = controls[c]
		lines.append("One-eye control, %s: %s" % [COND[c].get("short", COND[c]["label"]).to_lower(), describe_control(c, controls[c])])
	var pooled := pooled_summary(results_dir)
	summary["pooled"] = pooled
	for c in session_conds:
		if c in FIXED_RING_CONDITIONS:
			var hist := describe_history(c, pooled.get("per_session", []))
			if hist.size() >= 2:
				lines.append("")
				lines.append("%s, session by session (same disparities):" % COND[c]["label"])
				lines.append_array(hist)
	var pooled_lines := []
	var pooled_ctrl := []
	var pooled_fixed := []
	var n_fixed_sessions := 0
	for c in session_conds:
		var n_sess: int = pooled.get("sessions_by_condition", {}).get(c, 0)
		if n_sess < 2:
			continue
		if COND[c].get("fixed", false):
			pooled_fixed.append(c)
			n_fixed_sessions = maxi(n_fixed_sessions, n_sess)
		else:
			pooled_lines.append("%s, %d sessions: %s" % [COND[c]["label"], n_sess, describe(pooled[c])])
			var cov := describe_coverage(c, pooled["coverage"][c], pooled[c].get("outcome", ""))
			if not cov.is_empty():
				pooled_lines.append(cov)
		pooled_ctrl.append("One-eye control, %s: %s" % [COND[c].get("short", COND[c]["label"]).to_lower(), describe_control(c, pooled["controls"][c])])
	if not pooled_fixed.is_empty():
		pooled["family"] = family_cells(pooled_fixed, pooled)
		pooled_lines.append("%d sessions:" % n_fixed_sessions)
		pooled_lines.append_array(describe_family(pooled_fixed, pooled))
	pooled_lines.append_array(pooled_ctrl)
	if not pooled_lines.is_empty():
		lines.append("")
		lines.append("All compatible sessions of %s (protocol %s, setting %s):" % [participant, PROTOCOL, setting])
		lines.append_array(pooled_lines)
		var px: Array = pooled.get("px_arcsec", [])
		if px.size() >= 2 and px.max() > 1.25 * px.min():
			lines.append("Note: render resolution differs across the pooled sessions (%d–%d″ per pixel)." % [roundi(px.min()), roundi(px.max())])
	if not pooled["excluded"].is_empty():
		lines.append("Files not pooled (other protocols, conditions or stopped sessions): %d, listed with the reason in the summary file." % pooled["excluded"].size())
	lines.append("")
	lines.append("Eye check: %s." % SHOW_CHECK.get(checks["eyecheck"], checks["eyecheck"]))
	lines.append("Little lines: top, left eye alone: %s; bottom, right eye alone: %s; both eyes open: %s. Reading: %s." % [
		SHOW_CHECK.get(checks["nonius_sx"], checks["nonius_sx"]), SHOW_CHECK.get(checks["nonius_dx"], checks["nonius_dx"]),
		SHOW_CHECK.get(checks["nonius"], checks["nonius"]), SHOW_NONIUS_READING.get(nonius_reading(checks), nonius_reading(checks))])
	if pixel_arcsec > 0:
		lines.append("1 render pixel ≈ %d″ (not the panel resolution)." % roundi(pixel_arcsec))
	var rs := roll_summary(posture_rolls)
	var extra := {"file": "postura/" + posture_path.get_file() if not posture_path.is_empty() else ""}
	if not posture_ranges.is_empty():
		var rg := posture_ranges.duplicate()
		rg.sort()
		extra["escursione_mediana_deg"] = rg[rg.size() / 2]
		extra["prove_con_escursione_oltre_5_deg"] = rg.filter(func(x): return x > 5.0).size()
	summary["postura"] = rs.merged(extra)
	if not rs.is_empty():
		lines.append("Head: median roll %+.1f° (10th–90th percentile %+.1f…%+.1f°; positive toward the right shoulder)." % [
			rs["rollio_mediano_deg"], rs["rollio_q10_deg"], rs["rollio_q90_deg"]])
	if extra.has("escursione_mediana_deg"):
		lines.append("During the stimulus the head tilted by a median %.1f°; more than 5° in %d trials." % [extra["escursione_mediana_deg"], extra["prove_con_escursione_oltre_5_deg"]])
	lines.append("")
	lines.append("Trigger (or Space) to return to the hut." if from_capanna else "Trigger (or Space) to close.")
	if not _save_json(results_dir + "sessione_%s_riepilogo.json" % session_id, summary):
		lines.insert(1, "WARNING: JSON summary not saved (the trials are still in the CSV).")
	var text := "\n".join(lines)
	print("STEREOPSI_RESULT\n" + text)
	label.font_size = 34
	_show_text(text, 62)
	if autotest:
		get_tree().quit()


## Scrittura atomica del riepilogo (N8): file temporaneo, controllo degli errori, poi rinomina.
## Se qualcosa va storto non resta un riepilogo parziale col nome definitivo.
static func _save_json(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var fa := FileAccess.open(tmp, FileAccess.WRITE)
	if fa == null:
		return false
	var stored := fa.store_string(JSON.stringify(data, "  "))
	fa.flush()
	var err := fa.get_error()
	fa.close()
	if not stored or err != OK:
		DirAccess.remove_absolute(tmp)
		return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.remove_absolute(tmp)
		return false
	return true


# ---------------------------------------------------------------- verifica visiva

func _apply_params(level: float, cond: String, params: Dictionary) -> void:
	_set_param("disparity_deg", pow(10.0, level) / 3600.0)
	_set_param("target_index", params["target"])
	_set_param("seed_bg", params["seed_bg"])
	_set_param("seed_rg", params["seed_rg"])
	_set_param("ring_jitter", params["jitter"])
	_set_param("mono_source", params["mono"])
	_set_param("progress", -1.0)
	_set_geometry(cond)
	_show_field(COND[cond]["mode"], false, COLOR_NEUTRAL)


func _save_pair(prefix: String) -> void:
	# A: quad sinistro = occhio sinistro; B: quad sinistro = occhio destro (stessa griglia di pixel)
	for variant in ["A", "B"]:
		materials[0].set_shader_parameter("eye_override", 0 if variant == "A" else 1)
		materials[1].set_shader_parameter("eye_override", 1 if variant == "A" else 0)
		for f in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, variant])


func _capture(prefix: String) -> void:
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	var shots := [
		{"name": "rds", "cond": "rds", "level": log(1200.0) / log(10.0), "target": 1, "mono": -1},
		{"name": "rds_small", "cond": "rds", "level": 1.7, "target": 2, "mono": -1},
		{"name": "rds_max", "cond": "rds", "level": 3.5, "target": 3, "mono": -1},
		{"name": "rds_coarse", "cond": "rds_coarse", "level": 3.95, "target": 1, "mono": -1},
		{"name": "rds_control", "cond": "rds", "level": 3.4, "target": 0, "mono": 0},
		{"name": "rds_grande", "cond": "rds_grande", "level": 3.6, "target": 1, "mono": -1},
		{"name": "rds_grande_mid", "cond": "rds_grande", "level": log(1200.0) / log(10.0), "target": 3, "mono": -1},
		{"name": "rds_grande_control", "cond": "rds_grande", "level": 3.6, "target": 2, "mono": 1},
		{"name": "rds_1000", "cond": "rds", "level": 3.0, "target": 1, "mono": -1},
		{"name": "rds_1000_40", "cond": "rds_1000_40", "level": 3.0, "target": 1, "mono": -1},
		{"name": "rings", "cond": "rings", "level": 3.0, "target": 0, "mono": -1},
		{"name": "rings_control", "cond": "rings", "level": 3.0, "target": 1, "mono": 1},
	]
	for shot in shots:
		var params := trial_params(4242, shot["cond"])
		params["target"] = shot["target"]
		params["mono"] = shot["mono"]
		_apply_params(shot["level"], shot["cond"], params)
		await _save_pair("%s_%s" % [prefix, shot["name"]])
	_set_param("mono_source", -1)
	_set_geometry("")
	_set_param("progress", 0.4)
	_show_field(0, true, COLOR_NEUTRAL)
	await _save_pair(prefix + "_nonius")
	_set_param("progress", -1.0)
	_show_field(3, false, COLOR_NEUTRAL)
	await _save_pair(prefix + "_eyecheck")


## Catture random-dot con parametri registrati, per i controlli monoculari (manifest.json).
## Formato normale: 1259, 300, 50, 3000″; formato grande: 3981, 1585, 251, 631″.
## Con only_arcsec > 0 tutte le catture sono a quella disparità, con semi indipendenti
## (repliche di un risultato esplorativo).
func _capture_heldout(directory: String, n: int, cond := "rds", only_arcsec := 0.0) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest := []
	var r := RandomNumberGenerator.new()
	r.seed = (20260929 if cond == "rds" else 20261001) + int(only_arcsec) * 7919
	var disparities := [1258.93, 300.0, 50.0, 3000.0]
	if COND[cond].get("geometry", "normale") == "grande":
		disparities = [3981.07, 1584.89, 251.19, 630.96]
	if only_arcsec > 0.0:
		disparities = [only_arcsec]
	for i in n:
		var seed_ := r.randi()
		var params := trial_params(seed_, cond)
		params["target"] = i % 4
		var d: float = disparities[int(i / 4.0) % disparities.size()]
		_apply_params(log(d) / log(10.0), cond, params)
		var base_name := "%s/probe_%04d" % [directory, i]
		await _save_pair(base_name)
		manifest.append({"file": "probe_%04d" % i, "target": params["target"], "disparity": d, "trial_seed": seed_, "condition": cond})
	var f := FileAccess.open(directory + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "  "))
	f.close()
	print("STEREOPSI_HELDOUT %d" % n)
