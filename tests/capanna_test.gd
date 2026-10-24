extends SceneTree
## Test della capanna del custode (training 0.4): storia ricalcolata dai CSV di tutti gli schemi
## (0.1 → 0.4), obiettivi, menu, puntatore attraverso il pannello 3D, passaggio di opzioni al bosco.
## Uso: godot --headless --path . --xr-mode off --script res://tests/capanna_test.gd

const Storia := preload("res://scripts/training/storia.gd")
const Obiettivi := preload("res://scripts/training/obiettivi.gd")
const Fit := preload("res://scripts/training/fit.gd")
var failures := 0
var checks := 0
var rng := RandomNumberGenerator.new()


func check(cond: bool, what: String) -> void:
	checks += 1
	if OS.get_environment("VERBOSE_TEST") != "":
		print(("ok   " if cond else "NO   ") + what)
	if not cond:
		failures += 1
		print("FAIL: " + what)


func _write(path: String, header: Array, rows: Array) -> void:
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_csv_line(PackedStringArray(header))
	for r in rows:
		var line := PackedStringArray()
		for h in header:
			line.append(str(r.get(h, "")))
		fa.store_csv_line(line)
	fa.close()


## Osservatore con zero +600″ e sigma 500″: P(tocca la destra) = Phi((d + 600)/500).
func _trial(d_abs: float, near_dx: bool, twin := false) -> Dictionary:
	var signed := 0.0 if twin else (d_abs if near_dx else -d_abs)
	var right: bool = rng.randf() < Fit.phi((signed + 600.0) / 500.0)
	var r := {"near_side": "" if twin else ("dx" if near_dx else "sx"), "touched_side": "dx" if right else "sx",
		"disparity_geom_arcsec": "%.1f" % (0.0 if twin else d_abs), "rt_s": "2.0", "w_luce": "0.00", "w_misura": "0.00", "w_parallasse": "0.00"}
	r["outcome"] = "gemelle" if twin else ("near" if right == near_dx else "far")
	r["correct"] = "" if twin else ("1" if right == near_dx else "0")
	return r


func _initialize() -> void:
	rng.seed = 11
	var dir := ProjectSettings.globalize_path("res://results/desktop/test_capanna/training/")
	var tdir := ProjectSettings.globalize_path("res://results/test_capanna/")
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.make_dir_recursive_absolute(tdir)
	for d in [dir, tdir]:
		for f in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d.path_join(f))
	# --- CSV della 0.1 (niente kind, niente notte, niente disparità destra-sinistra)
	var h01 := ["session", "participant", "version", "mode", "trial", "probe", "level_target", "disparity_target_arcsec", "disparity_geom_arcsec", "near_side", "w_luce", "w_misura", "w_parallasse", "outcome", "touched_side", "correct", "rt_s"]
	var rows := []
	for i in 200:
		var r := _trial([100.0, 400.0, 900.0, 1600.0][i % 4], i % 2 == 0)
		r["version"] = "training-0.1"
		rows.append(r)
	rows.append({"version": "training-0.1", "outcome": "near", "w_luce": "0.40", "near_side": "dx", "touched_side": "dx", "disparity_geom_arcsec": "50", "rt_s": "1.0"})
	rows.append({"version": "training-0.1", "outcome": "timeout", "rt_s": "7.0"})
	_write(dir + "bosco_20260914_210000_aaaa.csv", h01, rows)
	# --- CSV della 0.3: due notti, prove con indizi, geometria mancata, lampo escluso
	var h03 := h01.duplicate()
	h03.erase("probe")
	h03.append_array(["kind", "night", "geom_ok", "disp_rl_spawn_arcsec", "cue", "cue_c", "exposure"])
	rows = []
	for night in [1, 2]:
		for i in 180:
			var twin := i % 10 == 5
			var r := _trial([100.0, 400.0, 900.0, 1600.0][i % 4], i % 2 == 0, twin)
			r["version"] = "training-0.3.0"
			r["kind"] = "gemelle" if twin else "normale"
			r["night"] = night
			r["geom_ok"] = "1"
			var sg := 0.0 if twin else (float(r["disparity_geom_arcsec"]) * (1.0 if r["near_side"] == "dx" else -1.0))
			r["disp_rl_spawn_arcsec"] = "%.1f" % sg
			r["exposure"] = "libero"
			rows.append(r)
	var cue_row := _trial(1300.0, false)
	cue_row.merge({"version": "training-0.3.0", "kind": "indizi", "night": 1, "geom_ok": "1", "disp_rl_spawn_arcsec": "-1300", "cue": "conflitto", "cue_c": "0.40", "w_luce": "0.40", "w_misura": "0.40"}, true)
	rows.append(cue_row)
	var bad_geom := _trial(400.0, true)
	bad_geom.merge({"version": "training-0.3.0", "kind": "normale", "night": 1, "geom_ok": "0", "disp_rl_spawn_arcsec": "380"}, true)
	rows.append(bad_geom)
	_write(dir + "bosco_20260928_224500_bbbb.csv", h03, rows)
	var lrows := []
	for i in 120:
		var r := _trial(700.0, i % 2 == 0)
		r["exposure"] = "lampo" if i % 2 == 0 else "libero"
		lrows.append(r)
	_write(dir + "lampo_20260929_180000_cccc.csv", h03, lrows)
	# --- test della stereopsi
	var tj := {"date": "2026-10-12T10:00:00", "protocol": "p6", "version": "0.5.1", "session_type": "standard",
		"rings": {"outcome": "measured", "arcsec_q50": 300.0, "arcsec_q025": 200.0, "arcsec_q975": 450.0}, "rds": {"outcome": "above"}}
	var fa := FileAccess.open(tdir + "sessione_20261012_100000_001_aaaa_riepilogo.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(tj))
	fa.close()
	var profile := {"specie": ["comune", "brina", "fatuo"], "contrasto": [{"data": "2026-09-29T18:00:00", "log_rapporto": [0.3, 0.2, 0.25, 0.35], "mediana": 0.275, "sparizioni": 1}],
		"diagnosi": [{"tipo": "lampo", "prove": 120, "data": "2026-09-29T18:10:00"}],
		"sessioni": [{"data": "2026-09-28T23:00:00", "fatui": {"conflitto": [12, 20], "coerente": [18, 20], "forza": 0.6, "soglia_forza": 0.55}}]}
	# --- storia
	var st := Storia.new()
	st.load_all(dir, tdir, profile)
	check(st.sessions.size() == 2 and st.nights.size() == 3, "due sessioni, tre notti (%d, %d)" % [st.sessions.size(), st.nights.size()])
	var s01: Dictionary = st.sessions[0]
	var s03: Dictionary = st.sessions[1]
	check(s01["vecchia"] and not s03["vecchia"], "le versioni prima della 0.2.1 sono segnate")
	check(Storia.reference_point({"outcome": "near", "w_luce": "0.40"}).is_empty(), "prova con rotelle esclusa")
	check(Storia.reference_point({"outcome": "near", "geom_ok": "0"}).is_empty(), "geometria mancata esclusa")
	check(Storia.reference_point({"outcome": "near", "cue": "conflitto"}).is_empty(), "fuochi fatui esclusi")
	check(Storia.reference_point({"outcome": "near", "exposure": "lampo"}).is_empty(), "lampo escluso")
	check(Storia.reference_point({"outcome": "timeout"}).is_empty(), "prove scadute escluse")
	check(Storia.reference_point({"outcome": "far", "disparity_geom_arcsec": "400", "near_side": "sx", "touched_side": "dx"}) == [-400.0, true], "0.1: disparità ricostruita dal lato della vicina")
	check(int(s01["stima"]["n"]) == 200 and int(s03["stima"]["n"]) == 360, "prove di riferimento contate (%d, %d)" % [s01["stima"]["n"], s03["stima"]["n"]])
	var f3: Dictionary = s03["stima"]
	check(f3["stimabile"] and absf(float(f3["zero"]) - 600.0) < 200.0 and f3["zero_ic"][0] < 600.0 and f3["zero_ic"][1] > 600.0,
		"sessione 0.3: zero %.0f″ (vero 600) con intervallo" % float(f3.get("zero", 0.0)))
	check(st.nights[1]["notte"] == 1 and st.nights[2]["notte"] == 2 and st.nights[1]["stima"]["stimabile"], "una stima per notte")
	check(s03["gemelle"][1] == 36 and st.nights[1]["gemelle"][1] == 18, "gemelle per sessione e per notte")
	var m03: float = s03["minuti"]
	check(absf(m03 - (362 * 3.3) / 60.0) < 0.2, "minuti attivi stimati dal CSV (%.1f)" % m03)
	check(st.days.has("2026-09-29") and absf(float(st.days["2026-09-29"]) - 120 * 3.3 / 60.0) < 0.1, "il lampo conta nei minuti del giorno")
	check(Storia.week_of("2026-09-28") == "2026-09-28" and Storia.week_of("2026-10-04") == "2026-09-28" and Storia.week_of("2026-10-05") == "2026-10-05", "settimane dal lunedì")
	check(st.tests.size() == 1 and st.tests[0]["rings"]["q50"] == 300.0 and st.tests[0]["rds"]["esito"] == "above", "riepiloghi del test letti")
	check(st.smascherati == 12 and st.fatui.size() == 1 and st.lampo.size() == 1 and st.contrasto.size() == 1, "fatui, lampo e contrasto dal profilo")
	# 0.5.9 (review dell'8/10, C1): serie del contrasto e invalidazioni retrospettive
	var ce := [{"sessione": "a", "versione": "training-0.4.0", "log_rapporto": [0.1, 0.5, 0.6, 0.5], "mediana": 0.5},
		{"sessione": "b", "versione": "training-0.5.4", "log_rapporto": [0.28, 0.06, 0.10, 0.30], "mediana": 0.19},
		{"sessione": "c", "versione": "training-0.5.7", "log_rapporto": [0.08, -0.05, 0.37, 0.09], "mediana": 0.085},
		{"sessione": "d", "versione": "training-0.5.8", "log_rapporto": [0.23, 0.15, 0.07, 0.09], "mediana": 0.12},
		{"sessione": "e", "versione": "training-0.5.10", "log_rapporto": [0.2], "mediana": 0.2}]
	var cn := {"b": {"ripetizioni_non_valide": [2, 3], "motivo": "x"}, "c": {"non_valida": true, "motivo": "y"}}
	var cs := Storia.contrast_series(ce, cn)
	check(cs[0]["serie"] == "orizzontale" and cs[1]["serie"] == "orizzontale" and cs[2]["serie"] == "riquadro"
		and cs[3]["serie"] == "verticale" and cs[4]["serie"] == "verticale", "contrasto: serie dalla versione (anche 0.5.10)")
	check(cs[1]["valide"] == [0.28, 0.30] and cs[1]["non_valide"] == [0.06, 0.10] and absf(float(cs[1]["mediana_valida"]) - 0.29) < 1e-9
		and not cs[1]["non_valida"] and absf(float(cs[1]["mediana"]) - 0.19) < 1e-9, "contrasto: due ripetizioni annotate non valide, mediana delle valide, grezzi intatti")
	check(cs[2]["non_valida"] and cs[2]["valide"].is_empty() and cs[2]["nota"] == "y", "contrasto: misura intera annotata non valida")
	check(not cs[3]["non_valida"] and cs[3]["non_valide"].is_empty() and ce[1]["log_rapporto"].size() == 4 and not ce[1].has("serie"), "contrasto: misure senza annotazioni invariate, ingresso non modificato")
	check(Storia.load_contrast_notes("") == {} and Storia.load_contrast_notes(dir).is_empty(), "contrasto: senza file di annotazioni nessuna invalidazione")
	# 0.1: 200 prove ≈ 11 min; 0.3: notte 1 ≈ 10,0 min (182 righe), notte 2 ≈ 9,9 min (180): non completa
	check(st.completed_nights() == 2, "notti complete sopra i 10 minuti: %d" % st.completed_nights())
	# --- obiettivi
	var res := Obiettivi.evaluate(st)
	check(res.size() == Obiettivi.LIST.size(), "un esito per ogni obiettivo")
	check(res["prima_notte"]["ok"] and not res["notti_10"]["ok"] and res["notti_10"]["cur"] == 2, "notti: prima sì, dieci no (2 su 10)")
	check(res["specie_3"]["ok"] and not res["specie_5"]["ok"], "specie contate")
	check(res["fatui_10"]["ok"] and not res["fatui_50"]["ok"], "fatui smascherati")
	check(res["resistente"]["ok"], "resistenza ai fatui dal profilo")
	check(res["lampo"]["ok"] and res["contrasto_1"]["ok"] and not res["contrasto_10"]["ok"], "curiosità: lampo e contrasto")
	check(res["test"]["ok"], "test rifatto dopo l'inizio del training")
	check(res["ritorno"]["ok"], "ritorno dopo più di una settimana (14/9 → 28/9)")
	check(not res["tre_lanterne"]["ok"], "una lanterna per settimana non basta")
	var hi: float = INF
	for s in st.estimable_sessions():
		hi = minf(hi, float(s["stima"]["soglia79_ic"][1]))
	check(res["occhio_600"]["ok"] == (hi < 600.0) and res["occhio_250"]["ok"] == (hi < 250.0), "abilità sull'estremo superiore dell'intervallo (%.0f″)" % hi)
	# giorni sintetici per costanza e buonanotte
	var st2 := Storia.new()
	for wk in 4:
		for dd in [0, 2, 4]:
			var t: float = Time.get_unix_time_from_datetime_string("2026-10-05T12:00:00") + (wk * 7 + dd) * 86400
			st2.days[Time.get_date_string_from_unix_time(t)] = 15.0
	for dd in ["2026-10-05", "2026-10-07", "2026-10-09"]:
		st2.sessions.append({"sessione": dd, "data": dd, "fine_ora": 22.5, "minuti": 15.0, "notti_complete": 1, "stima": {"stimabile": false}})
	var r2 := Obiettivi.evaluate(st2)
	check(r2["tre_lanterne"]["ok"] and r2["quattro_settimane"]["ok"] and r2["mese_lanterna"]["ok"], "costanza: quattro settimane di fila con tre lanterne")
	check(r2["buonanotte"]["ok"], "buonanotte: tre sere chiuse prima delle 23")
	check(not r2["progresso"]["ok"] and not r2["occhio_600"]["ok"], "niente abilità senza stime")
	var prof2 := {}
	var got := Obiettivi.update_profile(prof2, r2, "2026-11-01")
	var got_again := Obiettivi.update_profile(prof2, r2, "2026-11-02")
	check(got.size() >= 3 and got_again.is_empty() and prof2["obiettivi"]["tre_lanterne"] == "2026-11-01", "date di sblocco salvate una volta sola")
	# --- la scena della capanna, sul desktop
	var pf := FileAccess.open(dir + "profilo.json", FileAccess.WRITE)
	pf.store_string(JSON.stringify(profile))
	pf.close()
	root.set_meta("capanna_opts", {"partecipante": "test_capanna"})
	var cap: Node = load("res://scenes/capanna.tscn").instantiate()
	cap.no_switch = true
	root.add_child(cap)
	await process_frame
	await process_frame
	check(cap.participant == "test_capanna" and cap.storia.sessions.size() == 2, "capanna: dati del partecipante caricati")
	check(cap.prog.data.get("obiettivi", {}).has("prima_notte"), "capanna: obiettivi retroattivi salvati nel profilo")
	check(cap.menu.page == "capanna" and cap.menu.status_text().contains("Welcome back, Test Capanna") and cap.menu.status_text().contains("sensitivity"), "capanna: pagina iniziale con l'ultima stima")
	# ida e ritorno pixel ↔ mondo, poi un clic vero attraverso il pannello
	var px := Vector2(400, 300)
	var wp: Vector3 = cap.pixel_to_world(px)
	var cam_pos: Vector3 = cap.camera.global_position
	var back: Vector2 = cap.hit_pixel(cam_pos, (wp - cam_pos).normalized())
	check(back.distance_to(px) < 0.5, "raggio → pixel del pannello (%s)" % str(back))
	check(cap.hit_pixel(cam_pos, Vector3(0, 0, 1)).x < 0.0, "raggio che non colpisce il pannello")
	var tab: Button = cap.menu.tab_buttons["diario"]
	var center: Vector2 = tab.get_global_rect().get_center()
	var hit_px: Vector2 = cap.hit_pixel(cam_pos, (cap.pixel_to_world(center) - cam_pos).normalized())
	cap.click(hit_px)
	await process_frame
	await process_frame
	check(cap.menu.page == "diario", "clic col raggio sulla scheda Diario (pagina: %s)" % cap.menu.page)
	for t in ["cielo", "zero", "occhi", "calendario", "test"]:
		cap.menu._set_tab(t)
		await process_frame
		check(cap.menu.page == "diario" and cap.menu.diary_tab == t and cap.menu.content.get_child_count() > 0, "diario: scheda %s" % t)
	check(cap.menu.tests_text().contains("rings ~300″"), "diario: risultati del test a parole")
	check(cap.menu.calendar_weeks().size() >= 2 and cap.menu.calendar_weeks()[-1] == Storia.week_of(cap.today), "calendario: dalla prima settimana di gioco a questa")
	cap.menu._go("bestiario")
	await process_frame
	check(cap.menu.content.find_child("specie_fatuo", true, false) != null, "bestiario: una carta per specie")
	cap.menu._open_beast("fatuo")
	await process_frame
	check(cap.menu.beast_detail == "fatuo" and cap.menu.content.get_child_count() == 1, "bestiario: scheda della specie")
	cap.menu._go("obiettivi")
	await process_frame
	var lista: ScrollContainer = cap.menu.content.find_child("lista", true, false)
	check(lista != null, "obiettivi: lista scorrevole")
	cap.scroll(Vector2(960, 700), -3.0)
	cap.menu._go("impostazioni")
	await process_frame
	cap.menu.change_setting("durata_notte_min", 1)
	cap.menu.change_setting("suoni_volume", -1)
	cap.menu.change_setting("contrasto_modo", 1)
	check(cap.prog.data["contrasto_modo"] == "settimana", "contrasto: anche una volta a settimana (0.5.7)")
	cap.menu.change_setting("contrasto_modo", 1)
	await process_frame
	var saved = JSON.parse_string(FileAccess.get_file_as_string(dir + "profilo.json"))
	check(int(saved["durata_notte_min"]) == 15 and absf(float(saved["suoni_volume"]) - 0.4) < 1e-6 and saved["contrasto_modo"] == "mai", "impostazioni salvate nel profilo")
	# azione "lampo": opzioni passate al bosco
	cap.menu._go("capanna")
	await process_frame
	cap.menu.action.emit("lampo")
	check(cap.last_action == "lampo" and root.has_meta("bosco_opts") and root.get_meta("bosco_opts")["lampo"] == true, "capanna → lucciole lampo")
	# il bosco legge opzioni e impostazioni
	var bosco: Node = load("res://scenes/training.tscn").instantiate()
	root.add_child(bosco)
	await process_frame
	check(bosco.participant == "test_capanna" and bosco.lampo_mode and bosco.from_capanna, "bosco: partecipante e modalità dalla capanna")
	check(is_equal_approx(bosco.block_seconds, 900.0) and absf(bosco.sfx_volume - 0.4) < 1e-6 and bosco.no_contrast, "bosco: durata, effetti e contrasto dalla capanna")
	check(bosco._close_line().contains("hut") and not root.has_meta("bosco_opts"), "bosco: si torna alla capanna, opzioni consumate")
	var bcsv: String = bosco.csv_path
	bosco.queue_free()
	cap.queue_free()
	await process_frame
	DirAccess.remove_absolute(bcsv)
	for d in [dir, tdir]:
		for f in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d.path_join(f))
		DirAccess.remove_absolute(d)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://results/desktop/test_capanna"))
	print("PASS: capanna (%d controlli)" % checks if failures == 0 else "FAIL: capanna (%d su %d)" % [failures, checks])
	quit(0 if failures == 0 else 1)
