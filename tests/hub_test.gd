extends SceneTree
## 0.6: un'unica app. Capanna → test → di nuovo capanna, senza chiudere; interruzione (B o Y
## tenuto premuto) con la sessione esclusa dalla somma; anelli a livelli fissi; postura della
## testa in un file a parte; risultati nel diario.
## Uso: godot --headless --path . --xr-mode off --script res://tests/hub_test.gd

const Storia := preload("res://scripts/training/storia.gd")
const NAME := "test_hub"

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: " + what)


func _wait(n := 4) -> void:
	for i in n:
		await process_frame


func _is(node: Node, script_name: String) -> bool:
	return node != null and node.get_script() != null and node.get_script().resource_path.ends_with(script_name)


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://results/desktop/%s/" % NAME)
	_cleanup(dir)
	root.set_meta("capanna_opts", {"partecipante": NAME})
	change_scene_to_file("res://scenes/capanna.tscn")
	await _wait()
	var cap: Node = current_scene
	check(_is(cap, "capanna.gd") and cap.participant == NAME, "si parte dalla capanna, col partecipante")
	cap.menu._go("test")
	await _wait(2)
	var btn: Button = cap.menu.content.find_child("test_standard", true, false)
	check(cap.menu.page == "test" and btn != null, "pagina del test con il pulsante della standard")
	for t in ["anelli", "grossolana", "mappa", "mille"]:
		check(cap.menu.content.find_child("test_" + t, true, false) == null, "versione inglese: niente pulsante %s" % t)

	# --- 1. sessione interrotta a metà (gli anelli fissi restano nel codice, senza pulsante)
	cap._on_action("test:anelli")
	await _wait()
	var m: Node = current_scene
	check(_is(m, "main.gd"), "dal pulsante si entra nel test")
	check(m.session_type == "anelli" and m.session_conds == m.FIXED_RING_CONDITIONS, "tipo di sessione dalla capanna")
	check(m.from_capanna and m.participant == NAME and not root.has_meta("test_opts"), "partecipante e ritorno; opzioni consumate")
	check(m.state == m.S.EYECHECK, "si parte dai controlli iniziali")
	m._respond(2)
	m._respond(0)
	m._respond(0)
	m._respond(1)
	check(m.state == m.S.INTRO and m.intro_text.contains("RINGS AT FIXED LEVELS"), "istruzioni degli anelli fissi")
	m._confirm()
	var done := 0
	for i in 12:
		if m.state == m.S.PAUSE:
			m._confirm()
		m._present_stimulus()
		var before: int = m.trial_counter
		m._respond(1)
		check(m.trial_counter == before, "anelli fissi: destra ignorata")
		m._respond(m.direction_for(m.cur["cond"], m.cur["target"]))
		done += 1
		m._next_trial()
	var csv1: String = m.csv_path
	var post1: String = m.posture_path
	var post_header := ",".join(m.POSTURE_HEADER)
	m._abort()
	await _wait()
	cap = current_scene
	check(_is(cap, "capanna.gd"), "interruzione: si torna alla capanna")
	check(FileAccess.get_file_as_string(csv1).contains(",check,interrotta,"), "interruzione registrata nel CSV")
	check(not FileAccess.file_exists(csv1.replace(".csv", "_riepilogo.json")), "interruzione: nessun riepilogo")
	var plines := FileAccess.get_file_as_string(post1).strip_edges().split("\n")
	check(post1.contains("/postura/") and plines.size() == done + 1, "postura: un file a parte, una riga per prova (%d)" % plines.size())
	check(plines[0] == post_header, "postura: intestazione")

	# --- 2. sessione completa
	cap._on_action("test:anelli")
	await _wait()
	m = current_scene
	check(_is(m, "main.gd") and m.session_type == "anelli", "seconda sessione dalla capanna")
	m._confirm()
	m._confirm()
	m._confirm()
	var n_main := 0
	var n_ctrl := 0
	var n_prac := 0
	var guard := 0
	while m.state != m.S.DONE and guard < 400:
		guard += 1
		if m.state == m.S.PAUSE:
			m._confirm()
			continue
		if m.state == m.S.PRETRIAL:
			m._present_stimulus()
		if m.state == m.S.STIMULUS:
			var blk: String = m.cur["block"]
			n_main += 1 if blk == "main" else 0
			n_ctrl += 1 if blk == "control" else 0
			n_prac += 1 if blk == "practice" else 0
			var right: bool = (blk != "control" and m.cur["level"] >= 2.3) or randf() < 0.5
			m._respond(m.direction_for(m.cur["cond"], m.cur["target"] if right else 1 - m.cur["target"]))
		if m.state == m.S.FEEDBACK:
			m._next_trial()
	check(m.state == m.S.DONE, "sessione finita")
	check(n_prac == 3 and n_main == 80 and n_ctrl == 8, "3 di pratica, 80 principali, 8 di controllo (%d, %d, %d)" % [n_prac, n_main, n_ctrl])
	var keys: Array = m.fixed_counts["rings_fixed"].keys()
	keys.sort()
	check(keys == ["1.70", "2.00", "2.30", "2.60", "2.90"], "cinque livelli fissi (%s)" % str(keys))
	var ok16 := true
	for k in keys:
		ok16 = ok16 and int(m.fixed_counts["rings_fixed"][k][1]) == 16
	check(ok16, "16 prove per livello")
	var src := [0, 0]
	for item in m.schedule:
		if item.get("block") == "control":
			src[item["mono"]] += 1
	check(src == [4, 4], "controlli bilanciati fra gli occhi")
	var js = JSON.parse_string(FileAccess.get_file_as_string(m.results_dir + "sessione_%s_riepilogo.json" % m.session_id))
	check(js is Dictionary and js["session_type"] == "anelli" and js["version"] == m.VERSION and js["protocol"] == "p6", "riepilogo: tipo, versione, protocollo invariato")
	check(js["family"].size() == 5 and absf(float(js["family"][0]["chance"]) - 0.5) < 1e-9, "riepilogo: cinque caselle, caso 50%")
	var excl := " | ".join(js["pooled"]["excluded"])
	check(excl.contains("interrotta"), "somma: la sessione interrotta è esclusa e spiegata")
	check(js["pooled"]["sessions"] == 1 and js["pooled"]["rings_fixed"].size() == 5, "somma: entra solo la sessione completa")
	check(str(js["postura"].get("file", "")).begins_with("postura/"), "riepilogo: file della postura")
	check(m.label.text.contains("hut"), "fine: si torna alla capanna")
	m._confirm()
	await _wait()
	cap = current_scene
	check(_is(cap, "capanna.gd"), "dal riepilogo si torna alla capanna")
	cap.storia.tests = Storia.load_tests(dir)
	check(cap.storia.tests.size() == 1 and cap.storia.tests[0].has("rings_fixed"), "diario: il riepilogo degli anelli fissi si legge")
	check(cap.menu.tests_text().contains("fixed rings") and cap.menu.tests_text().contains("1 in 2"), "diario: anelli fissi a parole, caso 1 su 2")
	cap.menu._go("test")
	await _wait(2)
	check(cap.menu.page == "test", "pagina del test di nuovo")

	# --- 3. gli altri tipi partono dalla capanna
	for tipo in ["standard", "grossolana", "mappa", "grande", "mille"]:
		cap._on_action("test:" + tipo)
		await _wait()
		m = current_scene
		check(_is(m, "main.gd") and m.session_type == tipo and m.session_conds == m.SESSION_TYPES[tipo], "capanna → %s" % tipo)
		if tipo == "grande":
			m._confirm()
			m._confirm()
			m._confirm()
			var comp := {"practice": 0, "main": 0, "control": 0}
			var lv_ok := true
			for item in m.schedule:
				if comp.has(item.get("block", "")):
					comp[item["block"]] += 1
					lv_ok = lv_ok and absf(float(item["level"]) - 3.6) < 1e-9
			check(comp == {"practice": 2, "main": 40, "control": 4} and lv_ok, "verifica dischi grandi: 2 + 40 + 4 prove, tutte a 3981″ (%s)" % str(comp))
			m._present_stimulus()
			check(absf(float(m.materials[0].get_shader_parameter("field_extent")) - 9.6) < 1e-6, "verifica dischi grandi: geometria del formato grande")
			m._respond(m.cur["target"])
			m._next_trial()
		if tipo == "mille":
			m._confirm()
			m._confirm()
			m._confirm()
			var comp := {"practice": 0, "main": 0, "control": 0}
			var lv_ok := true
			for item in m.schedule:
				if comp.has(item.get("block", "")):
					comp[item["block"]] += 1
					lv_ok = lv_ok and absf(float(item["level"]) - 3.0) < 1e-9 and item["cond"] == "rds_1000_40"
			check(comp == {"practice": 2, "main": 40, "control": 4} and lv_ok, "verifica a 1000″: 2 + 40 + 4 prove, tutte a 1000″ (%s)" % str(comp))
			m._present_stimulus()
			check(absf(float(m.materials[0].get_shader_parameter("field_extent")) - 6.0) < 1e-6, "verifica a 1000″: geometria del formato normale")
			m._respond(m.cur["target"])
			m._next_trial()
			# stesso stimolo della standard a 1000″: a parità di seme, tutti i parametri dello shader uguali
			m._apply_params(3.0, "rds", m.trial_params(4242, "rds"))
			var u_std := _uniforms(m)
			m._apply_params(3.0, "rds_1000_40", m.trial_params(4242, "rds_1000_40"))
			var u_mille := _uniforms(m)
			check(u_std.size() > 10 and u_std == u_mille, "verifica a 1000″: stimolo identico alla standard a 1000″ (%d parametri)" % u_std.size())
		var c0: String = m.csv_path
		m._abort()
		await _wait()
		cap = current_scene
		check(_is(cap, "capanna.gd"), "%s interrotto: di nuovo nella capanna" % tipo)
		if tipo in ["grande", "mille"]:
			check(FileAccess.get_file_as_string(c0).contains(",check,interrotta,"), "%s interrotto dopo una prova: riga interrotta" % tipo)
		else:
			check(not FileAccess.file_exists(c0), "%s interrotto prima di ogni prova: nessun file lasciato" % tipo)

	# --- 4. lancio diretto (senza capanna): a fine sessione si chiude, come prima
	var direct: Node = load("res://scenes/main.tscn").instantiate()
	direct.session_override = "anelli"
	root.add_child(direct)
	await process_frame
	check(not direct.from_capanna and not direct.intro_text.contains("hut"), "lancio diretto: niente ritorno alla capanna")
	direct.csv.flush()
	var dcsv: String = direct.csv_path
	var dpost: String = direct.posture_path
	direct.queue_free()
	await process_frame
	DirAccess.remove_absolute(dcsv)
	DirAccess.remove_absolute(dpost)

	_cleanup(dir)
	print("PASS: hub (%d controlli)" % checks if failures == 0 else "FAIL: hub (%d su %d)" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _uniforms(m: Node) -> Dictionary:
	var out := {}
	for i in m.materials.size():
		var mat: ShaderMaterial = m.materials[i]
		for u in mat.shader.get_shader_uniform_list():
			out["%d:%s" % [i, u["name"]]] = mat.get_shader_parameter(u["name"])
	return out


func _cleanup(dir: String) -> void:
	for sub in ["postura/", "training/", ""]:
		var d: String = dir + sub
		if DirAccess.dir_exists_absolute(d):
			for f in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d + f)
			DirAccess.remove_absolute(d)
