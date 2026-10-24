extends SceneTree
## Flusso in modalità desktop, replay dei parametri, somma delle sessioni (chiave e validazione
## atomica), controlli bilanciati, sessioni grossolana e mappa, errori di salvataggio. Uso: godot --headless --path . --xr-mode off --script res://tests/flow_test.gd

var failures := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: " + what)


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var M = main.get_script()

	# --- controlli iniziali
	check(main.state == main.S.EYECHECK, "si parte dal controllo degli occhi")
	check(main.quads[0].visible and main.label.visible, "controllo occhi: campo e testo insieme")
	main._respond(2)
	check(main.checks["eyecheck"] == "vanno e vengono", "risposta al controllo occhi registrata")
	check(main.state == main.S.NONIUS and main.nonius_step == 0, "poi le lineette, primo passo")
	main._respond(1)
	check(main.nonius_step == 0 and main.checks["nonius_sx"] == "non data", "lineette a un occhio: destra/sinistra ignorate")
	main._respond(0)
	check(main.checks["nonius_sx"] == "sì" and main.nonius_step == 1, "lineetta sopra, occhio sinistro: sì")
	main._respond(2)
	check(main.checks["nonius_dx"] == "no" and main.nonius_step == 2, "lineetta sotto, occhio destro: no")
	main._confirm()
	check(main.checks["nonius"] == "saltato", "passo a occhi aperti saltato: registrato come saltato")
	check(main.state == main.S.INTRO, "poi le istruzioni")
	check(M.nonius_reading(main.checks).begins_with("almeno una lineetta non si vede"), "lettura: limite di visibilità")
	check(M.nonius_reading({"nonius_sx": "sì", "nonius_dx": "sì", "nonius": "solo quella sopra (occhio sinistro)"}).contains("compatibile con una soppressione"), "lettura: compatibile con soppressione")
	check(M.nonius_reading({"nonius_sx": "saltato", "nonius_dx": "sì", "nonius": "tutte e due"}).begins_with("verifica a un occhio non fatta"), "lettura: verifica mancante")
	main._respond(0)
	check(main.state == main.S.INTRO, "la levetta non salta le istruzioni")

	# --- sequenza: controlli bilanciati per occhio sorgente, fasce fisse del random-dot
	main._confirm()
	var sources := {"rds": [0, 0], "rings": [0, 0]}
	var n_cov := 0
	for item in main.schedule:
		if item.get("block") == "control":
			sources[item["cond"]][item["mono"]] += 1
		if item.get("rule") == "coverage":
			n_cov += 1
	check(sources["rds"] == [4, 4] and sources["rings"] == [12, 12], "controlli bilanciati fra i due occhi (%s)" % str(sources))
	check(n_cov == 12, "12 prove random-dot a fasce fisse")
	check(main.state == main.S.PRETRIAL, "grilletto: parte la pratica")
	var practice_levels := []
	for i in 6:
		main._present_stimulus()
		practice_levels.append([main.cur["cond"], main.cur["level"]])
		check(main.cur["block"] == "practice", "prova %d di pratica" % i)
		if main.cur["cond"] == "rings":
			var before: int = main.trial_counter
			main._respond(1)  # destra: non valida per gli anelli
			check(main.trial_counter == before and main.state == main.S.STIMULUS, "anelli: destra/sinistra ignorate")
		main._respond(M.direction_for(main.cur["cond"], main.cur["target"]))
		main._next_trial()
	check(practice_levels[0] == ["rds", 3.5] and practice_levels[1] == ["rings", 3.0], "pratica dalle disparità massime")
	check(main.state == main.S.PAUSE, "fine pratica: pausa")
	main._confirm()
	var n_main := 0
	var n_high := 0
	var n_ctrl := 0
	for i in 60:
		if main.state == main.S.PAUSE:
			main._confirm()
		main._present_stimulus()
		var c: String = main.cur["cond"]
		if main.cur["block"] == "main":
			n_main += 1
			n_high += 1 if main.cur["rule"] == "anchor" else 0
			check(main.cur["level"] <= main.COND[c]["level_max"] + 0.001, "livello entro il massimo")
			check(main.cur["rule"] in ["psi", "anchor", "coverage"], "regola del livello registrata")
		elif main.cur["block"] == "control":
			n_ctrl += 1
			check(main.cur["mono"] in [0, 1], "controllo: un solo occhio")
		var choice: int = main.cur["target"] if randf() < 0.6 else randi_range(0, main.COND[c]["n_alt"] - 1)
		main._respond(M.direction_for(c, choice))
		main._next_trial()
	check(n_main > 30 and n_ctrl > 0, "prove principali e di controllo eseguite")
	print("prove principali: %d, al livello alto: %d, di controllo: %d" % [n_main, n_high, n_ctrl])

	# --- CSV e replay
	main.csv.flush()
	var fa := FileAccess.open(main.csv_path, FileAccess.READ)
	var header := fa.get_csv_line()
	check(Array(header) == M.HEADER, "intestazione del CSV")
	var idx := {}
	for i in header.size():
		idx[header[i]] = i
	var n_rows := 0
	var n_checks := 0
	var replay_ok := true
	var mono_ok := true
	while not fa.eof_reached():
		var row := fa.get_csv_line()
		if row.size() != header.size():
			continue
		n_rows += 1
		if row[idx["block"]] == "check":
			n_checks += 1
			continue
		var params: Dictionary = M.trial_params(int(row[idx["trial_seed"]]), row[idx["condition"]])
		var names: Array = main.COND[row[idx["condition"]]]["choices"]
		var jit: PackedVector2Array = params["jitter"]
		if names[params["target"]] != row[idx["target"]] or str(params["seed_bg"]) != row[idx["seed_bg"]] \
				or str(params["seed_rg"]) != row[idx["seed_rg"]] \
				or "%.4f;%.4f;%.4f;%.4f" % [jit[0].x, jit[0].y, jit[1].x, jit[1].y] != row[idx["ring_jitter"]]:
			replay_ok = false
		if (row[idx["block"]] == "control") != (row[idx["mono_source"]] in ["0", "1"]):
			mono_ok = false
		if main._row_problem(row, idx) != "":
			replay_ok = false
	check(mono_ok, "occhio sorgente solo nelle prove di controllo")
	check(n_checks == 4, "righe dei controlli iniziali (occhi + tre passi delle lineette)")
	check(n_rows >= 68, "righe delle prove nel CSV")
	check(replay_ok, "replay: il seme di ogni prova rigenera gli stessi parametri")

	# --- somma delle sessioni: chiave completa e validazione del file intero prima della somma
	var tmp := ProjectSettings.globalize_path("user://pool_test/")
	DirAccess.make_dir_recursive_absolute(tmp)
	for f in DirAccess.get_files_at(tmp):
		DirAccess.remove_absolute(tmp + f)
	var own := FileAccess.get_file_as_string(main.csv_path)
	var own_lines := own.strip_edges().split("\n")
	_write(tmp + "sessione_a.csv", own)
	_write(tmp + "sessione_b.csv", own.replace("," + main.participant + ",", ",qualcun_altro,"))
	_write(tmp + "sessione_c.csv", own.replace("," + M.PROTOCOL + ",", ",p3,"))
	_write(tmp + "sessione_d.csv", own.replace("pmax_mean", "lapse_mean"))
	_write(tmp + "sessione_e.csv", own.replace("1.000;1.000", "0.000;1.000"))  # N2: contrasto diverso
	_write(tmp + "sessione_f.csv", own.replace(",base,", ",training,"))        # impostazione diversa
	# N4: righe valide seguite da una riga di un altro protocollo, a metà file
	var mixed := "\n".join(own_lines.slice(0, 40)) + "\n" + own_lines[40].replace("," + M.PROTOCOL + ",", ",p4,") + "\n" + "\n".join(own_lines.slice(41)) + "\n"
	_write(tmp + "sessione_g.csv", mixed)
	var pooled: Dictionary = main.pooled_summary(tmp)
	var solo: Dictionary = {}
	check(pooled["sessions"] == 1, "somma: entra solo la sessione compatibile (entrate %d)" % pooled["sessions"])
	check(pooled["excluded"].size() == 6, "somma: sei file esclusi ed elencati (%d)" % pooled["excluded"].size())
	var reasons := " | ".join(pooled["excluded"])
	check(reasons.contains("altro contrasto") and reasons.contains("altra impostazione") and reasons.contains("altro partecipante"), "somma: motivi dell'esclusione")
	for f in DirAccess.get_files_at(tmp):
		DirAccess.remove_absolute(tmp + f)
	_write(tmp + "sessione_a.csv", own)
	solo = main.pooled_summary(tmp)
	check(pooled["rds"]["n"] == solo["rds"]["n"] and pooled["rings"]["n"] == solo["rings"]["n"], "somma: un file escluso non lascia prove nel risultato (N4)")
	check(pooled["controls"]["rings"] == solo["controls"]["rings"], "somma: né controlli")
	for f in DirAccess.get_files_at(tmp):
		DirAccess.remove_absolute(tmp + f)

	# --- statistiche e testi
	check(absf(M.beta_quantile(600, 600, 0.025) - 0.4717) < 1e-3, "Beta con conteggi grandi (N5)")
	var ctrl_txt: String = M.describe_control("rings", [[8, 10], [9, 14]])
	check(ctrl_txt.contains("no signal above chance") and ctrl_txt.contains("= 0.096"), "17/24 della p5: dopo Holm non è un segnale (p 0,096)")
	check(M.describe_control("rings", [[20, 24], [21, 24]]).contains("above chance after correction"), "controllo davvero sopra il caso: segnalato")
	var fam: Array = M.describe_family(["rds_coarse"], {"rds_coarse": {"3.51": [7, 14], "3.67": [3, 14], "3.81": [2, 14], "3.95": [4, 14]}})
	check(String(fam[-1]).begins_with("No level above chance"), "7/14 su quattro livelli: niente dopo Holm (N3)")

	# review T6: un osservatore che discrimina ha fasce sopra il caso, e non deve ricevere l'avviso
	var good := {"2.00": [5, 20], "2.40": [10, 20], "2.80": [16, 20], "3.20": [20, 20]}
	check(not M.describe_coverage("rds", good, "measured").contains("WARNING"), "fasce fisse buone con curva misurata: nessun avviso")
	check(M.describe_coverage("rds", good, "above").contains("WARNING"), "fasce fisse sopra il caso ma curva non trovata: avviso")

	# --- riepilogo JSON atomico (N8)
	var jpath := tmp + "riepilogo.json"
	check(M._save_json(jpath, {"a": 1}) and JSON.parse_string(FileAccess.get_file_as_string(jpath))["a"] == 1, "JSON salvato e leggibile")
	check(not FileAccess.file_exists(jpath + ".tmp"), "nessun file temporaneo rimasto")
	check(not M._save_json(tmp + "manca/cartella/r.json", {"a": 1}), "JSON non scrivibile: segnalato")
	DirAccess.remove_absolute(jpath)

	# --- errore di salvataggio: l'app si ferma e lo dice
	var path: String = main.csv_path
	main.csv = null
	var wrote: bool = main._write_row({"trial": 999, "block": "main"})
	check(not wrote and main.state == main.S.ERROR and main.label.visible, "salvataggio fallito: arresto visibile")
	DirAccess.remove_absolute(path)

	# --- nomi dei partecipanti
	check(M.sanitize_name(" Player ") == "player", "nome normalizzato")
	check(M.sanitize_name("desktop") == "p_desktop", "nome riservato protetto")
	check(M.sanitize_name("../x") == "x", "niente percorsi nel nome")
	check(M.sanitize_name("", false) == "base" and M.sanitize_name("desktop", false) == "desktop", "impostazione normalizzata")

	# --- sessione grossolana (stimoli costanti)
	var coarse: Node = load("res://scenes/main.tscn").instantiate()
	coarse.session_override = "grossolana"
	root.add_child(coarse)
	await process_frame
	check(coarse.session_conds == M.COARSE_CONDITIONS, "grossolana: condizioni giuste")
	coarse._confirm()
	coarse._confirm()
	coarse._confirm()
	for i in 3:
		coarse._present_stimulus()
		check(coarse.cur["block"] == "practice" and coarse.cur["cond"] == "rds_coarse", "grossolana: pratica")
		coarse._respond(coarse.cur["target"])
		coarse._next_trial()
	check(coarse.state == coarse.S.PAUSE, "grossolana: pausa dopo la pratica")
	coarse._confirm()
	var seen := {}
	for i in 30:
		if coarse.state == coarse.S.PAUSE:
			coarse._confirm()
		coarse._present_stimulus()
		if coarse.cur["block"] == "main":
			seen["%.2f" % coarse.cur["level"]] = true
		coarse._respond(coarse.cur["target"])
		coarse._next_trial()
	var total := 0
	for key in coarse.fixed_counts["rds_coarse"]:
		total += coarse.fixed_counts["rds_coarse"][key][1]
		check(key in ["3.51", "3.67", "3.81", "3.95"], "grossolana: livello %s previsto" % key)
	check(total > 15 and seen.size() >= 3, "grossolana: prove principali contate per livello")
	check(str(M.describe_family(["rds_coarse"], coarse.fixed_counts)).contains("Holm"), "grossolana: riepilogo per livello con Holm")
	coarse.csv.flush()
	DirAccess.remove_absolute(coarse.csv_path)

	# --- mappa (stimoli costanti, due formati)
	var mp: Node = load("res://scenes/main.tscn").instantiate()
	mp.session_override = "mappa"
	root.add_child(mp)
	await process_frame
	check(mp.session_conds == M.MAP_CONDITIONS, "mappa: condizioni giuste")
	mp._confirm()
	mp._confirm()
	mp._confirm()
	var n_prac := 0
	while mp.state == mp.S.PRETRIAL:
		mp._present_stimulus()
		check(mp.cur["block"] == "practice", "mappa: pratica")
		n_prac += 1
		mp._respond(mp.cur["target"])
		mp._next_trial()
	check(n_prac == 4 and mp.state == mp.S.PAUSE, "mappa: 4 prove di pratica, poi pausa")
	var n_mp := 0
	for item in mp.schedule:
		if item.get("block") in ["main", "control"]:
			n_mp += 1
	check(n_mp == 88, "mappa: 80 prove principali e 8 di controllo (%d)" % n_mp)
	mp._confirm()
	var geom_ok := true
	var grande_seen := false
	for i in 40:
		if mp.state == mp.S.PAUSE:
			mp._confirm()
		mp._present_stimulus()
		var fe: float = mp.materials[0].get_shader_parameter("field_extent")
		var want: float = 9.6 if mp.cur["cond"] == "rds_grande" else 6.0
		grande_seen = grande_seen or mp.cur["cond"] == "rds_grande"
		if absf(fe - want) > 1e-6:
			geom_ok = false
		mp._respond(mp.cur["target"])
		mp._next_trial()
	check(geom_ok and grande_seen, "mappa: geometria del formato applicata a ogni prova")
	var keys_ok := true
	for c in M.MAP_CONDITIONS:
		for key in mp.fixed_counts[c]:
			if float(key) not in M.COND[c]["levels"]:
				keys_ok = false
	check(keys_ok, "mappa: conteggi solo ai livelli previsti")
	mp.csv.flush()
	DirAccess.remove_absolute(mp.csv_path)

	print("PASS: flow" if failures == 0 else "FAIL: flow (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
