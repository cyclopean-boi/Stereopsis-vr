extends SceneTree
## Test delle rovine (training 0.5.13, protocollo r5 col mosaico oltre la pietra nuda; r4, r3, r2 e i file 0.5.2 senza segno restano leggibili): scala del ponte con esiti agli estremi,
## sonde separate dai sentieri, bersagli imprevedibili dalla storia (RV1), regola sequenziale del
## restauro (RV2) confrontata con l'implementazione Python, estremi perfetti (RV3), vento a
## spostamento saturante (RV4), CSV validati per intero (RV5), diario e obiettivi.
## Uso: godot --headless --path . --xr-mode off --script res://tests/rovine_test.gd

const Ponte := preload("res://scripts/training/ponte.gd")
const Misure := preload("res://scripts/training/rovine_misure.gd")
const Rovine := preload("res://scripts/training/rovine.gd")
const Storia := preload("res://scripts/training/storia.gd")
const Obiettivi := preload("res://scripts/training/obiettivi.gd")
const Fit := preload("res://scripts/training/fit.gd")
var failures := 0
var checks := 0
var rng := RandomNumberGenerator.new()
var dir := ""


func check(cond: bool, what: String) -> void:
	checks += 1
	if OS.get_environment("VERBOSE_TEST") != "":
		print(("ok   " if cond else "NO   ") + what)
	if not cond:
		failures += 1
		print("FAIL: " + what)


func near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _initialize() -> void:
	rng.seed = 29092026
	dir = OS.get_user_data_dir().path_join("test_rovine")
	DirAccess.make_dir_recursive_absolute(dir)
	_clean()
	_test_ponte()
	_test_ponte_simulato()
	_test_estremi()
	_test_intervalli()
	_test_separazione()
	_test_sequenziale()
	_test_validazione()
	_test_storia_e_restauro()
	_test_sequenza()
	_test_vento()
	_test_segno()
	_test_postura()
	_test_mosaico()
	_test_senza_scaglie()
	_test_oltre()
	_clean()
	if failures == 0:
		print("PASS: rovine (%d controlli)" % checks)
	else:
		print("FAIL: rovine, %d su %d" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _clean() -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))


# ---------------------------------------------------------------- scala

func _test_ponte() -> void:
	var p := Ponte.new(Misure.SCALE_LEVELS)
	check(p.index == 0 and p.value() == 1.0, "il ponte parte dalla rotella piena")
	p.record(true)
	p.record(true)
	check(p.index == 0, "due giuste non bastano")
	var r: Dictionary = p.record(true)
	check(p.index == 1 and r["dir"] == 1 and not r["reversal"], "tre giuste: un gradino verso la pietra nuda")
	r = p.record(false)
	check(p.index == 0 and r["dir"] == -1 and r["reversal"] and p.reversals == [1], "una sbagliata: un gradino indietro, inversione al gradino 1")
	r = p.record(false)
	check(p.index == 0 and r["dir"] == 0 and not r["reversal"], "al gradino più facile: mossa bloccata, nessuna direzione")
	# RV3, nota: una mossa bloccata non deve generare inversioni dopo
	var q := Ponte.new(Misure.SCALE_LEVELS)
	q.record(false)
	for i in 3:
		q.record(true)
	check(q.index == 1 and q.reversals.is_empty(), "dopo una mossa bloccata al bordo la salita non è un'inversione")
	p.index = p.top()
	for i in 3:
		r = p.record(true)
	check(p.index == p.top() and p.pure() and r["dir"] == 0, "alla pietra nuda resta lì, mossa bloccata")
	check(p.value() == 0.0, "l'ultimo gradino è senza rotella")
	var e := Ponte.estimate_from(Misure.SCALE_LEVELS, [3, 4, 3, 4])
	check(e["stimabile"] and e["esito"] == "interno" and near(e["indice"], 3.5, 1e-9), "stima interna: media delle inversioni")
	check(near(e["valore"], sqrt(0.25 * 0.16), 1e-6), "stima: interpolazione in log fra 25% e 16%")
	check(Ponte.estimate_from(Misure.SCALE_LEVELS, [3, 4, 3])["esito"] == "insufficiente", "meno di 4 inversioni: insufficiente")
	var e6 := Ponte.estimate_from(Misure.SCALE_LEVELS, [0, 0, 5, 6, 5, 6, 5, 6])
	check(near(e6["indice"], 5.5, 1e-9), "stima: solo le ultime 6 inversioni")
	check(near(Ponte.value_at_levels(Misure.SCALE_LEVELS, 8.5), 0.0125, 1e-9), "fra l'ultima scaglia e zero: interpolazione lineare")
	var m := Ponte.new(Misure.MOVE_LEVELS)
	m.from_dict({"index": 5}, 2)
	check(m.index == 3, "da una sessione precedente: due gradini più facile")
	m.from_dict({"index": 1}, 2)
	check(m.index == 0, "riscaldamento non sotto il primo gradino")
	check(Misure.SCALE_LEVELS.size() == Misure.MOVE_LEVELS.size(), "stesso numero di gradini nei due sentieri")


func _test_ponte_simulato() -> void:
	var v50 := 0.12
	var v79 := v50 * exp(0.5 * Fit.phi_inv((0.79 - 0.25) / 0.72))
	var ests := []
	for s in 40:
		var p := Ponte.new(Misure.SCALE_LEVELS)
		for t in 45:
			var v := p.value()
			var pc := 0.25 + (0.72 * Fit.phi(log(v / v50) / 0.5) if v > 0.0 else 0.0)
			p.record(rng.randf() < pc)
		var e := Ponte.estimate_from(Misure.SCALE_LEVELS, p.reversals)
		if e["esito"] == "interno":
			ests.append(log(float(e["valore"]) / v79))
	check(ests.size() >= 34, "in 45 prove per sentiero la scala si assesta quasi sempre (%d su 40)" % ests.size())
	ests.sort()
	var med: float = ests[ests.size() / 2]
	check(absf(med) < log(1.6), "il punto del ponte stima il 79%% dell'osservatore (rapporto mediano %.2f)" % exp(med))


## RV3: prestazione perfetta = esito "al puro", non "instabile".
func _test_estremi() -> void:
	var p := Ponte.new(Misure.SCALE_LEVELS)
	var top_kn := [0, 0]
	for t in 60:
		var at_top := p.pure()
		p.record(true)
		if at_top:
			top_kn[0] += 1
			top_kn[1] += 1
	check(p.reversals.is_empty() and top_kn == [33, 33], "60 giuste: al puro dopo 27 prove, 33/33 lì, nessuna inversione")
	var e := Ponte.estimate_from(Misure.SCALE_LEVELS, p.reversals, top_kn, [0, 0])
	check(e["esito"] == "al_puro" and e["stimabile"] and e["valore"] == 0.0, "esito: al random-dot puro")
	var weak := Ponte.estimate_from(Misure.SCALE_LEVELS, [], [5, 11], [0, 0])
	check(weak["esito"] == "insufficiente", "poche prove al puro: insufficiente")
	var poor := Ponte.estimate_from(Misure.SCALE_LEVELS, [], [0, 0], [4, 14])
	check(poor["esito"] == "al_pieno" and not poor["stimabile"], "sotto metà giuste con l'aiuto pieno: al pieno")


func _test_intervalli() -> void:
	var a := Misure.probes(5, 20)
	check(near(a["ic"][0], 0.0866, 0.0005) and near(a["ic"][1], 0.4910, 0.0005), "Clopper-Pearson 5/20: 0,087–0,491")
	check(near(a["p_caso"], 0.5852, 0.0005), "P(X >= 5 | 20, 1/4) = 0,585")
	var b := Misure.probes(0, 10)
	check(b["ic"][0] == 0.0 and near(b["ic"][1], 0.3085, 0.0005) and b["p_caso"] == 1.0, "0/10: 0–0,308, p = 1")
	var c := Misure.probes(10, 10)
	check(c["ic"][1] == 1.0 and near(c["ic"][0], 0.6915, 0.0005), "10/10: 0,692–1")
	check(Misure.fmt_probes(Misure.probes(0, 0)) == "no probes", "nessuna sonda")
	check(Misure.fmt_level("scaglie", 0.063) == "scales at 6.3%", "formato delle scaglie")
	check(Misure.fmt_level("movimento", 0.08) == "wind 0.08°", "formato del vento")
	check(Misure.fmt_level("scaglie", 0.0) == "pure random-dot", "gradino puro")


func _row(kind: String, correct: bool, li := -1, extra := {}) -> Dictionary:
	var target := rng.randi_range(0, 3)
	var resp := target if correct else (target + 1 + rng.randi_range(0, 2)) % 4
	var sc := 0.0
	var pa := 0.0
	if kind == "scaglie":
		sc = Misure.SCALE_LEVELS[li]
	elif kind == "movimento":
		pa = Misure.MOVE_LEVELS[li]
	var r := {"session": "s", "participant": "prova", "version": "training-0.5.1", "protocol": "r3",
		"mode": "vr", "trial": "1", "night": "1", "kind": kind, "level_index": str(li) if li >= 0 else "",
		"scale_c": "%.3f" % sc, "parallax_amp_deg": "%.3f" % pa, "disparity_arcsec": "1000.0",
		"target": Misure.NAMES[target], "response": Misure.NAMES[resp], "correct": "1" if correct else "0",
		"outcome": "risposta", "rt_s": "3.0", "seed_bg": "1", "seed_rg": "2", "seed_sc": "3", "sway_max_mm": "20.0",
		"parallax_max_deg": "0", "cue_ok": "1", "head_rot_deg": "1", "ipd_m": "0.066", "px_arcsec": "150",
		"dir": "0", "reversal": "0", "level_after": str(li) if li >= 0 else "", "creature": "cervo", "hand": "sim", "sicuro": "0"}
	r.merge(extra, true)
	return r


func _test_separazione() -> void:
	var rows := []
	for i in 20:
		rows.append(_row("sonda", i < 7))
	for i in 30:
		rows.append(_row("scaglie", true, 9))           # arrivate alla pietra nuda: NON sono sonde
	for i in 10:
		rows.append(_row("movimento", i % 2 == 0, 9))
	for i in 5:
		rows.append(_row("movimento", true, 2, {"cue_ok": "0", "sway_max_mm": "3.0"}))   # testa ferma
	rows.append(_row("sonda", true, -1, {"outcome": "timeout", "response": ""}))
	rows.append(_row("sonda", true, -1, {"outcome": "pausa", "response": ""}))
	var s := Misure.summarize(rows)
	check(s["sonde"]["n"] == 20 and s["sonde"]["k"] == 7, "le sonde contano solo la pietra nuda con risposta (7/20)")
	check(s["puro"]["scaglie"] == [30, 30] and s["puro"]["movimento"] == [5, 10], "le prove dei sentieri al gradino puro stanno a parte")
	check(s["vento_fermo"] == 5 and s["sentieri"]["movimento"] == [5, 10], "vento non arrivato: fuori dalla scala e dalla stima")
	check(s["scadute"]["sonda"] == 1, "scadute contate")
	check(s["scaglie"]["esito"] == "al_puro", "30/30 al puro: esito al puro")
	check(near(s["minuti"], (66 * 5.4) / 60.0, 1e-6), "minuti: risposte e scadute con 2,4 s fissi, non le pause")


# ---------------------------------------------------------------- RV2

func _hist(seqs: Array) -> Array:
	var out := []
	for sq in seqs:
		out.append({"valida": true, "sonde_seq": sq})
	return out


func _test_sequenziale() -> void:
	# stessi valori dell'implementazione Python di verifica (verifica/training-0.5.1/)
	var seq := []
	for i in 100:
		seq.append(((i * 7) % 10) < 4)
	var h := _hist([seq.slice(0, 20), seq.slice(20, 40), seq.slice(40, 60), seq.slice(60, 80), seq.slice(80, 100)])
	var e1 := Misure.e_process(h, 0.25)
	check(near(e1["log_e"], 2.1447078996493887, 1e-9), "e-process contro il caso uguale al Python (%.12f)" % e1["log_e"])
	var e2 := Misure.e_process(h, 0.5)
	check(near(e2["log_e"], -0.011976191046715517, 1e-9) and near(e2["max_e"], 1.0, 1e-12), "e-process contro 1 su 2 uguale al Python")
	var seq2 := []
	for i in 100:
		seq2.append(((i * 3) % 5) < 3)
	var h2 := _hist([seq2.slice(0, 50), seq2.slice(50, 100)])
	check(near(Misure.e_process(h2, 0.25)["log_e"], 14.143769275495861, 1e-8), "60% in 100 sonde: evidenza uguale al Python")
	check(Misure.e_process(h2, 0.25)["superato"] and not Misure.e_process(h2, 0.5)["superato"], "60%: portale sì, torre no")
	# al caso, molte sessioni: il portale non si apre (Ville: <= 1% per sempre)
	var opened := 0
	for hist_i in 150:
		var hs := []
		for s in 40:
			var sq := []
			for t in 20:
				sq.append(rng.randf() < 0.25)
			hs.append(sq)
		if Misure.e_process(_hist(hs), 0.25)["superato"]:
			opened += 1
	check(opened <= 3, "al caso, 150 storie da 40 sessioni: portale aperto %d volte (atteso ~0)" % opened)
	# un osservatore che migliora: si apre
	var hs2 := []
	for s in 20:
		var sq := []
		for t in 20:
			sq.append(rng.randf() < (0.25 if s < 8 else 0.5))
		hs2.append(sq)
	check(Misure.e_process(_hist(hs2), 0.25)["superato"], "al caso per 8 sessioni, poi 50%: il portale si apre")


# ---------------------------------------------------------------- RV5

func _write_rows(path: String, header: Array, rows: Array) -> void:
	var fa := FileAccess.open(path, FileAccess.WRITE)
	fa.store_csv_line(PackedStringArray(header))
	for r in rows:
		var line := PackedStringArray()
		for hname in header:
			line.append(str(r.get(hname, "")))
		fa.store_csv_line(line)
	fa.close()


func _test_validazione() -> void:
	var good := []
	for i in 10:
		good.append(_row("sonda", i < 3))
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), good) == "", "file corretto accettato")
	var bad := good.duplicate(true)
	bad[4]["scale_c"] = "0.400"
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), bad).contains("sonda"), "una sonda con le scaglie viene rifiutata")
	bad = good.duplicate(true)
	bad[2]["correct"] = "1" if bad[2]["correct"] == "0" else "0"
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), bad).contains("correct"), "correct incoerente rifiutato")
	bad = good.duplicate(true)
	bad[7]["protocol"] = "r1"
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), bad).contains("protocollo"), "righe di un altro protocollo rifiutate")
	bad = good.duplicate(true)
	bad[5]["mode"] = "autotest"
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), bad).contains("mode"), "modo diverso dalla prima riga rifiutato")
	var sg := [_row("scaglie", true, 3)]
	sg[0]["scale_c"] = "0.100"
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), sg).contains("scaglie"), "contrasto diverso dal gradino rifiutato")
	# la riproduzione della review: prima riga r2 buona, poi 40 righe estranee marcate sonda
	var mixed := [_row("sonda", true)]
	for i in 40:
		mixed.append(_row("sonda", true, -1, {"protocol": "r0", "mode": "autotest", "scale_c": "1.000"}))
	_write_rows(dir.path_join("rovine_20260929_120001_mixd.csv"), Misure.HEADER_054, mixed)
	var old_header := Misure.HEADER_054.duplicate()
	old_header[old_header.find("parallax_amp_deg")] = "parallax_gain"
	_write_rows(dir.path_join("rovine_20260929_120002_oldr.csv"), old_header, good)
	var full := Misure.load_history_full(dir)
	check(full["sessioni"].is_empty() and full["esclusi"].size() == 2, "file misti o della r1: esclusi, con il motivo")
	_clean()


# ---------------------------------------------------------------- storia e restauro

func _session_rows(probe_seq: Array, sc_li: int, sc_rev: bool, mv_li: int, mv_rev: bool, top_perfect := false) -> Array:
	var rows := []
	for x in probe_seq:
		rows.append(_row("sonda", x))
	for i in 6:
		rows.append(_row("scaglie", i % 2 == 0, sc_li, {"reversal": "1" if sc_rev else "0"}))
		rows.append(_row("movimento", i % 2 == 0, mv_li, {"reversal": "1" if mv_rev else "0"}))
	if top_perfect:
		for i in 14:
			rows.append(_row("scaglie", true, 9))
			rows.append(_row("movimento", true, 9))
	for i in 100:
		rows.append(_row("scaglie", true, sc_li))
	return rows


func _seq(n: int, k_of_5: int) -> Array:
	var out := []
	for i in n:
		out.append(((i * 3) % 5) < k_of_5)
	return out


func _test_storia_e_restauro() -> void:
	_write_rows(dir.path_join("rovine_20260929_101000_aaaa.csv"), Misure.HEADER_054, _session_rows(_seq(50, 3), 3, true, 3, true))
	var hist := Misure.load_history(dir)
	check(hist.size() == 1 and hist[0]["data"] == "2026-09-29", "storia: una sessione con la data dal nome")
	var res := Misure.evaluate_pieces(hist)
	check(not res["scala"]["ok"] and res["scala"]["cur"] == 1, "una sessione sola non restaura la scala")
	_write_rows(dir.path_join("rovine_20260930_101000_bbbb.csv"), Misure.HEADER_054, _session_rows(_seq(50, 3), 3, true, 3, true))
	hist = Misure.load_history(dir)
	res = Misure.evaluate_pieces(hist)
	check(res["scala"]["ok"] and res["pozzo"]["ok"], "due sessioni di fila al 25% e a vento 0,2°: scala e pozzo")
	check(not res["arco"]["ok"] and not res["lanterne"]["ok"], "ma non l'arco (16%) né le lanterne (0,08°)")
	check(res["portale"]["ok"] and not res["torre"]["ok"], "60% su 100 sonde: portale sì, torre no")
	var prof := {}
	var fresh := Misure.update_pieces(prof, res, "2026-09-30")
	check(fresh.size() == 3 and prof["rovine"]["pezzi"].has("portale") and prof["rovine"]["protocollo"] == Misure.PROTOCOL, "tre pezzi nuovi nel profilo r2")
	check(Misure.update_pieces(prof, res, "2026-10-01").is_empty(), "un pezzo si restaura una volta sola")
	check(Misure.restored_ids(prof) == ["scala", "pozzo", "portale"], "ordine dei pezzi restaurati")
	# consecutività: una sessione informativa sopra il limite interrompe la serie
	_clean()
	_write_rows(dir.path_join("rovine_20261001_101000_c1.csv"), Misure.HEADER_054, _session_rows([], 3, true, 3, true))
	_write_rows(dir.path_join("rovine_20261002_101000_c2.csv"), Misure.HEADER_054, _session_rows([], 0, true, 0, true))
	_write_rows(dir.path_join("rovine_20261003_101000_c3.csv"), Misure.HEADER_054, _session_rows([], 3, true, 3, true))
	check(not Misure.evaluate_pieces(Misure.load_history(dir))["scala"]["ok"], "due sessioni buone non consecutive: niente scala")
	# RV3: due sessioni perfette al puro restaurano i sei pezzi dei sentieri
	_clean()
	for i in 2:
		_write_rows(dir.path_join("rovine_2026100%d_101000_pf.csv" % (4 + i)), Misure.HEADER_054, _session_rows([], 8, false, 8, false, true))
	res = Misure.evaluate_pieces(Misure.load_history(dir))
	var five := true
	for id in ["scala", "pozzo", "arco", "lanterne", "affresco"]:
		five = five and res[id]["ok"]
	check(five and not res["fontana"]["ok"], "due sessioni r3 perfette al puro: i cinque pezzi di scaglie e vento; la fontana ora è del mosaico")
	# migrazione di un profilo r1
	var p1 := {"rovine": {"pezzi": {"portale": "2026-09-29"}, "scaglie": {"index": 6}}}
	check(Misure.restored_ids(p1).is_empty(), "i pezzi della r1 non valgono nella r2")
	check(Misure.migrate(p1) and p1.has("rovine_r1") and p1["rovine"] == {"protocollo": Misure.PROTOCOL}, "profilo r1 conservato a parte")
	# diario e obiettivi
	_clean()
	_write_rows(dir.path_join("rovine_20260929_101000_aaaa.csv"), Misure.HEADER_054, _session_rows(_seq(50, 3), 3, true, 3, true))
	_write_rows(dir.path_join("rovine_20260930_101000_bbbb.csv"), Misure.HEADER_054, _session_rows(_seq(50, 3), 3, true, 3, true))
	var st := Storia.new()
	st.load_all(dir, dir, prof)
	check(st.rovine.size() == 2 and st.rovine_escluse.is_empty(), "il diario legge le rovine")
	check(float(st.days.get("2026-09-29", 0.0)) > 10.0, "i minuti delle rovine accendono le lanterne")
	check(st.completed_nights() == 2, "le notti delle rovine contano")
	var ach := Obiettivi.evaluate(st)
	check(ach["discesa"]["ok"] and ach["restauro_1"]["ok"] and not ach["restauro_4"]["ok"], "obiettivi: discesa e prima pietra")
	check(ach["sonde_100"]["ok"] and ach["due_sentieri"]["ok"], "obiettivi: cento sonde e due sentieri")
	_clean()


# ---------------------------------------------------------------- RV1

func _test_sequenza() -> void:
	var rv = Rovine.new()
	rv.rng.seed = 7
	var kinds := {"sonda": 0, "scaglie": 0, "mosaico": 0, "polarita": 0}
	for i in 1000:
		kinds[rv._draw_kind()] += 1
	check(kinds["sonda"] == 300 and kinds["scaglie"] == 0 and kinds["mosaico"] == 500 and kinds["polarita"] == 200, "0.5.10, blocchi di 10: 3 sonde, 5 mosaico, 2 polarità, niente scaglie (%s)" % str(kinds))
	var pols := {"scuri": 0, "chiari": 0}
	var pair_ok := true
	for i in 500:
		var a: String = rv._draw_polarity()
		var b: String = rv._draw_polarity()
		pols[a] += 1
		pols[b] += 1
		pair_ok = pair_ok and a != b
	check(pair_ok and pols["scuri"] == 500, "polarità a coppie: scuri e chiari alla pari")
	# osservatori senza immagini, che usano solo il riscontro delle sonde precedenti
	var n := 0
	var bag_hits := 0
	var avoid_hits := 0
	var seen := []
	var last := -1
	var pos := [0, 0, 0, 0]
	for i in 200000:
		var kind: String = rv._draw_kind()
		var t: int = rv._draw_target(kind)
		if kind != "sonda":
			continue
		n += 1
		pos[t] += 1
		# strategia "sacchetto": esclude i bersagli già rivelati da quando il sacchetto si è svuotato
		var cand := []
		for c in 4:
			if c not in seen:
				cand.append(c)
		var g: int = cand[rng.randi_range(0, cand.size() - 1)]
		bag_hits += 1 if g == t else 0
		seen.append(t)
		if seen.size() >= 4:
			seen.clear()
		var others := [0, 1, 2, 3]
		others.erase(last)
		var g2: int = others[rng.randi_range(0, others.size() - 1)] if last >= 0 else rng.randi_range(0, 3)
		avoid_hits += 1 if g2 == t else 0
		last = t
	var se := sqrt(0.25 * 0.75 / n)
	check(absf(float(bag_hits) / n - 0.25) < 3.0 * se, "RV1: la strategia del sacchetto resta al caso (%.4f su %d sonde)" % [float(bag_hits) / n, n])
	check(absf(float(avoid_hits) / n - 0.25) < 3.0 * se, "RV1: evitare l'ultimo bersaglio resta al caso (%.4f)" % (float(avoid_hits) / n))
	var chi := 0.0
	for c in pos:
		chi += pow(c - n / 4.0, 2.0) / (n / 4.0)
	check(chi < 16.27, "posizioni uniformi (chi quadro %.2f, 3 gl, soglia 0,001)" % chi)
	var lum: Vector3 = Rovine._tint()
	check(near(0.2126 * lum.x + 0.7152 * lum.y + 0.0722 * lum.z, 1.0, 1e-6), "la tinta della pietra ha luminanza 1")
	rv.free()


# ---------------------------------------------------------------- RV4

func _test_vento() -> void:
	var p := Rovine.parallax_for(0.2, 0.003)
	check(near(p, -0.2 * tanh(1.0), 1e-9), "vento: con 3 mm di testa a destra la creatura davanti va a sinistra (%.3f°)" % p)
	check(Rovine.parallax_for(0.0, 0.03) == 0.0, "gradino puro: niente vento")
	check(Rovine.parallax_for(0.2, -0.003) > 0.0, "testa a sinistra: la creatura davanti va a destra")
	# il controesempio della review: muoversi di più non aumenta l'aiuto oltre l'ampiezza del gradino
	check(absf(Rovine.parallax_for(0.032, 0.08)) <= 0.032 + 1e-12, "a 8 cm lo spostamento resta entro l'ampiezza del gradino")
	check(absf(Rovine.parallax_for(0.2, 0.004)) > 4.0 * absf(Rovine.parallax_for(0.032, 0.08)), "un gradino più piccolo resta più piccolo, qualunque movimento")
	# 0.5.2: il vento arriva se lo spostamento mostrato raggiunge metà dell'ampiezza
	check(absf(Rovine.parallax_for(0.2, 0.001)) < Rovine.CUE_MIN_FRAC * 0.2, "1 mm di movimento: vento non arrivato")
	check(absf(Rovine.parallax_for(0.2, 0.0043)) >= Rovine.CUE_MIN_FRAC * 0.2, "4 mm (la mediana del 29/9): vento arrivato")
	# un file r2: sonde e scaglie valgono, il vento no
	var rows := []
	for i in 20:
		rows.append(_row("sonda", i < 5, -1, {"protocol": "r2"}))
	for i in 6:
		rows.append(_row("scaglie", i % 2 == 0, 3, {"protocol": "r2", "reversal": "1"}))
		rows.append(_row("movimento", true, 3, {"protocol": "r2", "reversal": "1"}))
	_write_rows(dir.path_join("rovine_20260929_160832_r2r2.csv"), Misure.HEADER_054, rows)
	var h := Misure.load_history(dir)
	check(h.size() == 1 and h[0]["sonde"]["n"] == 20, "file r2: accettato, sonde contate")
	check(h[0]["scaglie"]["esito"] == "interno" and h[0]["movimento"]["esito"] == "insufficiente", "file r2: scaglie stimate, vento escluso")
	_clean()
	var prof := {"rovine": {"protocollo": "r2", "pezzi": {"scala": "2026-09-29"}, "scaglie": {"index": 4}, "movimento": {"index": 1}}}
	check(Misure.restored_ids(prof) == ["scala"], "profilo r2: i pezzi valgono")
	check(Misure.migrate(prof) and prof["rovine"]["protocollo"] == Misure.PROTOCOL and not prof["rovine"].has("movimento") and prof["rovine"]["scaglie"]["index"] == 4, "r2 -> r3: pezzi e scaglie restano, il vento riparte")


# ---------------------------------------------------------------- 0.5.3: segno "vista davvero"

## 0.5.4: tre colonne di postura della testa, annotazioni che non toccano conteggi e restauro.
func _test_postura() -> void:
	check(Misure.HEADER_054.slice(0, Misure.HEADER_053.size()) == Misure.HEADER_053 and Misure.HEADER_053.slice(0, Misure.HEADER_052.size()) == Misure.HEADER_052, "schemi 0.5.2, 0.5.3 e 0.5.4 l'uno prefisso dell'altro")
	var rows := []
	for i in 12:
		rows.append(_row("sonda", i < 4, -1, {"head_roll_deg": "3.25", "head_roll_resp_deg": "4.10", "head_pitch_deg": "-11.80"}))
	rows.append(_row("sonda", false, -1, {"outcome": "pausa", "response": "", "sicuro": "", "head_roll_deg": "", "head_roll_resp_deg": "", "head_pitch_deg": ""}))
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), rows) == "", "file 0.5.4 con la postura accettato (anche con celle vuote nelle pause)")
	check(Misure.HEADER == Misure.HEADER_054 + Misure.MOSAIC_COLS, "schema r4: lo 0.5.4 più le tre colonne del mosaico")
	var bad := rows.duplicate(true)
	bad[2]["head_roll_deg"] = "storta"
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), bad).contains("postura"), "postura non numerica rifiutata")
	bad = rows.duplicate(true)
	bad[2]["head_pitch_deg"] = "120"
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), bad).contains("postura"), "postura fuori da ±90° rifiutata")
	var r053 := []
	for r in rows:
		var c: Dictionary = r.duplicate()
		for k in Misure.POSE_COLS:
			c.erase(k)
		r053.append(c)
	check(Misure.validate(PackedStringArray(Misure.HEADER_053), r053) == "", "file 0.5.3 senza la postura: ancora accettato")
	check(Misure.summarize(rows)["sonde"] == Misure.summarize(r053)["sonde"], "la postura non cambia il conteggio delle sonde")
	_write_rows(dir.path_join("rovine_20261003_102035_v053.csv"), Misure.HEADER_053, r053)
	_write_rows(dir.path_join("rovine_20261004_102035_v054.csv"), Misure.HEADER_054, rows)
	var full := Misure.load_history_full(dir)
	check(full["sessioni"].size() == 2 and full["esclusi"].is_empty(), "storia mista 0.5.3 e 0.5.4: due file, nessuno escluso")
	check(int(Misure.all_probes(Misure.load_history(dir))["n"]) == 24, "sonde sommate fra i due schemi (24)")
	_clean()


func _test_segno() -> void:
	var rows := []
	for i in 10:
		rows.append(_row("sonda", i < 6, -1, {"sicuro": "1"}))
	for i in 20:
		rows.append(_row("sonda", i < 4))
	for i in 5:
		rows.append(_row("scaglie", i < 3, 0, {"sicuro": "1"}))
	for i in 4:
		rows.append(_row("movimento", true, 2, {"sicuro": "1", "cue_ok": "0"}))   # vento non arrivato: fuori
	rows.append(_row("sonda", false, -1, {"outcome": "timeout", "response": "", "sicuro": ""}))
	var s := Misure.summarize(rows)
	check(s["con_segno"], "segno presente")
	check(s["viste"]["sonda"] == [[6, 10], [4, 20]], "sonde segnate 6/10 e altre 4/20 (%s)" % str(s["viste"]["sonda"]))
	check(s["viste"]["scaglie"] == [[3, 5], [0, 0]], "scaglie segnate 3/5")
	check(s["viste"]["movimento"] == [[0, 0], [0, 0]], "vento non arrivato: fuori anche dal segno")
	check(s["sonde"]["k"] == 10 and s["sonde"]["n"] == 30, "il segno non cambia il conteggio delle sonde")
	check(Misure.fmt_seen(s["viste"], "sonda") == "6/10 marked, 4/20 unmarked", "testo del segno")
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), rows) == "", "file 0.5.3 con il segno accettato")
	var bad := rows.duplicate(true)
	bad[3]["sicuro"] = "2"
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), bad).contains("vista"), "segno non valido rifiutato")
	bad = rows.duplicate(true)
	bad[0]["sicuro"] = ""
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), bad).contains("vista"), "risposta senza segno rifiutata nel formato 0.5.3")
	# file della 0.5.2: senza la colonna, validi e senza segno
	var old := []
	for i in 12:
		var r := _row("sonda", i < 3)
		r.erase("sicuro")
		old.append(r)
	var old_header := Misure.HEADER_052
	check(Misure.validate(PackedStringArray(old_header), old) == "", "file 0.5.2 senza la colonna: accettato")
	check(not Misure.summarize(old)["con_segno"], "file 0.5.2: nessun segno")
	_write_rows(dir.path_join("rovine_20260929_212218_v052.csv"), old_header, old)
	_write_rows(dir.path_join("rovine_20260930_210000_v053.csv"), Misure.HEADER_054, rows)
	_write_rows(dir.path_join("rovine_20261001_210000_v053.csv"), Misure.HEADER_054, rows)
	var h := Misure.load_history(dir)
	check(h.size() == 3 and int(Misure.all_probes(h)["n"]) == 72, "storia mista 0.5.2 e 0.5.3: tre file, 72 sonde")
	var av := Misure.all_seen(h)
	check(av["con_segno"] and av["sessioni"] == 2 and av["sonda"] == [[12, 20], [8, 40]], "segni sommati sulle sole sessioni che li hanno")
	_clean()


# ---------------------------------------------------------------- 0.5.6: mosaico (r4)

func _row4(kind: String, correct: bool, li := -1, extra := {}) -> Dictionary:
	var r := _row(kind if kind in ["sonda", "scaglie"] else "sonda", correct, li if kind == "scaglie" else -1)
	r["protocol"] = "r4"
	r["version"] = "training-0.5.6"
	r["kind"] = kind
	var g: Dictionary = Misure.trial_geometry(kind, li)
	r["level_index"] = str(li) if kind != "sonda" else ""
	r["level_after"] = r["level_index"]
	r["disparity_arcsec"] = "%.1f" % float(g["disparity_arcsec"])
	r["grain"] = "%.4f" % float(g["grain"])
	r["region_t"] = "%.4f" % float(g["region_t"])
	r["polarity"] = "scuri" if kind == "polarita" else "misti"
	for k in Misure.POSE_COLS:
		r[k] = "0.50"
	r.merge(extra, true)
	return r


func _test_mosaico() -> void:
	var st: Array = Misure.MOSAIC_STEPS
	check(st.size() == Misure.MOSAIC_LEVELS.size() and st.size() == 22 and Misure.MOSAIC_LEVELS_R4.size() == 10, "mosaico: 22 gradini dalla r5, i 10 della r4 come gli altri sentieri")
	var one_knob := true
	var monotone := true
	for i in range(1, st.size()):
		var changed := 0
		for k in 3:
			if absf(float(st[i][k]) - float(st[i - 1][k])) > 1e-9:
				changed += 1
		one_knob = one_knob and changed == 1
		monotone = monotone and float(st[i][0]) <= float(st[i - 1][0]) and float(st[i][1]) <= float(st[i - 1][1]) and float(st[i][2]) >= float(st[i - 1][2])
		var knob: String = Misure.MOSAIC_KNOBS[i]
		var diffs := [absf(float(st[i][0]) - float(st[i - 1][0])) > 1e-9, absf(float(st[i][1]) - float(st[i - 1][1])) > 1e-9, absf(float(st[i][2]) - float(st[i - 1][2])) > 1e-9]
		var which: String = ["disparità", "grana", "regioni"][diffs.find(true)]
		one_knob = one_knob and knob == which
	check(one_knob, "mosaico: ogni gradino gira una sola manopola, quella dichiarata")
	check(monotone, "mosaico: ogni manopola va solo verso la pietra nuda")
	var g0: Dictionary = Misure.mosaic_rung(0)
	var g9: Dictionary = Misure.mosaic_rung(9)
	var same0 := true
	for k in Misure.GEOMETRY_LARGE:
		same0 = same0 and g0[k] == Misure.GEOMETRY_LARGE[k]
	check(same0 and near(float(g0["disparity_arcsec"]), 3981.07, 0.01), "gradino 0 = il formato grande della verifica, a 3981″")
	var same9 := true
	var gs: Dictionary = Misure.trial_geometry("sonda", -1)
	for k in Misure.GEOMETRY_NORMAL:
		same9 = same9 and g9[k] == Misure.GEOMETRY_NORMAL[k] and gs[k] == g9[k]
	check(same9 and g9["disparity_arcsec"] == 1000.0 and gs["disparity_arcsec"] == 1000.0, "gradino 9 = la sonda: formato normale a 1000″, valori esatti")
	var g5: Dictionary = Misure.mosaic_rung(5)
	check(near(float(g5["cell"]) / float(g5["dot_r"]), 0.2 / 0.075, 1e-9), "la grana scala punti e celle insieme (stessa copertura)")
	check(Misure.fmt_rung(0).contains("3981″") and Misure.fmt_rung(9).begins_with("bare stone"), "descrizione dei gradini")
	check(Misure.fmt_level("mosaico", 9.0).contains("step 0") and Misure.fmt_level("mosaico", 0.0).begins_with("bare stone (1000″"), "valore del gradino: passi che mancano alla pietra nuda")
	# validazione r4
	var rows := []
	for i in 10:
		rows.append(_row4("sonda", i < 3))
	for i in 6:
		rows.append(_row4("scaglie", i % 2 == 0, 2))
	for li in [0, 1, 2, 3]:
		rows.append(_row4("mosaico", true, li, {"reversal": "1" if li % 2 == 0 else "0"}))
	rows.append(_row4("polarita", false, 3))
	rows.append(_row4("polarita", true, 3, {"polarity": "chiari"}))
	var H := PackedStringArray(Misure.HEADER)
	check(Misure.validate(H, rows) == "", "file r4 corretto accettato (sonde, scaglie, mosaico, polarità)")
	var bad := rows.duplicate(true)
	bad[17]["disparity_arcsec"] = "1000.0"
	check(Misure.validate(H, bad).contains("disparità"), "mosaico con la disparità di un altro gradino rifiutato")
	bad = rows.duplicate(true)
	bad[18]["grain"] = "1.0000"
	check(Misure.validate(H, bad).contains("grana"), "mosaico con la grana sbagliata rifiutato")
	bad = rows.duplicate(true)
	bad[20]["polarity"] = "misti"
	check(Misure.validate(H, bad).contains("polarità"), "prova di polarità con punti misti rifiutata")
	bad = rows.duplicate(true)
	bad[16]["polarity"] = "scuri"
	check(Misure.validate(H, bad).contains("polarità"), "mosaico normale con punti di un colore rifiutato")
	bad = rows.duplicate(true)
	bad[20]["dir"] = "1"
	check(Misure.validate(H, bad).contains("polarità"), "una prova di polarità non muove la scala")
	bad = rows.duplicate(true)
	bad[2]["disparity_arcsec"] = "3981.1"
	check(Misure.validate(H, bad).contains("disparità"), "una sonda deve restare a 1000″")
	bad = rows.duplicate(true)
	bad[3] = _row4("sonda", true)
	bad[3]["kind"] = "movimento"
	check(Misure.validate(H, bad).contains("tipo"), "niente vento nella r4")
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), rows).contains("schema e protocollo"), "righe r4 con lo schema r3: rifiutate")
	var r3 := [_row("sonda", true)]
	check(Misure.validate(H, r3).contains("schema e protocollo"), "righe r3 con lo schema r4: rifiutate")
	# riassunto
	var s := Misure.summarize(rows)
	check(s["sonde"]["n"] == 10 and s["sonde"]["k"] == 3, "r4: le sonde contano come prima")
	check(s["sentieri"]["mosaico"] == [4, 4] and s["mosaico_max"] == 3, "mosaico: prove della scala e gradino più alto (le prove di polarità non contano)")
	check(s["polarita"]["scuri"] == [0, 1] and s["polarita"]["chiari"] == [1, 1] and s["polarita"]["per_gradino"]["3"]["chiari"] == [1, 1], "polarità contata a parte, anche per gradino")
	check(s["mosaico"]["esito"] == "insufficiente", "poche inversioni: mosaico non ancora stimato")
	check(s["gradino_max"]["mosaico"] == 3 and s["gradino_max"].has("scaglie") and s["gradino_max"].has("movimento"),
		"0.5.9: gradino più avanzato per ciascun sentiero, per il grafico del ponte")
	# la fontana con due sessioni di fila al gradino 6 o oltre
	_clean()
	for d in ["20261005", "20261006"]:
		var rr := []
		for i in 10:
			rr.append(_row4("sonda", i < 3))
		for li in [6, 7, 6, 7, 6, 7]:
			rr.append(_row4("mosaico", li == 6, li, {"reversal": "1"}))
		for i in 30:
			rr.append(_row4("mosaico", true, 6))
		_write_rows(dir.path_join("rovine_%s_211000_mz.csv" % d), Misure.HEADER, rr)
	var hist := Misure.load_history(dir)
	check(hist.size() == 2 and hist[0]["mosaico"]["esito"] == "interno" and near(float(hist[0]["mosaico"]["indice"]), 6.5, 1e-9), "storia r4: mosaico stimato al gradino 6,5")
	var res := Misure.evaluate_pieces(hist)
	check(res["fontana"]["ok"] and not res["pozzo"]["ok"], "due sessioni di fila oltre il gradino 6: la fontana; il pozzo resta del vento")
	# storia mista r3 + r4
	_write_rows(dir.path_join("rovine_20261004_101000_r3r3.csv"), Misure.HEADER_054, _session_rows(_seq(20, 1), 3, true, 3, true))
	var full := Misure.load_history_full(dir)
	check(full["sessioni"].size() == 3 and full["esclusi"].is_empty() and int(Misure.all_probes(full["sessioni"])["n"]) == 40, "storia mista r3 e r4: tre file, sonde sommate")
	# migrazione di un profilo reale (r3, pozzo e lanterne restaurati col vento)
	var prof := {"rovine": {"protocollo": "r3", "pezzi": {"pozzo": "2026-09-29", "lanterne": "2026-09-29"}, "scaglie": {"index": 0}, "movimento": {"index": 8}}}
	check(Misure.migrate(prof) and prof["rovine"]["protocollo"] == Misure.PROTOCOL and not prof["rovine"].has("movimento") and prof["rovine"]["scaglie"]["index"] == 0, "r3 -> r5: pezzi e scaglie restano, il vento esce")
	check(Misure.restored_ids(prof) == ["pozzo", "lanterne"], "pozzo e lanterne restano restaurati")
	var st2 := Storia.new()
	st2.load_all(dir, dir, prof)
	check(st2.rovine.size() == 3, "il diario legge la storia mista")
	_clean()
	# la scala del mosaico con un osservatore simulato: si assesta vicino al suo 79%
	var m79 := 4.0 - 1.2 * Fit.phi_inv((0.79 - 0.25) / 0.72)
	var ests := []
	for sess in 40:
		var p := Ponte.new(Misure.MOSAIC_LEVELS)
		for t in 40:
			var pc := 0.25 + 0.72 * Fit.phi((4.0 - float(p.index)) / 1.2)
			p.record(rng.randf() < pc)
		var e := Ponte.estimate_from(Misure.MOSAIC_LEVELS, p.reversals)
		if e["esito"] == "interno":
			ests.append(float(e["indice"]))
	ests.sort()
	check(ests.size() >= 30, "mosaico: in 40 prove la scala si assesta quasi sempre (%d su 40)" % ests.size())
	check(ests.size() > 0 and absf(float(ests[ests.size() / 2]) - m79) < 1.0, "mosaico: gradino stimato vicino al 79%% dell'osservatore (mediana %.2f, atteso %.2f)" % [float(ests[ests.size() / 2]) if ests.size() > 0 else -1.0, m79])


# ---------------------------------------------------------------- 0.5.10: senza scaglie

func _mosaic_session(path: String, rung_lo: int, sonde_k: int) -> void:
	var rr := []
	for i in 10:
		rr.append(_row4("sonda", i < sonde_k, -1, {"version": "training-0.5.10"}))
	for li in [rung_lo, rung_lo + 1, rung_lo, rung_lo + 1, rung_lo, rung_lo + 1]:
		rr.append(_row4("mosaico", li == rung_lo, li, {"reversal": "1", "version": "training-0.5.10"}))
	for i in 30:
		rr.append(_row4("mosaico", true, rung_lo, {"version": "training-0.5.10"}))
	_write_rows(path, Misure.HEADER, rr)


func _test_senza_scaglie() -> void:
	var with_alt := 0
	for pz in Misure.PEZZI:
		if pz["tipo"] == "scaglie":
			with_alt += 1 if pz.has("alt") and pz["alt"]["tipo"] == "mosaico" else 0
	check(with_alt == 3, "0.5.10: i tre pezzi delle scaglie hanno una seconda via sul mosaico")
	var scala: Dictionary = Misure.PEZZI[0]
	check(Misure.hint(scala).contains("mosaic") and Misure.hint(scala).contains("step 4"), "il suggerimento della scala parla del mosaico al gradino 4")
	check(not Rovine._has_kind([{"kind": "sonda"}, {"kind": "mosaico"}], "scaglie") and Rovine._has_kind([{"kind": "scaglie"}], "scaglie"), "righe delle scaglie nei riepiloghi solo se ci sono prove")
	# file della 0.5.10: r4 senza scaglie, valido; le sonde contano come prima
	_clean()
	_mosaic_session(dir.path_join("rovine_20261013_201000_n1.csv"), 6, 3)
	var full := Misure.load_history_full(dir)
	check(full["sessioni"].size() == 1 and full["esclusi"].is_empty(), "file r4 senza scaglie accettato")
	var h0: Dictionary = full["sessioni"][0]
	check(int(h0["sonde"]["n"]) == 10 and h0["scaglie"].get("esito", "insufficiente") == "insufficiente", "senza scaglie: sentiero delle scaglie non informativo, sonde contate")
	# due sessioni di fila al gradino 6,5: scala e fontana sì, arco e affresco no
	_mosaic_session(dir.path_join("rovine_20261014_201000_n2.csv"), 6, 3)
	var res := Misure.evaluate_pieces(Misure.load_history(dir))
	check(res["scala"]["ok"] and res["fontana"]["ok"] and not res["arco"]["ok"] and not res["affresco"]["ok"], "mosaico al 6,5 per due sessioni: scala e fontana, non arco né affresco")
	# una sessione sola al gradino 8,5 non basta; due di fila restaurano arco e affresco
	_clean()
	_mosaic_session(dir.path_join("rovine_20261015_201000_n3.csv"), 8, 3)
	res = Misure.evaluate_pieces(Misure.load_history(dir))
	check(not res["arco"]["ok"] and res["arco"]["cur"] == 1, "una sessione al gradino 8,5: l'arco a metà")
	_mosaic_session(dir.path_join("rovine_20261016_201000_n4.csv"), 8, 3)
	res = Misure.evaluate_pieces(Misure.load_history(dir))
	check(res["arco"]["ok"] and res["affresco"]["ok"] and res["scala"]["ok"], "due sessioni al gradino 8,5: arco e affresco")
	# obiettivo "Due sentieri": mosaico stabile e almeno metà nella pietra nuda su 10 sonde
	var prof := {"rovine": {"protocollo": "r4"}}
	var st := Storia.new()
	st.load_all(dir, dir, prof)
	check(not Obiettivi.evaluate(st)["due_sentieri"]["ok"], "mosaico stabile ma 3/10 nelle sonde: niente \"Due sentieri\"")
	_mosaic_session(dir.path_join("rovine_20261017_201000_n5.csv"), 8, 5)
	st = Storia.new()
	st.load_all(dir, dir, prof)
	check(Obiettivi.evaluate(st)["due_sentieri"]["ok"], "mosaico stabile e 5/10 nelle sonde: \"Due sentieri\"")
	_clean()


# ---------------------------------------------------------------- 0.5.13: oltre la pietra nuda (r5)

func _row5(kind: String, correct: bool, li := -1, extra := {}) -> Dictionary:
	var r := _row4(kind, correct, li, extra)
	r["protocol"] = "r5"
	r["version"] = "training-0.5.13"
	r.merge(extra, true)
	return r


## Una sessione r5 con il mosaico che si assesta fra rung_lo e rung_lo + 1 (punto del ponte a rung_lo + 0,5).
func _session5(path: String, rung_lo: int, sonde_k: int) -> void:
	var rr := []
	for i in 10:
		rr.append(_row5("sonda", i < sonde_k))
	for li in [rung_lo, rung_lo + 1, rung_lo, rung_lo + 1, rung_lo, rung_lo + 1]:
		rr.append(_row5("mosaico", li == rung_lo, li, {"reversal": "1"}))
	for i in 20:
		rr.append(_row5("mosaico", true, rung_lo))
	_write_rows(path, Misure.HEADER, rr)


func _test_oltre() -> void:
	# gradini nuovi: solo la disparità, sulla griglia della Psi del test, fino a 251″
	var st: Array = Misure.MOSAIC_STEPS
	var grid := true
	for i in range(Misure.PIETRA_NUDA + 1, st.size()):
		var g := Misure.mosaic_rung(i)
		grid = grid and near(float(st[i][0]), 3.0 - 0.05 * (i - Misure.PIETRA_NUDA), 1e-9) and float(st[i][1]) == 1.0 and float(st[i][2]) == 1.0
		grid = grid and near(float(g["disparity_arcsec"]), pow(10.0, 3.0 - 0.05 * (i - Misure.PIETRA_NUDA)), 1e-6)
		for k in Misure.GEOMETRY_NORMAL:
			grid = grid and g[k] == Misure.GEOMETRY_NORMAL[k]
	check(grid, "gradini 10–21: formato normale del test, disparità 10^(3 − 0,05 k)")
	var psi_grid := true
	for i in range(Misure.PIETRA_NUDA, st.size()):
		var k := (float(st[i][0]) - 1.0) / 0.05
		psi_grid = psi_grid and near(k, roundf(k), 1e-6)
	check(psi_grid, "ogni gradino oltre la pietra nuda è un livello della griglia della Psi (10^(1 + 0,05 k))")
	check(roundi(float(Misure.mosaic_rung(21)["disparity_arcsec"])) == 251 and roundi(float(Misure.mosaic_rung(10)["disparity_arcsec"])) == 891 and Misure.last_rung() == 21,
		"dal gradino 10 (891″) al 21 (251″)")
	check(Misure.levels_for("mosaico", "r4").size() == 10 and Misure.levels_for("mosaico", "r5").size() == 22 and Misure.levels_for("polarita").size() == 22,
		"gradini per protocollo: 10 nella r4, 22 dalla r5")
	check(Misure.fmt_rung(13) == "bare stone at 631″ (step 13 of 21)" and Misure.fmt_rung(9).begins_with("bare stone (1000″") and Misure.fmt_rung(4).begins_with("step 4 of 21"),
		"descrizione dei gradini oltre la pietra nuda")
	check(near(Misure.rung_arcsec(9.0), 1000.0, 1e-6) and near(Misure.rung_arcsec(10.5), pow(10.0, 2.925), 1e-6) and Misure.rung_arcsec(8.5) == 0.0,
		"disparità a un indice frazionario, solo dalla pietra nuda in su")
	var fp := Misure.fmt_path("mosaico", {"esito": "interno", "indice": 12.5, "inversioni": 8})
	check(fp.contains("12.5 of 21") and fp.contains("~668″"), "punto del ponte oltre la pietra nuda, con la disparità (%s)" % fp)
	# la scala del gioco: 22 gradini, riparte due più in basso, e l'indicatore conosce le famiglie
	var pz := Ponte.new(Misure.MOSAIC_LEVELS)
	pz.from_dict({"index": 9}, 2)
	check(pz.index == 7 and pz.top() == 21, "profilo al gradino 9: si riparte dal 7, la scala arriva al 21")
	check(Rovine.stone_family(3) == "grosso" and Rovine.stone_family(9) == "nuda" and Rovine.stone_family(15) == "oltre", "fila delle pietre: mosaico grosso, pietra nuda, oltre")
	check(not (Rovine.S.STIM in Rovine.STONE_SHOW) and not (Rovine.S.FIX in Rovine.STONE_SHOW) and Rovine.S.FEEDBACK in Rovine.STONE_SHOW,
		"la fila delle pietre non si vede durante la croce e lo stimolo")
	# validazione r5
	var H := PackedStringArray(Misure.HEADER)
	var rows := []
	for i in 10:
		rows.append(_row5("sonda", i < 6))
	for li in [9, 10, 11, 12, 13, 21]:
		rows.append(_row5("mosaico", true, li))
	rows.append(_row5("polarita", true, 14))
	rows.append(_row5("polarita", false, 14, {"polarity": "chiari"}))
	check(Misure.validate(H, rows) == "", "file r5 accettato, con il mosaico fino al gradino 21 e le polarità oltre la pietra nuda")
	var bad := rows.duplicate(true)
	bad[12]["disparity_arcsec"] = "1000.0"
	check(Misure.validate(H, bad).contains("disparità"), "r5: un gradino oltre la pietra nuda con la disparità sbagliata è rifiutato")
	var r4 := [_row4("mosaico", true, 9), _row4("mosaico", true, 9)]
	r4[1]["level_index"] = "10"
	r4[1]["disparity_arcsec"] = "891.3"
	check(Misure.validate(H, r4).contains("fuori scala"), "r4: niente gradini oltre la pietra nuda")
	var mixed := [_row4("sonda", true), _row5("sonda", true)]
	check(Misure.validate(H, mixed).contains("protocollo"), "r4 e r5 nello stesso file: rifiutato")
	check(Misure.validate(PackedStringArray(Misure.HEADER_054), [_row5("sonda", true)]).contains("schema e protocollo"), "r5 con lo schema r3: rifiutato")
	# riassunto r5: sonde invariate, la pietra nuda del mosaico per disparità, punto del ponte oltre
	var s := Misure.summarize(rows)
	check(s["sonde"]["n"] == 10 and s["sonde"]["k"] == 6 and s["mosaico_max"] == 21, "r5: sonde contate come prima, gradino più alto 21")
	check((s["pietra_mosaico"] as Dictionary).size() == 6 and s["pietra_mosaico"]["9"] == [1, 1] and Misure.fmt_bare(s["pietra_mosaico"]).begins_with("1000″ 1/1, 891″ 1/1"),
		"mosaico nella pietra nuda, per disparità (%s)" % Misure.fmt_bare(s["pietra_mosaico"]))
	var s4 := Misure.summarize([_row4("mosaico", true, 9), _row4("mosaico", false, 8)])
	check(s4["puro"]["mosaico"] == [1, 1] and s4["pietra_mosaico"]["9"] == [1, 1], "r4: la pietra nuda resta l'ultimo gradino di quei file")
	# migrazione r4 -> r5: tutto resta, anche il gradino del mosaico
	var prof := {"rovine": {"protocollo": "r4", "pezzi": {"torre": "2026-10-15", "fontana": "2026-10-08"}, "mosaico": {"index": 9}, "sessioni": [{"mosaico_max": 9}]}}
	check(Misure.migrate(prof) and prof["rovine"]["protocollo"] == "r5" and prof["rovine"]["mosaico"]["index"] == 9 and Misure.restored_ids(prof) == ["fontana", "torre"],
		"r4 -> r5: pezzi e gradino del mosaico restano")
	# osservatorio: i pezzi nuovi
	var obs := []
	for pq in Misure.PEZZI:
		if pq.get("gruppo", "") == "osservatorio":
			obs.append(pq)
	check(obs.size() == 4 and Misure.PEZZI.size() == 12 and roundi(9.0 - float(obs[0]["limite"])) == 11 and roundi(9.0 - float(obs[3]["limite"])) == 17,
		"osservatorio: quattro pezzi, dal gradino 11 al 17")
	check(Misure.hint(obs[1]).contains("631″") and Misure.hint(obs[1]).contains("step 13 of 21"), "suggerimento dell'osservatorio in secondi d'arco: %s" % Misure.hint(obs[1]))
	# una sessione r4 ferma alla pietra nuda ("al puro") non restaura l'osservatorio
	check(Misure._path_ok({"esito": "al_puro", "valore": 0.0}, 3.0) and not Misure._path_ok({"esito": "al_puro", "valore": 0.0}, -2.0)
		and Misure._path_ok({"esito": "al_puro", "valore": -12.0}, -8.0), "al puro vale fino all'ultimo gradino del suo file")
	_clean()
	for d in ["20261020", "20261021"]:
		var rr := []
		for i in 10:
			rr.append(_row4("sonda", i < 8))
		for i in 20:
			rr.append(_row4("mosaico", true, 9))
		_write_rows(dir.path_join("rovine_%s_201000_r4p.csv" % d), Misure.HEADER, rr)
	var res := Misure.evaluate_pieces(Misure.load_history(dir))
	check(Misure.load_history(dir)[0]["mosaico"]["esito"] == "al_puro" and res["arco"]["ok"] and not res["basamento"]["ok"],
		"due sessioni r4 al puro: l'arco sì, il basamento no")
	# due sessioni r5 a 11,5: il basamento sì, il tamburo no; poi due a 13,5 anche il tamburo
	_clean()
	_session5(dir.path_join("rovine_20261022_201000_o1.csv"), 11, 6)
	res = Misure.evaluate_pieces(Misure.load_history(dir))
	check(not res["basamento"]["ok"] and res["basamento"]["cur"] == 1, "una sessione a 11,5: il basamento a metà")
	_session5(dir.path_join("rovine_20261023_201000_o2.csv"), 11, 6)
	res = Misure.evaluate_pieces(Misure.load_history(dir))
	check(res["basamento"]["ok"] and not res["tamburo"]["ok"] and res["fontana"]["ok"], "due sessioni a 11,5: il basamento (e i pezzi del mosaico di prima), non il tamburo")
	_session5(dir.path_join("rovine_20261024_201000_o3.csv"), 13, 6)
	_session5(dir.path_join("rovine_20261025_201000_o4.csv"), 13, 6)
	var hist := Misure.load_history(dir)
	res = Misure.evaluate_pieces(hist)
	check(near(float(hist[3]["mosaico"]["indice"]), 13.5, 1e-9) and res["tamburo"]["ok"] and not res["cupola"]["ok"], "due sessioni a 13,5: il tamburo, non la cupola")
	var pr := {"rovine": {"protocollo": "r5"}}
	var st2 := Storia.new()
	st2.load_all(dir, dir, pr)
	var ob := Obiettivi.evaluate(st2)
	check(ob.has("osservatorio") and not ob["osservatorio"]["ok"] and ob["osservatorio"]["cur"] == 2, "obiettivo dell'osservatorio: due pezzi su quattro")
	_session5(dir.path_join("rovine_20261026_201000_o5.csv"), 17, 6)
	_session5(dir.path_join("rovine_20261027_201000_o6.csv"), 17, 6)
	st2 = Storia.new()
	st2.load_all(dir, dir, pr)
	ob = Obiettivi.evaluate(st2)
	check(ob["osservatorio"]["ok"], "due sessioni a 17,5: tutti e quattro i pezzi, obiettivo dell'osservatorio")
	# una sessione r4 e una r5 nella stessa storia: sonde sommate, nessun file escluso
	_write_rows(dir.path_join("rovine_20261019_181143_r4.csv"), Misure.HEADER, [_row4("sonda", true), _row4("mosaico", true, 9)])
	var full := Misure.load_history_full(dir)
	check(full["esclusi"].is_empty() and full["sessioni"].size() == 7, "storia mista r4 e r5: tutti i file validi")
	_clean()
	# niente più evidenza nel riepilogo, e niente numeri traboccati
	var src := FileAccess.get_file_as_string("res://scripts/training/rovine.gd")
	check(not src.contains("Evidenza contro il caso"), "riepilogo delle rovine senza l'evidenza contro il caso")
	var Menu = load("res://scripts/training/ui/menu.gd")
	check(Menu.fmt_e(1e30) == "over 100" and Menu.fmt_e(3.42) == "3.4", "evidenza nel menu: niente numeri traboccati")
