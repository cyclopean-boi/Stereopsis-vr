extends Node3D
## Il bosco delle lucciole — training 0.2 (mondo 1, stereopsi locale).
## A ogni prova due lucciole a portata di braccio: tocca la più vicina. La differenza di
## profondità è calcolata dalla disparità relativa voluta e dalle posizioni reali degli occhi.
## Novità della 0.2 (dopo la prima sessione, 28/9):
## - due scale alternate, una per "vicina a sinistra" e una per "vicina a destra": nella prima
##   sessione la vicina a destra era presa quasi sempre, quella a sinistra no. La media delle due
##   soglie stima la sensibilità, la semidifferenza lo sbilanciamento;
## - prove "gemelle" alla stessa distanza (1 su 10): la quota di tocchi a destra misura
##   direttamente la spinta verso un lato;
## - lucciole più alte (regolabili nella schermata iniziale) e più vicine fra loro;
## - pausa automatica quando il visore perde il fuoco (tolto dalla testa);
## - punteggio fisso in alto e lanterna nella mano che non ha toccato;
## - un riepilogo per ogni "notte" (blocco di 12 minuti).
## 0.2.1 (review T1-T7): riferimento costruito sugli occhi reali e disparità verificata entro
## tolleranza (anche con la testa inclinata); senza la rotella della parallasse le lucciole sono
## solidali con la testa anche nelle rotazioni, quindi la disparità resta quella voluta; stima
## probit con controllo di identificabilità; punti uguali fra i lati; arresto su errore di
## scrittura; pause e dose contate sul tempo attivo; avviso sulla visione doppia più prudente.
## 0.2.2 (29/9): musica di sottofondo. I brani di `musica/` (mp3 o ogg, in ordine di nome) partono
## a ogni notte e la accompagnano: si fermano in pausa, sfumano a fine notte, volume dalla
## schermata iniziale (levetta a sinistra e a destra, 0 = spenta) o con --musica=0..1.
## Il suono non è posizionale: è uguale per le due orecchie e non dice dove sono le lucciole.
## 0.3 (29/9, piano in DESIGN_TRAINING.md):
## - fuochi fatui: 1 prova su 6, a rotelle finite, ha luce e grandezza visibili; metà delle volte
##   dicono il vero, metà mentono (la vicina sembra lontana). Il riscontro segue la disparità.
##   Fuori da scale e stima; una scala propria sulla forza dell'inganno;
## - misura del contrasto fra gli occhi (una volta al giorno, a inizio sessione, saltabile);
## - modalità diagnostica --lampo: coppie per 250 ms o a tempo libero, risposta con la levetta;
## - suoni di riscontro sintetizzati, non posizionali.
## 0.4 (29/9): si entra dalla capanna del custode (capanna.gd) e a fine sessione si torna lì.
## Durata della notte, volume degli effetti e misura del contrasto si scelgono nella capanna e
## stanno nel profilo. Compito, stimoli e prove non cambiano rispetto alla 0.3.
## 0.5.4 (3/10): tre colonne nuove nel CSV, solo registrazione: rollio della testa alla comparsa
## e alla risposta, beccheggio alla comparsa (head_roll_deg, head_roll_resp_deg, head_pitch_deg).
## Compito, stimoli, scale e stima invariati rispetto alla 0.4.0.
## 0.5.7 (5/10): misura del contrasto più stabile. Un riquadro tratteggiato e quattro tacche
## attorno al puntino, visti da entrambi gli occhi, tengono la convergenza sul puntino; la levetta in
## giù (o F) segna "non riesco a fondere": la misura si scarta, non entra nella mediana e si rifà
## (al più due volte per sessione). Motivo: il 5/10, con la lucciola del sinistro a sinistra, gli
## occhi sono andati quasi paralleli e le due lucciole si sono fuse al centro. Nuova
## colonna `fusion_lost` nel CSV del contrasto; nel profilo, `scartate`. Nella capanna la misura si
## può fare anche una volta a settimana. Il compito delle lucciole non cambia.
## 0.5.8 (7/10): nel visore il riquadro non è bastato (lucciole ancora unite, quella del destro a
## volte sparita) e i tasti si confondevano. Le due lucciole ora stanno una SOPRA e una SOTTO il
## puntino (±4° in verticale): la convergenza orizzontale non le può più sovrapporre, e quella
## verticale ha un'ampiezza di un grado o due. La levetta su/giù illumina quella in alto o quella in
## basso; un solo tasto per "non vedo bene" (il laterale, o G): una lucciola sparisce, o il puntino si
## sdoppia. La misura si scarta e si rifà (al più due volte). Un promemoria dei comandi resta in alto
## durante la misura. Nel CSV `le_side` vale "su" o "giu"; `fusion_lost` = misura scartata.
## 0.5.9 (8/10): la stima (fit.gd) usa il lapse fisso a 0, per confrontare le sessioni alla pari.
## Compito, stimolo e CSV invariati.
## 0.5.10 (13/10): notti d'istinto e notti riflessive. Le notti del bosco si alternano: una d'istinto
## («tocca appena ti sembra la più vicina») e una riflessiva («prenditi il tempo»), con l'ordine invertito a
## ogni giorno di gioco, anche quando la sessione è spezzata in più ingressi (conto nel profilo, "ritmo").
## Serve a confrontare velocità e precisione dentro la stessa sessione (AGENTS.md, 12–13/10). Ogni tipo di
## notte ha la sua musica (musica/istinto/, musica/riflessiva/; se la cartella è vuota, musica/), in ordine
## mescolato senza ripetizioni che prosegue fra notti e sessioni (coda nel profilo, "musica_coda"). Nuova
## colonna "ritmo" in fondo al CSV; nel riepilogo, risposte, tempo mediano e stima per tipo di notte.
## Stimoli, scale e stima invariati. Il lampo non ha tipo di notte. --ritmo=istinto|riflessiva|no forza il
## tipo (autotest e prove); --musica-dir= cambia la cartella della musica (test).
## 0.5.11 (15/10, su richiesta): tacche sulla bacchetta. Con le scale adattive le catture restano
## sempre intorno all'80% e la notte «sembra andare ugualmente bene» finché non arriva il riepilogo. Otto
## tacche lungo la bacchetta mostrano la sensibilità della notte in corso in termini assoluti: la stima è
## quella del diario (fit.gd sulle prove di riferimento della notte, uno zero per notte), ricalcolata ogni 10
## prove di riferimento dalla 60ª; una tacca ogni decimo di decade da 631″ a 126″, verdi da 200″ in giù
## (un obiettivo per le notti riflessive). Isteresi del 3% perché le tacche non sfarfallino. Nella
## pausa la sensibilità della notte appena finita. Nuova colonna "tacche" in fondo al CSV (tacche accese
## durante la prova). Stimoli, scale, stima e punti invariati.
## 0.5.12 (16/10, su richiesta: più responsiva e granulare). Il 16/10
## la bacchetta ha cambiato stato 2 e 3 volte in tutta la notte (analisi/2026-10-16/bacchetta.py). Ora la stessa
## stima (quella del diario, sulle prove della notte in corso: a fine notte coincide col riepilogo) si ricalcola
## ogni 5 prove di riferimento invece che ogni 10, e ha mezze tacche: 15 livelli, un ventesimo di decade
## (~12%) l'uno, da 631″ a 126″; sulle 8 perle, la perla che sta per accendersi si accende piccola (60%)
## quando la stima passa il valore di mezzo. Isteresi del 2% sulle mezze tacche. Rigiocata sulle 20
## notti dal 5/10, la bacchetta cambia in media 5 volte per notte (prima 2) e, in simulazione, vede un
## miglioramento vero del 30% a metà notte nel 77% delle notti dopo ~30 prove (prima 50%, ~65). Per non
## distrarre di più, il messaggio arriva solo quando si accende una tacca intera mai accesa prima nella notte;
## le mezze tacche e le ricadute sono mute. Nuova colonna "mezze" in fondo al CSV (0–15, prima
## dell'aggiornamento della prova stessa, come "tacche"). Stimoli, scale, stima e punti invariati.
## 0.5.14 (20/10, su richiesta, dopo una notte con un ottimo inizio e un brusco calo): la
## bacchetta stima la notte con lo ZERO PER BLOCCO (40 prove di riferimento), così uno zero che si sposta non la fa
## crollare (il 20/10 ~800″ di deriva: 9 → 5 mezze tacche con uno zero, 8 col nuovo stimatore), e accende la prima
## stima alla 20ª prova invece che alla 60ª, con un priore debole sulla pendenza centrato sulla mediana delle ultime
## 5 notti dello stesso tipo (Fit.fit_bacchetta). È un riscontro: diario, CSV, riepiloghi e obiettivi restano su
## Fit.fit (uno zero per notte). La riga della pausa riporta le due stime.
## Progetto: DESIGN_TRAINING.md.

const Paths := preload("res://scripts/paths.gd")
const VERSION := "training-0.5.14"
const Geometry := preload("res://scripts/training/geometry.gd")
const Difficulty := preload("res://scripts/training/difficulty.gd")
const Progress := preload("res://scripts/training/progress.gd")
const Fit := preload("res://scripts/training/fit.gd")
const CueStaircase := preload("res://scripts/training/cue_staircase.gd")
const EyeShader := preload("res://shaders/lucciola_occhio.gdshader")

const BASE_MIN := 0.40          # distanza di base dal ciclopico (m)
const BASE_MAX := 0.55
const ELEV_DEFAULT := -12.0     # centro dell'elevazione (gradi sotto l'altezza degli occhi)
const ELEV_HALF := 5.0          # le prove variano di ±5° attorno al centro
const ELEV_LIMITS := Vector2(-25.0, 0.0)
const AZ_MIN := 3.5             # azimut delle due lucciole, ±a (gradi): separazione 7-14°
const AZ_MAX := 7.0
const CORE_DEG := 0.45          # raggio angolare del nucleo
const HALO_SCALE := 3.2
const TOUCH_R := 0.02           # raggio di tocco (m): a 40 cm e 3,5° le lucciole distano 4,9 cm
const TIP_OFFSET := Vector3(0.0, 0.0, -0.09)   # punta della bacchetta nel riferimento della presa
## 0.5.11: tacche della bacchetta (sensibilità della notte in corso, in ″, dalla più facile)
const TACCHE := [631.0, 501.0, 398.0, 316.0, 251.0, 200.0, 158.0, 126.0]
## 0.5.12: mezze tacche, un ventesimo di decade l'una; quelle di posto pari sono le tacche intere
const MEZZE := [631.0, 562.0, 501.0, 447.0, 398.0, 355.0, 316.0, 282.0, 251.0, 224.0, 200.0, 178.0, 158.0, 141.0, 126.0]
const TACCA_META := 5            # 200″: da qui in giù le tacche sono verdi
const TACCHE_MIN_N := 20         # prove di riferimento della notte prima della prima stima (0.5.14; prima 60)
const BACCHETTA_BLOCCO := 40     # 0.5.14: uno zero per ogni blocco di 40 prove di riferimento della notte
const BACCHETTA_PRIORE := 400.0  # 0.5.14: centro del priore senza notti precedenti dello stesso tipo
const BACCHETTA_PRIORE_N := 5    # 0.5.14: ultime sessioni del profilo da cui prendere il priore (mediana)
const TACCHE_OGNI := 5           # poi una nuova stima ogni 5 prove di riferimento (0.5.11: 10)
const TACCHE_ISTERESI := 0.02    # margine per accendere o spegnere una mezza tacca (0.5.11: 3% sulle intere)
const MEZZA_SCALA := 0.6         # 0.5.12: la perla a metà è accesa ma più piccola
const MAX_TIME := 7.0
const REST_SECONDS := 20.0
const DAY_SOFT_CAP := 3600.0
const PROBE_EVERY := 8          # sonda senza rotelle
const TWINS_EVERY := 10         # gemelle alla stessa distanza (prova 5, 15, 25, ...)
const WARMUP := 0.2             # a inizio sessione la disparità riparte un po' più facile
const CUE_EVERY := 6            # fuochi fatui: prova 3, 9, 15, ... se il lato è a rotelle finite
const CUE_P_TARGET := 0.9       # disparità dei fuochi fatui: giusta 9 volte su 10 senza indizi
const CUE_MIN_ARCSEC := 100.0
const LAMPO_EXPOSURE := 0.25    # secondi
const LAMPO_LEVELS := [300.0, 700.0, 1500.0]
const LAMPO_REPS := 8           # per livello, lato ed esposizione
const LAMPO_TWINS := 12         # gemelle per esposizione
const FIX_MIN := 0.6            # fissazione prima della coppia (s)
const FIX_MAX := 0.9
const C_REPS := 4               # ripetizioni della misura del contrasto
const C_L0 := 0.3               # luce di riferimento (lineare): a ±1 nessun canale satura
const C_RANGE := 1.0            # log10 del rapporto destro/sinistro: da -1 a +1
const C_VOFF := 4.0             # 0.5.8: gradi sopra e sotto il puntino (era C_AZ = 4°, ai lati)
const C_POS := ["su", "giu"]    # 0.5.8: posizione della lucciola dell'occhio sinistro, per il CSV
const C_HINT := "trigger: equal · thumbstick up/down: light · grip: can't see well"
const C_DIST := 0.5
const C_LOCK_DEG := 7.0         # 0.5.7: semilato del riquadro binoculare attorno al puntino
const C_LOCK_W_DEG := 0.1       # spessore dei tratti
const C_RETRY_MAX := 2          # misure rifatte al più, per sessione, dopo "non riesco a fondere"
const C_REFIX_S := 2.5          # pausa sul solo puntino prima di rifare la misura
const C_WEEK_DAYS := 7
const SFX_DEFAULT := 0.5
const DESKTOP_IPD := 0.063
const SIDES := ["sx", "dx"]
const MUSIC_DIR := "res://musica"
const MUSIC_DEFAULT := 0.7      # volume lineare
const MUSIC_FADE_IN := 2.0
const MUSIC_FADE_OUT := 3.0
const MUSIC_TAIL := 20.0        # se la notte sta per finire, non parte un brano nuovo
## 0.5.10: tipi di notte
const RITMI := ["istinto", "riflessiva"]
const RITMO_PLURALE := {"istinto": "Instinct nights", "riflessiva": "Reflective nights"}
const RITMO_NOME := {"istinto": "instinct", "riflessiva": "reflective"}   # solo per lo schermo (nel CSV resta ritmo)
const RITMO_CONSEGNA := {
	"istinto": "INSTINCT NIGHT. Touch the firefly that seems nearer as soon as you see it, without second-guessing.",
	"riflessiva": "REFLECTIVE NIGHT. Take your time: look carefully at both fireflies before you touch."}
## Motivi di fit.gd (salvati nel profilo così come sono), solo per lo schermo.
const MOTIVI := {"informazione singolare": "singular information", "separazione": "separation",
	"non converge": "did not converge", "meno di 3 disparità diverse": "fewer than 3 different disparities",
	"risposte separate: la curva non è identificata dalle disparità presentate": "answers fully separated: the curve can't be identified from the disparities shown",
	"pendenza non positiva": "slope not positive",
	"la curva non spiega le risposte meglio di una scelta costante": "the curve doesn't explain the answers better than a constant choice",
	"sensibilità sotto il minimo stimabile": "sensitivity below the lowest estimable value",
	"curva non determinata (intervallo della pendenza che include lo zero)": "curve not determined (slope interval includes zero)"}
const HEADER := ["session", "participant", "version", "mode", "trial", "kind", "level_target",
	"disparity_target_arcsec", "disparity_geom_arcsec", "delta_m", "base_m", "near_side",
	"az_left_deg", "az_right_deg", "elev_deg", "elev_center_deg", "ipd_m", "w_luce", "w_misura",
	"w_parallasse", "outcome", "touched_side", "correct", "rt_s", "hand", "head_move_mm", "points",
	"combo", "species", "level_after", "wheels_after", "night", "geom_ok", "disp_rl_spawn_arcsec",
	"disp_rl_resp_arcsec", "head_rot_deg", "cue", "cue_c", "exposure", "head_roll_deg", "head_roll_resp_deg",
	"head_pitch_deg", "ritmo", "tacche", "mezze"]
const C_HEADER := ["session", "participant", "version", "mode", "rep", "le_side", "log_ratio_start",
	"log_ratio_match", "light_le", "light_re", "adjust_s", "disappear_count", "disappear_times_s", "fusion_lost"]

enum S { INTRO, CONTRAST, FIX, SPAWN, WAIT, FEEDBACK, ITI_WAIT, REST, PAUSED, END, ERROR }
const PLAY_STATES := [S.FIX, S.SPAWN, S.WAIT, S.FEEDBACK, S.ITI_WAIT]

var state := S.INTRO
var timer := 0.0
var xr_active := false
var xr_focused := true
var autotest := false
var participant := "anonimo"
var session_id := ""
var mode_name := "desktop"
var results_dir := ""
var csv: FileAccess
var csv_path := ""
var rng := RandomNumberGenerator.new()
var diffs: Array = [Difficulty.new(), Difficulty.new()]   # scala per "vicina a sinistra" e "vicina a destra"
var prog := Progress.new()
var elev_center := ELEV_DEFAULT
var block_seconds := 720.0
var play_seconds := 0.0         # tempo attivo nel bosco (prove, riscontri, intervalli), per pause e dose
var stim_seconds := 0.0         # solo il tempo con le lucciole visibili
var block_played := 0.0
var sim_threshold := 400.0
var sim_bias := 0.0             # osservatore simulato: la destra sembra più vicina di tanti ″
var autotest_trials := 120
var capture_path := ""
var spawn_time := 0.25
var feedback_time := 0.7
var iti := 0.35

# scena
var origin: XROrigin3D
var camera: Node3D
var controllers: Array[XRController3D] = []
var tips: Array[Node3D] = []
var trigger_prev := {}
var quit_prev := {}
var stick_armed := {}
var rest_lore := ""
var label: Label3D
var hud: Label3D
var lantern: Node3D
var lantern_glow: MeshInstance3D
var flies: Array[Node3D] = []           # due lucciole: [sinistra, destra]
var fly_mats: Array = []                # [[nucleo, alone], [nucleo, alone]]
var cur_colors := [Color.WHITE, Color.WHITE]
var background_flies: MultiMeshInstance3D
var music: AudioStreamPlayer
var music_tracks: Array[AudioStream] = []
var music_names: Array[String] = []
var music_idx := 0
var music_volume := MUSIC_DEFAULT
var music_arg := -1.0
var music_tween: Tween
var music_dir := MUSIC_DIR
var music_sets := {}            # 0.5.10: "istinto"/"riflessiva" -> {"tracks": [...], "names": [...]}
var music_key := ""             # set in riproduzione ("" = cartella musica)
var music_last := ""            # ultimo brano partito (per non ripeterlo a cavallo della coda)
var ritmo := ""                 # tipo della notte in corso ("" nel lampo e prima della prima notte)
var ritmo_arg := ""
var ritmo_stats := {"istinto": {"fit": [], "rt": []}, "riflessiva": {"fit": [], "rt": []}}
var night_fit: Array = []       # 0.5.11: prove di riferimento della notte in corso ([disparità, destra])
var tacche := 0                 # tacche intere accese sulla bacchetta
var mezze := 0                  # 0.5.12: mezze tacche (0–15): tacche intere = (mezze + 1) / 2, e una a metà se pari
var tacche_max_notte := 0       # 0.5.12: tacche intere più alte raggiunte nella notte (il messaggio solo oltre)
var tacche_n_fit := -1          # numero di prove dell'ultima stima
var stima_notte := -1.0         # sensibilità al 79% della notte in corso (″), -1 se non ancora stimata
var priore_notte := -1.0        # 0.5.14: centro del priore della bacchetta per la notte in corso (″)
var wand_beads: Array = []      # per bacchetta, le MeshInstance3D delle tacche
var bead_mats := {}             # materiali condivisi delle tacche
var sfx: Array[AudioStreamPlayer] = []
var sfx_next := 0
var sounds := {}
var sfx_volume := SFX_DEFAULT
var fix_dot: Node3D
var fix_local := Vector3.ZERO

# prova corrente
var trial := 0
var cur := {}
var spawn_pos: Array[Vector3] = []
var head_spawn := Vector3.ZERO
var head_spawn_t := Transform3D.IDENTITY
var local_pos: Array[Vector3] = []      # posizioni delle lucciole nel riferimento della testa alla comparsa
var head_max_move := 0.0
var head_max_rot := 0.0
var fb_start: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   # posizioni all'inizio del riscontro
var armed := {}
var trial_time := 0.0

# sessione
var night := 1
var score := 0
var combo := 0
var captures := 0
var n_answered := 0
var n_correct := 0
var probes := [0, 0]
var twins := [0, 0]             # [tocchi a destra, gemelle risposte]
var by_side := [[0, 0], [0, 0]] # [giuste, risposte] con la vicina a sinistra / a destra
var night_stats := {}
var fit_data: Array = []        # [disparità segnata (+ se la vicina è a destra), toccata la destra] a rotelle finite
var new_species: Array = []
var message := ""
var message_timer := 0.0
var _saved_seconds := 0.0
var resume_to := S.ITI_WAIT
var diffs_touched := false      # le scale si salvano solo se una prova le ha mosse (niente riscaldamento accumulato)

# fuochi fatui
var fatui := CueStaircase.new()
var cue_counts := {"coerente": [0, 0], "conflitto": [0, 0]}   # [disparità seguita, prove]
var sim_cue_gain := 1.5         # osservatore simulato: peso degli indizi a c = 1, in unità di sigma

# lucciole lampo
var lampo_mode := false
var lampo_schedule: Array = []
var lampo_total := 0
var lampo_fit := {"lampo": [], "libero": []}
var lampo_twins := {"lampo": [0, 0], "libero": [0, 0]}
var lampo_cells := {}           # "esposizione|disparità segnata" -> [giuste, risposte]
var sim_bias_lampo := NAN

# misura del contrasto
var c_phase := ""
var c_rep := 0
var c_order: Array = []         # per ripetizione: lato della lucciola dell'occhio sinistro (0 sx, 1 dx)
var c_ratio := 0.0
var c_start := 0.0
var c_time := 0.0
var c_disappear: Array = []
var c_dis_total := 0
var c_results: Array = []
var c_flies: Array[MeshInstance3D] = []
var c_fix: MeshInstance3D
var c_lock: MeshInstance3D       # 0.5.7: riquadro e tacche binoculari
var c_retries := 0
var c_attempt := 0               # righe scritte nel CSV del contrasto (misure valide e scartate)
var c_scartate: Array = []
var c_csv: FileAccess
var no_contrast := false
var force_contrast := false
var sim_contrast := NAN
var grip_prev := {}
var from_capanna := false
var blocco_arg := false
var sfx_arg := false


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
		elif a.begins_with("--sim-soglia="):
			sim_threshold = a.split("=")[1].to_float()
		elif a.begins_with("--sim-bias="):
			sim_bias = a.split("=")[1].to_float()
		elif a.begins_with("--prove="):
			autotest_trials = int(a.split("=")[1])
		elif a.begins_with("--cattura="):
			capture_path = a.split("=")[1]
		elif a.begins_with("--ritmo="):
			ritmo_arg = a.split("=")[1]
		elif a.begins_with("--musica-dir="):
			music_dir = a.split("=")[1]
		elif a.begins_with("--musica="):
			music_arg = clampf(a.split("=")[1].to_float(), 0.0, 1.0)
		elif a.begins_with("--suoni="):
			sfx_volume = clampf(a.split("=")[1].to_float(), 0.0, 1.0)
			sfx_arg = true
		elif a == "--lampo":
			lampo_mode = true
		elif a == "--no-contrasto":
			no_contrast = true
		elif a == "--contrasto":
			force_contrast = true
		elif a.begins_with("--sim-contrasto="):
			sim_contrast = a.split("=")[1].to_float()
		elif a.begins_with("--sim-bias-lampo="):
			sim_bias_lampo = a.split("=")[1].to_float()
		elif a.begins_with("--sim-indizi="):
			sim_cue_gain = a.split("=")[1].to_float()
	# 0.4: opzioni passate dalla capanna
	if get_tree().root.has_meta("bosco_opts"):
		var opts: Dictionary = get_tree().root.get_meta("bosco_opts")
		get_tree().root.remove_meta("bosco_opts")
		if participant == "anonimo":
			participant = str(opts.get("partecipante", participant))
		lampo_mode = lampo_mode or bool(opts.get("lampo", false))
		from_capanna = bool(opts.get("da_capanna", false))
	participant = _sanitize(participant)
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	xr_active = xr != null and xr.is_initialized() and not autotest
	mode_name = "autotest" if autotest else ("vr" if xr_active else "desktop")
	if autotest:
		spawn_time = 0.001
		feedback_time = 0.001
		iti = 0.001
	_build_world()
	if xr_active:
		xr.session_visible.connect(_on_focus_lost)
		xr.session_stopping.connect(_on_session_stopping)
		xr.session_focussed.connect(_on_focus_gained)
	if not _open_files():
		return
	_load_difficulty(prog.data.get("difficolta", {}))
	elev_center = clampf(float(prog.data.get("elevazione", ELEV_DEFAULT)), ELEV_LIMITS.x, ELEV_LIMITS.y)
	music_volume = clampf(float(prog.data.get("musica_volume", MUSIC_DEFAULT)), 0.0, 1.0)
	if music_arg >= 0.0:
		music_volume = music_arg
	# 0.4: impostazioni della capanna (gli argomenti da riga di comando hanno la precedenza)
	if not blocco_arg:
		block_seconds = 60.0 * clampf(float(prog.data.get("durata_notte_min", 12)), 5.0, 30.0)
	if not sfx_arg:
		sfx_volume = clampf(float(prog.data.get("suoni_volume", SFX_DEFAULT)), 0.0, 1.0)
	if prog.data.get("contrasto_modo", "giorno") == "mai" and not force_contrast:
		no_contrast = true
	_setup_music()
	_setup_sounds()
	fatui.from_dict(prog.data.get("fatui", {}))
	if is_nan(sim_bias_lampo):
		sim_bias_lampo = sim_bias
	_reset_night()
	if lampo_mode:
		_build_lampo_schedule()
	_show_intro()
	if autotest or not capture_path.is_empty():
		_leave_intro()


## Profilo della 0.1 (una scala sola) o della 0.2 (una per lato); a inizio sessione un po' più facile.
func _load_difficulty(saved: Dictionary) -> void:
	for i in 2:
		var d: Dictionary = saved.get(SIDES[i], saved)
		if not d.is_empty():
			diffs[i].from_dict(d)
		diffs[i].level = minf(Difficulty.L_MAX, diffs[i].level + WARMUP)


static func _sanitize(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
	return "anonimo" if out.is_empty() else out


# ---------------------------------------------------------------- scena

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.012, 0.02, 0.045)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	add_child(env)
	origin = XROrigin3D.new()
	add_child(origin)
	if xr_active:
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var cam := XRCamera3D.new()
		cam.near = 0.03
		cam.far = 200.0
		origin.add_child(cam)
		camera = cam
		for hand in ["left_hand", "right_hand"]:
			var ctrl := XRController3D.new()
			ctrl.tracker = StringName(hand)
			ctrl.pose = &"grip"
			origin.add_child(ctrl)
			controllers.append(ctrl)
			# 0.4: si parte come se i tasti fossero premuti, così il grilletto ancora giù dalla
			# capanna non salta l'introduzione: conta solo una pressione dopo un rilascio
			trigger_prev[ctrl] = true
			quit_prev[ctrl] = true
			stick_armed[ctrl] = false
			grip_prev[ctrl] = true
			tips.append(_make_wand(ctrl))
		_make_lantern(controllers[1])   # nella 0.1 stava a sinistra, la mano che tocca
	else:
		var cam := Camera3D.new()
		cam.fov = 70.0
		cam.near = 0.03
		cam.far = 200.0
		cam.position = Vector3(0, 1.6, 0)
		origin.add_child(cam)
		cam.current = true
		camera = cam
	label = Label3D.new()
	label.font_size = 40
	label.outline_size = 8
	label.pixel_size = 0.0005
	label.no_depth_test = true
	label.modulate = Color(0.95, 0.95, 0.9)
	label.outline_modulate = Color(0, 0, 0)
	label.position = Vector3(0, 0.08, -1.2)
	camera.add_child(label)
	# punteggio solidale con la testa, in alto: lontano dalle lucciole e dalla mano
	hud = Label3D.new()
	hud.font_size = 28
	hud.outline_size = 6
	hud.pixel_size = 0.0004
	hud.no_depth_test = true
	hud.modulate = Color(1.0, 0.92, 0.6)
	hud.position = Vector3(0, 0.36, -1.2)
	camera.add_child(hud)
	for i in 2:
		var fly := Node3D.new()
		var core := _billboard(0.9, 0.62)
		var halo := _billboard(0.35, 0.0)
		halo.scale = Vector3.ONE * HALO_SCALE
		fly.add_child(halo)
		fly.add_child(core)
		fly.visible = false
		add_child(fly)
		flies.append(fly)
		fly_mats.append([core.material_override, halo.material_override])
	# punto di fissazione delle lucciole lampo: piccolo, fioco, visto da entrambi gli occhi
	fix_dot = _billboard(0.8, 0.5)
	(fix_dot.material_override as StandardMaterial3D).albedo_color = Color(0.7, 0.7, 0.8, 0.8)
	fix_dot.visible = false
	add_child(fix_dot)
	_build_contrast_nodes()
	_build_backdrop()


## Quad sempre rivolto alla camera, disegnato sopra a tutto (la mano non copre le lucciole).
func _billboard(alpha: float, solid_until: float) -> MeshInstance3D:
	var grad := Gradient.new()
	if solid_until > 0.0:
		grad.offsets = PackedFloat32Array([0.0, solid_until, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	else:
		grad.offsets = PackedFloat32Array([0.0, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true      # senza, il billboard ignora la scala del nodo
	mat.no_depth_test = true
	mat.render_priority = 10
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, alpha)
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)     # raggio 1: la scala del nodo è il raggio in metri
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_wand(ctrl: XRController3D) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.45, 0.36, 0.25)
	var stick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.005
	cyl.height = absf(TIP_OFFSET.z)
	stick.mesh = cyl
	stick.material_override = mat
	stick.rotation_degrees = Vector3(90, 0, 0)
	stick.position = TIP_OFFSET * 0.5
	ctrl.add_child(stick)
	var tip := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.007
	sph.height = 0.014
	tip.mesh = sph
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.albedo_color = Color(0.95, 0.85, 0.6)
	tip.material_override = tmat
	tip.position = TIP_OFFSET
	ctrl.add_child(tip)
	# 0.5.11: tacche sopra il manico, dalla mano (631″) verso la punta (126″)
	var beads := []
	var bm := SphereMesh.new()
	bm.radius = 0.0022
	bm.height = 0.0044
	for i in TACCHE.size():
		var b := MeshInstance3D.new()
		b.mesh = bm
		b.position = Vector3(0.0, 0.0058, lerpf(-0.012, -0.078, float(i) / (TACCHE.size() - 1)))
		ctrl.add_child(b)
		beads.append(b)
	wand_beads.append(beads)
	_show_tacche()
	return tip


func _make_lantern(ctrl: XRController3D) -> void:
	var glass := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.022
	cyl.bottom_radius = 0.026
	cyl.height = 0.06
	glass.mesh = cyl
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.albedo_color = Color(0.6, 0.7, 0.8, 0.18)
	glass.material_override = gmat
	glass.position = Vector3(0, -0.02, 0.05)
	ctrl.add_child(glass)
	lantern = glass
	lantern_glow = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.016
	sph.height = 0.032
	lantern_glow.mesh = sph
	var lmat := StandardMaterial3D.new()
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmat.albedo_color = Color(0.1, 0.12, 0.05)
	lantern_glow.material_override = lmat
	glass.add_child(lantern_glow)


## Sfondo: stelle e tronchi lontani, e lucciole decorative sopra l'orizzonte che aumentano con
## le catture totali (a 6-15 m la loro disparità è trascurabile e stanno lontano dalla zona di gioco).
func _build_backdrop() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var head := Vector3(0, 1.6, 0)
	var star_mm := MultiMesh.new()
	star_mm.transform_format = MultiMesh.TRANSFORM_3D
	var star := SphereMesh.new()
	star.radius = 0.05
	star.height = 0.1
	star.radial_segments = 4
	star.rings = 2
	star_mm.mesh = star
	star_mm.instance_count = 350
	for i in 350:
		var dir := Vector3(r.randf_range(-1, 1), r.randf_range(0.15, 1.0), r.randf_range(-1, 1)).normalized()
		star_mm.set_instance_transform(i, Transform3D(Basis(), head + dir * 60.0))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = star_mm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.5, 0.55, 0.7)
	stars.material_override = smat
	add_child(stars)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 45.0
	disc.bottom_radius = 45.0
	disc.height = 0.02
	ground.mesh = disc
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.albedo_color = Color(0.004, 0.006, 0.009)
	ground.material_override = gmat
	ground.position = Vector3(0, -0.01, 0)
	add_child(ground)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trunk_mat.albedo_color = Color(0.0, 0.0, 0.005)
	for i in 28:
		var ang := r.randf() * TAU
		var dist := r.randf_range(9.0, 26.0)
		var trunk := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = r.randf_range(0.12, 0.3)
		cyl.bottom_radius = cyl.top_radius * 1.3
		cyl.height = 16.0
		trunk.mesh = cyl
		trunk.material_override = trunk_mat
		trunk.position = Vector3(cos(ang) * dist, 6.0, sin(ang) * dist)
		add_child(trunk)
	var fmm := MultiMesh.new()
	fmm.transform_format = MultiMesh.TRANSFORM_3D
	var fs := SphereMesh.new()
	fs.radius = 0.03
	fs.height = 0.06
	fs.radial_segments = 6
	fs.rings = 3
	fmm.mesh = fs
	fmm.instance_count = 220
	fmm.visible_instance_count = 0
	for i in 220:
		var ang := r.randf() * TAU
		var dist := r.randf_range(6.0, 15.0)
		fmm.set_instance_transform(i, Transform3D(Basis(), Vector3(cos(ang) * dist, 1.6 + r.randf_range(0.2, 4.0), sin(ang) * dist)))
	background_flies = MultiMeshInstance3D.new()
	background_flies.multimesh = fmm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(0.6, 0.8, 0.3)
	background_flies.material_override = fmat
	add_child(background_flies)


func _update_backdrop() -> void:
	background_flies.multimesh.visible_instance_count = mini(220, 6 + int(prog.data["catture"]) / 4)


# ---------------------------------------------------------------- musica

func _setup_music() -> void:
	if music == null:
		music = AudioStreamPlayer.new()
		music.name = "Musica"
		add_child(music)
		music.finished.connect(_on_music_finished)
	_load_music()


## Brani della cartella musica (come prima) e, dalla 0.5.10, delle sottocartelle per tipo di notte.
func _load_music() -> void:
	var base := _load_dir(Paths.globalize(music_dir))
	music_tracks.assign(base["tracks"])
	music_names.assign(base["names"])
	music_sets = {}
	for r in RITMI:
		music_sets[r] = _load_dir(Paths.globalize(music_dir + "/" + r))


static func _load_dir(dir: String) -> Dictionary:
	var out := {"tracks": [], "names": []}
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var names := Array(DirAccess.get_files_at(dir))
	names.sort()
	for f in names:
		if f.get_extension().to_lower() not in ["mp3", "ogg"]:
			continue
		var st := _load_track(dir + "/" + f)
		if st == null:
			push_warning("Brano non leggibile: " + f)
			continue
		out["tracks"].append(st)
		out["names"].append(f.get_basename())
	return out


## Letto dai byte del file, così funziona anche senza l'importazione dell'editor.
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
	return music != null and music_volume > 0.001 and _has_any_track()


func _has_any_track() -> bool:
	if not music_tracks.is_empty():
		return true
	for r in music_sets:
		if not music_sets[r]["tracks"].is_empty():
			return true
	return false


func _set_tracks(key: String) -> Array:
	return music_tracks if key == "" else music_sets[key]["tracks"]


func _set_names(key: String) -> Array:
	return music_names if key == "" else music_sets[key]["names"]


## Il set di un tipo di notte: la sua cartella se ha brani, altrimenti la cartella musica, altrimenti
## una qualunque cartella con brani.
func _set_for(r: String) -> String:
	if r != "" and music_sets.has(r) and not music_sets[r]["tracks"].is_empty():
		return r
	if not music_tracks.is_empty():
		return ""
	for k in RITMI:
		if music_sets.has(k) and not music_sets[k]["tracks"].is_empty():
			return k
	return ""


## 0.5.10: ordine mescolato senza ripetizioni finché non sono passati tutti, che prosegue fra notti e
## sessioni (coda per set nel profilo). Alla nuova mescolata l'ultimo brano non riparte subito.
func _next_track(key: String) -> int:
	var names: Array = _set_names(key)
	if names.is_empty():
		return -1
	var label := key if key != "" else "base"
	var coda: Dictionary = prog.data.get("musica_coda", {})
	var q: Array = coda.get(label, []).duplicate()
	var i := -1
	while i < 0:
		if q.is_empty():
			q = names.duplicate()
			q.shuffle()
			if q.size() > 1 and str(q[0]) == music_last:
				q.push_back(q.pop_front())
		i = names.find(str(q.pop_front()))
	coda[label] = q
	prog.data["musica_coda"] = coda
	return i


func _music_line() -> String:
	var ni: int = music_sets.get("istinto", {"tracks": []})["tracks"].size()
	var nr: int = music_sets.get("riflessiva", {"tracks": []})["tracks"].size()
	if not _has_any_track():
		return "Music: no tracks in the musica folder."
	if not _music_on():
		return "Music: off (thumbstick right to turn it on)."
	if ni + nr > 0:
		return "Music: %d%%; %d tracks for instinct nights, %d for reflective nights (thumbstick left/right; 0 = off)." % [roundi(music_volume * 100.0), ni, nr]
	return "Music: %d%%, %d tracks (thumbstick left/right; 0 = off)." % [roundi(music_volume * 100.0), music_tracks.size()]


func _kill_music_tween() -> void:
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	music_tween = null


func _music_play(i: int, fade: float) -> void:
	_kill_music_tween()
	music_idx = i
	music.stream = _set_tracks(music_key)[i]
	music_last = str(_set_names(music_key)[i])
	music.stream_paused = false
	var target := linear_to_db(music_volume)
	music.volume_db = -60.0 if fade > 0.0 else target
	music.play()
	if fade > 0.0:
		music_tween = create_tween()
		music_tween.tween_property(music, "volume_db", target, fade)


## 0.5.10: la notte prende i brani del suo tipo, dalla coda mescolata.
func _music_start_night() -> void:
	if not _music_on():
		return
	music_key = _set_for(ritmo)
	var i := _next_track(music_key)
	if i >= 0:
		_music_play(i, MUSIC_FADE_IN)


func _on_music_finished() -> void:
	if not _music_on() or state not in [S.SPAWN, S.WAIT, S.FEEDBACK, S.ITI_WAIT]:
		return
	if block_seconds - block_played < MUSIC_TAIL:
		return
	var i := _next_track(music_key)
	if i >= 0:
		_music_play(i, 0.0)


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


## Nell'introduzione: cambia il volume e fa sentire un'anteprima.
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
		music_key = _set_for(_ritmo_prossimo())
		_music_play(0, 0.5)
	_show_intro()


# ---------------------------------------------------------------- tipi di notte (0.5.10)

static func _altro(r: String) -> String:
	return "riflessiva" if r == "istinto" else "istinto"


## Il tipo della prossima notte. Nello stesso giorno le notti si alternano; un giorno nuovo comincia con il
## tipo opposto alla prima notte del giorno di gioco precedente. Senza storia si parte d'istinto.
func _ritmo_prossimo() -> String:
	if lampo_mode or ritmo_arg == "no":
		return ""
	if ritmo_arg in RITMI:
		return ritmo_arg
	var rd: Dictionary = prog.data.get("ritmo", {})
	if str(rd.get("data", "")) == Time.get_date_string_from_system():
		return str(rd["primo"]) if int(rd.get("notti", 0)) % 2 == 0 else _altro(str(rd["primo"]))
	return "istinto" if rd.is_empty() else _altro(str(rd.get("primo", "riflessiva")))


## All'inizio di ogni notte: fissa il tipo e lo conta nel profilo (non quando è forzato da --ritmo).
func _inizia_ritmo() -> void:
	ritmo = _ritmo_prossimo()
	if ritmo == "" or ritmo_arg in RITMI:
		return
	var today := Time.get_date_string_from_system()
	var rd: Dictionary = prog.data.get("ritmo", {})
	if str(rd.get("data", "")) != today:
		rd = {"data": today, "primo": ritmo, "notti": 0}
	rd["notti"] = int(rd.get("notti", 0)) + 1
	prog.data["ritmo"] = rd


# ---------------------------------------------------------------- suoni

## Suoni di riscontro sintetizzati all'avvio (0.3): niente file e niente posizione nello spazio,
## quindi non dicono dov'è una lucciola. Suonano solo dopo la risposta.
func _setup_sounds() -> void:
	for i in 3:
		var pl := AudioStreamPlayer.new()
		pl.name = "Effetto%d" % i
		add_child(pl)
		sfx.append(pl)
	sounds["cattura"] = _synth([[659.3, 0.0, 0.5], [987.8, 0.0, 0.15]], 0.8, 0.25)
	sounds["fuga"] = _synth([[196.0, 0.0, 0.3], [207.7, 0.0, 0.22]], 0.4, 0.1)
	sounds["gemelle"] = _synth([[523.3, 0.0, 0.35], [659.3, 0.09, 0.3]], 0.8, 0.28)
	sounds["fatuo"] = _synth([[523.3, 0.0, 0.3], [659.3, 0.08, 0.3], [784.0, 0.16, 0.3], [1046.5, 0.24, 0.3]], 1.2, 0.3)
	sounds["specie"] = _synth([[392.0, 0.0, 0.3], [523.3, 0.12, 0.3], [659.3, 0.24, 0.3], [784.0, 0.36, 0.35]], 1.6, 0.45)
	sounds["notte"] = _synth([[261.6, 0.0, 0.25], [329.6, 0.0, 0.2], [392.0, 0.0, 0.2]], 2.0, 0.6)
	sounds["segno"] = _synth([[880.0, 0.0, 0.25]], 0.25, 0.06)


## Campanelle: per nota [frequenza, inizio (s), ampiezza], con due armoniche e decadimento esponenziale.
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
			var env := exp(-dt / decay) * minf(1.0, dt * 400.0)
			v += float(nt[2]) * env * (sin(TAU * f * dt) + 0.25 * sin(TAU * 2.0 * f * dt) + 0.08 * sin(TAU * 3.0 * f * dt))
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


# ---------------------------------------------------------------- fuochi fatui

## Disparità delle prove con indizi, per lato: quella a cui, senza indizi, la risposta sarebbe
## giusta CUE_P_TARGET delle volte secondo l'ultima stima informativa (sessioni precedenti).
## Tiene conto dello sbilanciamento: con lo zero verso destra, la vicina a sinistra ha bisogno di
## più disparità. Senza una stima: il doppio della soglia della scala di quel lato.
func _cue_disparity(near: int) -> float:
	var st := _last_estimate()
	var d := 0.0
	if not st.is_empty():
		var z := Fit.phi_inv(CUE_P_TARGET) * float(st["sigma"])
		var zero := float(st["zero"])
		d = z - zero if near == 1 else z + zero
	else:
		d = 2.0 * pow(10.0, diffs[near].level)
	return clampf(d, CUE_MIN_ARCSEC, pow(10.0, Difficulty.L_MAX))


func _last_estimate() -> Dictionary:
	var sess: Array = prog.data["sessioni"]
	for i in range(sess.size() - 1, -1, -1):
		var st: Dictionary = sess[i].get("stima", {})
		if st.get("stimabile", false):
			return st
	return {}


# ---------------------------------------------------------------- lucciole lampo

## 120 prove in ordine casuale: per esposizione (lampo, libero) 3 disparità × 2 lati × 8, più 12
## gemelle. Stesse coppie di riferimento del bosco; cambia solo quanto restano in vista.
func _build_lampo_schedule() -> void:
	lampo_schedule.clear()
	for ex in ["lampo", "libero"]:
		for lv in LAMPO_LEVELS:
			for side in 2:
				for r in LAMPO_REPS:
					lampo_schedule.append({"exposure": ex, "near": side, "target": lv})
		for r in LAMPO_TWINS:
			lampo_schedule.append({"exposure": ex, "near": r % 2, "target": 0.0})
	for i in range(lampo_schedule.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = lampo_schedule[i]
		lampo_schedule[i] = lampo_schedule[j]
		lampo_schedule[j] = tmp
	lampo_total = lampo_schedule.size()


func _next_lampo_trial() -> void:
	if lampo_schedule.is_empty():
		_finish()
		return
	trial += 1
	var item: Dictionary = lampo_schedule.pop_back()
	_place_pair(int(item["near"]), float(item["target"]), {"luce": 0.0, "misura": 0.0, "parallasse": 0.0}, 1.0)
	cur["kind"] = "gemelle" if float(item["target"]) == 0.0 else "normale"
	cur["level"] = log(maxf(float(item["target"]), 1.0)) / log(10.0)
	cur["exposure"] = item["exposure"]
	cur["item"] = item
	for f in flies:
		f.visible = false
	# punto di fissazione fra le due lucciole, alla distanza di base, solidale con la testa
	var eyes := _eyes()
	var cyc: Vector3 = (eyes[0] + eyes[1]) * 0.5
	var frame := Geometry.eye_frame(eyes[0], eyes[1], -camera.global_transform.basis.z)
	var p := cyc + Geometry.direction_in(frame, 0.0, float(cur["elev"])) * float(cur["base"])
	fix_local = head_spawn_t.affine_inverse() * p
	fix_dot.position = p
	fix_dot.scale = Vector3.ONE * float(cur["base"]) * tan(deg_to_rad(0.2))
	fix_dot.visible = true
	trial_time = 0.0
	state = S.FIX
	timer = 0.001 if autotest else rng.randf_range(FIX_MIN, FIX_MAX)


func _answer_lampo(touched: int) -> void:
	n_answered += 1
	prog.data["prove"] = int(prog.data["prove"]) + 1
	_mark_response()
	for f in flies:
		f.visible = false
	var ex: String = cur["exposure"]
	if cur["geom_ok"]:
		lampo_fit[ex].append([cur["rl_spawn"], touched == 1])
	var correct := false
	var points := 0
	var outcome := "gemelle"
	if cur["kind"] == "gemelle":
		lampo_twins[ex][1] += 1
		lampo_twins[ex][0] += 1 if touched == 1 else 0
		captures += 1
		_play("gemelle")
	else:
		var near: int = cur["near"]
		correct = touched == near
		outcome = "near" if correct else "far"
		var key := "%s|%s|%d" % [ex, SIDES[near], roundi(float(cur["target"]))]
		if not lampo_cells.has(key):
			lampo_cells[key] = [0, 0]
		lampo_cells[key][1] += 1
		lampo_cells[key][0] += 1 if correct else 0
		by_side[near][1] += 1
		by_side[near][0] += 1 if correct else 0
		if correct:
			n_correct += 1
			combo += 1
			captures += 1
			points = roundi(15.0 * (1.0 + 0.1 * mini(combo, 20)))
			score += points
			_play("cattura", pow(2.0, mini(combo - 1, 12) / 12.0))
			_pulse(0.5, 0.06)
		else:
			combo = 0
			_play("fuga")
			_pulse(0.15, 0.12)
	if not _log(outcome, touched, correct, points):
		return
	cur["correct"] = correct
	cur["touched"] = touched
	state = S.FEEDBACK
	timer = feedback_time
	_update_hud()


func _finish_lampo() -> void:
	var lines := ["FLASH FIREFLIES: RESULTS", ""]
	var rec := {"tipo": "lampo", "sessione": session_id, "versione": VERSION, "data": Time.get_datetime_string_from_system(),
		"modo": mode_name, "prove": n_answered, "esposizione_s": LAMPO_EXPOSURE}
	for ex in ["lampo", "libero"]:
		var f := Fit.fit(lampo_fit[ex])
		var cells := {}
		for key in lampo_cells:
			var parts: PackedStringArray = key.split("|")
			if parts[0] == ex:
				cells[parts[1] + "_" + parts[2]] = lampo_cells[key].duplicate()
		rec[ex] = {"stima": f, "gemelle_destra": lampo_twins[ex].duplicate(), "celle": cells}
		var title := "Flash (%d ms)" % roundi(LAMPO_EXPOSURE * 1000.0) if ex == "lampo" else "Untimed"
		if f["stimabile"]:
			lines.append("%s: sensitivity at 79%% ~%d″ (%d–%d″); bias %s." % [title,
				roundi(f["soglia79"]), roundi(f["soglia79_ic"][0]), roundi(f["soglia79_ic"][1]), _fmt_zero(f)])
		else:
			lines.append("%s: estimate not available (%s)." % [title, _motivo_txt(f["motivo"])])
		var row := []
		for side in SIDES:
			var parts2 := []
			for lv in LAMPO_LEVELS:
				var c: Array = cells.get("%s_%d" % [side, roundi(lv)], [0, 0])
				parts2.append("%d/%d" % [c[0], c[1]])
			row.append("nearer on the %s %s" % ["left" if side == "sx" else "right", " ".join(parts2)])
		lines.append("   " + " · ".join(row) + " (at 300, 700, 1500″)")
		lines.append("   Twins touched on the right: %d of %d." % [lampo_twins[ex][0], lampo_twins[ex][1]])
	if n_answered > 0:
		prog.data["diagnosi"].append(rec)
	var saved := _save_progress()
	if not saved:
		lines.insert(1, "WARNING: profile not saved (the trials are in the CSV).")
	lines.append("")
	lines.append(_close_line())
	var text := "\n".join(lines)
	print("BOSCO_RESULT\n" + text)
	_say(text)
	_play("notte")
	if autotest:
		get_tree().quit()


# ---------------------------------------------------------------- misura del contrasto

func _build_contrast_nodes() -> void:
	var radius := C_DIST * tan(deg_to_rad(CORE_DEG))
	for i in 2:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 2.0 * HALO_SCALE * radius
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = EyeShader
		m.set_shader_parameter("halo", HALO_SCALE)
		m.render_priority = 10
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		camera.add_child(mi)
		c_flies.append(mi)
	c_fix = _billboard(0.8, 0.5)
	(c_fix.material_override as StandardMaterial3D).albedo_color = Color(0.7, 0.7, 0.8, 0.8)
	c_fix.scale = Vector3.ONE * C_DIST * tan(deg_to_rad(0.2))
	c_fix.visible = false
	camera.add_child(c_fix)
	c_lock = MeshInstance3D.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.42, 0.42, 0.5)
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	lm.no_depth_test = true
	lm.render_priority = 9
	c_lock.material_override = lm
	c_lock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c_lock.visible = false
	camera.add_child(c_lock)


## 0.5.7: riquadro tratteggiato (semilato C_LOCK_DEG) e quattro tacche attorno al puntino, sulla
## sfera di raggio C_DIST come lucciole e puntino: stessa distanza, quindi disparità nulla rispetto
## al puntino. I tratti verticali danno l'aggancio per la convergenza orizzontale.
static func fusion_lock_mesh(elev_deg: float) -> ArrayMesh:
	var rects := []   # [az0, az1, el0, el1] in gradi, relativi al centro
	var h := C_LOCK_DEG
	var w := C_LOCK_W_DEG * 0.5
	var n := 7
	var step := 2.0 * h / n
	for k in n:
		var a0 := -h + k * step + step * 0.2
		var a1 := a0 + step * 0.6
		rects.append([a0, a1, h - w, h + w])
		rects.append([a0, a1, -h - w, -h + w])
		rects.append([h - w, h + w, a0, a1])
		rects.append([-h - w, -h + w, a0, a1])
	for t in [[0.6, 1.3]]:
		rects.append([-w, w, t[0], t[1]])
		rects.append([-w, w, -t[1], -t[0]])
		rects.append([t[0], t[1], -w, w])
		rects.append([-t[1], -t[0], -w, w])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rects:
		var v := []
		for c in [[r[0], r[2]], [r[1], r[2]], [r[1], r[3]], [r[0], r[3]]]:
			var az := deg_to_rad(float(c[0]))
			var el := deg_to_rad(elev_deg + float(c[1]))
			v.append(Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)) * C_DIST)
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(v[i])
	return st.commit()


## Una volta al giorno, a inizio sessione, se non è stata chiesta di saltarla.
func _contrast_due() -> bool:
	if lampo_mode or no_contrast or not capture_path.is_empty():
		return false
	if autotest:
		return not is_nan(sim_contrast)
	if force_contrast:
		return true
	var list: Array = prog.data["contrasto"]
	if list.is_empty():
		return true
	var last := str(list[-1].get("data", "")).substr(0, 10)
	if prog.data.get("contrasto_modo", "giorno") == "settimana":
		var days := (Time.get_unix_time_from_system() - Time.get_unix_time_from_datetime_string(last + "T00:00:00")) / 86400.0
		return days >= C_WEEK_DAYS
	return last != Time.get_date_string_from_system()


func _start_contrast() -> void:
	state = S.CONTRAST
	c_phase = "intro"
	c_rep = 0
	c_results.clear()
	c_dis_total = 0
	c_retries = 0
	c_attempt = 0
	c_scartate.clear()
	c_order = [0, 1, 0, 1]
	c_order.shuffle()
	for f in flies:
		f.visible = false
	hud.visible = false
	_say("CONTRAST MATCH BETWEEN THE EYES (about a minute)\n\nLook at the dot in the middle of the frame. Above and below it you'll see two fireflies: one is seen only by your left eye, the other only by your right. Push the thumbstick toward the dimmer firefly (up or down) until they look equally bright, then press the trigger. Four times. If they don't look exactly one above the other, that's fine: don't try to line them up.\n\nIf a firefly disappears, or the dot doubles, press the GRIP BUTTON (or G): that match is discarded and redone. Don't strain. The controls stay written at the top.\n\nTrigger (or Space) to start, B/Y (or Esc) to skip the match.")
	if autotest:
		_contrast_begin_rep()


func _contrast_begin_rep() -> void:
	c_phase = "adjust"
	label.visible = false
	c_ratio = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.25, 0.6)   # partenza casuale
	c_start = c_ratio
	c_time = 0.0
	c_disappear.clear()
	var le_side: int = c_order[c_rep]
	var e := deg_to_rad(elev_center)
	for i in 2:   # posizione: 0 sopra, 1 sotto il puntino
		var ei := deg_to_rad(elev_center + (C_VOFF if i == 0 else -C_VOFF))
		c_flies[i].position = Vector3(0.0, sin(ei), -cos(ei)) * C_DIST
		var eye := 0 if i == le_side else 1
		(c_flies[i].material_override as ShaderMaterial).set_shader_parameter("eye", eye if xr_active else -1)
		c_flies[i].visible = true
	c_fix.position = Vector3(0.0, sin(e), -cos(e)) * C_DIST
	c_fix.visible = true
	c_lock.mesh = fusion_lock_mesh(elev_center)
	c_lock.visible = true
	_contrast_apply()
	hud.text = "match %d of %d\n%s" % [c_rep + 1, C_REPS, C_HINT]
	hud.visible = true
	if autotest:
		c_ratio = clampf(sim_contrast + rng.randfn(0.0, 0.08), -C_RANGE, C_RANGE)
		_contrast_apply()
		_contrast_confirm()


## [luce della lucciola dell'occhio sinistro, luce di quella del destro], lineari.
func _contrast_lights() -> Array:
	return [C_L0 * pow(10.0, -c_ratio / 2.0), C_L0 * pow(10.0, c_ratio / 2.0)]


func _contrast_apply() -> void:
	var l := _contrast_lights()
	var le_side: int = c_order[c_rep]
	for i in 2:
		var lv: float = l[0] if i == le_side else l[1]
		(c_flies[i].material_override as ShaderMaterial).set_shader_parameter("light", Vector3(1.0, 0.95, 0.7) * lv)


## 0.5.8: dy > 0: la lucciola in alto diventa più luminosa rispetto a quella in basso. Se in alto c'è
## quella del sinistro (c_order 0), il rapporto destro/sinistro scende.
func _contrast_adjust(dy: float) -> void:
	var dr := -dy if c_order[c_rep] == 0 else dy
	c_ratio = clampf(c_ratio + dr, -C_RANGE, C_RANGE)
	_contrast_apply()


## Scrive la riga della misura corrente. lost = "non riesco a fondere": la riga resta nel CSV ma la
## misura non entra nella mediana.
func _contrast_log(lost: bool) -> bool:
	var l := _contrast_lights()
	var r := log(float(l[1]) / float(l[0])) / log(10.0)
	if lost:
		c_scartate.append(r)
	else:
		c_results.append(r)
	c_attempt += 1
	var times := []
	for t in c_disappear:
		times.append("%.2f" % t)
	if c_csv == null:        # il file nasce alla prima misura: saltare la misura non lascia file vuoti
		var path := results_dir + "contrasto_%s.csv" % session_id
		c_csv = FileAccess.open(path, FileAccess.WRITE)
		if c_csv == null:
			_fatal("Cannot write %s" % path)
			return false
		c_csv.store_csv_line(PackedStringArray(C_HEADER))
	c_csv.store_csv_line(PackedStringArray([session_id, participant, VERSION, mode_name, str(c_attempt),
		C_POS[c_order[c_rep]], "%.3f" % c_start, "%.3f" % r, "%.4f" % l[0], "%.4f" % l[1], "%.2f" % c_time,
		str(c_disappear.size()), " ".join(times), "1" if lost else "0"]))
	c_csv.flush()
	if c_csv.get_error() != OK:
		_fatal("Write error during the contrast match: the forest stops.")
		return false
	c_dis_total += c_disappear.size()
	c_disappear.clear()
	return true


func _contrast_confirm() -> void:
	if not _contrast_log(false):
		return
	c_rep += 1
	_play("segno", 1.5)
	_contrast_next()


## "Non vedo bene" (0.5.7 "non riesco a fondere"; dalla 0.5.8 anche una lucciola sparita). La misura si
## scarta; si rifà la stessa (stessa disposizione) dopo qualche secondo sul solo puntino, al più
## C_RETRY_MAX volte per sessione; poi si va avanti.
func _contrast_fusion_lost() -> void:
	if not _contrast_log(true):
		return
	_play("segno", 0.7)
	for n in c_flies:
		n.visible = false
	if c_retries < C_RETRY_MAX:
		c_retries += 1
		c_phase = "refix"
		timer = C_REFIX_S
		hud.text = "match %d of %d · discarded\nclose your eyes for a moment, then look at the dot" % [c_rep + 1, C_REPS]
		if autotest:
			_contrast_begin_rep()
		return
	c_rep += 1
	_contrast_next()


func _contrast_next() -> void:
	for n in c_flies:
		n.visible = false
	c_fix.visible = false
	c_lock.visible = false
	if c_rep >= C_REPS:
		_contrast_done(false)
	elif autotest:
		_contrast_begin_rep()
	else:
		c_phase = "gap"
		timer = 0.6


static func _median(v: Array) -> float:
	var a := v.duplicate()
	a.sort()
	var n := a.size()
	if n == 0:
		return NAN
	return float(a[n / 2]) if n % 2 == 1 else 0.5 * (float(a[n / 2 - 1]) + float(a[n / 2]))


func _contrast_done(skipped: bool) -> void:
	for n in c_flies:
		n.visible = false
	c_fix.visible = false
	c_lock.visible = false
	hud.visible = false
	if c_results.is_empty():
		if c_scartate.is_empty() or skipped:
			_start_play()
			return
		c_phase = "result"
		_say("CONTRAST MATCH\n\nNo valid match today: all were discarded because you couldn't see well. That's not a problem; the match will be done another time.\n\nTrigger (or Space) to enter the forest. B/Y (or Esc) to go home.")
		if autotest:
			_start_play()
		return
	var med := _median(c_results)
	var mean := 0.0
	for r in c_results:
		mean += float(r)
	mean /= c_results.size()
	var sd := 0.0
	for r in c_results:
		sd += pow(float(r) - mean, 2.0)
	sd = sqrt(sd / maxf(1.0, c_results.size() - 1.0))
	var n_dis := c_dis_total
	prog.data["contrasto"].append({"data": Time.get_datetime_string_from_system(), "sessione": session_id,
		"versione": VERSION, "modo": mode_name, "log_rapporto": c_results.duplicate(), "mediana": med,
		"ds": sd, "sparizioni": n_dis, "incompleta": skipped, "ordine": c_order.duplicate(),
		"scartate": c_scartate.duplicate()})
	_save_progress()
	if skipped:
		_start_play()
		return
	var times := pow(10.0, absf(med))
	var txt := "CONTRAST MATCH\n\n"
	if absf(med) < 0.05:
		txt += "The two fireflies looked equal to you at the same light: no difference between the eyes."
	else:
		txt += "To look equal, the %s eye's firefly needed %.1f times the light of the %s eye's firefly." % [
			"right" if med > 0.0 else "left", times, "left" if med > 0.0 else "right"]
	var reps := []
	for r in c_results:
		reps.append("%.1f" % pow(10.0, float(r)))
	txt += "\n\n%s (right/left light): %s." % ["The four matches" if reps.size() == 4 else "The valid matches", ", ".join(reps)]
	if sd > 0.25:
		txt += " They don't agree well with each other: take it as a rough guide."
	if n_dis > 0:
		txt += "\nDisappearances reported: %d." % n_dis
	if not c_scartate.is_empty():
		txt += "\nMatches discarded because you couldn't see well: %d." % c_scartate.size()
	txt += "\n\nTrigger (or Space) to enter the forest. B/Y (or Esc) to go home."
	c_phase = "result"
	_say(txt)
	if autotest:
		_start_play()


func _contrast_skip() -> void:
	_contrast_done(true)


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
	label.text = _wrap(text, 48)
	label.visible = true


## Sbilanciamento con segno e intervallo: positivo = la destra sembra più vicina.
static func _fmt_zero(f: Dictionary) -> String:
	var z: float = f["zero"]
	var txt := "%+d″" % roundi(z)
	if f.has("zero_ic"):
		txt += " (rough interval %+d to %+d″)" % [roundi(f["zero_ic"][0]), roundi(f["zero_ic"][1])]
	return txt + (", the right one looks nearer" if z > 0.0 else ", the left one looks nearer")


## Motivo di una stima non disponibile, per lo schermo (nel profilo resta quello di fit.gd).
static func _motivo_txt(m: String) -> String:
	if m.begins_with("meno di ") and m.ends_with(" risposte"):
		return "fewer than %s answers" % m.trim_prefix("meno di ").trim_suffix(" risposte")
	var parts := []
	for p in m.split(", "):
		parts.append(MOTIVI.get(p, p))
	return ", ".join(parts)


func _fmt_thr(t: float) -> String:
	return "%d″" % roundi(t) if t > 0.0 else "not yet stable"


func _show_intro() -> void:
	state = S.INTRO
	_update_backdrop()
	var n_species: int = prog.data["specie"].size()
	var last := ""
	var sess: Array = prog.data["sessioni"]
	if not sess.is_empty():
		var st: Dictionary = sess[-1].get("stima", {})
		last = "Last estimated sensitivity: %s. " % (_fmt_thr(float(st["soglia79"])) if st.get("stimabile", false) else "not available")
	if lampo_mode:
		_say("FLASH FIREFLIES (%s): diagnostic test, about 7 minutes\n\nLook at the dot in the middle. Then two fireflies appear: sometimes just for a flash, sometimes they stay until you answer. Point to the NEARER one with the thumbstick: left or right (or the arrow keys). If you're not sure, choose anyway.\n\nHeight: %d° below your eyes (thumbstick up and down).\n%s\n\nStop if you see double outside the headset or feel any discomfort (B/Y).\n\nTrigger (or Space) to start. B/Y (or Esc) to finish." % [
			participant, roundi(-elev_center), _music_line()])
		_show_preview()
		_update_hud()
		return
	var fatui_note := ""
	if diffs[0].wheels_off() or diffs[1].wheels_off():
		fatui_note = "\n\nBeware the will-o'-wisps: sometimes a firefly pretends to be near or far with its light and size. Trust your two eyes."
	_say("THE FIREFLY FOREST (%s)\n\nWith the tip of your wand, touch the NEARER firefly. The first one you touch is your answer. Sometimes the fireflies are twins, at the same distance: touch the one that seems nearer.\n\nFirefly height: %d° below your eyes (thumbstick up and down to change it; you can see them below).\n%s\n\nSpecies discovered: %d of %d. %s\n\nStop and see an eye doctor if you see double OUTSIDE the headset, if headaches or eye discomfort don't go away, or if your vision changes. In the headset, two fireflies far apart in depth can look double; if the double vision is new, doesn't go away or bothers you, stop right away (B/Y).\n\nTrigger (or Space) to enter the forest. B/Y (or Esc) to finish." % [
		participant, roundi(-elev_center), _music_line() + (("\n\nTonight: " + RITMO_CONSEGNA[_ritmo_prossimo()]) if _ritmo_prossimo() != "" else ""), n_species, Progress.SPECIES.size(), last + fatui_note])
	_show_preview()
	_update_hud()


## Anteprima dell'altezza: due lucciole alla stessa distanza, al centro dell'elevazione scelta.
func _show_preview() -> void:
	var eyes := _eyes()
	var cyc: Vector3 = (eyes[0] + eyes[1]) * 0.5
	var fwd := -camera.global_transform.basis.z
	for i in 2:
		var dir := Geometry.direction(fwd, (-5.0 if i == 0 else 5.0), elev_center)
		flies[i].position = cyc + dir * 0.47
		flies[i].scale = Vector3.ONE * 0.47 * tan(deg_to_rad(CORE_DEG))
		flies[i].visible = true
		cur_colors[i] = Color(0.55, 0.7, 0.25)
	_set_fly_alpha(1.0)


func _change_elevation(step: float) -> void:
	elev_center = clampf(elev_center + step, ELEV_LIMITS.x, ELEV_LIMITS.y)
	prog.data["elevazione"] = elev_center
	_show_intro()


func _reset_night() -> void:
	night_stats = {"catture": 0, "risposte": 0, "punti": 0, "gemelle": [0, 0], "lati": [[0, 0], [0, 0]]}
	night_fit = []
	tacche = 0
	mezze = 0
	tacche_max_notte = 0
	tacche_n_fit = -1
	stima_notte = -1.0
	priore_notte = -1.0
	_show_tacche()


func _update_hud() -> void:
	var txt := "night %d · score %d · streak %d · catches %d" % [night, score, combo, captures]
	if ritmo != "":
		txt = RITMO_NOME.get(ritmo, ritmo) + " · " + txt
	if wand_beads.is_empty() and stima_notte > 0.0 and not lampo_mode:
		txt += " · ~%d″" % roundi(stima_notte)
	if lampo_mode:
		txt = "flash · trial %d of %d · streak %d · catches %d" % [mini(trial, lampo_total), lampo_total, combo, captures]
	if message_timer > 0.0:
		txt = message + "\n" + txt
	hud.text = txt
	hud.visible = state != S.INTRO
	if lantern_glow:
		var k := clampf(captures / 60.0, 0.0, 1.0)
		(lantern_glow.material_override as StandardMaterial3D).albedo_color = Color(0.1, 0.12, 0.05).lerp(Color(0.95, 1.0, 0.45), k)


## La lanterna va nella mano che non ha appena toccato, così non ingombra la mano che gioca.
func _place_lantern(touching: int) -> void:
	if lantern == null or controllers.size() < 2:
		return
	var dest: Node = controllers[1 - touching]
	if lantern.get_parent() != dest:
		lantern.reparent(dest, false)


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
	csv_path = results_dir + ("lampo_%s.csv" if lampo_mode else "bosco_%s.csv") % session_id
	csv = FileAccess.open(csv_path, FileAccess.WRITE)
	if csv == null:
		_fatal("Cannot write %s" % csv_path)
		return false
	csv.store_csv_line(PackedStringArray(HEADER))
	csv.flush()
	return csv.get_error() == OK


func _write_row(fields: Dictionary) -> bool:
	var base := {"session": session_id, "participant": participant, "version": VERSION, "mode": mode_name}
	base.merge(fields, true)
	var row := PackedStringArray()
	for col in HEADER:
		row.append(str(base.get(col, "")))
	csv.store_csv_line(row)
	csv.flush()
	if csv.get_error() != OK:
		_fatal("Write error on %s: the forest stops. The trials already saved stay in the file." % csv_path)
		return false
	return true


func _fatal(msg: String) -> void:
	push_error(msg)
	if music:
		music.stop()
	print("BOSCO_ERROR " + msg)
	state = S.ERROR
	_say("ERROR\n\n" + msg + "\n\nTrigger to close.")
	if autotest:
		get_tree().quit(1)


# ---------------------------------------------------------------- occhi e testa

func _eyes() -> Array:
	if xr_active:
		var xr := XRServer.primary_interface
		var ot := origin.global_transform
		return [xr.get_transform_for_view(0, ot).origin, xr.get_transform_for_view(1, ot).origin]
	var t := camera.global_transform
	var right := t.basis.x.normalized()
	return [t.origin - right * DESKTOP_IPD * 0.5, t.origin + right * DESKTOP_IPD * 0.5]


func _head() -> Vector3:
	return camera.global_transform.origin


# ---------------------------------------------------------------- prove

func _start_play() -> void:
	label.visible = false
	for f in flies:
		f.visible = false
	for n in c_flies:
		n.visible = false
	c_fix.visible = false
	trial = 0
	state = S.ITI_WAIT
	_inizia_ritmo()
	_save_progress()
	_update_hud()
	_music_start_night()
	_next_trial()


func _next_trial() -> void:
	if lampo_mode:
		_next_lampo_trial()
		return
	if block_played >= block_seconds:
		_start_rest()
		return
	trial += 1
	var kind := "normale"
	if trial % TWINS_EVERY == TWINS_EVERY / 2:
		kind = "gemelle"
	elif trial % PROBE_EVERY == 0:
		kind = "sonda"
	var near := rng.randi_range(0, 1)       # 0: la sinistra è la più vicina
	var diff: Difficulty = diffs[near]
	# fuochi fatui (0.3): a rotelle finite per quel lato, luce e grandezza tornano visibili con la
	# forza della scala dei fatui; metà delle volte dicono il vero, metà mentono. Così gli indizi
	# a un occhio solo non predicono niente e resta solo la disparità.
	var cue := ""
	if kind == "normale" and trial % CUE_EVERY == CUE_EVERY / 2 and diff.wheels_off():
		kind = "indizi"
		cue = "conflitto" if rng.randf() < 0.5 else "coerente"
	var w := diff.wheels.duplicate()
	if kind != "normale":
		for k in w:
			w[k] = 0.0
	if kind == "indizi":
		w["luce"] = fatui.c
		w["misura"] = fatui.c
	var target := 0.0
	if kind == "indizi":
		target = _cue_disparity(near)
	elif kind != "gemelle":
		target = pow(10.0, diff.level)
	_place_pair(near, target, w, -1.0 if cue == "conflitto" else 1.0)
	cur["kind"] = kind
	cur["level"] = log(target) / log(10.0) if kind == "indizi" else diff.level
	cur["cue"] = cue
	cur["cue_c"] = fatui.c if kind == "indizi" else 0.0
	cur["exposure"] = "libero"
	trial_time = 0.0
	state = S.SPAWN
	timer = spawn_time
	_set_fly_alpha(0.0)


## Dispone la coppia: riferimento sugli occhi reali, azimut simmetrici, disparità voluta verificata.
## cue_sign = -1 inverte luce e grandezza (la vicina sembra lontana). Riempie cur con la geometria.
func _place_pair(near: int, target: float, w: Dictionary, cue_sign: float) -> void:
	var eyes := _eyes()
	var el: Vector3 = eyes[0]
	var er: Vector3 = eyes[1]
	var cyc := (el + er) * 0.5
	var frame := Geometry.eye_frame(el, er, -camera.global_transform.basis.z)
	# fino a 5 tentativi di posizione; se la disparità voluta non si ottiene entro tolleranza la
	# prova si gioca comunque, ma è segnata e non entra né nella scala né nella stima
	var base := 0.0
	var elev := 0.0
	var az := [0.0, 0.0]
	var dirs := []
	var sol := {}
	for attempt in 5:
		base = rng.randf_range(BASE_MIN, BASE_MAX)
		elev = rng.randf_range(elev_center - ELEV_HALF, elev_center + ELEV_HALF)
		# azimut simmetrici rispetto agli occhi: a parità di distanza un punto più eccentrico ha
		# meno vergenza, e l'eccentricità diventerebbe un indizio di profondità falso
		var a_ := rng.randf_range(AZ_MIN, AZ_MAX)
		az = [-a_, a_]
		dirs = [Geometry.direction_in(frame, az[0], elev), Geometry.direction_in(frame, az[1], elev)]
		sol = Geometry.solve_pair_checked(cyc, dirs[near], dirs[1 - near], base, target, el, er)
		if sol["ok"]:
			break
	var d := [sol["near"], sol["far"]]
	var dist := [0.0, 0.0]
	dist[near] = d[0]
	dist[1 - near] = d[1]
	spawn_pos.clear()
	for i in 2:
		spawn_pos.append(cyc + dirs[i] * dist[i])
	var geom := Geometry.relative_disparity_arcsec(spawn_pos[near], spawn_pos[1 - near], el, er)
	var rl := Geometry.relative_disparity_arcsec(spawn_pos[1], spawn_pos[0], el, er)
	var colors := prog.species_colors()
	var col: Color = colors[rng.randi_range(0, colors.size() - 1)]
	for i in 2:
		var sign_ := (1.0 if i == near else -1.0) * cue_sign
		var bright: float = 1.0 + 0.4 * w["luce"] * sign_
		var theta: float = deg_to_rad(CORE_DEG) * pow(base / float(dist[i]), 6.0 * float(w["misura"]) * cue_sign)
		var radius := (spawn_pos[i] - cyc).length() * tan(theta)
		flies[i].position = spawn_pos[i]
		flies[i].scale = Vector3.ONE * radius
		flies[i].visible = true
		cur_colors[i] = Color(col.r * 0.7 * bright, col.g * 0.7 * bright, col.b * 0.7 * bright)
	head_spawn = _head()
	head_spawn_t = camera.global_transform
	local_pos.clear()
	for i in 2:
		local_pos.append(head_spawn_t.affine_inverse() * spawn_pos[i])
	head_max_move = 0.0
	head_max_rot = 0.0
	armed.clear()
	for t in tips.size():
		for i in 2:
			armed["%d_%d" % [t, i]] = tips[t].global_position.distance_to(spawn_pos[i]) > TOUCH_R
	cur = {"kind": "normale", "level": 0.0, "target": target, "geom": geom, "delta": d[1] - d[0],
		"geom_ok": bool(sol["ok"]), "rl_spawn": rl, "cue": "", "cue_c": 0.0, "exposure": "libero",
		"base": base, "near": near, "az": az, "elev": elev, "ipd": el.distance_to(er), "w": w,
		"roll": Geometry.head_roll_deg(el, er), "pitch": Geometry.head_pitch_deg(-camera.global_transform.basis.z),
		"species": Progress.SPECIES[_species_index(col)]["id"]}


func _species_index(col: Color) -> int:
	for i in Progress.SPECIES.size():
		if Progress.SPECIES[i]["colore"] == col:
			return i
	return 0


func _set_fly_alpha(a: float) -> void:
	var pulse := 0.88 + 0.12 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.8)   # stessa fase per le due
	for i in 2:
		var c: Color = cur_colors[i] * pulse
		(fly_mats[i][0] as StandardMaterial3D).albedo_color = Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), 0.9 * a)
		(fly_mats[i][1] as StandardMaterial3D).albedo_color = Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), 0.3 * a)


## Parallasse come rotella: a 1 le lucciole restano ferme nel mondo; a 0 sono solidali con la
## testa (spostamenti E rotazioni rispetto alla posa alla comparsa), quindi niente parallasse di
## movimento e disparità costante anche se la testa ruota (review T1). In mezzo, interpolazione.
func _follow_head() -> void:
	var t := camera.global_transform
	head_max_move = maxf(head_max_move, (t.origin - head_spawn).length())
	head_max_rot = maxf(head_max_rot, rad_to_deg((head_spawn_t.basis.inverse() * t.basis).get_rotation_quaternion().get_angle()))
	var w: float = cur["w"]["parallasse"]
	for i in 2:
		flies[i].position = (t * local_pos[i]).lerp(spawn_pos[i], w)
	if fix_dot.visible:
		fix_dot.position = t * fix_local


## Al momento della risposta (o della scadenza o della pausa): disparità relativa e rollio della testa.
func _mark_response() -> void:
	cur["rl_resp"] = _rl_now()
	var eyes := _eyes()
	cur["roll_resp"] = Geometry.head_roll_deg(eyes[0], eyes[1])


## Disparità relativa destra meno sinistra adesso (positiva se la destra è più vicina).
func _rl_now() -> float:
	var eyes := _eyes()
	return Geometry.relative_disparity_arcsec(flies[1].position, flies[0].position, eyes[0], eyes[1])


func _check_touch() -> int:
	for t in tips.size():
		if not controllers[t].get_is_active():
			continue
		for i in 2:
			var inside := tips[t].global_position.distance_to(flies[i].position) < TOUCH_R
			var key := "%d_%d" % [t, i]
			if not armed[key]:
				armed[key] = not inside
			elif inside:
				cur["hand"] = "sx" if t == 0 else "dx"
				_place_lantern(t)
				return i
	return -1


func _answer(touched: int) -> void:
	if lampo_mode:
		_answer_lampo(touched)
		return
	var points := 0
	n_answered += 1
	night_stats["risposte"] += 1
	prog.data["prove"] = int(prog.data["prove"]) + 1
	_mark_response()
	var w0: bool = cur["w"]["luce"] == 0.0 and cur["w"]["misura"] == 0.0 and cur["w"]["parallasse"] == 0.0
	if w0 and cur["geom_ok"] and cur["kind"] != "indizi":
		# disparità effettiva (destra meno sinistra) alla comparsa: senza rotella della parallasse
		# le lucciole sono solidali con la testa e resta quella fino alla risposta
		fit_data.append([cur["rl_spawn"], touched == 1])
		night_fit.append([cur["rl_spawn"], touched == 1])
		if ritmo != "":
			ritmo_stats[ritmo]["fit"].append([cur["rl_spawn"], touched == 1])
	if ritmo != "":
		ritmo_stats[ritmo]["rt"].append(trial_time)
	if cur["kind"] == "gemelle":
		# alla stessa distanza non c'è una risposta giusta: si catturano tutte e due
		twins[1] += 1
		twins[0] += 1 if touched == 1 else 0
		night_stats["gemelle"][1] += 1
		night_stats["gemelle"][0] += 1 if touched == 1 else 0
		points = 5
		score += points
		captures += 1
		night_stats["catture"] += 1
		prog.data["catture"] = int(prog.data["catture"]) + 1
		message = "Twins! They were at the same distance."
		message_timer = 2.0
		_pulse(0.3, 0.05)
		_play("gemelle")
		if not _log("gemelle", touched, false, points):
			return
		_update_tacche()
		cur["correct"] = true
		cur["touched"] = -2
		fb_start = [flies[0].position, flies[1].position]
		state = S.FEEDBACK
		timer = feedback_time
		_update_hud()
		return
	var correct: bool = touched == cur["near"]
	var near: int = cur["near"]
	var is_cue: bool = cur["kind"] == "indizi"
	var unmasked := false
	if is_cue:
		# le prove con indizi restano fuori dai conteggi per lato, dalle scale e dalla stima
		var ck: String = cur["cue"]
		cue_counts[ck][1] += 1
		cue_counts[ck][0] += 1 if correct else 0
		if ck == "conflitto":
			fatui.record(correct)
			unmasked = correct
			message = "Will-o'-wisp unmasked!" if correct else "A will-o'-wisp fooled you: it was the other one."
			message_timer = 2.5
	else:
		by_side[near][1] += 1
		by_side[near][0] += 1 if correct else 0
		night_stats["lati"][near][1] += 1
		night_stats["lati"][near][0] += 1 if correct else 0
	if cur["kind"] == "sonda":
		probes[1] += 1
		probes[0] += 1 if correct else 0
	if correct:
		n_correct += 1
		combo += 1
		captures += 1
		night_stats["catture"] += 1
		prog.data["catture"] = int(prog.data["catture"]) + 1
		var mw := 0.0
		for k in cur["w"]:
			mw += cur["w"][k]
		mw /= 3.0
		# punti uguali fra i lati (review T3): legarli alla disparità premiava il lato già favorito,
		# la cui scala scende anche per lo sbilanciamento
		points = roundi(10.0 * (1.0 + 0.5 * (1.0 - mw)) * (1.0 + 0.1 * mini(combo, 20)))
		if is_cue:
			# gli indizi valgono come a rotelle finite; smascherare un fatuo dà un premio
			points = roundi(15.0 * (1.0 + 0.1 * mini(combo, 20))) + (10 if unmasked else 0)
		score += points
		night_stats["punti"] += points
		_pulse(0.5, 0.06)
		if unmasked:
			_play("fatuo")
		else:
			_play("cattura", pow(2.0, mini(combo - 1, 12) / 12.0))
	else:
		combo = 0
		_pulse(0.15, 0.12)
		_play("fuga")
	if cur["kind"] == "normale" and cur["geom_ok"]:
		diffs[near].record(correct)
		diffs_touched = true
	# durante la sessione solo i traguardi di catture e rotelle: quelli di soglia si decidono a
	# fine sessione, sulla stima finale (a metà sessione, con poche inversioni, la stima oscilla)
	for s in prog.check_unlocks(_wheels_off(), -1.0):
		new_species.append(s)
		message = "New species: " + s["nome"] + "!"
		message_timer = 4.0
		_play("specie")
	if not _log(("near" if correct else "far"), touched, correct, points):
		return
	_update_tacche()
	cur["correct"] = correct
	cur["touched"] = touched
	fb_start = [flies[0].position, flies[1].position]
	state = S.FEEDBACK
	timer = feedback_time
	_update_hud()


func _wheels_off() -> bool:
	return diffs[0].wheels_off() and diffs[1].wheels_off()


func _timeout() -> void:
	combo = 0
	_mark_response()
	if not _log("timeout", -1, false, 0):
		return
	cur["correct"] = false
	cur["touched"] = -1
	fb_start = [flies[0].position, flies[1].position]
	state = S.FEEDBACK
	timer = feedback_time * 0.6
	_update_hud()


func _log(outcome: String, touched: int, correct: bool, points: int) -> bool:
	var w: Dictionary = cur["w"]
	var near: int = cur["near"]
	var near_txt: String = "" if cur["kind"] == "gemelle" else SIDES[near]
	return _write_row({"trial": trial, "kind": cur["kind"], "level_target": "%.3f" % cur["level"],
		"disparity_target_arcsec": "%.1f" % cur["target"], "disparity_geom_arcsec": "%.1f" % cur["geom"],
		"delta_m": "%.5f" % cur["delta"], "base_m": "%.4f" % cur["base"], "near_side": near_txt,
		"az_left_deg": "%.2f" % cur["az"][0], "az_right_deg": "%.2f" % cur["az"][1], "elev_deg": "%.2f" % cur["elev"],
		"elev_center_deg": "%.1f" % elev_center, "ipd_m": "%.4f" % cur["ipd"], "w_luce": "%.2f" % w["luce"],
		"w_misura": "%.2f" % w["misura"], "w_parallasse": "%.2f" % w["parallasse"], "outcome": outcome,
		"touched_side": "" if touched < 0 else SIDES[touched], "correct": "" if cur["kind"] == "gemelle" else (1 if correct else 0),
		"rt_s": "%.3f" % trial_time, "hand": cur.get("hand", ""), "head_move_mm": "%.1f" % (head_max_move * 1000.0),
		"points": points, "combo": combo, "species": cur["species"], "level_after": "%.3f" % diffs[near].level,
		"wheels_after": "%.2f" % diffs[near].mean_wheels(), "night": night, "geom_ok": 1 if cur["geom_ok"] else 0,
		"disp_rl_spawn_arcsec": "%.1f" % cur["rl_spawn"], "disp_rl_resp_arcsec": "%.1f" % cur.get("rl_resp", cur["rl_spawn"]),
		"head_rot_deg": "%.2f" % head_max_rot, "cue": cur.get("cue", ""),
		"cue_c": "%.2f" % float(cur.get("cue_c", 0.0)), "exposure": cur.get("exposure", "libero"),
		"head_roll_deg": _deg_txt(cur, "roll"), "head_roll_resp_deg": _deg_txt(cur, "roll_resp"),
		"head_pitch_deg": _deg_txt(cur, "pitch"), "ritmo": ritmo, "tacche": tacche, "mezze": mezze})


static func _deg_txt(d: Dictionary, key: String) -> String:
	return "%.2f" % float(d[key]) if d.has(key) else ""


func _pulse(amp: float, dur: float) -> void:
	for c in controllers:
		if c.get_is_active():
			c.trigger_haptic_pulse("haptic", 150.0, amp, dur, 0.0)


func _animate_feedback(frac: float) -> void:
	# frac da 0 a 1: la catturata vola verso la lanterna, le altre salgono e si spengono
	if lampo_mode:
		return       # nel lampo le lucciole spariscono alla risposta: riscontro col suono
	for i in 2:
		var p := fb_start[i]
		var caught: bool = cur["touched"] == -2 or (bool(cur["correct"]) and i == cur["touched"])
		if caught:
			var dest := lantern.global_position if lantern != null else _head() + Vector3(-0.2, -0.3, -0.3)
			flies[i].position = p.lerp(dest, frac)
		else:
			flies[i].position = p + Vector3(0, 0.25 * frac, 0)
	_set_fly_alpha(1.0 - frac)


# ---------------------------------------------------------------- tacche della bacchetta (0.5.11)

## Tacche accese per la sensibilità s79 (″), partendo da quelle accese ora: se ne accende una in più
## solo se la stima scende sotto il suo valore di almeno `isteresi`, se ne spegne una solo se
## risale sopra di almeno altrettanto. s79 non positiva: tacche invariate. Con le soglie e l'isteresi di
## default sono le 8 tacche intere della 0.5.11 (3%); la 0.5.12 usa mezze_accese.
static func tacche_accese(s79: float, ora: int, soglie: Array = TACCHE, isteresi: float = 0.03) -> int:
	if s79 <= 0.0:
		return ora
	var m := clampi(ora, 0, soglie.size())
	while m < soglie.size() and s79 <= float(soglie[m]) * (1.0 - isteresi):
		m += 1
	while m > 0 and s79 > float(soglie[m - 1]) * (1.0 + isteresi):
		m -= 1
	return m


## 0.5.12: mezze tacche accese (0–15) per la sensibilità s79, con l'isteresi del 2%.
static func mezze_accese(s79: float, ora: int) -> int:
	return tacche_accese(s79, ora, MEZZE, TACCHE_ISTERESI)


## 0.5.12: tacche intere per un numero di mezze tacche (la 1ª, la 3ª, ... mezza sono tacche intere).
static func intere(m: int) -> int:
	return (m + 1) / 2


## Nuova stima della notte dalla 20ª prova di riferimento (0.5.14; prima dalla 60ª), poi ogni 5. Il messaggio solo per
## una tacca intera mai accesa prima nella notte (0.5.12): le mezze tacche e le ricadute non dicono niente.
## 0.5.14: la stima è Fit.fit_bacchetta, con lo zero per blocco di 40 prove e un priore debole sulla pendenza.
func _update_tacche() -> void:
	var n := night_fit.size()
	if n < TACCHE_MIN_N or n == tacche_n_fit or (n - TACCHE_MIN_N) % TACCHE_OGNI != 0:
		return
	tacche_n_fit = n
	var s79 := Fit.fit_bacchetta(night_fit, _priore_bacchetta(), BACCHETTA_BLOCCO)
	if s79 <= 0.0:
		return
	_applica_stima(s79)


## 0.5.14: centro del priore della bacchetta, la mediana delle stime (del diario) delle ultime BACCHETTA_PRIORE_N
## sessioni per lo stesso tipo di notte (istinto o riflessiva; per il lampo o senza tipo, tutte e due); 400″ se mancano.
## Si calcola una volta per notte.
func _priore_bacchetta() -> float:
	if priore_notte > 0.0:
		return priore_notte
	priore_notte = priore_da_profilo(prog.data, ritmo)
	return priore_notte


static func priore_da_profilo(data: Dictionary, tipo: String) -> float:
	var v := []
	for ses in data.get("sessioni", []):
		if not ses is Dictionary:
			continue
		var rit: Dictionary = ses.get("ritmi", {})
		for r in rit:
			if tipo != "" and r != tipo:
				continue
			var st: Dictionary = rit[r].get("stima", {})
			if st.get("stimabile", false) and float(st.get("soglia79", -1.0)) > 0.0:
				v.append(float(st["soglia79"]))
	v = v.slice(maxi(0, v.size() - BACCHETTA_PRIORE_N * (1 if tipo != "" else 2)))
	if v.is_empty():
		return BACCHETTA_PRIORE
	v.sort()
	var m := v.size()
	return float(v[m / 2]) if m % 2 == 1 else 0.5 * (float(v[m / 2 - 1]) + float(v[m / 2]))


## 0.5.12: una stima nuova della notte sulla bacchetta (mezze tacche, tacche intere, messaggio).
func _applica_stima(s79: float) -> void:
	stima_notte = s79
	mezze = mezze_accese(s79, mezze)
	tacche = intere(mezze)
	if tacche > tacche_max_notte:
		message = ("The wand lights up to %d″" % roundi(float(TACCHE[tacche - 1]))) + (": into the green!" if tacche > TACCA_META else ".")
		message_timer = 2.5
		tacche_max_notte = tacche
	_show_tacche()


func _show_tacche() -> void:
	if bead_mats.is_empty():
		for k in [["spenta", Color(0.16, 0.12, 0.08)], ["accesa", Color(1.0, 0.82, 0.38)],
				["meta_spenta", Color(0.07, 0.17, 0.14)], ["meta_accesa", Color(0.55, 1.0, 0.82)]]:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = k[1]
			bead_mats[k[0]] = m
	# 0.5.12: mezze pari e non nulle = una perla a metà, quella dopo le intere: accesa ma piccola (60%). Una luce
	# smorzata si confondeva col manico (verifica/training-0.5.12/colori_mezza.png); la grandezza no.
	var mezza := tacche if mezze > 0 and mezze % 2 == 0 else -1
	for beads in wand_beads:
		for i in beads.size():
			var key := ("meta_" if i >= TACCA_META else "") + ("accesa" if i < tacche or i == mezza else "spenta")
			var b := beads[i] as MeshInstance3D
			b.material_override = bead_mats[key]
			b.scale = Vector3.ONE * (MEZZA_SCALA if i == mezza else 1.0)


## Riga della pausa: sensibilità della notte appena finita, su tutte le sue prove di riferimento. 0.5.14: le tacche
## vengono dalla stima della bacchetta (zero per blocco); accanto, il numero del diario (uno zero per la notte).
func _tacche_line() -> String:
	if night_fit.size() < TACCHE_MIN_N:
		return "This night's sensitivity: can't be estimated (fewer than %d trials)." % TACCHE_MIN_N
	var s79 := Fit.fit_bacchetta(night_fit, _priore_bacchetta(), BACCHETTA_BLOCCO)
	if s79 <= 0.0:
		return "This night's sensitivity: can't be estimated."
	var m := 0
	for v in MEZZE:
		m += 1 if s79 <= float(v) else 0
	var n := intere(m)
	var f := Fit.fit(night_fit)
	var diario := (", in the Journal ~%d″ (one bias for the whole night)" % roundi(float(f["soglia79"]))) if f.get("stimabile", false) else ""
	return "This night's sensitivity: ~%d″ on the wand (bias per block)%s; %d%s of %d notches%s." % [roundi(s79), diario, n,
		" and a half" if m > 0 and m % 2 == 0 else "", TACCHE.size(),
		" (in the green)" if n > TACCA_META else " (green from 200″ down)"]


# ---------------------------------------------------------------- soglie

## Soglie per lato e loro combinazione. Se la destra sembra più vicina di b″ a parità di
## profondità, la scala "vicina a destra" si assesta su s - b e quella "vicina a sinistra" su
## s + b: la media stima la sensibilità s, la semidifferenza lo sbilanciamento b (positivo = la
## destra sembra più vicina). Se una scala tocca il minimo, la stima è solo un limite.
func thresholds() -> Dictionary:
	var sx: float = diffs[0].threshold_arcsec()
	var dx: float = diffs[1].threshold_arcsec()
	var out := {"sx": sx, "dx": dx, "media": -1.0, "sbilanciamento": 0.0, "al_limite": false}
	if sx > 0.0 and dx > 0.0:
		out["media"] = 0.5 * (sx + dx)
		out["sbilanciamento"] = 0.5 * (sx - dx)
		out["al_limite"] = minf(sx, dx) < pow(10.0, Difficulty.L_MIN + 0.3)
	return out


func _side_line(stats: Array) -> String:
	return "nearer on the left %d of %d, on the right %d of %d" % [stats[0][0], stats[0][1], stats[1][0], stats[1][1]]


# ---------------------------------------------------------------- pause e fine

func _start_rest() -> void:
	block_played = 0.0
	state = S.REST
	timer = REST_SECONDS
	_music_fade_out()
	_play("notte")
	for f in flies:
		f.visible = false
	var ns := night_stats
	rest_lore = "\n\nNIGHT %d: %d catches out of %d answers, %d points. %s. Twins touched on the right: %d of %d.\nStaircases: nearer on the left %d″, on the right %d″." % [
		night, ns["catture"], ns["risposte"], ns["punti"], _side_line(ns["lati"]).capitalize().substr(0, 1) + _side_line(ns["lati"]).substr(1),
		ns["gemelle"][0], ns["gemelle"][1], roundi(pow(10.0, diffs[0].level)), roundi(pow(10.0, diffs[1].level))]
	rest_lore += "\n" + _tacche_line()
	for s in new_species:
		rest_lore += "\n\n%s\n%s" % [s["nome"].to_upper(), s["storia"]]
	new_species.clear()
	night += 1
	_reset_night()
	_save_progress()
	hud.visible = false
	if autotest:
		timer = 0.0


func _rest_text() -> String:
	var over := float(prog.data["secondi_oggi"]) + (play_seconds - _saved_seconds) > DAY_SOFT_CAP
	var txt := "The lantern needs oil.\n\nClose your eyes and blink slowly: %d seconds." % ceili(maxf(timer, 0.0))
	if timer <= 0.0:
		txt = "Lantern refilled.\n\nTrigger (or Space) for another night, B/Y (or Esc) to go home."
		if over:
			txt += "\n\nYou've played more than an hour today: the forest suggests you come back tomorrow."
	var nx := _ritmo_prossimo()
	if nx != "":
		txt += "\n\nNext night: " + RITMO_CONSEGNA[nx]
	return txt + rest_lore


func _on_focus_lost() -> void:
	xr_focused = false
	if state == S.CONTRAST:
		resume_to = S.CONTRAST
		state = S.PAUSED
		for n in c_flies:
			n.visible = false
		c_fix.visible = false
		c_lock.visible = false
		hud.visible = false
		_say("PAUSED\n\nPut the headset back on, then trigger (or Space) to continue. B/Y (or Esc) to go home.")
		return
	if state in PLAY_STATES:
		if state in [S.FIX, S.SPAWN, S.WAIT]:
			_mark_response()
			if not _log("pausa", -1, false, 0):
				return
			if lampo_mode and cur.has("item"):
				lampo_schedule.push_front(cur["item"])   # la prova interrotta si rifà alla fine
		resume_to = S.ITI_WAIT
		fix_dot.visible = false
		state = S.PAUSED
		_music_pause(true)
		for f in flies:
			f.visible = false
		hud.visible = false
		_save_progress()
		_say("PAUSED\n\nPut the headset back on, then trigger (or Space) to continue. B/Y (or Esc) to go home.")


func _on_focus_gained() -> void:
	xr_focused = true


## Chiusura della sessione XR o della finestra: si salva come con B/Y (nella seconda sessione
## del 28/9 la finestra chiusa a metà ha lasciato il profilo senza il riepilogo).
func _on_session_stopping() -> void:
	if state not in [S.END, S.ERROR]:
		_finish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and state not in [S.END, S.ERROR] and csv != null:
		_finish()


func _finish() -> void:
	if state == S.END:
		return
	state = S.END
	_music_fade_out()
	for f in flies:
		f.visible = false
	for n in c_flies:
		n.visible = false
	c_fix.visible = false
	fix_dot.visible = false
	hud.visible = false
	if lampo_mode:
		_finish_lampo()
		return
	var th := thresholds()
	var fit := Fit.fit(fit_data)
	# traguardi e record solo con una stima informativa (review T2)
	var sens: float = fit["soglia79"] if fit["stimabile"] else -1.0
	if n_answered > 0:
		for s in prog.check_unlocks(_wheels_off(), sens, {"fatui": cue_counts["conflitto"][0]}):
			new_species.append(s)
	var minutes := play_seconds / 60.0
	var stim_minutes := stim_seconds / 60.0
	var sess := {"sessione": session_id, "versione": VERSION, "data": Time.get_datetime_string_from_system(),
		"modo": mode_name, "prove": n_answered, "giuste": n_correct, "catture": captures, "punti": score,
		"soglia_arcsec": th["media"], "soglia_sx": th["sx"], "soglia_dx": th["dx"],
		"sbilanciamento_arcsec": th["sbilanciamento"], "gemelle_destra": twins.duplicate(),
		"lati": by_side.duplicate(true), "sonde": probes.duplicate(), "minuti": minutes, "notti": night,
		"elevazione": elev_center, "minuti_stimolo": stim_minutes, "stima": fit,
		"musica": {"volume": music_volume if _music_on() else 0.0, "brani": music_names.duplicate()},
		"fatui": {"conflitto": cue_counts["conflitto"].duplicate(), "coerente": cue_counts["coerente"].duplicate(),
			"forza": fatui.c, "soglia_forza": fatui.threshold()}}
	var rit_lines := []
	var rit_sess := {}
	for r in RITMI:
		var rs: Dictionary = ritmo_stats[r]
		if rs["rt"].is_empty():
			continue
		var rts: Array = rs["rt"].duplicate()
		rts.sort()
		var med: float = float(rts[rts.size() / 2]) if rts.size() % 2 == 1 else 0.5 * (float(rts[rts.size() / 2 - 1]) + float(rts[rts.size() / 2]))
		var rf := Fit.fit(rs["fit"])
		# 0.5.14: accanto, la stima con lo zero per blocco (come la bacchetta), che non risente di uno zero che si sposta
		var rb := Fit.fit_bacchetta(rs["fit"], priore_da_profilo(prog.data, r), BACCHETTA_BLOCCO) if (rs["fit"] as Array).size() >= TACCHE_MIN_N else -1.0
		rit_sess[r] = {"risposte": rts.size(), "tempo_mediano_s": med, "stima": rf, "bacchetta": rb}
		rit_lines.append("%s: %d answers, median time %s s, %s%s" % [RITMO_PLURALE[r], rts.size(), "%.2f" % med,
			("sensitivity at 79%% ~%d″" % roundi(rf["soglia79"])) if rf["stimabile"] else "estimate not available",
			(" (with bias per block, like the wand, ~%d″)" % roundi(rb)) if rb > 0.0 else ""])
	if not rit_sess.is_empty():
		sess["ritmi"] = rit_sess
	if n_answered > 0:
		prog.data["sessioni"].append(sess)
	var record := score > int(prog.data["record_punti"])
	if record:
		prog.data["record_punti"] = score
	var thr: float = sens
	if thr > 0.0 and (float(prog.data["migliore_soglia"]) <= 0.0 or thr < float(prog.data["migliore_soglia"])):
		prog.data["migliore_soglia"] = thr
	var saved := _save_progress()
	var lines := ["BACK HOME", ""]
	lines.append("Catches: %d of %d answers · score %d%s" % [captures, n_answered, score, " (new record!)" if record else ""])
	lines.append("Correct: " + _side_line(by_side))
	lines.append("Staircases: nearer on the left %s, on the right %s" % [_fmt_thr(th["sx"]), _fmt_thr(th["dx"])])
	if th["media"] > 0.0:
		var bias: float = th["sbilanciamento"]
		lines.append("From the staircases: sensitivity %d″ · bias: %s%s" % [roundi(th["media"]),
			"the right one looks nearer by about %d″" % roundi(bias) if bias > 0 else "the left one looks nearer by about %d″" % roundi(-bias),
			" (one staircase is at its limit: rough estimate)" if th["al_limite"] else ""])
	if fit["stimabile"]:
		lines.append("Estimate from %d trials without training wheels: sensitivity at 79%% ~%d″ (rough interval %d–%d″), net of response bias: %s" % [
			fit["n"], roundi(fit["soglia79"]), roundi(fit["soglia79_ic"][0]), roundi(fit["soglia79_ic"][1]), _fmt_zero(fit)])
	else:
		lines.append("Sensitivity estimate not available: %s." % _motivo_txt(fit["motivo"]))
	lines.append_array(rit_lines)
	lines.append("Twins touched on the right: %d of %d" % [twins[0], twins[1]])
	lines.append("Probes without training wheels: %d of %d correct" % [probes[0], probes[1]])
	if cue_counts["conflitto"][1] + cue_counts["coerente"][1] > 0:
		var ft := fatui.threshold()
		lines.append("Will-o'-wisps unmasked: %d of %d (with honest light and size: %d of %d). Deception strength now %.1f%s" % [
			cue_counts["conflitto"][0], cue_counts["conflitto"][1], cue_counts["coerente"][0], cue_counts["coerente"][1],
			fatui.c, (", steady resistance ~%.2f (from 0 to 1)" % ft) if ft > 0.0 else ""])
	lines.append("Minutes played: %.0f, of which %.0f with fireflies in view (%.0f in all today)" % [minutes, stim_minutes, float(prog.data["secondi_oggi"]) / 60.0])
	for s in new_species:
		lines.append("")
		lines.append("%s\n%s" % [s["nome"].to_upper(), s["storia"]])
	_play("specie" if not new_species.is_empty() else "notte")
	new_species.clear()
	if not saved:
		lines.insert(1, "WARNING: profile not saved (the trials are in the CSV).")
	lines.append("")
	lines.append(_close_line())
	var text := "\n".join(lines)
	print("BOSCO_RESULT\n" + text)
	_say(text)
	if autotest:
		get_tree().quit()


func _save_progress() -> bool:
	if diffs_touched:
		prog.data["difficolta"] = {"sx": diffs[0].to_dict(), "dx": diffs[1].to_dict()}
	prog.data["fatui"] = fatui.to_dict()
	prog.data["elevazione"] = elev_center
	prog.add_seconds(play_seconds - _saved_seconds, Time.get_date_string_from_system())
	_saved_seconds = play_seconds
	return prog.save()


# ---------------------------------------------------------------- ciclo

func _process(delta: float) -> void:
	_poll_controllers()
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0:
			_update_hud()
	match state:
		S.INTRO:
			_set_fly_alpha(1.0)
		S.CONTRAST:
			if c_phase == "adjust":
				play_seconds += delta
				c_time += delta
				var v := 0.0
				for ctrl in controllers:
					if ctrl.get_is_active():
						var y: float = ctrl.get_vector2("primary").y   # 0.5.8: su/giù, come le lucciole
						if absf(y) > absf(v):
							v = y
				if absf(v) > 0.15:
					_contrast_adjust(signf(v) * (absf(v) - 0.15) / 0.85 * 0.5 * delta)
			elif c_phase in ["gap", "refix"]:
				timer -= delta
				if timer <= 0.0:
					_contrast_begin_rep()
		S.FIX:
			play_seconds += delta
			block_played += delta
			_follow_head()
			timer -= delta
			if timer <= 0.0:
				# comparsa brusca: il lampo deve durare davvero LAMPO_EXPOSURE
				fix_dot.visible = false
				for f in flies:
					f.visible = true
				_set_fly_alpha(1.0)
				trial_time = 0.0
				state = S.WAIT
		S.SPAWN, S.WAIT:
			play_seconds += delta
			stim_seconds += delta
			block_played += delta
			trial_time += delta
			_follow_head()
			if state == S.SPAWN:
				timer -= delta
				_set_fly_alpha(clampf(1.0 - timer / spawn_time, 0.0, 1.0))
				if timer <= 0.0:
					state = S.WAIT
			else:
				_set_fly_alpha(1.0)
				if not capture_path.is_empty():
					_capture_and_quit()
					return
				if autotest:
					_answer(_simulated_choice())
					return
				if lampo_mode:
					if cur["exposure"] == "lampo" and flies[0].visible and trial_time >= LAMPO_EXPOSURE:
						for f in flies:
							f.visible = false
						cur["shown_s"] = trial_time
					if trial_time > MAX_TIME:
						_timeout()
					return
				var t := _check_touch()
				if t >= 0:
					_answer(t)
				elif trial_time > MAX_TIME:
					_timeout()
		S.FEEDBACK:
			play_seconds += delta
			block_played += delta
			timer -= delta
			_animate_feedback(clampf(1.0 - timer / feedback_time, 0.0, 1.0))
			if timer <= 0.0:
				for f in flies:
					f.visible = false
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


func _capture_and_quit() -> void:
	var path := capture_path
	capture_path = ""
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("BOSCO_CAPTURE " + path)
	get_tree().quit()


## Osservatore simulato: sceglie la destra con probabilità Phi((d_segnata + bias)/sigma), dove
## d_segnata è positiva se la vicina è a destra e sigma fa cadere il 79% su sim_threshold;
## le rotelle aiutano come nella 0.1. Serve a verificare che le due scale separino le cose.
func _simulated_choice() -> int:
	cur["hand"] = "sim"
	var sigma := sim_threshold / 0.806
	var signed: float = 0.0
	if cur["kind"] != "gemelle":
		signed = cur["target"] if cur["near"] == 1 else -cur["target"]
	var bias := sim_bias_lampo if cur.get("exposure", "libero") == "lampo" else sim_bias
	var p_right := _phi((signed + bias) / sigma)
	if cur["kind"] == "indizi":
		# combinazione degli indizi: luce e grandezza spingono verso il lato che indicano
		var cue_dir := (1.0 if cur["near"] == 1 else -1.0) * (-1.0 if cur["cue"] == "conflitto" else 1.0)
		p_right = _phi((signed + bias) / sigma + sim_cue_gain * float(cur["cue_c"]) * cue_dir)
		return 1 if rng.randf() < p_right else 0
	var w: Dictionary = cur["w"]
	var cue := maxf(w["luce"], maxf(w["misura"], w["parallasse"]))
	if cur["kind"] != "gemelle" and cue > 0.0:
		var p_cue := 0.5 + 0.45 * cue
		var p_ok := maxf(p_right if cur["near"] == 1 else 1.0 - p_right, p_cue)
		p_right = p_ok if cur["near"] == 1 else 1.0 - p_ok
	return 1 if rng.randf() < p_right else 0


static func _phi(x: float) -> float:
	return Fit.phi(x)


func _confirm() -> void:
	match state:
		S.INTRO:
			_leave_intro()
		S.CONTRAST:
			match c_phase:
				"intro":
					_contrast_begin_rep()
				"adjust":
					_contrast_confirm()
				"result":
					_start_play()
		S.REST:
			if timer <= 0.0:
				label.visible = false
				hud.visible = true
				_inizia_ritmo()
				_update_hud()
				_music_start_night()
				_next_trial()
		S.PAUSED:
			label.visible = false
			_music_pause(false)
			if resume_to == S.CONTRAST:
				resume_to = S.ITI_WAIT
				state = S.CONTRAST
				if c_phase in ["adjust", "gap", "refix"]:
					_contrast_begin_rep()      # la misura interrotta si rifà da capo
				elif c_phase == "intro":
					_start_contrast()
				else:
					label.visible = true
				return
			hud.visible = true
			_update_hud()
			state = S.ITI_WAIT
			timer = iti
		S.END, S.ERROR:
			_leave()


func _quit_request() -> void:
	match state:
		S.END, S.ERROR:
			_leave()
		S.CONTRAST:
			if c_phase == "result":
				_finish()
			else:
				_contrast_skip()
		_:
			_finish()


## Fine: si torna alla capanna se si è partiti da lì, altrimenti si chiude.
func _leave() -> void:
	if from_capanna:
		get_tree().root.set_meta("capanna_opts", {"partecipante": participant})
		get_tree().call_deferred("change_scene_to_file", "res://scenes/capanna.tscn")
	else:
		get_tree().quit()


func _close_line() -> String:
	return "Trigger (or Space) to go back to the hut." if from_capanna else "Trigger (or Space) to close."


## Dall'introduzione: misura del contrasto se è il momento, altrimenti dritti nel bosco.
func _leave_intro() -> void:
	if _contrast_due():
		_start_contrast()
	else:
		_start_play()


func _poll_controllers() -> void:
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
		var grip := ctrl.is_button_pressed("grip_click") or ctrl.get_float("grip") > 0.85 or ctrl.is_button_pressed("primary_click")
		if grip and not grip_prev[ctrl] and state == S.CONTRAST and c_phase == "adjust":
			grip_prev[ctrl] = grip
			_contrast_fusion_lost()
			return
		grip_prev[ctrl] = grip
		if state == S.WAIT and lampo_mode:
			var vl: Vector2 = ctrl.get_vector2("primary")
			if stick_armed[ctrl] and absf(vl.x) > 0.75:
				stick_armed[ctrl] = false
				cur["hand"] = "levetta_" + ("sx" if ctrl == controllers[0] else "dx")
				_answer(1 if vl.x > 0 else 0)
				return
			elif vl.length() < 0.3:
				stick_armed[ctrl] = true
		elif state != S.INTRO and ctrl.get_vector2("primary").length() < 0.3:
			stick_armed[ctrl] = true
		if state == S.INTRO:
			var v: Vector2 = ctrl.get_vector2("primary")
			if stick_armed[ctrl] and absf(v.y) > 0.75:
				stick_armed[ctrl] = false
				_change_elevation(2.0 if v.y > 0 else -2.0)
			elif stick_armed[ctrl] and absf(v.x) > 0.75:
				stick_armed[ctrl] = false
				_change_music(0.1 if v.x > 0 else -0.1)
			elif v.length() < 0.3:
				stick_armed[ctrl] = true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_SPACE, KEY_ENTER:
			_confirm()
		KEY_ESCAPE:
			_quit_request()
		KEY_UP, KEY_W:
			if state == S.INTRO:
				_change_elevation(2.0)
			elif state == S.CONTRAST and c_phase == "adjust":
				_contrast_adjust(0.05)
		KEY_DOWN, KEY_S:
			if state == S.INTRO:
				_change_elevation(-2.0)
			elif state == S.CONTRAST and c_phase == "adjust":
				_contrast_adjust(-0.05)
		KEY_LEFT, KEY_A:
			if state == S.WAIT:
				cur["hand"] = "tastiera"
				_answer(0)
			elif state == S.INTRO:
				_change_music(-0.1)
		KEY_RIGHT, KEY_D:
			if state == S.WAIT:
				cur["hand"] = "tastiera"
				_answer(1)
			elif state == S.INTRO:
				_change_music(0.1)
		KEY_G, KEY_F:
			if state == S.CONTRAST and c_phase == "adjust":
				_contrast_fusion_lost()
