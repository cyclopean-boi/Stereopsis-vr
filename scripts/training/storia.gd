extends RefCounted
## La storia del giocatore per il diario della capanna (training 0.4).
## Le stime NON si leggono dal profilo: si ricalcolano dai CSV con lo stesso stimatore (fit.gd)
## e la stessa regola per tutte le versioni, così le sessioni vecchie (0.1, 0.2) hanno una stima
## anche se il profilo non l'aveva salvata, e le notti hanno ciascuna la sua.
## Regola delle prove di riferimento (come nel bosco): nessuna rotella, geometria ottenuta,
## niente indizi (fuochi fatui), esposizione libera, risposta data. Normali, sonde e gemelle.
## La disparità è quella destra-meno-sinistra alla comparsa; per i CSV che non la hanno
## (0.1–0.2) si ricostruisce da disparità geometrica e lato della vicina.
## Le versioni prima della 0.2.1 avevano una geometria meno controllata (rotazioni e testa
## inclinata): sono segnate "geometria precedente" e il diario le mostra a parte.
## 0.5.9 (review dell'8/10, C1): le misure del contrasto hanno una SERIE (la disposizione delle
## lucciole: ai lati fino alla 0.5.6, ai lati col riquadro nella 0.5.7, sopra e sotto dalla 0.5.8),
## perché serie diverse non si confrontano. Le invalidazioni dichiarate dopo la sessione stanno in
## <cartella del training>/contrasto_annotazioni.json, separate dai CSV e dal profilo, e il diario le
## mostra come tali: non sono tasti premuti durante la misura.

const Fit := preload("res://scripts/training/fit.gd")
const Misure := preload("res://scripts/training/rovine_misure.gd")
const OVERHEAD_S := 1.3          # comparsa + riscontro + intervallo per prova, oltre al tempo di risposta
const LANTERN_MIN := 10.0        # minuti in un giorno per accendere una lanterna
const NIGHT_MIN := 10.0          # minuti di una notte per contarla completa

var sessions: Array = []         # {sessione, file, versione, data, ora, stima, gemelle, minuti, notti, vecchia, fine_ora}
var nights: Array = []           # {sessione, versione, data, notte, stima, gemelle, minuti, vecchia}
var days := {}                   # "AAAA-MM-GG" -> minuti attivi (bosco e lampo)
var lampo: Array = []            # dal profilo: esiti delle lucciole lampo
var contrasto: Array = []        # dal profilo: misure del contrasto (0.5.9: con serie e annotazioni)
var fatui: Array = []            # dal profilo: {data, forza, soglia_forza, conflitto, coerente}
var tests: Array = []            # riepiloghi del test della stereopsi
var species: Array = []
var smascherati := 0
var rovine: Array = []           # 0.5: sessioni delle rovine (rovine_misure.gd), dalla più vecchia
var pezzi_restaurati := 0        # 0.5: dal profilo
var rovine_escluse: Array = []   # 0.5.1: file delle rovine esclusi dalla validazione, con il motivo


func load_all(training_dir: String, test_dir: String, profile: Dictionary) -> void:
	sessions.clear()
	nights.clear()
	days.clear()
	species = Array(profile.get("specie", []))
	pezzi_restaurati = Misure.restored_ids(profile).size()
	contrasto = contrast_series(Array(profile.get("contrasto", [])), load_contrast_notes(training_dir))
	lampo = []
	for d in profile.get("diagnosi", []):
		if d.get("tipo", "") == "lampo":
			lampo.append(d)
	fatui = []
	smascherati = 0
	for s in profile.get("sessioni", []):
		if s.has("fatui"):
			var f: Dictionary = s["fatui"]
			fatui.append({"data": str(s.get("data", "")).substr(0, 10), "forza": f.get("forza", 0.0),
				"soglia_forza": f.get("soglia_forza", -1.0), "conflitto": f.get("conflitto", [0, 0]), "coerente": f.get("coerente", [0, 0])})
			smascherati += int(f.get("conflitto", [0, 0])[0])
	for fname in _list(training_dir, "bosco_", ".csv"):
		_load_session(training_dir.path_join(fname))
	for fname in _list(training_dir, "lampo_", ".csv"):
		var rows := parse_csv(training_dir.path_join(fname))
		var dt := _date_from_name(fname)
		if not dt.is_empty():
			days[dt["data"]] = float(days.get(dt["data"], 0.0)) + active_seconds(rows) / 60.0
	# 0.5: le rovine contano per le lanterne e per le notti, con le loro misure a parte
	var rh := Misure.load_history_full(training_dir)
	rovine = rh["sessioni"]
	rovine_escluse = rh["esclusi"]
	for r in rovine:
		days[r["data"]] = float(days.get(r["data"], 0.0)) + float(r["minuti"])
	sessions.sort_custom(func(a, b): return str(a["sessione"]) < str(b["sessione"]))
	nights.sort_custom(func(a, b): return str(a["sessione"]) + "%03d" % int(a["notte"]) < str(b["sessione"]) + "%03d" % int(b["notte"]))
	tests = load_tests(test_dir)


const CONTRAST_NOTES := "contrasto_annotazioni.json"
const CONTRAST_SERIES := {"orizzontale": ["fireflies at the sides", "earlier layout"], "riquadro": ["at the sides, framed", "earlier layout"], "verticale": ["above and below", "current layout"]}


## Versione "training-a.b.c" come numero confrontabile (a·10000 + b·100 + c); 0 se non si legge.
static func version_number(v: String) -> int:
	var parts := v.trim_prefix("training-").split(".")
	if parts.size() < 2:
		return 0
	var n := 0
	for i in 3:
		n = n * 100 + (parts[i].to_int() if i < parts.size() else 0)
	return n


## Serie della misura del contrasto, dalla versione che l'ha registrata.
static func contrast_series_of(version: String) -> String:
	var n := version_number(version)
	if n >= 508:
		return "verticale"
	if n == 507:
		return "riquadro"
	return "orizzontale"


## Annotazioni retrospettive: {"sessioni": {id: {"non_valida": bool, "ripetizioni_non_valide": [1-based], "motivo": ""}}}.
static func load_contrast_notes(training_dir: String) -> Dictionary:
	var path := training_dir.path_join(CONTRAST_NOTES)
	if training_dir == "" or not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed.get("sessioni", {})


static func _median_of(v: Array) -> float:
	if v.is_empty():
		return NAN
	var s := v.duplicate()
	s.sort()
	var n := s.size()
	return float(s[n / 2]) if n % 2 == 1 else 0.5 * (float(s[n / 2 - 1]) + float(s[n / 2]))


## Misure del contrasto con serie e validità: aggiunge "serie", "valide" e "non_valide" (valori),
## "mediana_valida" (NAN se non ne resta nessuna), "non_valida" (tutta la misura) e "nota".
## I valori grezzi ("log_rapporto", "mediana") restano com'erano.
static func contrast_series(entries: Array, notes: Dictionary) -> Array:
	var out := []
	for e0 in entries:
		var e: Dictionary = e0.duplicate(true)
		var note: Dictionary = notes.get(str(e.get("sessione", "")), {})
		var bad_reps: Array = note.get("ripetizioni_non_valide", [])
		var all_bad: bool = note.get("non_valida", false)
		var ok := []
		var ko := []
		var vals: Array = e.get("log_rapporto", [])
		for i in vals.size():
			if all_bad or (i + 1) in bad_reps or float(i + 1) in bad_reps:
				ko.append(float(vals[i]))
			else:
				ok.append(float(vals[i]))
		e["serie"] = contrast_series_of(str(e.get("versione", "")))
		e["valide"] = ok
		e["non_valide"] = ko
		e["non_valida"] = all_bad or ok.is_empty()
		e["mediana_valida"] = _median_of(ok)
		e["nota"] = str(note.get("motivo", ""))
		out.append(e)
	return out


static func _list(dir: String, prefix: String, suffix: String) -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(prefix) and f.ends_with(suffix):
			out.append(f)
	out.sort()
	return out


## "bosco_20260928_213312_0fbf.csv" → {"data": "2026-09-28", "ora": 21.55, "id": "20260928_213312_0fbf"}
static func _date_from_name(fname: String) -> Dictionary:
	var parts := fname.get_basename().split("_")
	if parts.size() < 3 or parts[1].length() != 8 or parts[2].length() != 6:
		return {}
	var d := parts[1]
	var t := parts[2]
	return {"data": "%s-%s-%s" % [d.substr(0, 4), d.substr(4, 2), d.substr(6, 2)],
		"ora": t.substr(0, 2).to_float() + t.substr(2, 2).to_float() / 60.0,
		"id": "_".join(parts.slice(1))}


static func parse_csv(path: String) -> Array:
	var rows := []
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return rows
	var header := fa.get_csv_line()
	while not fa.eof_reached():
		var line := fa.get_csv_line()
		if line.size() < header.size():
			continue
		var r := {}
		for i in header.size():
			r[header[i]] = line[i]
		rows.append(r)
	return rows


## [disparità segnata (+ se la vicina è a destra), toccata la destra] oppure [] se la prova non è
## di riferimento.
static func reference_point(r: Dictionary) -> Array:
	var outcome: String = r.get("outcome", "")
	if outcome not in ["near", "far", "gemelle"]:
		return []
	for k in ["w_luce", "w_misura", "w_parallasse"]:
		if str(r.get(k, "0")).to_float() != 0.0:
			return []
	if str(r.get("geom_ok", "1")) != "1":
		return []
	if str(r.get("cue", "")) != "":
		return []
	if str(r.get("exposure", "libero")) not in ["libero", ""]:
		return []
	var kind: String = r.get("kind", "gemelle" if outcome == "gemelle" else "normale")
	var signed := 0.0
	var rl := str(r.get("disp_rl_spawn_arcsec", ""))
	if rl != "":
		signed = rl.to_float()
	elif kind != "gemelle":
		signed = absf(str(r.get("disparity_geom_arcsec", "0")).to_float()) * (1.0 if r.get("near_side", "") == "dx" else -1.0)
	return [signed, r.get("touched_side", "") == "dx"]


static func active_seconds(rows: Array) -> float:
	var s := 0.0
	for r in rows:
		if r.get("outcome", "") in ["near", "far", "gemelle", "timeout"]:
			s += str(r.get("rt_s", "0")).to_float() + OVERHEAD_S
	return s


func _load_session(path: String) -> void:
	var fname := path.get_file()
	var dt := _date_from_name(fname)
	if dt.is_empty():
		return
	var rows := parse_csv(path)
	if rows.is_empty():
		return
	var version: String = rows[0].get("version", "")
	var old := version < "training-0.2.1"
	var by_night := {}
	var all_pts := []
	var twins := [0, 0]
	for r in rows:
		var n := int(str(r.get("night", "1")).to_int())
		n = maxi(n, 1)
		if not by_night.has(n):
			by_night[n] = {"punti": [], "righe": [], "gemelle": [0, 0]}
		by_night[n]["righe"].append(r)
		var p := reference_point(r)
		if p.is_empty():
			continue
		all_pts.append(p)
		by_night[n]["punti"].append(p)
		if r.get("outcome", "") == "gemelle":
			twins[1] += 1
			twins[0] += 1 if p[1] else 0
			by_night[n]["gemelle"][1] += 1
			by_night[n]["gemelle"][0] += 1 if p[1] else 0
	var minutes := active_seconds(rows) / 60.0
	days[dt["data"]] = float(days.get(dt["data"], 0.0)) + minutes
	var complete := 0
	for n in by_night:
		var nm := active_seconds(by_night[n]["righe"]) / 60.0
		if nm >= NIGHT_MIN:
			complete += 1
		nights.append({"sessione": dt["id"], "versione": version, "data": dt["data"], "notte": n,
			"stima": Fit.fit(by_night[n]["punti"]), "gemelle": by_night[n]["gemelle"], "minuti": nm, "vecchia": old})
	sessions.append({"sessione": dt["id"], "file": fname, "versione": version, "data": dt["data"], "ora": dt["ora"],
		"stima": Fit.fit(all_pts), "gemelle": twins, "minuti": minutes, "notti": by_night.size(),
		"notti_complete": complete, "vecchia": old, "fine_ora": dt["ora"] + minutes / 60.0})


## Riepiloghi del test (risultati/<nome>/sessione_*_riepilogo.json), dal più vecchio.
static func load_tests(test_dir: String) -> Array:
	var out := []
	for fname in _list(test_dir, "sessione_", "_riepilogo.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(test_dir.path_join(fname)))
		if not parsed is Dictionary:
			continue
		var d: Dictionary = parsed
		var rec := {"data": str(d.get("date", "")).substr(0, 10), "protocollo": d.get("protocol", ""),
			"versione": d.get("version", ""), "tipo": d.get("session_type", "standard"), "modo": d.get("mode", "")}
		for cond in ["rings", "rings_fixed", "rds", "rds_coarse", "rds_mappa", "rds_grande", "rds_grande_40", "rds_1000_40"]:
			if d.has(cond) and d[cond] is Dictionary:
				var c: Dictionary = d[cond]
				if c.has("outcome"):
					rec[cond] = {"esito": c["outcome"], "q50": c.get("arcsec_q50", -1.0),
						"q025": c.get("arcsec_q025", -1.0), "q975": c.get("arcsec_q975", -1.0)}
				else:
					rec[cond] = {"celle": c}
		out.append(rec)
	return out


## ---------------------------------------------------------------- aggregati

func estimable_sessions() -> Array:
	var out := []
	for s in sessions:
		if s["stima"].get("stimabile", false):
			out.append(s)
	return out


func completed_nights() -> int:
	var n := 0
	for s in sessions:
		n += int(s["notti_complete"])
	for r in rovine:
		n += int(r["notti_complete"])
	return n


## Lunedì della settimana di una data "AAAA-MM-GG".
static func week_of(date: String) -> String:
	var t := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	var wd: int = Time.get_datetime_dict_from_unix_time(t)["weekday"]      # 0 = domenica
	var monday := t - ((wd + 6) % 7) * 86400
	return Time.get_date_string_from_unix_time(monday)


## Settimana (lunedì) → giorni con almeno LANTERN_MIN minuti.
func lantern_weeks() -> Dictionary:
	var out := {}
	for d in days:
		if float(days[d]) >= LANTERN_MIN:
			var w := week_of(d)
			out[w] = int(out.get(w, 0)) + 1
	return out


func first_day() -> String:
	var keys := days.keys()
	keys.sort()
	return keys[0] if not keys.is_empty() else ""
