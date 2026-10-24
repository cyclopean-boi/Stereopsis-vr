extends RefCounted
## Obiettivi della capanna (training 0.4). Quattro famiglie, ciascuna col suo medaglione.
## Principi (DESIGN_TRAINING.md, 0.4):
## - la costanza pesa più della prestazione: la prestazione di una notte è rumorosa, mentre la
##   costanza è ciò che fa funzionare l'apprendimento percettivo;
## - gli obiettivi di abilità usano solo stime informative e l'INTERO intervallo: una soglia
##   "confermata" (le specie invece scattano sulla stima puntuale, la prima volta);
## - niente obiettivi su un lato, sulle gemelle o sulle serie, che lo sbilanciamento gonfia;
## - alcuni sono nascosti finché non si ottengono.
## Si calcolano sempre sull'intera storia, quindi valgono anche per le sessioni passate.

const Storia := preload("res://scripts/training/storia.gd")
const Misure := preload("res://scripts/training/rovine_misure.gd")

const FAMILIES := {
	"costanza": {"nome": "Consistency", "icona": "res://assets/2d/obiettivi/costanza.png"},
	"scoperta": {"nome": "Discovery", "icona": "res://assets/2d/obiettivi/scoperta.png"},
	"abilita": {"nome": "Skill", "icona": "res://assets/2d/obiettivi/abilita.png"},
	"curiosita": {"nome": "Curiosity", "icona": "res://assets/2d/obiettivi/curiosita.png"},
}

const LIST := [
	{"id": "prima_notte", "fam": "costanza", "nome": "First Night", "descr": "Complete a night, in the forest or in the Ruins (at least 10 minutes of play)."},
	{"id": "tre_lanterne", "fam": "costanza", "nome": "Three Lanterns", "descr": "Play on three different days of the same week, at least 10 minutes a day."},
	{"id": "quattro_settimane", "fam": "costanza", "nome": "Four Weeks", "descr": "Four weeks with three lanterns, not necessarily in a row."},
	{"id": "mese_lanterna", "fam": "costanza", "nome": "The Lantern Month", "descr": "Four weeks in a row with three lanterns."},
	{"id": "notti_10", "fam": "costanza", "nome": "Ten Nights", "descr": "Complete ten nights."},
	{"id": "notti_25", "fam": "costanza", "nome": "Twenty-Five Nights", "descr": "Complete twenty-five nights."},
	{"id": "notti_50", "fam": "costanza", "nome": "Fifty Nights", "descr": "Complete fifty nights."},
	{"id": "sonde_100", "fam": "costanza", "nome": "A Hundred Probes", "descr": "Answer a hundred bare-stone trials in the Ruins: they are what measure global stereopsis."},
	{"id": "ritorno", "fam": "costanza", "nome": "The Way Home", "descr": "Come back to the forest after at least a week away. The forest was waiting for you.", "nascosto": true},
	{"id": "specie_3", "fam": "scoperta", "nome": "First Notebook", "descr": "Discover three species."},
	{"id": "specie_5", "fam": "scoperta", "nome": "Notebook Half Full", "descr": "Discover five species."},
	{"id": "specie_8", "fam": "scoperta", "nome": "The Complete Bestiary", "descr": "Discover every species in the forest."},
	{"id": "fatui_10", "fam": "scoperta", "nome": "Will-o'-Wisp Hunter", "descr": "Unmask ten will-o'-wisps."},
	{"id": "fatui_50", "fam": "scoperta", "nome": "No One Fools You Now", "descr": "Unmask fifty will-o'-wisps."},
	{"id": "discesa", "fam": "scoperta", "nome": "The Descent", "descr": "Go down into the Ruins and complete a night among the stones."},
	{"id": "restauro_1", "fam": "scoperta", "nome": "The First Stone", "descr": "Restore the first piece of the Ruins."},
	{"id": "restauro_4", "fam": "scoperta", "nome": "The Ruins Awaken", "descr": "Restore four pieces of the Ruins."},
	{"id": "restauro_8", "fam": "scoperta", "nome": "The Ruins Reborn", "descr": "Restore eight pieces of the Ruins."},
	{"id": "osservatorio", "fam": "abilita", "nome": "The Sky Has Depth", "descr": "Restore the four pieces of the observatory, beyond the bare stone (down to 398″)."},
	{"id": "occhio_600", "fam": "abilita", "nome": "Watchful Eye", "descr": "A session with estimated sensitivity under 600″, whole interval included."},
	{"id": "occhio_400", "fam": "abilita", "nome": "Keen Eye", "descr": "A session with estimated sensitivity under 400″, whole interval included."},
	{"id": "occhio_250", "fam": "abilita", "nome": "The Keeper's Eye", "descr": "A session with estimated sensitivity under 250″, whole interval included."},
	{"id": "progresso", "fam": "abilita", "nome": "Better Than Before", "descr": "The median of your last three sessions is better than that of your first three by at least a quarter."},
	{"id": "bosco_dritto", "fam": "abilita", "nome": "Straight and True", "descr": "A session in which the left–right bias cannot be told apart from zero."},
	{"id": "resistente", "fam": "abilita", "nome": "The Light Lies", "descr": "Will-o'-wisp resistance steady at 0.5 or more."},
	{"id": "contrasto_1", "fam": "curiosita", "nome": "Two Eyes, Two Lights", "descr": "Do the contrast match between your eyes."},
	{"id": "contrasto_10", "fam": "curiosita", "nome": "The Book of Lights", "descr": "Ten contrast matches, on different days."},
	{"id": "lampo", "fam": "curiosita", "nome": "In a Flash", "descr": "Complete the flash fireflies."},
	{"id": "due_sentieri", "fam": "curiosita", "nome": "Two Paths", "descr": "In a single Ruins session, bring the mosaic path to a stable bridge point and find at least half the creatures in the bare stone, over 10 probes or more."},
	{"id": "test", "fam": "curiosita", "nome": "Out of the Woods", "descr": "Take the stereopsis test again after you start training."},
	{"id": "buonanotte", "fam": "curiosita", "nome": "Good Night", "descr": "Leave the forest before 11 p.m. on three different days. Sleep is training too.", "nascosto": true},
]


static func _median(v: Array) -> float:
	var a := v.duplicate()
	a.sort()
	if a.is_empty():
		return NAN
	var n := a.size()
	return float(a[n / 2]) if n % 2 == 1 else 0.5 * (float(a[n / 2 - 1]) + float(a[n / 2]))


## Esito per ogni obiettivo: {id: {"ok": bool, "cur": numero, "max": numero}}.
static func evaluate(st: Storia) -> Dictionary:
	var out := {}
	var nights := st.completed_nights()
	var weeks := st.lantern_weeks()
	var full_weeks := []
	for w in weeks:
		if int(weeks[w]) >= 3:
			full_weeks.append(w)
	full_weeks.sort()
	var best_run := 0
	var run := 0
	var prev := ""
	for w in full_weeks:
		var t := Time.get_unix_time_from_datetime_string(w + "T12:00:00")
		if prev != "" and absf(t - Time.get_unix_time_from_datetime_string(prev + "T12:00:00") - 7 * 86400) < 7200:
			run += 1
		else:
			run = 1
		best_run = maxi(best_run, run)
		prev = w
	var max_week := 0
	for w in weeks:
		max_week = maxi(max_week, int(weeks[w]))
	# giorni di gioco in ordine, per il ritorno dopo una pausa
	var day_list := []
	for d in st.days:
		if float(st.days[d]) >= 1.0:
			day_list.append(d)
	day_list.sort()
	var gap := 0.0
	for i in range(1, day_list.size()):
		var a := Time.get_unix_time_from_datetime_string(day_list[i - 1] + "T12:00:00")
		var b := Time.get_unix_time_from_datetime_string(day_list[i] + "T12:00:00")
		gap = maxf(gap, (b - a) / 86400.0)
	out["prima_notte"] = {"ok": nights >= 1, "cur": mini(nights, 1), "max": 1}
	out["tre_lanterne"] = {"ok": max_week >= 3, "cur": mini(max_week, 3), "max": 3}
	out["quattro_settimane"] = {"ok": full_weeks.size() >= 4, "cur": mini(full_weeks.size(), 4), "max": 4}
	out["mese_lanterna"] = {"ok": best_run >= 4, "cur": mini(best_run, 4), "max": 4}
	for n in [10, 25, 50]:
		out["notti_%d" % n] = {"ok": nights >= n, "cur": mini(nights, n), "max": n}
	out["ritorno"] = {"ok": gap >= 7.0, "cur": 1 if gap >= 7.0 else 0, "max": 1}
	var ns := st.species.size()
	for n in [3, 5, 8]:
		out["specie_%d" % n] = {"ok": ns >= n, "cur": mini(ns, n), "max": n}
	for n in [10, 50]:
		out["fatui_%d" % n] = {"ok": st.smascherati >= n, "cur": mini(st.smascherati, n), "max": n}
	# abilità: solo stime informative
	var est := st.estimable_sessions()
	var best_hi := INF
	var straight := false
	var s79 := []
	for s in est:
		var f: Dictionary = s["stima"]
		best_hi = minf(best_hi, float(f["soglia79_ic"][1]))
		s79.append(float(f["soglia79"]))
		if f.has("zero_ic") and float(f["zero_ic"][0]) <= 0.0 and float(f["zero_ic"][1]) >= 0.0:
			straight = true
	for lim in [600, 400, 250]:
		out["occhio_%d" % lim] = {"ok": best_hi < lim, "cur": 1 if best_hi < lim else 0, "max": 1}
	var prog_ok := false
	if s79.size() >= 6:
		prog_ok = _median(s79.slice(-3)) <= 0.75 * _median(s79.slice(0, 3))
	out["progresso"] = {"ok": prog_ok, "cur": mini(s79.size(), 6), "max": 6}
	out["bosco_dritto"] = {"ok": straight, "cur": 1 if straight else 0, "max": 1}
	var resist := false
	for f in st.fatui:
		if float(f.get("soglia_forza", -1.0)) >= 0.5:
			resist = true
	out["resistente"] = {"ok": resist, "cur": 1 if resist else 0, "max": 1}
	# curiosità
	var c_days := {}
	for c in st.contrasto:
		if not c.get("incompleta", false):
			c_days[str(c.get("data", "")).substr(0, 10)] = true
	out["contrasto_1"] = {"ok": c_days.size() >= 1, "cur": mini(c_days.size(), 1), "max": 1}
	out["contrasto_10"] = {"ok": c_days.size() >= 10, "cur": mini(c_days.size(), 10), "max": 10}
	var lampo_done := false
	for l in st.lampo:
		if int(l.get("prove", 0)) >= 100:
			lampo_done = true
	out["lampo"] = {"ok": lampo_done, "cur": 1 if lampo_done else 0, "max": 1}
	var first := st.first_day()
	var test_after := false
	for t in st.tests:
		if first != "" and str(t.get("data", "")) > first:
			test_after = true
	out["test"] = {"ok": test_after, "cur": 1 if test_after else 0, "max": 1}
	var early := {}
	for s in st.sessions + st.rovine:
		if float(s["fine_ora"]) < 23.0 and float(s["minuti"]) >= 5.0:
			early[s["data"]] = true
	# rovine (0.5)
	var ruin_nights := 0
	var probes_n := 0
	var both := false
	for r in st.rovine:
		ruin_nights += int(r["notti_complete"])
		if not r.get("altro_protocollo", false):
			probes_n += int(r["sonde"]["n"])
		if r["scaglie"].get("stimabile", false) and (r["movimento"].get("stimabile", false) or r.get("mosaico", {}).get("stimabile", false)):
			both = true
		# 0.5.10: senza scaglie, il secondo sentiero è la pietra nuda (almeno metà su 10 sonde o più)
		var sn := int(r["sonde"]["n"])
		if r.get("mosaico", {}).get("stimabile", false) and sn >= 10 and 2 * int(r["sonde"]["k"]) >= sn:
			both = true
	var pieces := 0
	var ev := Misure.evaluate_pieces(st.rovine)
	for pz in ev.values():
		pieces += 1 if pz["ok"] else 0
	pieces = maxi(pieces, st.pezzi_restaurati)
	# 0.5.13: l'osservatorio, i quattro pezzi oltre la pietra nuda
	var obs := 0
	for pz in Misure.PEZZI:
		if pz.get("gruppo", "") == "osservatorio" and ev.get(pz["id"], {}).get("ok", false):
			obs += 1
	out["osservatorio"] = {"ok": obs >= 4, "cur": obs, "max": 4}
	out["discesa"] = {"ok": ruin_nights >= 1, "cur": mini(ruin_nights, 1), "max": 1}
	for n in [1, 4, 8]:
		out["restauro_%d" % n] = {"ok": pieces >= n, "cur": mini(pieces, n), "max": n}
	out["sonde_100"] = {"ok": probes_n >= 100, "cur": mini(probes_n, 100), "max": 100}
	out["due_sentieri"] = {"ok": both, "cur": 1 if both else 0, "max": 1}
	out["buonanotte"] = {"ok": early.size() >= 3, "cur": mini(early.size(), 3), "max": 3}
	return out


## Aggiorna le date di sblocco nel profilo; restituisce gli obiettivi appena ottenuti.
static func update_profile(profile: Dictionary, results: Dictionary, today: String) -> Array:
	if not profile.has("obiettivi") or not profile["obiettivi"] is Dictionary:
		profile["obiettivi"] = {}
	var got: Dictionary = profile["obiettivi"]
	var fresh := []
	for o in LIST:
		var r: Dictionary = results.get(o["id"], {})
		if r.get("ok", false) and not got.has(o["id"]):
			got[o["id"]] = today
			fresh.append(o)
	return fresh
