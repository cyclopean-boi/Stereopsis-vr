extends Node3D
## Le rovine — training 0.5.0 (mondo 2): il ponte dalla stereopsi locale a quella globale.
## Il compito è quello del random-dot del test: quattro creature nascoste nella pietra, una
## DAVANTI e tre DIETRO alla stessa |disparità|; si indica quella davanti con la levetta.
## Tre tipi di prova, mescolati in blocchi di 10:
## - 2 SONDE: random-dot puro, identico al test (formato normale, 1000″), nessuna rotella. Sono il
##   vero bersaglio e si contano a parte, con posizioni del bersaglio bilanciate;
## - 4 del sentiero delle SCAGLIE: macchie chiare, rade e grandi, alla profondità della superficie
##   su cui stanno, che si fondono una per una con la stereopsi locale; il loro contrasto sfuma
##   con una scala 3/1 fino al random-dot puro;
## - 4 del sentiero del VENTO: parallasse di movimento, le creature scorrono con la testa in
##   proporzione alla profondità; il guadagno sfuma con una scala 3/1 fino a zero.
## Il contorno delle creature non è una rotella: ogni occhio lo vedrebbe spostato di d/2 in un
## verso per la creatura davanti e nel verso opposto per le altre, un indizio monoculare forte.
## 0.5.1 (review Codex RV1–RV6, protocollo r2):
## - il bersaglio di ogni prova è estratto a caso, indipendente dalle precedenti (RV1);
## - portale e torre si decidono con una regola sequenziale (rovine_misure.gd, e_process) (RV2);
## - le scale hanno esiti agli estremi e le mosse bloccate non contano come inversioni (RV3);
## - il vento è uno SPOSTAMENTO massimo in gradi, che satura con un centimetro di movimento della
##   testa (-A tanh(dx / 1 cm)): muoversi di più non aumenta l'aiuto. Se la testa resta ferma
##   (meno di 1 cm) l'aiuto non arriva, e la prova non muove la scala (RV4);
## - CSV validati per intero, introduzione in due pagine (RV5, RV6).
## 0.5.2 (protocollo r3, dopo la prima sessione vera del 29/9): nel visore la testa oscilla di
## pochi millimetri (mediana 4 mm), e con la soglia di 1 cm 89 prove del vento su 93 erano "vento
## non arrivato": la scala era ferma. Ora lo spostamento satura in 3 mm (-A tanh(dx / 3 mm)) e il
## vento conta come arrivato se lo spostamento MOSTRATO ha raggiunto metà dell'ampiezza A.
## 0.5.3 (stesso protocollo r3): il grilletto (o Spazio) premuto durante lo stimolo, prima della
## levetta o insieme, segna la prova come "vista davvero" (colonna "sicuro" del CSV). Serve a capire
## se le prove in cui il giocatore sente di vedere vanno meglio delle altre. Stimoli e regole invariati.
## Nella stessa versione il tempo per rispondere passa da 12 a 30 s (le scadute restano fuori dai conteggi).
## Lo stimolo è solidale con la testa (come nel test), il panorama delle rovine sta a distanza
## infinita. Progetto: DESIGN_TRAINING.md, sezione "Mondo 2".

## 0.5.4 (3/10, stesso protocollo r3): tre colonne nuove nel CSV, solo registrazione: rollio della
## testa alla comparsa dello stimolo e alla risposta, beccheggio alla comparsa (head_roll_deg,
## head_roll_resp_deg, head_pitch_deg). Lo stimolo è solidale con la testa: la postura non lo cambia.

## 0.5.6 (5/10, protocollo r4): il sentiero del MOSAICO prende il posto del vento. Parte dal
## random-dot nel formato grande a 3981″ (dove la verifica del 4/10 ha dato 29/40) e scende verso la
## pietra nuda girando una manopola per gradino: disparità, grana dei punti, grandezza ed eccentricità
## delle regioni (rovine_misure.gd, MOSAIC_STEPS). Due prove su dieci sono di POLARITÀ:
## stesso gradino, punti solo scuri o solo chiari, fuori dalla scala. Sonde e scaglie invariate.
## Il quad è più grande (20° invece di 13°) perché il formato grande arriva a 9,9° dal centro; lo
## stimolo, in gradi, non cambia.

## 0.5.10 (12/10, stesso protocollo r4): le SCAGLIE escono dal blocco, su richiesta. Nel r4
## andavano peggio della pietra nuda (63/156 contro 50/100) e la loro scala non si era mai mossa dal
## contrasto pieno. I tre posti vanno al mosaico (+2) e alle sonde (+1): 3 sonde, 5 mosaico, 2 polarità.
## Stimoli invariati (sonde, mosaico e polarità identici), quindi il protocollo resta r4 e le sonde si
## sommano con quelle di prima; il codice delle scaglie resta per leggere i file passati e per l'autotest.
## I pezzi delle scaglie si restaurano anche col mosaico (rovine_misure.gd, PEZZI, "alt").

## 0.5.13 (19/10, protocollo r5): il mosaico prosegue OLTRE la pietra nuda, su richiesta (una pietra nuda adattiva):
## dodici gradini nel formato del test che girano solo la disparità, da 1000″ a 251″ a passi di 0,05 in log10 (la griglia della Psi del test). Sonde, blocco e
## gradini 0–9 identici. Quattro pezzi nuovi, l'osservatorio (794, 631, 501 e 398″). La FILA DELLE PIETRE in
## alto mostra il gradino del mosaico: si vede solo fra una prova e l'altra (riscontro e intervallo) e
## nella pausa, mai durante la croce e lo stimolo, così le sonde restano come prima. Tolta dal riepilogo la
## riga dell'evidenza contro il caso (19/10: non serviva più; e oltre
## 9,2·10^18 il numero traboccava: roundi dava -9223372036854775808).

const Paths := preload("res://scripts/paths.gd")
const VERSION := "training-0.5.13"
const Misure := preload("res://scripts/training/rovine_misure.gd")
const Geo := preload("res://scripts/training/geometry.gd")
const Ponte := preload("res://scripts/training/ponte.gd")
const Progress := preload("res://scripts/training/progress.gd")
const Cielo := preload("res://scripts/training/rovine_cielo.gd")
const Fit := preload("res://scripts/training/fit.gd")
const RovineShader := preload("res://shaders/rovine.gdshader")

const VIEW_DISTANCE := 1.5
const FIELD_HALF_DEG := 20.0     # 0.5.6: era 13; il formato grande del mosaico arriva a 9,9°, col portale a ~20°
const GEOMETRY := {"rds_ecc": 3.2, "region_r": 1.4, "cell": 0.2, "dot_r": 0.075, "field_extent": 6.0}   # formato normale del test
const GEOMETRY_KEYS := ["rds_ecc", "region_r", "cell", "dot_r", "field_extent"]
const POLARITY_MODE := {"misti": 0, "scuri": 1, "chiari": 2}
const DISPARITY_ARCSEC := 1000.0
const SCALE_R_DEG := 0.2        # scaglie: dischi chiari di raggio 0,2° (quasi il triplo dei punti), 1 per grado quadrato
## 0.5.6: 2 sonde, 3 scaglie, 3 mosaico e 2 polarità ogni 10 prove (prima: 2 sonde, 4 scaglie, 4 vento).
## Due prove di polarità e non una perché il confronto scuri/chiari abbia una risposta in una o due
## settimane di notti invece che in un mese (DESIGN_TRAINING.md, 0.5.6); il costo è una prova delle scaglie.
## 0.5.10: 3 sonde, 5 mosaico, 2 polarità (prima 2 sonde, 3 scaglie, 3 mosaico, 2 polarità).
const BLOCK := ["sonda", "sonda", "sonda", "mosaico", "mosaico", "mosaico", "mosaico", "mosaico", "polarita", "polarita"]
const FIX_TIME := 0.5
const MAX_TIME := 30.0          # 0.5.3: era 12 s; nel test non c'è limite, e nel random-dot la profondità può metterci secondi a emergere
const FEEDBACK_TIME := 1.6
const ITI := 0.3
const REST_SECONDS := 20.0
const DAY_SOFT_CAP := 3600.0
const PARALLAX_MAX_DEG := 0.8
const SWAY_MAX_M := 0.10
const SWAY_REF_M := 0.003       # vento: con 3 mm di movimento lo spostamento è al 76% dell'ampiezza
const CUE_MIN_FRAC := 0.5       # vento arrivato se lo spostamento mostrato ha raggiunto metà dell'ampiezza
const WARMUP := 2
const DESKTOP_IPD := 0.063
const CREATURES := ["cervo", "serpente", "uccello", "lucertola", "orante", "rosa"]
const MUSIC_DIR := "res://musica"
const MUSIC_DEFAULT := 0.7
const MUSIC_FADE_IN := 2.0
const MUSIC_FADE_OUT := 3.0
const MUSIC_TAIL := 20.0
const SFX_DEFAULT := 0.5
const HEADER := Misure.HEADER
## 0.5.13: la fila delle pietre (gradino del mosaico). In gradi sul piano del testo, a 1,35 m.
const STONE_STEP_DEG := 0.7
const STONE_R_DEG := 0.2
const STONE_EL_DEG := 17.6       # sopra la riga in alto (15,2°): fuori dal campo del formato normale e del grande
const STONE_PULSE_S := 0.9
const OSSERVATORIO_RUNGS := [11, 13, 15, 17]

enum S { INTRO, FIX, STIM, FEEDBACK, ITI_WAIT, REST, PAUSED, END, ERROR }
const PLAY_STATES := [S.FIX, S.STIM, S.FEEDBACK, S.ITI_WAIT]
const STONE_SHOW := [S.FEEDBACK, S.ITI_WAIT, S.REST]        # 0.5.13: mai durante la croce e lo stimolo

var state := S.INTRO
var timer := 0.0
var xr_active := false
var autotest := false
var participant := "anonimo"
var session_id := ""
var mode_name := "desktop"
var results_dir := ""
var csv: FileAccess
var csv_path := ""
var rng := RandomNumberGenerator.new()
var prog := Progress.new()
var paths := {"scaglie": Ponte.new(Misure.SCALE_LEVELS), "mosaico": Ponte.new(Misure.MOSAIC_LEVELS)}
var polarity_bag: Array = []
var from_capanna := false
var block_seconds := 720.0
var blocco_arg := false
var play_seconds := 0.0
var block_played := 0.0
var _saved_seconds := 0.0
var autotest_trials := 150
var sim_global := 0.25
var sim_c50 := 0.2
var sim_g50 := 0.1
var sim_sway := 0.02
var sim_still := 0.0
var sim_sure := 0.3
var sim_m50 := 4.0               # 0.5.6: gradino del mosaico al 50% dell'osservatore simulato
var sim_dark := 0.0              # 0.5.6: vantaggio (in gradini) dei punti scuri per l'osservatore simulato
var capture_path := ""
var capture_kind := ""
var fix_time := FIX_TIME
var feedback_time := FEEDBACK_TIME
var iti := ITI

var origin: XROrigin3D
var camera: Node3D
var env: Environment
var controllers: Array[XRController3D] = []
var trigger_prev := {}
var quit_prev := {}
var stick_armed := {}
var materials: Array[ShaderMaterial] = []
var quads: Array[MeshInstance3D] = []
var label: Label3D
var hud: Label3D
var wind: Label3D
var pixel_arcsec := -1.0
var creature_tex := {}

var music: AudioStreamPlayer
var music_tracks: Array[AudioStream] = []
var music_names: Array[String] = []
var music_idx := 0
var music_volume := MUSIC_DEFAULT
var music_arg := -1.0
var music_tween: Tween
var sfx: Array[AudioStreamPlayer] = []
var sfx_next := 0
var sounds := {}
var sfx_volume := SFX_DEFAULT
var sfx_arg := false

var trial := 0
var night := 1
var cur := {}
var block_bag: Array = []
var capture_rung := 0
var capture_polarity := "misti"
var capture_series := 0
var trial_time := 0.0
var head0 := Vector3.ZERO
var lateral := Vector3.RIGHT
var fwd0 := Vector3.FORWARD
var sway_max := 0.0
var parallax_max := 0.0
var intro_page := 0
var rot_max := 0.0
var fake_sway := 0.0
var found := 0
var answered := 0
var combo := 0
var session_rows: Array = []
var night_rows: Array = []
var new_pieces: Array = []
var rest_lore := ""
var resume_to := S.ITI_WAIT
var sentiero: Node3D                # 0.5.13: la fila delle pietre
var stones: Array[MeshInstance3D] = []
var stone_today: MeshInstance3D
var stone_ever: MeshInstance3D
var stone_mats := {}
var stone_pos: Array[Vector3] = []
var stone_size := 0.01
var rung_today := -1
var rung_ever := -1
var stone_last := -1
var stone_pulse := 0.0


func _ready() -> void:
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	autotest = "--autotest" in args
	for a in args:
		if a.begins_with("--partecipante="):
			participant = a.split("=")[1]
		elif a.begins_with("--blocco="):
			block_seconds = maxf(5.0, a.split("=")[1].to_float())
			blocco_arg = true
		elif a.begins_with("--prove="):
			autotest_trials = int(a.split("=")[1])
		elif a.begins_with("--sim-globale="):
			sim_global = clampf(a.split("=")[1].to_float(), 0.0, 1.0)
		elif a.begins_with("--sim-scaglie="):
			sim_c50 = maxf(1e-4, a.split("=")[1].to_float())
		elif a.begins_with("--sim-vento="):
			sim_g50 = maxf(1e-4, a.split("=")[1].to_float())
		elif a.begins_with("--sim-sicuro="):
			sim_sure = clampf(a.split("=")[1].to_float(), 0.0, 1.0)
		elif a.begins_with("--sim-mosaico="):
			sim_m50 = a.split("=")[1].to_float()
		elif a.begins_with("--sim-scuri="):
			sim_dark = a.split("=")[1].to_float()
		elif a.begins_with("--sim-fermo="):
			sim_still = clampf(a.split("=")[1].to_float(), 0.0, 1.0)
		elif a.begins_with("--musica="):
			music_arg = clampf(a.split("=")[1].to_float(), 0.0, 1.0)
		elif a.begins_with("--suoni="):
			sfx_volume = clampf(a.split("=")[1].to_float(), 0.0, 1.0)
			sfx_arg = true
		elif a.begins_with("--cattura="):
			capture_path = a.split("=")[1]
		elif a.begins_with("--cattura-tipo="):
			capture_kind = a.split("=")[1]
		elif a.begins_with("--cattura-gradino="):
			capture_rung = clampi(int(a.split("=")[1]), 0, Misure.MOSAIC_LEVELS.size() - 1)
		elif a.begins_with("--cattura-polarita="):
			capture_polarity = a.split("=")[1]
		elif a.begins_with("--cattura-serie="):
			capture_series = maxi(0, int(a.split("=")[1]))
	if get_tree().root.has_meta("rovine_opts"):
		var opts: Dictionary = get_tree().root.get_meta("rovine_opts")
		get_tree().root.remove_meta("rovine_opts")
		if participant == "anonimo":
			participant = str(opts.get("partecipante", participant))
		from_capanna = bool(opts.get("da_capanna", false))
	participant = _sanitize(participant)
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	xr_active = xr != null and xr.is_initialized() and not autotest
	mode_name = "autotest" if autotest else ("vr" if xr_active else "desktop")
	if autotest:
		fix_time = 0.001
		feedback_time = 0.001
		iti = 0.001
	if not _open_files():
		_build_world([])
		_fatal("Can't write %s" % csv_path)
		return
	_build_world(Misure.restored_ids(prog.data))
	if xr_active:
		xr.session_visible.connect(_on_focus_lost)
		xr.session_stopping.connect(_on_session_stopping)
	Misure.migrate(prog.data)
	var rv: Dictionary = prog.data.get("rovine", {})
	for k in paths:
		if rv.has(k) and rv[k] is Dictionary:
			paths[k].from_dict(rv[k], WARMUP)
	for ses in rv.get("sessioni", []):
		if ses is Dictionary:
			rung_ever = maxi(rung_ever, int(ses.get("mosaico_max", -1)))
	_update_stones()
	music_volume = clampf(float(prog.data.get("musica_volume", MUSIC_DEFAULT)), 0.0, 1.0)
	if music_arg >= 0.0:
		music_volume = music_arg
	if not blocco_arg:
		block_seconds = 60.0 * clampf(float(prog.data.get("durata_notte_min", 12)), 5.0, 30.0)
	if not sfx_arg:
		sfx_volume = clampf(float(prog.data.get("suoni_volume", SFX_DEFAULT)), 0.0, 1.0)
	for id in CREATURES:
		var t := Cielo.creature(id)
		if t != null:
			creature_tex[id] = t
	_setup_music()
	_setup_sounds()
	_show_intro()
	if not capture_path.is_empty():
		_capture_setup()
		return
	if autotest:
		_start_play()


static func _sanitize(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
	return "anonimo" if out.is_empty() else out


# ---------------------------------------------------------------- scena

func _build_world(restored: Array) -> void:
	var we := WorldEnvironment.new()
	env = Cielo.environment(restored)
	we.environment = env
	add_child(we)
	var width := 2.0 * VIEW_DISTANCE * tan(deg_to_rad(FIELD_HALF_DEG))
	var field_half := rad_to_deg(tan(deg_to_rad(FIELD_HALF_DEG)))
	origin = XROrigin3D.new()
	add_child(origin)
	label = Label3D.new()
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.0005
	label.no_depth_test = true
	label.render_priority = 20
	label.modulate = Color(0.97, 0.95, 0.9)
	label.outline_modulate = Color(0, 0, 0)
	hud = Label3D.new()
	hud.font_size = 28
	hud.outline_size = 6
	hud.pixel_size = 0.0004
	hud.no_depth_test = true
	hud.render_priority = 20
	hud.modulate = Color(1.0, 0.9, 0.62)
	wind = Label3D.new()
	wind.font_size = 30
	wind.outline_size = 6
	wind.pixel_size = 0.0004
	wind.no_depth_test = true
	wind.render_priority = 20
	wind.modulate = Color(0.7, 0.95, 1.0)
	wind.text = "~ wind: move your head slightly left and right ~"
	wind.visible = false
	var top_y := 1.35 * tan(deg_to_rad(15.2))
	if xr_active:
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var cam := XRCamera3D.new()
		cam.near = 0.05
		cam.far = 100.0
		origin.add_child(cam)
		cam.current = true
		camera = cam
		for hand in ["left_hand", "right_hand"]:
			var ctrl := XRController3D.new()
			ctrl.tracker = StringName(hand)
			ctrl.pose = &"aim"
			origin.add_child(ctrl)
			controllers.append(ctrl)
			# si parte come se i tasti fossero premuti: il grilletto ancora giù dalla capanna non conta
			trigger_prev[ctrl] = true
			quit_prev[ctrl] = true
			stick_armed[ctrl] = false
		var quad := _make_quad(width, field_half, -1)
		quad.position = Vector3(0, 0, -VIEW_DISTANCE)
		cam.add_child(quad)
		label.position = Vector3(0, 0, -1.35)
		hud.position = Vector3(0, top_y, -1.35)
		wind.position = Vector3(0, top_y - 0.05, -1.35)
		cam.add_child(label)
		cam.add_child(hud)
		cam.add_child(wind)
		var d := 1.35
		var row := []
		for i in Misure.last_rung() + 1:
			var az := deg_to_rad((i - 0.5 * Misure.last_rung()) * STONE_STEP_DEG)
			row.append(Vector3(d * tan(az), d * tan(deg_to_rad(STONE_EL_DEG)), -d))
		_build_stones(cam, row, d * tan(deg_to_rad(STONE_R_DEG)))
	else:
		# desktop: le immagini dei due occhi affiancate (sinistro a sinistra), come nel test
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = width * 1.25
		cam.position = Vector3(0, 0, 3)
		add_child(cam)
		cam.current = true
		camera = cam
		var gap := width * 0.03
		for eye in 2:
			var quad := _make_quad(width, field_half, eye)
			quad.position = Vector3((-1 if eye == 0 else 1) * (width + gap) * 0.5, 0, 0)
			add_child(quad)
		# 0.5.6: il quad è passato da 13° a 20°; il testo si ingrandisce di quanto si è allargata la vista
		var k := width / (2.0 * VIEW_DISTANCE * tan(deg_to_rad(13.0)))
		label.pixel_size = 0.00042 * k
		hud.pixel_size *= k
		wind.pixel_size *= k
		label.position = Vector3(0, 0, 0.5)
		hud.position = Vector3(0, width * 0.5 + 0.05, 0.5)
		wind.position = Vector3(0, width * 0.5 + 0.0, 0.5)
		add_child(label)
		add_child(hud)
		add_child(wind)
		var row := []
		var step := width * 0.027
		for i in Misure.last_rung() + 1:
			row.append(Vector3((i - 0.5 * Misure.last_rung()) * step, width * 0.5 + 0.095, 0.5))
		_build_stones(self, row, step * 0.29)
	_measure_display()


func _make_quad(width: float, field_half: float, eye: int) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, width)
	var mat := ShaderMaterial.new()
	mat.shader = RovineShader
	mat.set_shader_parameter("field_half", field_half)
	mat.set_shader_parameter("eye_override", eye)
	mat.set_shader_parameter("disparity_deg", DISPARITY_ARCSEC / 3600.0)
	mat.set_shader_parameter("tint", _tint())
	mat.set_shader_parameter("scale_r", SCALE_R_DEG)
	for key in GEOMETRY:
		mat.set_shader_parameter(key, GEOMETRY[key])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	materials.append(mat)
	quads.append(mi)
	return mi


## Tinta calda della pietra riportata a luminanza 1 (Rec. 709): i grigi del test non cambiano.
static func _tint() -> Vector3:
	var t := Vector3(1.06, 0.99, 0.87)
	var lum := 0.2126 * t.x + 0.7152 * t.y + 0.0722 * t.z
	return t / lum


func _set_param(param: String, value: Variant) -> void:
	for m in materials:
		m.set_shader_parameter(param, value)


func _measure_display() -> void:
	if not xr_active:
		return
	var xr := XRServer.primary_interface
	var rs := xr.get_render_target_size()
	if rs.x > 0:
		var proj: Projection = xr.get_projection_for_view(0, rs.x / rs.y, 0.05, 50.0)
		pixel_arcsec = 2.0 / (proj.x.x * rs.x) * 206264.8


# ---------------------------------------------------------------- la fila delle pietre (0.5.13)

## Una pietra per gradino del mosaico, da sinistra (formato grande) a destra (251″): lilla i gradini del
## mosaico grosso, bianca la pietra nuda (1000″), argento quelli oltre; a rombo i quattro gradini
## dell'osservatorio. Accese fino al gradino attuale, che è più grande (e pulsa quando cambia); sopra, un
## punto d'oro sul gradino più avanzato di oggi; sotto, uno chiaro sul più avanzato di sempre.
func _build_stones(parent: Node3D, row: Array, radius: float) -> void:
	sentiero = Node3D.new()
	sentiero.name = "Sentiero"
	parent.add_child(sentiero)
	stone_size = radius
	for k in [["grosso", Color(0.85, 0.6, 1.0)], ["grosso_spento", Color(0.16, 0.11, 0.2)],
			["nuda", Color(1.0, 0.94, 0.82)], ["nuda_spento", Color(0.24, 0.21, 0.18)],
			["oltre", Color(0.62, 0.84, 1.0)], ["oltre_spento", Color(0.09, 0.13, 0.2)],
			["oggi", Color(1.0, 0.8, 0.35)], ["sempre", Color(0.85, 0.88, 0.95)]]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = k[1]
		m.no_depth_test = true
		m.render_priority = 19
		stone_mats[k[0]] = m
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = 2.0 * radius
	sph.radial_segments = 16
	sph.rings = 8
	var box := BoxMesh.new()
	box.size = Vector3.ONE * radius * 1.5
	for i in row.size():
		var st := MeshInstance3D.new()
		st.mesh = box if i in OSSERVATORIO_RUNGS else sph
		st.position = row[i]
		if i in OSSERVATORIO_RUNGS:
			st.rotation_degrees = Vector3(0, 0, 45)
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sentiero.add_child(st)
		stones.append(st)
		stone_pos.append(row[i])
	var dot := SphereMesh.new()
	dot.radius = radius * 0.45
	dot.height = radius * 0.9
	stone_today = MeshInstance3D.new()
	stone_today.mesh = dot
	stone_today.material_override = stone_mats["oggi"]
	sentiero.add_child(stone_today)
	stone_ever = MeshInstance3D.new()
	stone_ever.mesh = dot
	stone_ever.material_override = stone_mats["sempre"]
	sentiero.add_child(stone_ever)
	sentiero.visible = false


static func stone_family(i: int) -> String:
	return "grosso" if i < Misure.PIETRA_NUDA else ("nuda" if i == Misure.PIETRA_NUDA else "oltre")


func _update_stones() -> void:
	if sentiero == null:
		return
	var cur_i: int = paths["mosaico"].index
	if stone_last >= 0 and cur_i != stone_last:
		stone_pulse = 1.0
	stone_last = cur_i
	for i in stones.size():
		var fam := stone_family(i)
		stones[i].material_override = stone_mats[fam if i <= cur_i else fam + "_spento"]
		stones[i].scale = Vector3.ONE * ((1.6 + 0.8 * stone_pulse) if i == cur_i else 1.0)
	stone_today.visible = rung_today >= 0
	if rung_today >= 0:
		stone_today.position = stone_pos[mini(rung_today, stone_pos.size() - 1)] + Vector3(0, stone_size * 2.6, 0)
	stone_ever.visible = rung_ever >= 0
	if rung_ever >= 0:
		stone_ever.position = stone_pos[mini(rung_ever, stone_pos.size() - 1)] - Vector3(0, stone_size * 2.6, 0)


# ---------------------------------------------------------------- musica e suoni

func _setup_music() -> void:
	music = AudioStreamPlayer.new()
	music.name = "Musica"
	add_child(music)
	music.finished.connect(_on_music_finished)
	var md := Paths.globalize(MUSIC_DIR)
	if not DirAccess.dir_exists_absolute(md):
		return
	var names := Array(DirAccess.get_files_at(md))
	names.sort()
	for f in names:
		if f.get_extension().to_lower() not in ["mp3", "ogg"]:
			continue
		var s := _load_track(md + "/" + f)
		if s != null:
			music_tracks.append(s)
			music_names.append(f.get_basename())


static func _load_track(path: String) -> AudioStream:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	match path.get_extension().to_lower():
		"mp3":
			var s := AudioStreamMP3.new()
			s.data = bytes
			return s if s.get_length() > 0.0 else null
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
	return null


func _music_on() -> bool:
	return music != null and music_volume > 0.001 and not music_tracks.is_empty()


func _music_line() -> String:
	if music_tracks.is_empty():
		return "Music: no tracks in the musica folder."
	if not _music_on():
		return "Music: off (thumbstick right to turn it on)."
	return "Music: %d%% (thumbstick left and right; 0 = off)." % roundi(music_volume * 100.0)


func _kill_music_tween() -> void:
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	music_tween = null


func _music_play(i: int, fade: float) -> void:
	_kill_music_tween()
	music_idx = i
	music.stream = music_tracks[i]
	music.stream_paused = false
	var target := linear_to_db(music_volume)
	music.volume_db = -60.0 if fade > 0.0 else target
	music.play()
	if fade > 0.0:
		music_tween = create_tween()
		music_tween.tween_property(music, "volume_db", target, fade)


func _music_start_night() -> void:
	if _music_on():
		_music_play(0, MUSIC_FADE_IN)


func _on_music_finished() -> void:
	if not _music_on() or state not in PLAY_STATES:
		return
	var next := music_idx + 1
	if next >= music_tracks.size():
		if block_seconds - block_played < MUSIC_TAIL:
			return
		next = 0
	_music_play(next, 0.0)


func _music_fade_out() -> void:
	if music == null or not music.playing:
		return
	_kill_music_tween()
	music.stream_paused = false
	music_tween = create_tween()
	music_tween.tween_property(music, "volume_db", -60.0, MUSIC_FADE_OUT)
	music_tween.tween_callback(music.stop)


func _music_pause(paused: bool) -> void:
	if music:
		music.stream_paused = paused


func _change_music(step: float) -> void:
	if music_tracks.is_empty():
		return
	music_volume = clampf(snappedf(music_volume + step, 0.1), 0.0, 1.0)
	prog.data["musica_volume"] = music_volume
	if not _music_on():
		_kill_music_tween()
		music.stop()
	elif music.playing:
		_kill_music_tween()
		music.volume_db = linear_to_db(music_volume)
	else:
		_music_play(0, 0.5)
	_show_intro()


## Suoni sintetizzati, non posizionali: suonano solo dopo la risposta.
func _setup_sounds() -> void:
	for i in 3:
		var pl := AudioStreamPlayer.new()
		pl.name = "Effetto%d" % i
		add_child(pl)
		sfx.append(pl)
	sounds["trovata"] = _synth([[587.3, 0.0, 0.45], [880.0, 0.05, 0.2]], 0.9, 0.3)
	sounds["sfuggita"] = _synth([[174.6, 0.0, 0.3], [185.0, 0.0, 0.2]], 0.45, 0.12)
	sounds["notte"] = _synth([[261.6, 0.0, 0.25], [329.6, 0.0, 0.2], [392.0, 0.0, 0.2]], 2.0, 0.6)
	sounds["segno"] = _synth([[1318.5, 0.0, 0.12]], 0.14, 0.035)
	sounds["restauro"] = _synth([[392.0, 0.0, 0.3], [493.9, 0.14, 0.3], [587.3, 0.28, 0.3], [784.0, 0.42, 0.35], [987.8, 0.56, 0.3]], 2.2, 0.55)


static func _synth(notes: Array, dur: float, decay: float, rate := 16000) -> AudioStreamWAV:
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for nt in notes:
			var dt: float = t - float(nt[1])
			if dt < 0.0:
				continue
			var f: float = nt[0]
			var e := exp(-dt / decay) * minf(1.0, dt * 400.0)
			v += float(nt[2]) * e * (sin(TAU * f * dt) + 0.25 * sin(TAU * 2.0 * f * dt) + 0.08 * sin(TAU * 3.0 * f * dt))
		v *= minf(1.0, (dur - t) * 20.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	return st


func _play(sound: String, pitch := 1.0) -> void:
	if sfx_volume <= 0.001 or not sounds.has(sound) or sfx.is_empty():
		return
	var pl := sfx[sfx_next]
	sfx_next = (sfx_next + 1) % sfx.size()
	pl.stream = sounds[sound]
	pl.pitch_scale = pitch
	pl.volume_db = linear_to_db(sfx_volume)
	pl.play()


# ---------------------------------------------------------------- testi

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
		out.append(line if not line.is_empty() else "·")
	return "\n".join(out)


func _say(text: String) -> void:
	label.text = _wrap(text, 52)
	label.visible = true


func _path_line(kind: String, summary: Dictionary) -> String:
	var nm: String = {"scaglie": "Scales path", "movimento": "Wind path", "mosaico": "Mosaic path"}[kind]
	var e: Dictionary = summary[kind]
	if e.get("esito", "insufficiente") == "insufficiente":
		return "%s: now at \"%s\", %s" % [nm, Misure.fmt_level(kind, paths[kind].value()), Misure.fmt_path(kind, e)]
	return "%s: %s" % [nm, Misure.fmt_path(kind, e)]


func _show_intro() -> void:
	state = S.INTRO
	_set_param("mode", 0)
	_set_param("reveal_t", 0.0)
	var n_rest := Misure.restored_ids(prog.data).size()
	if intro_page == 0:
		_say("THE RUINS (%s) · 1 of 2\n\nFour creatures hide in the stone: one stands IN FRONT, three BEHIND. Point at the one in front with the thumbstick: up, right, down or left (or the arrow keys). You have up to 30 seconds: take your time, but don't strain your eyes. If you can't see it, take a guess.\n\nThe MOSAIC path: big creatures, coarse tiles, lots of depth. As you find them the mosaic grows finer, down to bare stone; then the depth shrinks further, down to 251″. Between trials, the row of stones at the top shows the step you're on. Sometimes the mosaic has only dark or only light tiles: it's a comparison, play it like the others.\nThree trials in ten are BARE STONE, with no help, as in the test: those are the ones that count.\n\nTrigger (or Space): next." % ("anonymous" if participant == "anonimo" else participant))
	else:
		_say("THE RUINS · 2 of 2\n\nAfter each answer the creature shows itself: look at it, and at the stone around it.\n\nIF YOU REALLY SEE IT, MARK IT: press the trigger before moving the thumbstick, or together (Space or Shift on the keyboard). Only when you see it, not when you guess. A soft sound confirms the mark; the trial doesn't change.\n\nRestored pieces: %d of %d.\n%s\n\nStop and see a doctor if you see double OUTSIDE the headset, if headaches or eye discomfort don't go away, or if your vision changes. If double vision in the headset is new, doesn't go away or bothers you, stop (B/Y).\n\nTrigger (or Space) to go down into the ruins. B/Y (or Esc) to go back." % [
			n_rest, Misure.PEZZI.size(), _music_line()])
	hud.visible = false
	wind.visible = false


func _update_hud() -> void:
	hud.text = "night %d · creatures found %d · streak %d" % [night, found, combo]
	hud.visible = state in PLAY_STATES


# ---------------------------------------------------------------- file

func _open_files() -> bool:
	var now := Time.get_datetime_string_from_system(false, false).replace("-", "").replace(":", "").replace("T", "_")
	session_id = "%s_%04x" % [now, rng.randi() & 0xffff]
	var sub := participant + "/training/"
	if mode_name == "desktop":
		sub = "desktop/" + participant + "/training/"
	elif mode_name == "autotest":
		sub = "autotest/training/"
	results_dir = Paths.globalize("res://results/" + sub)
	DirAccess.make_dir_recursive_absolute(results_dir)
	prog.load_from(results_dir + "profilo.json")
	csv_path = results_dir + "rovine_%s.csv" % session_id
	csv = FileAccess.open(csv_path, FileAccess.WRITE)
	if csv == null:
		return false
	csv.store_csv_line(PackedStringArray(HEADER))
	csv.flush()
	return csv.get_error() == OK


func _write_row(fields: Dictionary) -> bool:
	var base := {"session": session_id, "participant": participant, "version": VERSION,
		"protocol": Misure.PROTOCOL, "mode": mode_name}
	base.merge(fields, true)
	var row := PackedStringArray()
	for col in HEADER:
		row.append(str(base.get(col, "")))
	csv.store_csv_line(row)
	csv.flush()
	if csv.get_error() != OK:
		_fatal("Write error on %s: the ruins stop here. Trials already saved stay in the file." % csv_path)
		return false
	var rec := {}
	for col in HEADER:
		rec[col] = str(base.get(col, ""))
	session_rows.append(rec)
	night_rows.append(rec)
	return true


func _fatal(msg: String) -> void:
	push_error(msg)
	if music:
		music.stop()
	print("ROVINE_ERROR " + msg)
	state = S.ERROR
	if label:
		_say("ERROR\n\n" + msg + "\n\nTrigger to close.")
	if autotest:
		get_tree().quit(1)


# ---------------------------------------------------------------- testa

func _eyes() -> Array:
	if xr_active:
		var xr := XRServer.primary_interface
		var ot := origin.global_transform
		return [xr.get_transform_for_view(0, ot).origin, xr.get_transform_for_view(1, ot).origin]
	var t := camera.global_transform
	var right := t.basis.x.normalized()
	return [t.origin - right * DESKTOP_IPD * 0.5, t.origin + right * DESKTOP_IPD * 0.5]


func _ipd() -> float:
	var e := _eyes()
	var d: float = (e[0] as Vector3).distance_to(e[1])
	return d if d > 0.04 else DESKTOP_IPD


func _head() -> Vector3:
	return camera.global_transform.origin


## Spostamento laterale della testa dall'inizio della prova (m), lungo l'asse interoculare di allora.
func _sway() -> float:
	if not xr_active:
		return clampf(fake_sway, -SWAY_MAX_M, SWAY_MAX_M)
	return clampf((_head() - head0).dot(lateral), -SWAY_MAX_M, SWAY_MAX_M)


## Vento (gradi) della regione davanti: -A tanh(dx / SWAY_REF). Il verso è quello della
## parallasse (la regione davanti scorre in verso opposto alla testa, quelle dietro nello stesso),
## ma l'ampiezza satura: con 1 cm di movimento è già al 76% di A, e muoversi di più non la fa
## crescere. A è il gradino della scala (review RV4: con la parallasse proporzionale, guadagno ed
## escursione della testa erano confusi).
func _parallax_deg(amp: float) -> float:
	return parallax_for(amp, _sway())


static func parallax_for(amp: float, sway_m: float) -> float:
	if amp <= 0.0:
		return 0.0
	return clampf(-amp * tanh(sway_m / SWAY_REF_M), -PARALLAX_MAX_DEG, PARALLAX_MAX_DEG)


# ---------------------------------------------------------------- prove

func _start_play() -> void:
	label.visible = false
	trial = 0
	state = S.ITI_WAIT
	timer = 0.0
	_save_progress()
	_update_hud()
	_music_start_night()
	_next_trial()


func _draw_kind() -> String:
	if block_bag.is_empty():
		block_bag = BLOCK.duplicate()
		for i in range(block_bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = block_bag[i]
			block_bag[i] = block_bag[j]
			block_bag[j] = t
	return block_bag.pop_back()


## Punti scuri o chiari nelle prove di polarità, a sacchetti di due: in ogni coppia uno e uno.
## Non dice niente sul bersaglio, che resta estratto a caso a ogni prova.
func _draw_polarity() -> String:
	if polarity_bag.is_empty():
		polarity_bag = ["scuri", "chiari"]
		if rng.randf() < 0.5:
			polarity_bag.reverse()
	return polarity_bag.pop_back()


## Geometria e disparità della prova (0.5.6): il formato normale a 1000″ per sonde e scaglie, il
## gradino del mosaico per mosaico e polarità. Si impostano già alla croce, così la cornice non
## cambia alla comparsa dello stimolo.
func _apply_geometry(g: Dictionary, polarity: String) -> void:
	for key in GEOMETRY_KEYS:
		_set_param(key, g[key])
	_set_param("disparity_deg", float(g["disparity_arcsec"]) / 3600.0)
	_set_param("portal_scale", maxf(1.0, float(g["field_extent"]) / float(GEOMETRY["field_extent"])))
	_set_param("polarity_mode", POLARITY_MODE.get(polarity, 0))


## Posizione del bersaglio: estratta a caso e indipendente dalle prove precedenti (review RV1).
## Con i sacchetti di 4 della r1, il riscontro rendeva prevedibili i bersagli successivi.
func _draw_target(_kind: String) -> int:
	return rng.randi_range(0, 3)


func _next_trial() -> void:
	if block_played >= block_seconds:
		_start_rest()
		return
	trial += 1
	var kind := _draw_kind()
	var target := _draw_target(kind)
	var li := -1
	var value := 0.0
	var polarity := "misti"
	if kind in paths:
		li = paths[kind].index
		value = paths[kind].value()
	elif kind == "polarita":
		# 0.5.6: stesso gradino del mosaico, punti di un solo colore; fuori dalla scala
		li = paths["mosaico"].index
		value = paths["mosaico"].value()
		polarity = _draw_polarity()
	cur = {"kind": kind, "target": target, "level_index": li, "value": value, "polarity": polarity,
		"geo": Misure.trial_geometry(kind, li),
		"seed_bg": rng.randi() & 0x3fffffff, "seed_rg": rng.randi() & 0x3fffffff, "seed_sc": rng.randi() & 0x3fffffff,
		"creature": CREATURES[rng.randi_range(0, CREATURES.size() - 1)], "hand": "", "sicuro": false}
	_apply_geometry(cur["geo"], polarity)
	_set_param("mode", 0)
	_set_param("reveal_t", 0.0)
	_set_param("reveal_index", -1)
	_set_param("wrong_index", -1)
	_set_param("parallax_deg", 0.0)
	wind.visible = kind == "movimento" and value > 0.0
	state = S.FIX
	timer = fix_time
	_update_hud()


func _present() -> void:
	_set_param("target_index", cur["target"])
	_set_param("seed_bg", cur["seed_bg"])
	_set_param("seed_rg", cur["seed_rg"])
	_set_param("seed_sc", cur["seed_sc"])
	_set_param("scale_c", cur["value"] if cur["kind"] == "scaglie" else 0.0)
	_set_param("parallax_deg", 0.0)
	_set_param("mode", 1)
	head0 = _head()
	var b := camera.global_transform.basis
	lateral = Vector3(b.x.x, 0.0, b.x.z).normalized() if Vector2(b.x.x, b.x.z).length() > 0.1 else Vector3.RIGHT
	fwd0 = -b.z
	var e0 := _eyes()
	cur["roll"] = Geo.head_roll_deg(e0[0], e0[1])
	cur["pitch"] = Geo.head_pitch_deg(fwd0)
	sway_max = 0.0
	parallax_max = 0.0
	rot_max = 0.0
	if autotest:
		fake_sway = 0.0 if rng.randf() < sim_still else sim_sway
	trial_time = 0.0
	state = S.STIM


func _track_head() -> void:
	var dx := _sway()
	sway_max = maxf(sway_max, absf(dx))
	rot_max = maxf(rot_max, rad_to_deg(fwd0.angle_to(-camera.global_transform.basis.z)))
	if cur.get("kind", "") == "movimento":
		var pd := _parallax_deg(float(cur["value"]))
		_set_param("parallax_deg", pd)
		if state == S.STIM:
			parallax_max = maxf(parallax_max, absf(pd))


## Il vento è arrivato? Sì se lo spostamento mostrato durante la prova ha raggiunto almeno metà
## dell'ampiezza del gradino (circa 1,6 mm di movimento della testa), o se il gradino è puro.
func _cue_ok() -> bool:
	if cur.get("kind", "") != "movimento" or float(cur["value"]) <= 0.0:
		return true
	return parallax_max >= CUE_MIN_FRAC * float(cur["value"]) - 1e-9


func _answer(choice: int) -> void:
	if state != S.STIM:
		return
	var correct: bool = choice == cur["target"]
	var kind: String = cur["kind"]
	var mv := {"dir": 0, "reversal": false}
	var cue := _cue_ok()
	if kind == "mosaico":
		rung_today = maxi(rung_today, int(cur["level_index"]))
		rung_ever = maxi(rung_ever, int(cur["level_index"]))
	if kind in paths and cue:          # sonde e polarità non muovono nessuna scala
		mv = paths[kind].record(correct)
	_update_stones()
	answered += 1
	if correct:
		found += 1
		combo += 1
	else:
		combo = 0
	var ok := _log("risposta", choice, correct, mv)
	if not ok:
		return
	_play("trovata" if correct else "sfuggita", pow(2.0, minf(combo - 1, 12) / 12.0) if correct else 1.0)
	_feedback(choice, correct)
	if not cue:
		hud.text = "the wind didn't come: move your head slightly\n" + hud.text


func _timeout() -> void:
	if not _log("timeout", -1, false, {"dir": 0, "reversal": false}):
		return
	combo = 0
	_feedback(-1, false)


func _log(outcome: String, choice: int, correct: bool, mv: Dictionary) -> bool:
	var kind: String = cur["kind"]
	var e := _eyes()
	var roll_now := "%.2f" % Geo.head_roll_deg(e[0], e[1]) if cur.has("roll") else ""
	var g: Dictionary = cur.get("geo", Misure.trial_geometry(kind, int(cur["level_index"])))
	var after = ""
	if kind in paths:
		after = paths[kind].index
	elif kind == "polarita":
		after = cur["level_index"]
	return _write_row({"trial": trial, "night": night, "kind": kind,
		"level_index": cur["level_index"] if kind != "sonda" else "",
		"scale_c": "%.3f" % (cur["value"] if kind == "scaglie" else 0.0),
		"parallax_amp_deg": "%.3f" % (cur["value"] if kind == "movimento" else 0.0),
		"disparity_arcsec": "%.1f" % float(g["disparity_arcsec"]), "target": Misure.NAMES[cur["target"]],
		"response": Misure.NAMES[choice] if choice >= 0 else "", "correct": 1 if correct else 0,
		"outcome": outcome, "rt_s": "%.3f" % trial_time, "seed_bg": cur["seed_bg"], "seed_rg": cur["seed_rg"],
		"seed_sc": cur["seed_sc"], "sway_max_mm": "%.1f" % (sway_max * 1000.0),
		"parallax_max_deg": "%.4f" % parallax_max, "cue_ok": 1 if _cue_ok() else 0, "head_rot_deg": "%.2f" % rot_max,
		"ipd_m": "%.4f" % _ipd(), "px_arcsec": "%.1f" % pixel_arcsec, "dir": mv["dir"],
		"reversal": 1 if mv["reversal"] else 0,
		"level_after": after, "creature": cur["creature"], "hand": cur["hand"],
		"sicuro": (1 if cur.get("sicuro", false) else 0) if outcome == "risposta" else "",
		"head_roll_deg": "%.2f" % float(cur["roll"]) if cur.has("roll") else "", "head_roll_resp_deg": roll_now,
		"head_pitch_deg": "%.2f" % float(cur["pitch"]) if cur.has("pitch") else "",
		"grain": "%.4f" % float(g["grain"]), "region_t": "%.4f" % float(g["region_t"]), "polarity": cur.get("polarity", "misti")})


## Grilletto (o Spazio) durante lo stimolo: "questa l'ho vista davvero". Vale fino alla risposta;
## un suono leggero conferma il segno. Non cambia nulla nella prova.
func _mark_seen() -> void:
	if state != S.STIM or cur.get("sicuro", false):
		return
	cur["sicuro"] = true
	_play("segno")


func _feedback(choice: int, _correct: bool) -> void:
	_set_param("reveal_index", cur["target"])
	_set_param("wrong_index", choice if choice >= 0 and choice != cur["target"] else -1)
	var tex: Texture2D = creature_tex.get(cur["creature"], null)
	_set_param("show_creature", tex != null)
	if tex != null:
		_set_param("creature_tex", tex)
	state = S.FEEDBACK
	timer = feedback_time
	_update_hud()


func _animate_feedback() -> void:
	var t := 1.0 - timer / maxf(feedback_time, 1e-6)
	var a := clampf(t / 0.18, 0.0, 1.0) * clampf((1.0 - t) / 0.3, 0.0, 1.0)
	_set_param("reveal_t", a)


# ---------------------------------------------------------------- notti

func _start_rest() -> void:
	block_played = 0.0
	state = S.REST
	timer = REST_SECONDS
	_music_fade_out()
	_play("notte")
	wind.visible = false
	_set_param("mode", 0)
	_set_param("reveal_t", 0.0)
	var s := Misure.summarize(night_rows)
	var ss := Misure.summarize(session_rows)
	rest_lore = "\n\nNIGHT %d: %d creatures found.\nProbes in bare stone: %s.\n%s%s." % [night,
		_count_found(night_rows), Misure.fmt_probes(s["sonde"]), (_path_line("scaglie", ss) + ".\n") if _has_kind(session_rows, "scaglie") else "", _path_line("mosaico", ss)]
	night += 1
	night_rows = []
	_save_progress()
	hud.visible = false
	if autotest:
		timer = 0.0


## Dalla 0.5.10 le scaglie non sono più nel blocco: le loro righe nei riepiloghi compaiono solo se ci sono prove.
static func _has_kind(rows: Array, kind: String) -> bool:
	for r in rows:
		if str(r.get("kind", "")) == kind:
			return true
	return false


func _count_found(rows: Array) -> int:
	var n := 0
	for r in rows:
		if r.get("outcome", "") == "risposta" and str(r.get("correct", "0")) == "1":
			n += 1
	return n


func _rest_text() -> String:
	var over := float(prog.data.get("secondi_oggi", 0.0)) + (play_seconds - _saved_seconds) > DAY_SOFT_CAP
	var txt := "The lantern needs oil.\n\nClose your eyes and blink slowly: %d seconds." % ceili(maxf(timer, 0.0))
	if timer <= 0.0:
		txt = "Lantern refilled.\n\nTrigger (or Space) for another night, B/Y (or Esc) to go back to the hut."
		if over:
			txt += "\n\nYou've played over an hour today: the ruins suggest you come back tomorrow."
	return txt + rest_lore


# ---------------------------------------------------------------- pause e fine

func _on_focus_lost() -> void:
	if state in PLAY_STATES:
		if state in [S.FIX, S.STIM]:
			if not _log("pausa", -1, false, {"dir": 0, "reversal": false}):
				return
		resume_to = S.ITI_WAIT
		state = S.PAUSED
		_music_pause(true)
		_set_param("mode", 0)
		_set_param("reveal_t", 0.0)
		wind.visible = false
		hud.visible = false
		_save_progress()
		_say("PAUSED\n\nPut the headset back on, then trigger (or Space) to continue. B/Y (or Esc) to go back.")


func _on_session_stopping() -> void:
	if state not in [S.END, S.ERROR]:
		_finish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and state not in [S.END, S.ERROR] and csv != null:
		_finish()


func _save_progress() -> bool:
	if not prog.data.has("rovine") or not prog.data["rovine"] is Dictionary:
		prog.data["rovine"] = {}
	var rv: Dictionary = prog.data["rovine"]
	for k in paths:
		if paths[k].moved:
			rv[k] = paths[k].to_dict()
	prog.add_seconds(play_seconds - _saved_seconds, Time.get_date_string_from_system())
	_saved_seconds = play_seconds
	return prog.save()


func _finish() -> void:
	if state == S.END:
		return
	state = S.END
	_music_fade_out()
	wind.visible = false
	hud.visible = false
	_set_param("mode", 0)
	_set_param("reveal_t", 0.0)
	var s := Misure.summarize(session_rows)
	var today := Time.get_date_string_from_system()
	if csv:
		csv.flush()
	var history := Misure.load_history(results_dir)
	var fresh := Misure.update_pieces(prog.data, Misure.evaluate_pieces(history), today)
	if answered > 0:
		var rv: Dictionary = prog.data["rovine"]
		if not rv.has("sessioni"):
			rv["sessioni"] = []
		rv["sessioni"].append({"sessione": session_id, "versione": VERSION, "protocollo": Misure.PROTOCOL,
			"data": Time.get_datetime_string_from_system(), "modo": mode_name, "risposte": answered, "trovate": found,
			"sonde": [s["sonde"]["k"], s["sonde"]["n"]], "scaglie": s["scaglie"], "mosaico": s["mosaico"],
			"mosaico_max": s["mosaico_max"], "polarita": {"scuri": s["polarita"]["scuri"], "chiari": s["polarita"]["chiari"]},
			"minuti": s["minuti"], "notti": night})
	var saved := _save_progress()
	var lines := ["BACK TO THE HUT" if from_capanna else "END", ""]
	if not saved:
		lines.append("WARNING: profile not saved (the trials are in the CSV).")
	lines.append("Creatures found: %d of %d answers." % [found, answered])
	lines.append("")
	lines.append("BARE STONE, the real target: %s." % Misure.fmt_probes(s["sonde"]))
	var allp := Misure.all_probes(history)
	if int(allp["n"]) > int(s["sonde"]["n"]):
		lines.append("All probes so far: %s." % Misure.fmt_probes(allp))
	lines.append("Answers in the probes: up %d, right %d, down %d, left %d." % [s["risposte_sonde"]["alto"],
		s["risposte_sonde"]["destra"], s["risposte_sonde"]["basso"], s["risposte_sonde"]["sinistra"]])
	lines.append("")
	if _has_kind(session_rows, "scaglie"):
		lines.append(_path_line("scaglie", s) + ".")
	lines.append(_path_line("mosaico", s) + ".")
	if int(s["mosaico_max"]) >= 0:
		var best := int(s["mosaico_max"])
		for h in history:
			best = maxi(best, int(h.get("mosaico_max", -1)))
		lines.append("Mosaic, furthest point today: %s. Furthest ever: %s." % [Misure.fmt_rung(int(s["mosaico_max"])), Misure.fmt_rung(best)])
	if not (s["pietra_mosaico"] as Dictionary).is_empty():
		lines.append("Mosaic in bare stone, by disparity (not probes): %s." % Misure.fmt_bare(s["pietra_mosaico"]))
	var pol_s: Dictionary = s["polarita"]
	if int(pol_s["scuri"][1]) + int(pol_s["chiari"][1]) > 0:
		var apz := Misure.all_polarity(history)
		lines.append("Polarity trials (off the staircase): %s%s." % [Misure.fmt_polarity(pol_s),
			("; overall %s" % Misure.fmt_polarity(apz)) if int(apz["sessioni"]) > 1 else ""])
	if s["con_segno"]:
		var vs: Dictionary = s["viste"]
		var sc_vs := int(vs["scaglie"][0][1]) + int(vs["scaglie"][1][1]) > 0
		lines.append("Really seen (trigger), correct of answered: probes %s;%s mosaic %s." % [
			Misure.fmt_seen(vs, "sonda"), (" scales %s;" % Misure.fmt_seen(vs, "scaglie")) if sc_vs else "", Misure.fmt_seen(vs, "mosaico")])
		var av := Misure.all_seen(history)
		if int(av["sessioni"]) > 1:
			var mos_av := int(av["mosaico"][0][1]) + int(av["mosaico"][1][1]) > 0
			lines.append("All sessions with marks (%d): probes %s; scales %s%s." % [av["sessioni"],
				Misure.fmt_seen(av, "sonda"), Misure.fmt_seen(av, "scaglie"),
				("; mosaic " + Misure.fmt_seen(av, "mosaico")) if mos_av else ""])
	var pp: Dictionary = s["per_posizione"]["scaglie"]
	if int(pp["alto"][1]) + int(pp["destra"][1]) + int(pp["basso"][1]) + int(pp["sinistra"][1]) > 0:
		lines.append("Scales, by position of the front creature: up %d/%d, right %d/%d, down %d/%d, left %d/%d." % [
			pp["alto"][0], pp["alto"][1], pp["destra"][0], pp["destra"][1], pp["basso"][0], pp["basso"][1], pp["sinistra"][0], pp["sinistra"][1]])
	if int(s["puro"]["scaglie"][1]) > 0:
		lines.append("Scales-path trials that reached bare stone (not probes): %d of %d." % [
			s["puro"]["scaglie"][0], s["puro"]["scaglie"][1]])
	var sc: Dictionary = s["scadute"]
	var n_out := 0
	for k in sc:
		n_out += int(sc[k])
	if n_out > 0:
		lines.append("Trials timed out without an answer: %d (probes %d)." % [n_out, sc["sonda"]])
	lines.append("Minutes played: %.0f (%.0f in all today)." % [play_seconds / 60.0, float(prog.data.get("secondi_oggi", 0.0)) / 60.0])
	for pz in fresh:
		lines.append("")
		lines.append("%s\n%s" % [pz["nome"].to_upper(), pz["storia"]])
	if not fresh.is_empty():
		Cielo.update(env, Misure.restored_ids(prog.data))
		_play("restauro")
	else:
		_play("notte")
	lines.append("")
	lines.append("Trigger (or Space) to go back to the hut." if from_capanna else "Trigger (or Space) to close.")
	var text := "\n".join(lines)
	print("ROVINE_RESULT\n" + text)
	_say(text)
	if autotest:
		get_tree().quit()


func _leave() -> void:
	if from_capanna:
		get_tree().root.set_meta("capanna_opts", {"partecipante": participant})
		get_tree().call_deferred("change_scene_to_file", "res://scenes/capanna.tscn")
	else:
		get_tree().quit()


# ---------------------------------------------------------------- ciclo

func _process(delta: float) -> void:
	_poll_controllers()
	_set_param("time_s", Time.get_ticks_msec() / 1000.0)
	if sentiero != null and capture_path.is_empty():
		sentiero.visible = state in STONE_SHOW
		if stone_pulse > 0.0:
			stone_pulse = maxf(0.0, stone_pulse - delta / STONE_PULSE_S)
			_update_stones()
	match state:
		S.FIX:
			play_seconds += delta
			block_played += delta
			timer -= delta
			if timer <= 0.0:
				_present()
		S.STIM:
			play_seconds += delta
			block_played += delta
			trial_time += delta
			_track_head()
			if autotest:
				cur["hand"] = "sim"
				cur["sicuro"] = rng.randf() < sim_sure
				_answer(_simulated_choice())
			elif trial_time > MAX_TIME:
				_timeout()
		S.FEEDBACK:
			play_seconds += delta
			block_played += delta
			timer -= delta
			_track_head()
			_animate_feedback()
			if timer <= 0.0:
				_set_param("reveal_t", 0.0)
				_set_param("mode", 0)
				_set_param("parallax_deg", 0.0)
				wind.visible = false
				state = S.ITI_WAIT
				timer = iti
				if autotest and trial >= autotest_trials:
					_finish()
		S.ITI_WAIT:
			play_seconds += delta
			block_played += delta
			timer -= delta
			if timer <= 0.0:
				_next_trial()
		S.REST:
			timer -= delta
			_say(_rest_text())
			if autotest and timer <= 0.0:
				_confirm()


## Osservatore simulato (autotest): nel random-dot puro è giusto con probabilità sim_global; con
## una rotella, 0,25 + 0,72 Phi(ln(v / v50) / 0,5), dove v è il contrasto delle scaglie o il
## guadagno della parallasse. Serve a verificare le scale e la separazione delle sonde.
func _simulated_choice() -> int:
	var p := sim_global
	var v: float = cur["value"]
	if cur["kind"] == "scaglie" and v > 0.0:
		p = maxf(p, 0.25 + 0.72 * Fit.phi(log(v / sim_c50) / 0.5))
	elif cur["kind"] == "movimento" and v > 0.0 and _cue_ok():
		p = maxf(p, 0.25 + 0.72 * Fit.phi(log(v / sim_g50) / 0.5))
	elif cur["kind"] in ["mosaico", "polarita"]:
		var rung := float(cur["level_index"])
		var m50 := sim_m50 + (sim_dark if cur.get("polarity", "") == "scuri" else 0.0)
		p = maxf(p, 0.25 + 0.72 * Fit.phi((m50 - rung) / 1.2))
	if rng.randf() < p:
		return cur["target"]
	var others := [0, 1, 2, 3]
	others.erase(cur["target"])
	return others[rng.randi_range(0, 2)]


func _confirm() -> void:
	match state:
		S.STIM:
			_mark_seen()
		S.INTRO:
			if intro_page == 0:
				intro_page = 1
				_show_intro()
			else:
				_start_play()
		S.REST:
			if timer <= 0.0:
				label.visible = false
				_music_start_night()
				_next_trial()
		S.PAUSED:
			label.visible = false
			_music_pause(false)
			state = S.ITI_WAIT
			timer = iti
			_update_hud()
		S.END, S.ERROR:
			_leave()


func _quit_request() -> void:
	match state:
		S.END, S.ERROR:
			_leave()
		S.INTRO:
			_save_progress()
			_leave()
		_:
			_finish()


func _poll_controllers() -> void:
	# prima i grilletti di entrambe le mani, poi le levette: un segno "vista" dato con una mano nello
	# stesso fotogramma della risposta con l'altra vale ancora
	for ctrl in controllers:
		if not ctrl.get_is_active():
			continue
		var pressed := ctrl.is_button_pressed("trigger_click") or ctrl.is_button_pressed("ax_button")
		if pressed and not trigger_prev[ctrl]:
			_confirm()
		trigger_prev[ctrl] = pressed
		var quit := ctrl.is_button_pressed("by_button")
		if quit and not quit_prev[ctrl]:
			_quit_request()
		quit_prev[ctrl] = quit
	for ctrl in controllers:
		if not ctrl.get_is_active():
			continue
		var v: Vector2 = ctrl.get_vector2("primary")
		if stick_armed[ctrl] and v.length() > 0.75:
			stick_armed[ctrl] = false
			if state == S.STIM:
				cur["hand"] = "levetta_" + ("sx" if ctrl == controllers[0] else "dx")
				if absf(v.y) >= absf(v.x):
					_answer(0 if v.y > 0 else 2)
				else:
					_answer(1 if v.x > 0 else 3)
			elif state == S.INTRO and absf(v.x) > absf(v.y):
				_change_music(0.1 if v.x > 0 else -0.1)
		elif v.length() < 0.3:
			stick_armed[ctrl] = true


func _unhandled_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm != null and not xr_active:
		# desktop: il mouse fa da testa per il sentiero del vento (±5 cm)
		var w := get_viewport().get_visible_rect().size.x
		fake_sway = (mm.position.x / maxf(w, 1.0) - 0.5) * 0.1
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.shift_pressed and state == S.STIM and key.physical_keycode in [KEY_UP, KEY_W, KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S, KEY_LEFT, KEY_A]:
		_mark_seen()           # Maiusc con la freccia: "vista davvero", come il grilletto
	match key.physical_keycode:
		KEY_SPACE, KEY_ENTER:
			_confirm()
		KEY_ESCAPE:
			_quit_request()
		KEY_UP, KEY_W:
			if state == S.STIM:
				cur["hand"] = "tastiera"
				_answer(0)
		KEY_RIGHT, KEY_D:
			if state == S.STIM:
				cur["hand"] = "tastiera"
				_answer(1)
			elif state == S.INTRO:
				_change_music(0.1)
		KEY_DOWN, KEY_S:
			if state == S.STIM:
				cur["hand"] = "tastiera"
				_answer(2)
		KEY_LEFT, KEY_A:
			if state == S.STIM:
				cur["hand"] = "tastiera"
				_answer(3)
			elif state == S.INTRO:
				_change_music(-0.1)


# ---------------------------------------------------------------- catture (verifiche)

## --cattura=percorso.png [--cattura-tipo=sonda|scaglie|movimento|mosaico|polarita|riscontro|intro|intro2]
## [--cattura-gradino=0..21] [--cattura-polarita=misti|scuri|chiari]: una prova fissa, una cattura del
## viewport e uscita. Serve alle verifiche dei render.
## 0.5.6: --cattura-serie=N cattura N prove a semi e bersagli casuali (stesso tipo e gradino) in
## percorso_0000.png..., con manifest.json (bersaglio, semi, gradino): per i decodificatori monoculari.
func _capture_setup() -> void:
	var kind := capture_kind if capture_kind != "" else "sonda"
	if kind in ["intro", "intro2"]:
		intro_page = 0 if kind == "intro" else 1
		_show_intro()
		state = S.END
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path)
		print("ROVINE_CAPTURE " + capture_path)
		get_tree().quit()
		return
	label.visible = false
	var tkind := "sonda"
	if kind in ["scaglie", "movimento", "mosaico", "polarita"]:
		tkind = kind
	elif kind == "sentiero":
		tkind = "mosaico"
	var li := capture_rung if tkind in ["mosaico", "polarita"] else 0
	var pol := capture_polarity if tkind == "polarita" else "misti"
	var n := maxi(1, capture_series)
	var manifest := []
	var r := RandomNumberGenerator.new()
	r.seed = 5102026 + li * 101 + POLARITY_MODE.get(pol, 0) * 7
	for i in n:
		var tgt := 1 if capture_series == 0 else r.randi_range(0, 3)
		cur = {"kind": tkind, "target": tgt, "level_index": li if tkind != "sonda" else -1,
			"value": 1.0 if tkind == "scaglie" else (0.8 if tkind == "movimento" else 0.0), "polarity": pol,
			"geo": Misure.trial_geometry(tkind, li if tkind != "sonda" else -1),
			"seed_bg": 11 if capture_series == 0 else r.randi() & 0x3fffffff,
			"seed_rg": 22 if capture_series == 0 else r.randi() & 0x3fffffff,
			"seed_sc": 33, "creature": "cervo", "hand": ""}
		_apply_geometry(cur["geo"], pol)
		_present()
		if tkind == "movimento":
			fake_sway = 0.05
			_set_param("parallax_deg", _parallax_deg(0.8))
		if kind in ["riscontro", "sentiero"]:
			_feedback(3, false)
			_set_param("reveal_t", 1.0)
		state = S.END
		if kind == "sentiero":
			# 0.5.13: la fila delle pietre com'è nel riscontro, al gradino della cattura
			paths["mosaico"].index = li
			rung_today = li
			rung_ever = mini(li + 2, Misure.last_rung())
			stone_last = li
			_update_stones()
			sentiero.visible = true
			_update_hud()
			hud.visible = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := capture_path if capture_series == 0 else "%s_%04d.png" % [capture_path.get_basename(), i]
		get_viewport().get_texture().get_image().save_png(path)
		manifest.append({"file": path.get_file(), "target": tgt, "seed_bg": cur["seed_bg"], "seed_rg": cur["seed_rg"],
			"kind": tkind, "level_index": li, "polarity": pol, "geo": cur["geo"]})
	if capture_series > 0:
		var f := FileAccess.open(capture_path.get_basename() + "_manifest.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(manifest, "  "))
		f.close()
	print("ROVINE_CAPTURE %s (%d)" % [capture_path, n])
	get_tree().quit()
