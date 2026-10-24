extends SceneTree
## Test del bosco delle lucciole: geometria (disparità dalla profondità), scala e rotelle,
## traguardi e profilo, rotelle applicate agli stimoli (grandezza angolare, luce, parallasse),
## sonde, occlusione, CSV.
## Uso: godot --headless --path . --xr-mode off --script res://tests/training_test.gd

const Geometry := preload("res://scripts/training/geometry.gd")
const Difficulty := preload("res://scripts/training/difficulty.gd")
const Progress := preload("res://scripts/training/progress.gd")
var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if OS.get_environment("VERBOSE_TEST") != "":
		print(("ok   " if cond else "NO   ") + what)
	if not cond:
		failures += 1
		print("FAIL: " + what)


func _initialize() -> void:
	# --- geometria: la disparità ricalcolata coincide con quella voluta
	var el := Vector3(-0.0315, 1.6, 0)
	var er := Vector3(0.0315, 1.6, 0)
	var cyc := (el + er) * 0.5
	var worst := 0.0
	for target in [20.0, 100.0, 400.0, 1500.0, 3981.0]:
		for base in [0.40, 0.475, 0.55]:
			for az in [[-12.0, 12.0], [-5.0, 5.0], [-8.0, 8.0]]:
				var dn := Geometry.direction(Vector3.FORWARD, az[0], -22.0)
				var df := Geometry.direction(Vector3.FORWARD, az[1], -22.0)
				var d: Array = Geometry.solve_pair(cyc, dn, df, base, target, el, er)
				var got := Geometry.relative_disparity_arcsec(cyc + dn * d[0], cyc + df * d[1], el, er)
				worst = maxf(worst, absf(got - target))
				check(d[0] < d[1], "la vicina è più vicina")
	check(worst < 0.5, "disparità ricalcolata entro 0,5″ (scarto massimo %.3f″)" % worst)
	# ordine di grandezza: 400″ a 50 cm con IPD 63 mm ~ 7,7 mm di profondità
	var d400: Array = Geometry.solve_pair(cyc, Vector3.FORWARD, Vector3.FORWARD, 0.5, 400.0, el, er)
	check(absf((d400[1] - d400[0]) - 0.0077) < 0.0006, "400″ a 50 cm ≈ 7,7 mm (%.2f mm)" % ((d400[1] - d400[0]) * 1000))
	var ecc := Geometry.relative_disparity_arcsec(cyc + Geometry.direction(Vector3.FORWARD, -5.0, -22.0) * 0.5,
		cyc + Geometry.direction(Vector3.FORWARD, 12.0, -22.0) * 0.5, el, er)
	check(ecc > 300.0, "a pari distanza l'eccentricità crea disparità (%.0f″): per questo gli azimut sono simmetrici" % ecc)
	var dir := Geometry.direction(Vector3.FORWARD, 0.0, -22.0)
	check(absf(rad_to_deg(asin(dir.y)) + 22.0) < 1e-4, "elevazione")
	# --- 0.5.4: postura della testa (solo registrazione)
	check(absf(Geometry.head_roll_deg(el, er)) < 1e-6, "testa dritta: rollio 0")
	var tilt_r := Basis(Vector3.BACK, deg_to_rad(-10.0))      # rotazione attorno all'asse di vista: destra in basso
	var roll_r := Geometry.head_roll_deg(cyc + tilt_r * (el - cyc), cyc + tilt_r * (er - cyc))
	check(absf(roll_r - 10.0) < 1e-3, "testa inclinata verso la spalla destra: rollio +10° (%.3f°)" % roll_r)
	check(absf(Geometry.head_pitch_deg(Geometry.direction(Vector3.FORWARD, 0.0, -12.0)) + 12.0) < 1e-3, "testa che guarda in basso di 12°: beccheggio -12°")

	# --- scala: prima le rotelle, nell'ordine, poi la disparità
	var df := Difficulty.new()
	df.level = 3.3
	for i in 3:
		df.record(true)
	check(is_equal_approx(df.wheels["luce"], 0.8) and df.level == 3.3, "3 giuste: via 0,2 di luce, disparità ferma")
	for i in 3 * 16:
		df.record(true)
	check(df.wheels_off() and df.level < 3.3, "a rotelle finite scende la disparità")
	var lv := df.level
	df.record(false)
	check(df.level > lv, "una sbagliata: disparità su")
	var dmax := Difficulty.new()
	dmax.level = Difficulty.L_MAX
	dmax.wheels = {"luce": 0.0, "misura": 0.0, "parallasse": 0.0}
	dmax.record(false)
	check(is_equal_approx(dmax.wheels["parallasse"], 0.2) and dmax.wheels["luce"] == 0.0, "al massimo tornano le rotelle, dall'ultima tolta")
	var dser := Difficulty.new()
	dser.from_dict({"level": 2.7, "wheels": {"luce": 0.0, "misura": 0.4, "parallasse": 1.0}, "settled": true})
	check(dser.level == 2.7 and dser.wheels["misura"] == 0.4 and dser.settled, "scala salvata e riletta")
	# convergenza con un osservatore simulato (soglia 400″): la scala 3/1 punta al ~79%
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ths := []
	for run in 40:
		var s := Difficulty.new()
		s.level = 3.5
		for t in 200:
			var p_st := 0.5 + 0.48 * (1.0 - exp(-pow(pow(10.0, s.level) / 400.0, 2.0)))
			var p_cue := 0.5 + 0.45 * maxf(s.wheels["luce"], maxf(s.wheels["misura"], s.wheels["parallasse"]))
			s.record(rng.randf() < maxf(p_st, p_cue))
		if s.threshold_arcsec() > 0:
			ths.append(s.threshold_arcsec())
	ths.sort()
	var med: float = ths[ths.size() / 2] if not ths.is_empty() else -1.0
	check(ths.size() >= 38 and med > 300 and med < 500, "soglia stimata vicino al 79%% dell'osservatore (~390″): mediana %.0f su %d" % [med, ths.size()])

	# --- traguardi e profilo
	var pr := Progress.new()
	pr.path = ProjectSettings.globalize_path("user://profilo_test.json")
	check(pr.check_unlocks(false, -1.0).is_empty(), "all'inizio nessun traguardo nuovo")
	pr.data["catture"] = 150
	var got_ids := []
	for s in pr.check_unlocks(true, 550.0):
		got_ids.append(s["id"])
	check(got_ids == ["ambra", "brina", "crepuscolo", "lunare"], "traguardi: catture, senza rotelle, soglie (%s)" % str(got_ids))
	check(pr.save(), "profilo salvato")
	var pr2 := Progress.new()
	pr2.load_from(pr.path)
	check(pr2.data["specie"].size() == 5 and int(pr2.data["catture"]) == 150, "profilo riletto")
	pr2.add_seconds(100.0, "2026-10-03")
	pr2.add_seconds(50.0, "2026-10-03")
	pr2.add_seconds(10.0, "2026-10-04")
	check(is_equal_approx(float(pr2.data["secondi_oggi"]), 10.0), "secondi di oggi azzerati al cambio di data")
	DirAccess.remove_absolute(pr.path)

	# --- scale per lato con un osservatore sbilanciato (la destra sembra più vicina di 300″,
	# sensibilità 500″ al 79%): la media delle due soglie stima la sensibilità, la semidifferenza lo sbilanciamento
	var Bosco = load("res://scripts/training/bosco.gd")
	var sens := []
	var biases := []
	for run in 30:
		var ds := [Difficulty.new(), Difficulty.new()]
		for dd in ds:
			dd.level = 3.3
			dd.wheels = {"luce": 0.0, "misura": 0.0, "parallasse": 0.0}
		for t in 300:
			var near := rng.randi_range(0, 1)
			var dval := pow(10.0, ds[near].level)
			var p_right: float = Bosco._phi(((dval if near == 1 else -dval) + 300.0) / (500.0 / 0.806))
			var right := rng.randf() < p_right
			ds[near].record(right == (near == 1))
		var sx: float = ds[0].threshold_arcsec()
		var dx: float = ds[1].threshold_arcsec()
		if sx > 0 and dx > 0:
			sens.append(0.5 * (sx + dx))
			biases.append(0.5 * (sx - dx))
	sens.sort()
	biases.sort()
	var ms: float = sens[sens.size() / 2]
	var mb: float = biases[biases.size() / 2]
	check(sens.size() >= 28 and ms > 420 and ms < 620 and mb > 200 and mb < 400, "scale per lato: sensibilità %.0f″ (vera ~500), sbilanciamento %.0f″ (vero 300)" % [ms, mb])
	# stima dello zero su dati simulati (zero 600″, sigma 500″, come nella seconda sessione)
	var sim := []
	for t in 260:
		var dd: float = [0.0, 100.0, 300.0, 800.0, 1200.0][t % 5]
		var sd: float = dd if rng.randf() < 0.5 else -dd
		sim.append([sd, rng.randf() < Bosco._phi((sd + 600.0) / 500.0)])
	var Fit = load("res://scripts/training/fit.gd")
	var fz: Dictionary = Fit.fit(sim)
	check(fz["stimabile"] and absf(fz["zero"] - 600.0) < 200.0 and fz["soglia79_ic"][0] <= 403.0 and fz["soglia79_ic"][1] >= 403.0,
		"stima probit: zero %.0f″ (vero 600), soglia %.0f″ con intervallo che contiene 403″" % [fz.get("zero", 0.0), fz.get("soglia79", 0.0)])
	check(not Fit.fit(sim.slice(0, 20))["stimabile"], "stima solo con almeno 40 risposte")
	# 0.5.9: lapse fisso a 0, anche con il 15% di risposte a caso (prima avrebbe scelto 0,1)
	var simlap := []
	for t in 400:
		var dl: float = [0.0, 100.0, 300.0, 800.0, 1200.0, 2000.0][t % 6]
		var sl: float = dl if rng.randf() < 0.5 else -dl
		var yl: bool = rng.randf() < 0.5 if rng.randf() < 0.15 else rng.randf() < Bosco._phi((sl + 300.0) / 400.0)
		simlap.append([sl, yl])
	var fl: Dictionary = Fit.fit(simlap)
	check(Fit.LAPSES == [0.0] and fl["stimabile"] and float(fl["lapse"]) == 0.0,
		"0.5.9: lapse fisso a 0 (stima %s, lapse %s)" % [str(fl.get("stimabile", false)), str(fl.get("lapse", "-"))])
	# 0.5.9, review dell'8/10 (C4): con il lapse fisso l'AIC conta 2 parametri contro 1. Controesempio di Astra:
	# 16 risposte per disparità, destra 5, 6, 8, 10, 11 su -1000…+1000″: delta AIC 4,547, stimabile.
	var aic_d := []
	var rights := [5, 6, 8, 10, 11]
	for j in 5:
		for t in 16:
			aic_d.append([[-1000.0, -500.0, 0.0, 500.0, 1000.0][j], t < rights[j]])
	var fa: Dictionary = Fit.fit(aic_d)
	check(absf(float(fa.get("delta_aic", 0.0)) - 4.5474) < 0.01 and fa["stimabile"],
		"0.5.9: AIC con 2 parametri contro 1 (delta %.4f, stimabile %s)" % [float(fa.get("delta_aic", 0.0)), str(fa["stimabile"])])
	# 0.3: intervallo dello zero, copertura su 40 simulazioni
	var cover := 0
	var n_est := 0
	for run in 40:
		var simz := []
		for t in 200:
			var dz: float = [0.0, 300.0, 700.0, 1500.0][t % 4]
			var sz: float = dz if rng.randf() < 0.5 else -dz
			simz.append([sz, rng.randf() < Bosco._phi((sz + 600.0) / 500.0)])
		var fr: Dictionary = Fit.fit(simz)
		if fr["stimabile"]:
			n_est += 1
			if fr["zero_ic"][0] <= 600.0 and fr["zero_ic"][1] >= 600.0:
				cover += 1
	check(n_est >= 38 and cover >= int(0.85 * n_est), "intervallo dello zero: contiene il vero in %d casi su %d" % [cover, n_est])
	# 0.3: scala dei fuochi fatui con un osservatore che segue la disparità con P = Phi(2 - 3c)
	var CueSt = load("res://scripts/training/cue_staircase.gd")
	var cts := []
	for run in 30:
		var cs = CueSt.new()
		for t in 300:
			cs.record(rng.randf() < Bosco._phi(2.0 - 3.0 * cs.c))
		if cs.threshold() > 0.0:
			cts.append(cs.threshold())
	cts.sort()
	check(cts.size() >= 28 and absf(cts[cts.size() / 2] - 0.40) < 0.1, "scala dei fatui: resistenza %.2f (vera 0,40)" % (cts[cts.size() / 2] if not cts.is_empty() else -1.0))
	var cs_max = CueSt.new()
	cs_max.c = 1.0
	for t in 9:
		cs_max.record(true)
	check(cs_max.threshold() == 1.0 and cs_max.c == 1.0, "chi resiste anche all'inganno più forte: resistenza 1")
	var cs_d = CueSt.new()
	cs_d.from_dict(cs_max.to_dict())
	check(cs_d.c == 1.0 and cs_d.at_max == cs_max.at_max, "scala dei fatui salvata e riletta")
	# controprove della review (T2): senza informazione la stima dev'essere "non stimabile"
	var sep := []
	for i in 60:
		var sd: float = [1000.0, 2000.0, 3000.0][i % 3] * (1.0 if i % 2 == 0 else -1.0)
		sep.append([sd, sd > 0])
	check(not Fit.fit(sep)["stimabile"], "tutte giuste a disparità grandi: non stimabile (%s)" % Fit.fit(sep)["motivo"])
	var tw := []
	for i in 40:
		tw.append([0.0, true])
	check(not Fit.fit(tw)["stimabile"], "gemelle sempre a destra: non stimabile")
	var flat := []
	for i in 120:
		var sd: float = [100.0, 400.0, 1500.0][i % 3] * (1.0 if i % 2 == 0 else -1.0)
		flat.append([sd, rng.randf() < 0.7])
	check(not Fit.fit(flat)["stimabile"], "scelte indipendenti dalla disparità: non stimabile (%s)" % Fit.fit(flat)["motivo"])
	check(absf(Fit.phi_inv(0.79) - 0.806421) < 1e-4, "quantile normale")
	check(absf(Bosco._phi(0.0) - 0.5) < 1e-6 and absf(Bosco._phi(1.0) - 0.841345) < 1e-5, "funzione di ripartizione normale")

	# --- la scena: rotelle applicate agli stimoli
	var bosco: Node = load("res://scenes/training.tscn").instantiate()
	root.add_child(bosco)
	await process_frame
	check(bosco.state == bosco.S.INTRO, "si parte dall'introduzione")
	check(bosco.flies[0].visible and absf(bosco.flies[0].position.y - bosco.flies[1].position.y) < 1e-6, "anteprima dell'altezza nell'introduzione")
	bosco.elev_center = -12.0            # il profilo di prova conserva l'altezza fra un'esecuzione e l'altra
	var e0: float = bosco.elev_center
	bosco._change_elevation(2.0)
	check(is_equal_approx(bosco.elev_center, e0 + 2.0) and is_equal_approx(float(bosco.prog.data["elevazione"]), e0 + 2.0), "altezza regolabile e salvata")
	# 0.2.2: musica
	check(bosco.music_names == ["01_evening_focus", "02_evening_focus_1"] and bosco.music_tracks.size() == 2, "due brani letti dalla cartella musica, in ordine (%s)" % str(bosco.music_names))
	check(bosco.music_tracks.size() == 2 and bosco.music_tracks[0].get_length() > 350.0 and bosco.music_tracks[1].get_length() > 350.0, "brani da circa 6 minuti")
	check(bosco.music.get_class() == "AudioStreamPlayer", "musica non posizionale (uguale per le due orecchie)")
	var vol0: float = bosco.music_volume
	bosco._change_music(-1.0)
	check(not bosco._music_on() and not bosco.music.playing and bosco.label.text.contains("Music: off"), "volume a zero: musica spenta")
	bosco._music_start_night()
	check(not bosco.music.playing, "musica spenta: la notte parte senza")
	bosco._change_music(0.3)
	check(bosco._music_on() and bosco.music.playing and is_equal_approx(float(bosco.prog.data["musica_volume"]), 0.3), "volume regolabile, salvato, con anteprima")
	bosco.music_volume = vol0
	bosco._load_difficulty({"level": 3.2, "wheels": {"luce": 0.0, "misura": 0.0, "parallasse": 0.0}, "settled": true})
	check(is_equal_approx(bosco.diffs[0].level, 3.4) and is_equal_approx(bosco.diffs[1].level, 3.4), "profilo della 0.1: una scala sola diventa due, con il riscaldamento")
	for dd in bosco.diffs:
		dd.wheels = {"luce": 0.0, "misura": 0.0, "parallasse": 0.0}
		dd.level = 2.6
	bosco.trial = 0
	bosco.label.visible = false
	bosco._next_trial()
	check(absf(bosco.cur["elev"] - bosco.elev_center) <= bosco.ELEV_HALF + 1e-6, "elevazione attorno al centro scelto")
	check(absf(bosco.cur["az"][0] + bosco.cur["az"][1]) < 1e-9 and absf(bosco.cur["az"][1]) >= bosco.AZ_MIN and absf(bosco.cur["az"][1]) <= bosco.AZ_MAX, "azimut simmetrici fra 3,5° e 7°")
	var eyes: Array = bosco._eyes()
	var c: Vector3 = (eyes[0] + eyes[1]) * 0.5
	var ang := []
	for i in 2:
		ang.append(bosco.flies[i].scale.x / (bosco.flies[i].position - c).length())
	check(absf(ang[0] - ang[1]) < 1e-6, "senza rotella della misura: stessa grandezza angolare")
	check(bosco.cur_colors[0] == bosco.cur_colors[1], "senza rotella della luce: stessa luminosità")
	check(absf(bosco.cur["geom"] - bosco.cur["target"]) < 0.5, "disparità della prova ricalcolata dalla geometria")
	check(bosco.flies[0].position.distance_to(bosco.flies[1].position) > 2.0 * bosco.TOUCH_R, "zone di tocco separate")
	var before: Vector3 = bosco.flies[0].position
	bosco.camera.position += Vector3(0.05, 0.0, 0.0)
	bosco._follow_head()
	check((bosco.flies[0].position - before).distance_to(Vector3(0.05, 0, 0)) < 1e-6, "senza rotella della parallasse: le lucciole seguono la testa")
	bosco.camera.position -= Vector3(0.05, 0.0, 0.0)
	# review T1: senza la rotella della parallasse anche le rotazioni della testa lasciano la disparità invariata
	bosco._follow_head()
	var rl0: float = bosco._rl_now()
	bosco.camera.rotation_degrees = Vector3(0, 5, 0)
	bosco._follow_head()
	check(absf(bosco._rl_now() - rl0) < 0.5, "testa ruotata di 5°: disparità invariata (%.1f″ → %.1f″)" % [rl0, bosco._rl_now()])
	check(absf(bosco.head_max_rot - 5.0) < 0.1, "rotazione della testa registrata")
	bosco.camera.rotation_degrees = Vector3.ZERO
	# review T1: testa inclinata lateralmente, gemelle a disparità zero e disparità richiesta ottenuta
	for roll in [5.0, 15.0]:
		bosco.camera.rotation_degrees = Vector3(0, 0, roll)
		bosco.trial = 4
		bosco._next_trial()
		check(bosco.cur["kind"] == "gemelle" and bosco.cur["geom_ok"] and absf(bosco.cur["rl_spawn"]) < 0.5, "testa inclinata di %d°: gemelle a %.2f″" % [roll, bosco.cur["rl_spawn"]])
		check(absf(float(bosco.cur["roll"]) + roll) < 0.01, "testa inclinata di %d° verso la spalla sinistra: rollio registrato %.2f°" % [roll, bosco.cur["roll"]])
		for dd in bosco.diffs:
			dd.level = log(40.0) / log(10.0)
		bosco.trial = 1
		bosco._next_trial()
		check(bosco.cur["geom_ok"] and absf(bosco.cur["geom"] - 40.0) < 0.5, "testa inclinata di %d°: 40″ richiesti, %.1f″ ottenuti" % [roll, bosco.cur["geom"]])
		for dd in bosco.diffs:
			dd.level = 2.6
	bosco.camera.rotation_degrees = Vector3.ZERO
	for dd in bosco.diffs:
		dd.wheels = {"luce": 1.0, "misura": 1.0, "parallasse": 1.0}
	bosco.trial = 1
	bosco._next_trial()
	var n: int = bosco.cur["near"]
	var ang_n: float = bosco.flies[n].scale.x / (bosco.flies[n].position - c).length()
	var ang_f: float = bosco.flies[1 - n].scale.x / (bosco.flies[1 - n].position - c).length()
	check(ang_n > ang_f and bosco.cur_colors[n].g > bosco.cur_colors[1 - n].g, "con le rotelle la vicina è più grande e più luminosa")
	before = bosco.flies[0].position
	bosco.camera.position += Vector3(0.05, 0.0, 0.0)
	bosco._follow_head()
	check(bosco.flies[0].position.distance_to(before) < 1e-6, "con la rotella della parallasse: lucciole ferme nel mondo")
	bosco.camera.position -= Vector3(0.05, 0.0, 0.0)
	# risposte: ciascuna aggiorna solo la scala del proprio lato
	for dd in bosco.diffs:
		dd.wheels = {"luce": 0.0, "misura": 0.0, "parallasse": 0.0}
		dd.level = 2.6
	bosco.trial = 1
	bosco._next_trial()
	n = bosco.cur["near"]
	bosco.state = bosco.S.WAIT
	bosco.cur["hand"] = "test"
	bosco._answer(1 - n)
	check(bosco.diffs[n].level > 2.6 and is_equal_approx(bosco.diffs[1 - n].level, 2.6), "l'errore sposta solo la scala del proprio lato")
	check(bosco.by_side[n] == [0, 1], "conteggio per lato")
	# review T3: i punti non dipendono dalla disparità né dal lato
	bosco.combo = 0
	bosco.diffs[0].level = 3.0
	bosco.diffs[1].level = 1.8
	var pts := []
	for side in 2:
		bosco.trial = 1
		bosco._next_trial()
		bosco.cur["near"] = side
		bosco.cur["level"] = bosco.diffs[side].level
		bosco.state = bosco.S.WAIT
		var sc0: int = bosco.score
		bosco.combo = 0
		bosco._answer(side)
		pts.append(bosco.score - sc0)
	check(pts[0] == pts[1], "stessi punti a sinistra a 1000″ e a destra a 63″ (%s)" % str(pts))
	for dd in bosco.diffs:
		dd.level = 2.6
	# sonda
	bosco.trial = 7
	bosco._next_trial()
	check(bosco.cur["kind"] == "sonda" and bosco.cur["w"]["luce"] == 0.0, "una prova su 8 è una sonda senza rotelle")
	check((bosco.fly_mats[0][0] as StandardMaterial3D).no_depth_test, "le lucciole si disegnano sopra la mano (niente occlusione)")
	# gemelle: stessa distanza, stessa grandezza; la risposta non muove le scale
	var lvs := [bosco.diffs[0].level, bosco.diffs[1].level]
	bosco.trial = 4
	bosco._next_trial()
	check(bosco.cur["kind"] == "gemelle" and absf(bosco.cur["delta"]) < 1e-5 and absf(bosco.cur["geom"]) < 0.5, "gemelle alla stessa distanza (disparità %.2f″)" % bosco.cur["geom"])
	bosco.state = bosco.S.WAIT
	bosco.cur["hand"] = "test"
	bosco._answer(1)
	check(bosco.twins == [1, 1] and bosco.diffs[0].level == lvs[0] and bosco.diffs[1].level == lvs[1], "gemelle contate, scale ferme")
	# i traguardi di soglia non scattano a metà sessione, anche con una stima bassa
	bosco.diffs[0].reversals = [2.5, 2.4, 2.5, 2.4]
	bosco.diffs[1].reversals = [2.5, 2.4, 2.5, 2.4]
	bosco.trial = 1
	bosco._next_trial()
	bosco.state = bosco.S.WAIT
	bosco._answer(bosco.cur["near"])
	check(not bosco.prog.unlocked("lunare") and not bosco.prog.unlocked("fantasma"), "niente traguardi di soglia a metà sessione")
	var th: Dictionary = bosco.thresholds()
	check(th["media"] > 0 and is_equal_approx(th["sbilanciamento"], 0.0), "soglie per lato combinate")
	# review T5: riscontro e intervalli contano nel tempo attivo
	var ps0: float = bosco.play_seconds
	var ss0: float = bosco.stim_seconds
	bosco.state = bosco.S.FEEDBACK
	bosco.timer = 10.0
	bosco._process(0.7)
	bosco.state = bosco.S.ITI_WAIT
	bosco.timer = 10.0
	bosco._process(0.35)
	check(absf(bosco.play_seconds - ps0 - 1.05) < 1e-6 and bosco.stim_seconds == ss0, "riscontro e intervallo contano nel tempo attivo, non in quello di stimolo")
	# pausa quando il visore perde il fuoco
	bosco.trial = 1
	bosco._next_trial()
	bosco._on_focus_lost()
	check(bosco.state == bosco.S.PAUSED and not bosco.flies[0].visible and bosco.label.visible, "visore tolto: pausa")
	check(bosco.music.stream_paused, "visore tolto: musica in pausa")
	bosco._confirm()
	check(bosco.state == bosco.S.ITI_WAIT, "grilletto: si riprende")
	check(not bosco.music.stream_paused, "grilletto: la musica riprende")
	# scaletta della notte (0.5.10: ordine mescolato senza ripetizioni, coda nel profilo)
	bosco.prog.data["musica_coda"] = {}
	bosco.ritmo = ""
	bosco._music_start_night()
	var first_name: String = bosco.music_last
	check(bosco.music.playing and bosco.music_key == "" and first_name in bosco.music_names, "senza cartelle per tipo di notte: brani della cartella musica (%s)" % first_name)
	check(bosco.prog.data["musica_coda"]["base"].size() == 1, "la coda resta nel profilo")
	bosco.block_played = 100.0
	bosco._on_music_finished()
	var second_name: String = bosco.music_last
	check(second_name != first_name and second_name in bosco.music_names, "finito un brano parte l'altro: niente ripetizioni finché non sono passati tutti")
	bosco.block_played = bosco.block_seconds - 5.0
	bosco._on_music_finished()
	check(bosco.music_last == second_name, "a pochi secondi dalla fine della notte non parte un brano nuovo")
	bosco.block_played = 100.0
	bosco._on_music_finished()
	check(bosco.music_last != second_name, "coda finita: si rimescola senza ripetere subito l'ultimo")
	bosco.block_played = 0.0
	# 0.5.10: notti d'istinto e riflessive
	var today := Time.get_date_string_from_system()
	var rit0 = bosco.prog.data.get("ritmo", {})
	bosco.prog.data["ritmo"] = {}
	check(bosco._ritmo_prossimo() == "istinto", "senza storia si parte da una notte d'istinto")
	bosco.prog.data["ritmo"] = {"data": today, "primo": "istinto", "notti": 1}
	check(bosco._ritmo_prossimo() == "riflessiva", "dopo una notte d'istinto, nello stesso giorno, una riflessiva")
	bosco.prog.data["ritmo"] = {"data": today, "primo": "istinto", "notti": 2}
	check(bosco._ritmo_prossimo() == "istinto", "poi di nuovo d'istinto")
	bosco.prog.data["ritmo"] = {"data": "2000-01-01", "primo": "istinto", "notti": 2}
	check(bosco._ritmo_prossimo() == "riflessiva", "un giorno nuovo comincia con l'altro tipo")
	bosco._inizia_ritmo()
	check(bosco.ritmo == "riflessiva" and bosco.prog.data["ritmo"]["data"] == today and bosco.prog.data["ritmo"]["primo"] == "riflessiva" and int(bosco.prog.data["ritmo"]["notti"]) == 1, "inizio della notte: tipo e conto del giorno nel profilo")
	bosco._inizia_ritmo()
	check(bosco.ritmo == "istinto" and int(bosco.prog.data["ritmo"]["notti"]) == 2, "sessione spezzata in più ingressi: il conto prosegue")
	bosco._update_hud()
	check(bosco.hud.text.contains("instinct · night"), "il tipo di notte in alto (%s)" % bosco.hud.text)
	check(bosco._rest_text().contains("Next night: REFLECTIVE NIGHT"), "nella pausa, la consegna della notte dopo")
	bosco.ritmo_arg = "riflessiva"
	check(bosco._ritmo_prossimo() == "riflessiva", "--ritmo forza il tipo")
	bosco._inizia_ritmo()
	check(int(bosco.prog.data["ritmo"]["notti"]) == 2, "il tipo forzato non entra nel conto del giorno")
	bosco.ritmo_arg = "no"
	check(bosco._ritmo_prossimo() == "", "--ritmo=no: notti senza tipo")
	bosco.ritmo_arg = ""
	bosco.lampo_mode = true
	check(bosco._ritmo_prossimo() == "", "nel lampo niente tipo di notte")
	bosco.lampo_mode = false
	# 0.5.10: musica per tipo di notte, in una cartella di prova
	# 0.6.3: lo stato della cartella vera si confronta con quello di prima (dal 13/10 istinto/ e riflessiva/ hanno brani)
	var n_tracks0: int = bosco.music_tracks.size()
	var n_ist0: int = bosco.music_sets["istinto"]["tracks"].size()
	var mdir := "user://musica_prova"
	for sub in ["", "/istinto", "/riflessiva"]:
		DirAccess.make_dir_recursive_absolute(mdir + sub)
	var b1 := FileAccess.get_file_as_bytes("res://musica/01_evening_focus.mp3")
	var b2 := FileAccess.get_file_as_bytes("res://musica/02_evening_focus_1.mp3")
	for pair in [["/istinto/a.mp3", b1], ["/istinto/b.mp3", b2], ["/riflessiva/c.mp3", b2], ["/leggimi.txt", PackedByteArray([65])]]:
		var fw := FileAccess.open(mdir + pair[0], FileAccess.WRITE)
		fw.store_buffer(pair[1])
		fw.close()
	bosco.music_dir = mdir
	bosco._load_music()
	check(bosco.music_tracks.is_empty() and bosco.music_sets["istinto"]["names"] == ["a", "b"] and bosco.music_sets["riflessiva"]["names"] == ["c"], "brani letti dalle cartelle dei due tipi di notte")
	bosco.prog.data["musica_coda"] = {}
	bosco.ritmo = "riflessiva"
	bosco._music_start_night()
	check(bosco.music_key == "riflessiva" and bosco.music_last == "c", "notte riflessiva: musica riflessiva")
	bosco.ritmo = "istinto"
	bosco._music_start_night()
	check(bosco.music_key == "istinto" and bosco.music_last in ["a", "b"] and bosco.prog.data["musica_coda"]["istinto"].size() == 1, "notte d'istinto: musica d'istinto, coda propria")
	check(bosco._music_line().contains("2 tracks for instinct nights") and bosco._music_line().contains("1 for reflective nights"), "l'introduzione conta i brani per tipo (%s)" % bosco._music_line())
	bosco.ritmo = ""
	bosco._music_start_night()
	check(bosco.music_key == "istinto", "senza tipo e senza brani nella cartella musica: si usa una cartella con brani")
	bosco.music.stop()
	for f in ["/istinto/a.mp3", "/istinto/b.mp3", "/riflessiva/c.mp3", "/leggimi.txt"]:
		DirAccess.remove_absolute(mdir + f)
	bosco.music_dir = bosco.MUSIC_DIR
	bosco._load_music()
	check(bosco.music_tracks.size() == n_tracks0 and bosco.music_sets["istinto"]["tracks"].size() == n_ist0, "cartella della musica ripristinata")
	bosco.prog.data["ritmo"] = rit0
	bosco.ritmo = ""
	# 0.5.11: tacche della bacchetta (sensibilità della notte in corso)
	check(bosco.tacche_accese(700.0, 0) == 0, "700″: nessuna tacca")
	check(bosco.tacche_accese(620.0, 0) == 0 and bosco.tacche_accese(600.0, 0) == 1, "isteresi: 620″ non accende la tacca dei 631″, 600″ sì")
	check(bosco.tacche_accese(226.0, 0) == 5, "226″ (la notte riflessiva del 15/10): 5 tacche, fino a 251″")
	check(bosco.tacche_accese(255.0, 5) == 5 and bosco.tacche_accese(260.0, 5) == 4, "isteresi: a 255″ la tacca dei 251″ resta accesa, a 260″ si spegne")
	check(bosco.tacche_accese(190.0, 5) == 6 and bosco.tacche_accese(120.0, 0) == 8, "sotto i 200″ la prima verde, sotto i 126″ tutte")
	check(bosco.tacche_accese(-1.0, 3) == 3, "senza stima le tacche restano come sono")
	# 0.5.12: mezze tacche (15 livelli, isteresi 2%), stima ogni 5 prove, messaggio solo per una tacca intera nuova
	check(bosco.MEZZE.size() == 15 and bosco.MEZZE[0] == 631.0 and bosco.MEZZE[14] == 126.0, "0.5.12: 15 mezze tacche da 631″ a 126″")
	var pari_ok := true
	for i in bosco.TACCHE.size():
		pari_ok = pari_ok and bosco.MEZZE[2 * i] == bosco.TACCHE[i]
	check(pari_ok, "le mezze tacche di posto pari sono le tacche intere della 0.5.11")
	check(bosco.mezze_accese(620.0, 0) == 0 and bosco.mezze_accese(615.0, 0) == 1, "isteresi del 2%: 620″ non accende la prima, 615″ sì")
	check(bosco.mezze_accese(422.0, 0) == 4 and bosco.intere(4) == 2, "422″ (la notte d'istinto del 16/10): 4 mezze, 2 tacche e mezza")
	check(bosco.mezze_accese(312.0, 0) == 6 and bosco.intere(6) == 3, "312″ (la notte riflessiva del 16/10): 6 mezze, 3 tacche e mezza")
	check(bosco.mezze_accese(226.0, 0) == 9 and bosco.intere(9) == 5, "226″ (la riflessiva del 15/10): 9 mezze, 5 tacche intere")
	check(bosco.mezze_accese(253.0, 9) == 9 and bosco.mezze_accese(258.0, 9) == 8, "isteresi: a 253″ la tacca dei 251″ resta, a 258″ scende a metà")
	check(bosco.mezze_accese(120.0, 0) == 15 and bosco.intere(15) == 8 and bosco.mezze_accese(-1.0, 7) == 7, "sotto i 126″ tutte; senza stima invariate")
	var ctrl_f := XRController3D.new()
	bosco.add_child(ctrl_f)
	var nb0: int = bosco.wand_beads.size()
	bosco._make_wand(ctrl_f)
	var beads_f: Array = bosco.wand_beads[nb0]
	check(beads_f.size() == 8 and beads_f[0].material_override == bosco.bead_mats["spenta"] and beads_f[5].material_override == bosco.bead_mats["meta_spenta"],
		"bacchetta: 8 tacche spente, dalla sesta (200″) verdi scure")
	# 0.5.14: stima della bacchetta con lo zero per blocco
	var dati_b := []
	for i in 160:
		var d_b := float((i * 7919) % 1201 - 600)
		var z_b := 300.0 if i < 80 else -300.0          # lo zero si sposta di 600″ a metà
		var y_b := d_b + z_b > 0.0
		if i % 9 == 0:
			y_b = not y_b                                # qualche errore, niente separazione
		dati_b.append([d_b, y_b])
	var fb1: float = bosco.Fit.fit_bacchetta(dati_b, 380.0, 40)
	check(absf(fb1 - 340.3) < 1.0, "0.5.14: fit_bacchetta uguale alla replica Python (analisi/2026-10-20/bacchetta2.py): %.1f″" % fb1)
	var fl1: Dictionary = bosco.Fit.fit(dati_b)
	check(not fl1.get("stimabile", false) or float(fl1["soglia79"]) > 1.1 * fb1, "con lo zero che si sposta, uno zero solo vede una sensibilità peggiore (Python: 393 contro 340″)")
	var sep_b := []
	for i in 20:
		sep_b.append([600.0 if i % 2 == 0 else -600.0, i % 2 == 0])
	var fbs: float = bosco.Fit.fit_bacchetta(sep_b, 400.0, 40)
	check(fbs > 50.0 and fbs < 400.0 and not bosco.Fit.fit(sep_b).get("stimabile", false), "20 risposte tutte giuste: stima finita grazie al priore (%.0f″), il diario non stima" % fbs)
	check(bosco.priore_da_profilo({}, "istinto") == 400.0, "priore senza storia: 400″")
	var prof_b := {"sessioni": [{"ritmi": {"istinto": {"stima": {"stimabile": true, "soglia79": 394.0}}, "riflessiva": {"stima": {"stimabile": true, "soglia79": 234.0}}}},
		{"ritmi": {"istinto": {"stima": {"stimabile": true, "soglia79": 365.0}}}}, {"ritmi": {"istinto": {"stima": {"stimabile": false}}}},
		{"ritmi": {"istinto": {"stima": {"stimabile": true, "soglia79": 308.0}}, "riflessiva": {"stima": {"stimabile": true, "soglia79": 206.0}}}}]}
	check(bosco.priore_da_profilo(prof_b, "istinto") == 365.0 and bosco.priore_da_profilo(prof_b, "riflessiva") == 220.0, "priore: mediana delle notti dello stesso tipo")
	# 0.5.12: messaggi e perle a metà, con stime date a mano
	bosco._reset_night()
	bosco.message = ""
	bosco._applica_stima(420.0)
	check(bosco.mezze == 4 and bosco.tacche == 2 and bosco.message.contains("501″"), "420″: due tacche e mezza, messaggio fino a 501″")
	check(beads_f[1].material_override == bosco.bead_mats["accesa"] and beads_f[1].scale.x == 1.0 and beads_f[2].material_override == bosco.bead_mats["accesa"]
		and is_equal_approx(beads_f[2].scale.x, bosco.MEZZA_SCALA) and beads_f[3].material_override == bosco.bead_mats["spenta"] and beads_f[3].scale.x == 1.0,
		"perle: due accese, la terza (398″) accesa piccola, la quarta spenta")
	bosco.message = ""
	bosco._applica_stima(350.0)
	check(bosco.mezze == 5 and bosco.tacche == 3 and bosco.message.contains("398″"), "350″: tre tacche, messaggio fino a 398″")
	bosco.message = ""
	bosco._applica_stima(420.0)
	check(bosco.mezze == 4 and bosco.tacche == 2 and bosco.message == "", "ricaduta a 420″: due e mezza, nessun messaggio")
	bosco._applica_stima(360.0)
	check(bosco.tacche == 3 and bosco.message == "", "riaccensione della terza tacca: nessun messaggio (già accesa in questa notte)")
	bosco._applica_stima(340.0)
	check(bosco.mezze == 6 and bosco.tacche == 3 and bosco.message == "" and is_equal_approx(beads_f[3].scale.x, bosco.MEZZA_SCALA) and beads_f[2].scale.x == 1.0, "340″: tre e mezza (la piccola passa alla quarta), muta")
	bosco._applica_stima(190.0)
	check(bosco.mezze == 11 and bosco.tacche == 6 and bosco.message.contains("200″: into the green!") and beads_f[5].material_override == bosco.bead_mats["meta_accesa"],
		"190″: sei tacche, la prima verde, obiettivo raggiunto")
	bosco._applica_stima(172.0)
	check(bosco.mezze == 12 and beads_f[6].material_override == bosco.bead_mats["meta_accesa"] and is_equal_approx(beads_f[6].scale.x, bosco.MEZZA_SCALA), "172″: la settima (158″) verde piccola")
	var rng_t := RandomNumberGenerator.new()
	rng_t.seed = 1510
	bosco._reset_night()
	var sig := 250.0 / 0.8064     # osservatore simulato: s79 = 250″, zero 0
	for i in 19:
		var dd_t := rng_t.randf_range(100.0, 700.0) * (1.0 if rng_t.randf() < 0.5 else -1.0)
		bosco.night_fit.append([dd_t, rng_t.randf() < bosco.Fit.phi(dd_t / sig)])
		bosco._update_tacche()
	check(bosco.stima_notte < 0.0 and bosco.tacche == 0, "0.5.14: prima della 20ª prova di riferimento nessuna stima e nessuna tacca")
	var stime_t := []
	for i in 181:
		var dd_t := rng_t.randf_range(100.0, 700.0) * (1.0 if rng_t.randf() < 0.5 else -1.0)
		bosco.night_fit.append([dd_t, rng_t.randf() < bosco.Fit.phi(dd_t / sig)])
		var prima: float = bosco.stima_notte
		bosco._update_tacche()
		if bosco.stima_notte != prima:
			stime_t.append(bosco.stima_notte)
	check(stime_t.size() == 37, "0.5.14: una stima alla 20ª prova e poi ogni 5 (%d stime su 200 prove)" % stime_t.size())
	var accese := 0
	for b in beads_f:
		accese += 1 if b.material_override in [bosco.bead_mats["accesa"], bosco.bead_mats["meta_accesa"]] else 0
	check(bosco.stima_notte > 170.0 and bosco.stima_notte < 380.0 and bosco.tacche >= 3 and bosco.tacche <= 6 and accese == bosco.tacche,
		"osservatore a 250″: stima ~%d″, %d tacche accese sulla bacchetta" % [roundi(bosco.stima_notte), accese])
	check(bosco.mezze == bosco.mezze_accese(bosco.stima_notte, bosco.mezze) and bosco.tacche == bosco.intere(bosco.mezze), "mezze e tacche coerenti con la stima (%d mezze)" % bosco.mezze)
	var fb_t: float = bosco.Fit.fit_bacchetta(bosco.night_fit, bosco._priore_bacchetta(), bosco.BACCHETTA_BLOCCO)
	check(absf(fb_t - bosco.stima_notte) < 1e-6, "0.5.14: a fine notte la stima delle tacche è quella della bacchetta (zero per blocco)")
	check(bosco._tacche_line().begins_with("This night's sensitivity: ~%d″ on the wand" % roundi(bosco.stima_notte)) and bosco._tacche_line().contains("in the Journal ~"),
		"riga della pausa con le due stime: %s" % bosco._tacche_line())
	# fine di una notte
	bosco._start_rest()
	check(bosco.state == bosco.S.REST and bosco.night == 2 and bosco.rest_lore.contains("NIGHT 1"), "riepilogo della notte")
	check(bosco.rest_lore.contains("This night's sensitivity: ~"), "0.5.11: nella pausa la sensibilità della notte appena finita")
	check(bosco.tacche == 0 and bosco.mezze == 0 and bosco.tacche_max_notte == 0 and bosco.night_fit.is_empty() and bosco.stima_notte < 0.0 and beads_f[0].material_override == bosco.bead_mats["spenta"],
		"notte nuova: tacche spente, stima e massimo della notte azzerati")
	await create_timer(bosco.MUSIC_FADE_OUT + 0.4).timeout
	check(not bosco.music.playing, "fine della notte: la musica sfuma e si ferma")
	# CSV
	bosco.csv.flush()
	var lines := FileAccess.get_file_as_string(bosco.csv_path).strip_edges().split("\n")
	check(lines[0].begins_with("session,participant") and lines.size() == 7, "CSV: intestazione e 6 righe (%d)" % (lines.size() - 1))
	check(lines[0].ends_with(",ritmo,tacche,mezze"), "0.5.10–0.5.12: colonne ritmo, tacche e mezze in fondo al CSV")
	check(lines.size() == 7 and lines[4].contains(",gemelle,") and lines[6].contains(",pausa,"), "CSV: gemelle e pausa registrate")
	# --- 0.3: suoni sintetizzati
	check(bosco.sounds.size() == 7 and (bosco.sounds["cattura"] as AudioStreamWAV).get_length() > 0.5, "suoni di riscontro pronti")
	check(bosco.sfx.size() == 3 and bosco.sfx[0].get_class() == "AudioStreamPlayer", "effetti non posizionali")
	# --- 0.3: fuochi fatui
	var sess_saved: Array = bosco.prog.data["sessioni"]
	bosco.prog.data["sessioni"] = [{"stima": {"stimabile": true, "zero": 600.0, "sigma": 500.0}}]
	check(absf(bosco._cue_disparity(0) - (600.0 + 1.28155 * 500.0)) < 3.0 and is_equal_approx(bosco._cue_disparity(1), 100.0),
		"disparità dei fatui dal modello: vicina a sinistra %.0f″, a destra %.0f″" % [bosco._cue_disparity(0), bosco._cue_disparity(1)])
	bosco.prog.data["sessioni"] = []
	check(absf(bosco._cue_disparity(0) - 2.0 * pow(10.0, bosco.diffs[0].level)) < 1.0, "senza stima: il doppio della scala del lato")
	bosco.prog.data["sessioni"] = [{"stima": {"stimabile": true, "zero": 600.0, "sigma": 500.0}}]
	for dd in bosco.diffs:
		dd.wheels = {"luce": 0.0, "misura": 0.0, "parallasse": 0.0}
		dd.level = 2.6
	bosco.fatui.c = 0.5
	var seen := {"conflitto": 0, "coerente": 0}
	var cue_ok := true
	for k in 30:
		bosco.trial = 2
		bosco._next_trial()
		if bosco.cur["kind"] != "indizi":
			cue_ok = false
			continue
		var n3: int = bosco.cur["near"]
		var cc: Vector3 = (bosco._eyes()[0] + bosco._eyes()[1]) * 0.5
		var an: float = bosco.flies[n3].scale.x / (bosco.flies[n3].position - cc).length()
		var af: float = bosco.flies[1 - n3].scale.x / (bosco.flies[1 - n3].position - cc).length()
		var brighter: bool = bosco.cur_colors[n3].g > bosco.cur_colors[1 - n3].g
		seen[bosco.cur["cue"]] += 1
		if bosco.cur["cue"] == "conflitto":
			cue_ok = cue_ok and not brighter and an < af
		else:
			cue_ok = cue_ok and brighter and an > af
		cue_ok = cue_ok and absf(bosco.cur["geom"] - bosco.cur["target"]) < 0.5 and is_equal_approx(bosco.cur["cue_c"], 0.5)
	check(cue_ok and seen["conflitto"] > 5 and seen["coerente"] > 5, "fatui: in conflitto la vicina è più fioca e più piccola, coerenti il contrario (%s)" % str(seen))
	bosco.trial = 2
	bosco.diffs[1].wheels["luce"] = 0.4
	var both_ok := true
	for k in 20:
		bosco.trial = 2
		bosco._next_trial()
		if bosco.cur["near"] == 1 and bosco.cur["kind"] == "indizi":
			both_ok = false
	check(both_ok, "niente fatui sul lato che ha ancora le rotelle")
	bosco.diffs[1].wheels["luce"] = 0.0
	var lv0 := [bosco.diffs[0].level, bosco.diffs[1].level]
	var fd0: int = bosco.fit_data.size()
	var bs0: Array = bosco.by_side.duplicate(true)
	var c0: float = bosco.fatui.c
	var nconf := 0
	var guard := 0
	while nconf < 3 and guard < 200:
		guard += 1
		bosco.trial = 2
		bosco._next_trial()
		if bosco.cur["cue"] != "conflitto":
			continue
		bosco.state = bosco.S.WAIT
		bosco.cur["hand"] = "test"
		bosco._answer(bosco.cur["near"])
		nconf += 1
	check(nconf == 3 and bosco.fatui.c > c0, "tre fatui smascherati di fila: l'inganno si fa più forte (%.1f → %.1f)" % [c0, bosco.fatui.c])
	check(bosco.diffs[0].level == lv0[0] and bosco.diffs[1].level == lv0[1] and bosco.fit_data.size() == fd0 and bosco.by_side == bs0,
		"i fatui restano fuori da scale, stima e conteggi per lato")
	check(bosco.cue_counts["conflitto"][0] >= 3, "fatui smascherati contati")
	bosco.csv.flush()
	var last: String = FileAccess.get_file_as_string(bosco.csv_path).strip_edges().split("\n")[-1]
	check(last.contains(",indizi,") and last.contains(",conflitto,0.50,libero"), "CSV: prova coi fatui registrata con tipo, forza ed esposizione")
	bosco.prog.data["sessioni"] = sess_saved
	# --- 0.3: lucciole lampo, la stessa scena in modalità diagnostica
	bosco.lampo_mode = true
	bosco._build_lampo_schedule()
	var cnt := {}
	for it in bosco.lampo_schedule:
		var key := "%s|%d|%d" % [it["exposure"], it["near"], roundi(it["target"])]
		cnt[key] = cnt.get(key, 0) + 1
	var bal: bool = bosco.lampo_schedule.size() == 120
	for ex in ["lampo", "libero"]:
		for lvv in bosco.LAMPO_LEVELS:
			for side in 2:
				bal = bal and cnt.get("%s|%d|%d" % [ex, side, roundi(lvv)], 0) == 8
		bal = bal and cnt.get("%s|0|0" % ex, 0) + cnt.get("%s|1|0" % ex, 0) == 12
	check(bal, "lampo: 120 prove bilanciate per esposizione, lato e disparità, 12 gemelle per esposizione")
	var lvl0 := [bosco.diffs[0].level, bosco.diffs[1].level]
	bosco.state = bosco.S.ITI_WAIT
	bosco._next_trial()
	check(bosco.state == bosco.S.FIX and bosco.fix_dot.visible and not bosco.flies[0].visible, "lampo: prima il punto di fissazione, lucciole nascoste")
	bosco.cur["exposure"] = "lampo"
	bosco.timer = 0.0
	bosco._process(0.016)
	check(bosco.state == bosco.S.WAIT and bosco.flies[0].visible and bosco.flies[1].visible and not bosco.fix_dot.visible, "lampo: comparsa brusca della coppia")
	bosco._process(0.1)
	check(bosco.flies[0].visible, "lampo: a 100 ms ancora visibili")
	bosco._process(0.2)
	check(not bosco.flies[0].visible and not bosco.flies[1].visible and bosco.state == bosco.S.WAIT, "lampo: spariscono dopo 250 ms, la risposta resta aperta")
	var nl: int = bosco.lampo_fit["lampo"].size()
	bosco.cur["hand"] = "test"
	bosco._answer(bosco.cur["near"])
	check(bosco.state == bosco.S.FEEDBACK and bosco.lampo_fit["lampo"].size() == nl + (1 if bosco.cur["geom_ok"] else 0), "lampo: risposta registrata per esposizione")
	check(bosco.diffs[0].level == lvl0[0] and bosco.diffs[1].level == lvl0[1], "lampo: le scale del bosco non si muovono")
	bosco.lampo_mode = false
	bosco.lampo_schedule.clear()
	# --- 0.3: misura del contrasto
	bosco._start_contrast()
	check(bosco.state == bosco.S.CONTRAST and bosco.c_phase == "intro" and bosco.c_order.count(0) == 2, "contrasto: introduzione e ordine bilanciato")
	bosco._confirm()
	check(bosco.c_phase == "adjust" and bosco.c_flies[0].visible and bosco.c_flies[1].visible and bosco.c_fix.visible, "contrasto: due lucciole e il punto di fissazione")
	check(bosco.c_lock.visible and bosco.c_lock.mesh != null and bosco.c_lock.mesh.get_faces().size() == 6 * (4 * 7 + 4), "0.5.7: riquadro e tacche binoculari attorno al puntino")
	var lock_ok := true
	for v in bosco.c_lock.mesh.get_faces():
		lock_ok = lock_ok and absf(v.length() - bosco.C_DIST) < 2e-4   # 0,2 mm a 0,5 m: meno di 12″ di disparità
	check(lock_ok, "0.5.7: il riquadro sta alla distanza del puntino (disparità nulla rispetto al puntino)")
	bosco.xr_active = true
	bosco.c_rep = 0
	bosco._contrast_begin_rep()
	var le: int = bosco.c_order[0]
	var m_le: ShaderMaterial = bosco.c_flies[le].material_override
	var m_re: ShaderMaterial = bosco.c_flies[1 - le].material_override
	check(int(m_le.get_shader_parameter("eye")) == 0 and int(m_re.get_shader_parameter("eye")) == 1, "contrasto: ogni lucciola la vede un occhio solo")
	bosco.xr_active = false
	var up_before: float = (bosco.c_flies[0].material_override.get_shader_parameter("light") as Vector3).x
	var down_before: float = (bosco.c_flies[1].material_override.get_shader_parameter("light") as Vector3).x
	bosco._contrast_adjust(0.2)
	check((bosco.c_flies[0].material_override.get_shader_parameter("light") as Vector3).x > up_before and (bosco.c_flies[1].material_override.get_shader_parameter("light") as Vector3).x < down_before,
		"contrasto (0.5.8): levetta su, la lucciola in alto si illumina e l'altra si abbassa")
	var fix_p: Vector3 = bosco.c_fix.position
	var up_p: Vector3 = bosco.c_flies[0].position
	var dn_p: Vector3 = bosco.c_flies[1].position
	check(absf(up_p.x) < 1e-6 and absf(dn_p.x) < 1e-6 and up_p.y > fix_p.y and dn_p.y < fix_p.y
		and absf(rad_to_deg(up_p.angle_to(fix_p)) - bosco.C_VOFF) < 1e-3 and absf(rad_to_deg(dn_p.angle_to(fix_p)) - bosco.C_VOFF) < 1e-3
		and absf(up_p.length() - bosco.C_DIST) < 1e-6, "contrasto (0.5.8): lucciole sopra e sotto il puntino, a 4° e alla sua distanza")
	check(bosco.hud.text.contains("grip: can't see well"), "contrasto (0.5.8): promemoria dei comandi in alto")
	bosco.c_ratio = 0.3
	bosco._contrast_apply()
	var lre: float = (m_re.get_shader_parameter("light") as Vector3).x
	var lle: float = (m_le.get_shader_parameter("light") as Vector3).x
	check(absf(log(lre / lle) / log(10.0) - 0.3) < 1e-4, "contrasto: il rapporto è luce del destro su luce del sinistro")
	for k in bosco.C_REPS:
		if bosco.c_phase != "adjust":
			bosco._contrast_begin_rep()
		bosco.c_ratio = 0.3
		bosco._contrast_apply()
		bosco._confirm()
	var crec: Dictionary = bosco.prog.data["contrasto"][-1]
	check(bosco.c_phase == "result" and absf(float(crec["mediana"]) - 0.3) < 1e-3 and int(crec["sparizioni"]) == 0, "contrasto: 4 misure e mediana salvate")
	check(bosco.label.text.contains("right") and bosco.label.text.contains("2.0 times"), "contrasto: risultato detto a parole")
	var c_path: String = bosco.results_dir + "contrasto_%s.csv" % bosco.session_id
	check(FileAccess.get_file_as_string(c_path).strip_edges().split("\n").size() == 5, "contrasto: CSV con intestazione e 4 righe")
	check(not bosco._contrast_due(), "contrasto: una volta al giorno")
	bosco._confirm()
	check(bosco.state in [bosco.S.SPAWN, bosco.S.WAIT] and not bosco.c_flies[0].visible, "contrasto: poi si entra nel bosco")
	DirAccess.remove_absolute(c_path)
	# --- 0.5.7: "non riesco a fondere"
	bosco.c_csv = null
	bosco.session_id += "_f"
	bosco._start_contrast()
	bosco._confirm()
	var side0: int = bosco.c_order[0]
	bosco.c_ratio = 0.05
	bosco._contrast_apply()
	var gk := InputEventKey.new()
	gk.physical_keycode = KEY_G
	gk.pressed = true
	bosco._unhandled_input(gk)
	check(bosco.c_phase == "refix" and bosco.c_rep == 0 and not bosco.c_flies[0].visible and bosco.c_fix.visible and bosco.c_lock.visible,
		"0.5.7: misura scartata, si guarda il solo puntino nel riquadro")
	bosco._process(bosco.C_REFIX_S + 0.1)
	check(bosco.c_phase == "adjust" and bosco.c_rep == 0 and bosco.c_order[0] == side0 and bosco.c_flies[0].visible, "0.5.7: poi si rifà la stessa misura, stesso lato")
	bosco._contrast_fusion_lost()
	bosco._process(bosco.C_REFIX_S + 0.1)
	bosco._contrast_fusion_lost()
	check(bosco.c_retries == bosco.C_RETRY_MAX and bosco.c_rep == 1 and bosco.c_scartate.size() == 3, "0.5.7: al più due misure rifatte, poi si va avanti")
	for k in 3:
		if bosco.c_phase != "adjust":
			bosco._contrast_begin_rep()
		bosco.c_ratio = 0.3
		bosco._contrast_apply()
		bosco._confirm()
	var frec: Dictionary = bosco.prog.data["contrasto"][-1]
	check(bosco.c_phase == "result" and Array(frec["log_rapporto"]).size() == 3 and Array(frec["scartate"]).size() == 3 and absf(float(frec["mediana"]) - 0.3) < 1e-3,
		"0.5.7: le scartate non entrano nella mediana e sono salvate a parte")
	check(bosco.label.text.contains("Matches discarded") and bosco.label.text.contains("valid matches"), "0.5.7: il riepilogo dice quante misure sono state scartate")
	var f_path: String = bosco.results_dir + "contrasto_%s.csv" % bosco.session_id
	var flines := FileAccess.get_file_as_string(f_path).strip_edges().split("\n")
	check(flines.size() == 7 and flines[0].ends_with(",fusion_lost") and flines[1].ends_with(",1") and flines[6].ends_with(",0"),
		"0.5.7: tutte le righe nel CSV (3 scartate, 3 valide), colonna fusion_lost")
	check(flines[1].split(",")[4] == "1" and flines[6].split(",")[4] == "6", "0.5.7: righe numerate per tentativo")
	check(flines[1].split(",")[5] in ["su", "giu"] and flines[6].split(",")[5] in ["su", "giu"], "0.5.8: nel CSV la posizione della lucciola del sinistro (su/giu)")
	DirAccess.remove_absolute(f_path)
	# solo scartate: nessun record nel profilo, si entra nel bosco
	bosco._confirm()
	bosco.c_csv = null
	bosco.session_id += "_g"
	var n_rec: int = bosco.prog.data["contrasto"].size()
	bosco._start_contrast()
	bosco._confirm()
	for k in bosco.C_RETRY_MAX + bosco.C_REPS:
		if bosco.c_phase != "adjust":
			bosco._contrast_begin_rep()
		bosco._contrast_fusion_lost()
	check(bosco.c_phase == "result" and bosco.prog.data["contrasto"].size() == n_rec and bosco.label.text.contains("No valid match"),
		"0.5.7: tutte scartate, niente nel profilo e lo dice")
	DirAccess.remove_absolute(bosco.results_dir + "contrasto_%s.csv" % bosco.session_id)
	bosco._confirm()
	check(bosco.state in [bosco.S.SPAWN, bosco.S.WAIT, bosco.S.FIX], "0.5.7: poi si entra nel bosco")
	# una volta a settimana
	var keep_mode = bosco.prog.data.get("contrasto_modo", "giorno")
	var keep_list: Array = bosco.prog.data["contrasto"].duplicate(true)
	bosco.prog.data["contrasto_modo"] = "settimana"
	var six := Time.get_date_string_from_unix_time(Time.get_unix_time_from_system() - 6 * 86400)
	var eight := Time.get_date_string_from_unix_time(Time.get_unix_time_from_system() - 8 * 86400)
	bosco.prog.data["contrasto"] = [{"data": six + "T20:00:00"}]
	check(not bosco._contrast_due(), "0.5.7: a settimana, sei giorni dopo non tocca")
	bosco.prog.data["contrasto"] = [{"data": eight + "T20:00:00"}]
	check(bosco._contrast_due(), "0.5.7: a settimana, otto giorni dopo tocca")
	bosco.prog.data["contrasto_modo"] = keep_mode
	bosco.prog.data["contrasto"] = keep_list
	# review T4: dopo un errore di scrittura il bosco resta fermo
	bosco.csv.close()
	bosco.csv = FileAccess.open(bosco.csv_path, FileAccess.READ)
	bosco.trial = 1
	bosco._next_trial()
	bosco.state = bosco.S.WAIT
	bosco._answer(bosco.cur["near"])
	check(bosco.state == bosco.S.ERROR, "errore di scrittura: il bosco si ferma (stato %d)" % bosco.state)
	var path: String = bosco.csv_path
	bosco.queue_free()
	DirAccess.remove_absolute(path)
	print("PASS: training (%d controlli)" % checks if failures == 0 else "FAIL: training (%d su %d)" % [failures, checks])
	quit(0 if failures == 0 else 1)
