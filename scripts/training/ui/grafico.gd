extends Control
## Grafici del diario (training 0.4), disegnati con _draw: niente librerie esterne.
## Modi:
## - "cielo": una stella per notte, sensibilità al 79% in scala logaritmica, PIÙ IN ALTO = MEGLIO,
##   con l'intervallo indicativo e le soglie delle specie tratteggiate;
## - "zero": sbilanciamento per notte con intervallo, linea dello zero marcata;
## - "contrasto": log10 del rapporto di luce destro/sinistro per misura (ripetizioni e mediana);
## - "fatui": forza dell'inganno a cui si resiste (0–1) per sessione;
## - "calendario": ultime settimane, una lanterna per giorno con almeno 10 minuti.
## - "sonde" (0.5): rovine, quota di sonde giuste per sessione con intervallo esatto, linea del caso
##   (1 su 4) e quota cumulata;
## - "ponte" (0.5): rovine, punto del ponte per sessione nei due sentieri; più in alto = più vicino
##   al random-dot puro. Dalla 0.5.9, quando il punto non è ancora stabile, un anello velato segna il
##   gradino più avanzato raggiunto nella sessione (prima quelle sessioni non comparivano affatto).

const Misure := preload("res://scripts/training/rovine_misure.gd")
const Storia := preload("res://scripts/training/storia.gd")

const GOLD := Color(1.0, 0.86, 0.45)
const OLD := Color(0.62, 0.74, 0.9)
const INK := Color(0.93, 0.9, 0.82)
const DIM := Color(0.93, 0.9, 0.82, 0.35)
const GRID := Color(0.93, 0.9, 0.82, 0.12)
const FS := 22
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var mode := "cielo"
var data: Array = []
var extra := {}
var title := ""


func set_data(p_mode: String, p_data: Array, p_extra := {}, p_title := "") -> void:
	mode = p_mode
	data = p_data
	extra = p_extra
	title = p_title
	queue_redraw()


func _font() -> Font:
	return ThemeDB.fallback_font


func _text(pos: Vector2, s: String, col := INK, size := FS, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_font(), pos, s, align, width, size, col)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.02, 0.03, 0.06, 0.55))
	if title != "":
		_text(Vector2(16, 30), title, INK, 26)
	match mode:
		"cielo":
			_draw_sky()
		"zero":
			_draw_zero()
		"contrasto":
			_draw_contrast()
		"fatui":
			_draw_fatui()
		"calendario":
			_draw_calendar()
		"sonde":
			_draw_probes()
		"ponte":
			_draw_bridge()


## Area del grafico (margini per gli assi).
func _plot_rect() -> Rect2:
	return Rect2(Vector2(110, 50), size - Vector2(110 + 190, 50 + 60))


func _x_positions(n: int, pr: Rect2) -> Array:
	if n == 1:
		return [pr.position.x + pr.size.x * 0.5]
	var xs := []
	var pad := minf(60.0, pr.size.x / (n + 1))
	for i in n:
		xs.append(pr.position.x + pad + float(i) / (n - 1) * (pr.size.x - 2.0 * pad))
	return xs


func _date_labels(xs: Array, pr: Rect2) -> void:
	var last := ""
	for i in data.size():
		var d: String = str(data[i].get("data", ""))
		if d != last and d.length() >= 10:
			_text(Vector2(xs[i] - 30, pr.end.y + 30), "%s %d" % [MONTHS[clampi(d.substr(5, 2).to_int(), 1, 12) - 1], d.substr(8, 2).to_int()], DIM, 20)
			last = d


func _empty(msg: String) -> void:
	_text(Vector2(0, size.y * 0.5), msg, DIM, 26, HORIZONTAL_ALIGNMENT_CENTER, size.x)


static func star_points(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		var rr := r_out if k % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


# ---------------------------------------------------------------- cielo delle notti

const SKY_MIN := 50.0
const SKY_MAX := 4000.0


func _y_log(v: float, pr: Rect2) -> float:
	var t := (log(clampf(v, SKY_MIN, SKY_MAX)) - log(SKY_MIN)) / (log(SKY_MAX) - log(SKY_MIN))
	return pr.position.y + t * pr.size.y       # 50″ in alto: più in alto = meglio


func _draw_sky() -> void:
	var pr := _plot_rect()
	for v in [50, 100, 200, 500, 1000, 2000, 4000]:
		var y := _y_log(v, pr)
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), GRID, 1.0)
		_text(Vector2(pr.position.x - 100, y + 8), "%d″" % v, DIM, 20, HORIZONTAL_ALIGNMENT_RIGHT, 90)
	for sp in [[1000.0, "Twilight Firefly"], [600.0, "Moon Moth"], [400.0, "Ghost Spark"], [250.0, "Keeper of the Path"]]:
		var y := _y_log(sp[0], pr)
		var x := pr.position.x
		while x < pr.end.x:
			draw_line(Vector2(x, y), Vector2(minf(x + 10, pr.end.x), y), Color(0.75, 0.9, 0.75, 0.35), 2.0)
			x += 18
		_text(Vector2(pr.end.x + 10, y + 7), sp[1], Color(0.75, 0.9, 0.75, 0.6), 18)
	var pts := []
	for n in data:
		if n["stima"].get("stimabile", false):
			pts.append(n)
	if pts.is_empty():
		_empty("No night with an estimate yet: it takes about forty trials without training wheels.")
		return
	var saved := data
	data = pts
	var xs := _x_positions(pts.size(), pr)
	_date_labels(xs, pr)
	data = saved
	for i in pts.size():
		var f: Dictionary = pts[i]["stima"]
		var col: Color = OLD if pts[i].get("vecchia", false) else GOLD
		var x: float = xs[i]
		var y := _y_log(float(f["soglia79"]), pr)
		var y_lo := _y_log(float(f["soglia79_ic"][0]), pr)
		var y_hi := _y_log(float(f["soglia79_ic"][1]), pr)
		draw_line(Vector2(x, y_lo), Vector2(x, y_hi), Color(col, 0.55), 3.0)
		draw_line(Vector2(x - 8, y_lo), Vector2(x + 8, y_lo), Color(col, 0.55), 2.0)
		draw_line(Vector2(x - 8, y_hi), Vector2(x + 8, y_hi), Color(col, 0.55), 2.0)
		var big: bool = f.get("precisa", false)
		draw_circle(Vector2(x, y), 20.0 if big else 14.0, Color(col, 0.18))
		draw_colored_polygon(star_points(Vector2(x, y), 14.0 if big else 10.0, 6.0 if big else 4.5), col)
		_text(Vector2(x - 40, y - 24), "%d″" % roundi(float(f["soglia79"])), col, 18, HORIZONTAL_ALIGNMENT_CENTER, 80)


# ---------------------------------------------------------------- sbilanciamento

func _draw_zero() -> void:
	var pr := _plot_rect()
	var pts := []
	for n in data:
		if n["stima"].get("stimabile", false) and n["stima"].has("zero_ic"):
			pts.append(n)
	if pts.is_empty():
		_empty("No night with a bias estimate yet.")
		return
	var lo := -300.0
	var hi := 1000.0
	for n in pts:
		lo = minf(lo, float(n["stima"]["zero_ic"][0]) - 50.0)
		hi = maxf(hi, float(n["stima"]["zero_ic"][1]) + 50.0)
	var ymap := func(v: float) -> float: return pr.end.y - (v - lo) / (hi - lo) * pr.size.y
	var step := 250.0 if hi - lo < 2500.0 else 500.0
	var v0 := ceilf(lo / step) * step
	while v0 <= hi:
		var y: float = ymap.call(v0)
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), GRID if v0 != 0.0 else Color(INK, 0.7), 1.0 if v0 != 0.0 else 3.0)
		_text(Vector2(pr.position.x - 100, y + 8), "%+d″" % roundi(v0), DIM, 20, HORIZONTAL_ALIGNMENT_RIGHT, 90)
		v0 += step
	_text(Vector2(pr.end.x + 10, ymap.call(0.0) - 12), "none", DIM, 18)
	_text(Vector2(pr.end.x + 10, pr.position.y + 16), "right looks", DIM, 18)
	_text(Vector2(pr.end.x + 10, pr.position.y + 38), "nearer ↑", DIM, 18)
	_text(Vector2(pr.end.x + 10, pr.end.y - 26), "left looks", DIM, 18)
	_text(Vector2(pr.end.x + 10, pr.end.y - 4), "nearer ↓", DIM, 18)
	var saved := data
	data = pts
	var xs := _x_positions(pts.size(), pr)
	_date_labels(xs, pr)
	data = saved
	for i in pts.size():
		var f: Dictionary = pts[i]["stima"]
		var col: Color = OLD if pts[i].get("vecchia", false) else GOLD
		var x: float = xs[i]
		draw_line(Vector2(x, ymap.call(float(f["zero_ic"][0]))), Vector2(x, ymap.call(float(f["zero_ic"][1]))), Color(col, 0.55), 3.0)
		draw_circle(Vector2(x, ymap.call(float(f["zero"]))), 9.0, col)
		_text(Vector2(x - 40, ymap.call(float(f["zero"])) - 18), "%+d″" % roundi(float(f["zero"])), col, 18, HORIZONTAL_ALIGNMENT_CENTER, 80)


# ---------------------------------------------------------------- occhi

func _draw_contrast() -> void:
	var pr := _plot_rect()
	if data.is_empty():
		_empty("No measurements yet: the first one comes when you enter the forest.")
		return
	var ymap := func(v: float) -> float: return pr.position.y + (1.0 - (clampf(v, -1.0, 1.0) + 1.0) / 2.0) * pr.size.y
	for v in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		var y: float = ymap.call(v)
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), GRID if v != 0.0 else Color(INK, 0.7), 1.0 if v != 0.0 else 3.0)
		_text(Vector2(pr.position.x - 100, y + 8), "×%.1f" % pow(10.0, absf(v)) if v != 0.0 else "equal", DIM, 20, HORIZONTAL_ALIGNMENT_RIGHT, 90)
	_text(Vector2(pr.end.x + 10, pr.position.y + 16), "right eye needs", DIM, 18)
	_text(Vector2(pr.end.x + 10, pr.position.y + 38), "more light ↑", DIM, 18)
	_text(Vector2(pr.end.x + 10, pr.end.y - 26), "left eye needs", DIM, 18)
	_text(Vector2(pr.end.x + 10, pr.end.y - 4), "more light ↓", DIM, 18)
	var xs := _x_positions(data.size(), pr)
	_date_labels(xs, pr)
	# 0.5.9 (review dell'8/10, C1): una linea verticale e un'etichetta dove comincia una serie nuova
	# (disposizione diversa delle lucciole: le serie non si confrontano). Le misure dichiarate non valide
	# dopo la sessione sono anelli grigi, distinti dai punti validi.
	var grey := Color(INK, 0.45)
	for i in data.size():
		var m: Dictionary = data[i]
		var serie := str(m.get("serie", "orizzontale"))
		if i == 0 or serie != str(data[i - 1].get("serie", "orizzontale")):
			var xl: float = (float(xs[i]) + float(xs[i - 1])) * 0.5 if i > 0 else pr.position.x
			if i > 0:
				for k in 12:
					var y0 := pr.position.y + k * pr.size.y / 12.0
					draw_line(Vector2(xl, y0), Vector2(xl, y0 + pr.size.y / 24.0), Color(INK, 0.6), 2.0)
			var lab: Array = Storia.CONTRAST_SERIES.get(serie, [serie, ""])
			_text(Vector2(xl + 8, pr.position.y + 18), str(lab[0]), Color(INK, 0.75), 16)
			_text(Vector2(xl + 8, pr.position.y + 38), str(lab[1]), Color(INK, 0.5), 15)
		for r in m.get("valide", m.get("log_rapporto", [])):
			draw_circle(Vector2(xs[i], ymap.call(float(r))), 5.0, Color(GOLD, 0.45))
		for r in m.get("non_valide", []):
			draw_arc(Vector2(xs[i], ymap.call(float(r))), 5.0, 0.0, TAU, 14, grey, 1.5)
		var med := float(m.get("mediana_valida", m.get("mediana", 0.0)))
		if m.get("non_valida", false):
			var raw := float(m.get("mediana", 0.0))
			draw_arc(Vector2(xs[i], ymap.call(raw)), 11.0, 0.0, TAU, 24, grey, 2.0)
			_text(Vector2(xs[i] - 50, ymap.call(raw) + 34), "invalid", grey, 16, HORIZONTAL_ALIGNMENT_CENTER, 100)
			continue
		draw_circle(Vector2(xs[i], ymap.call(med)), 11.0, GOLD)
		var nk: int = m.get("non_valide", []).size()
		if nk > 0:
			_text(Vector2(xs[i] - 50, ymap.call(med) - 20), "%d of %d valid" % [m.get("valide", []).size(), nk + m.get("valide", []).size()], grey, 16, HORIZONTAL_ALIGNMENT_CENTER, 100)
		elif int(m.get("sparizioni", 0)) > 0:
			_text(Vector2(xs[i] - 40, ymap.call(med) + 34), "vanished: %d" % int(m["sparizioni"]), Color(1.0, 0.6, 0.5), 16, HORIZONTAL_ALIGNMENT_CENTER, 80)


func _draw_fatui() -> void:
	var pr := _plot_rect()
	if data.is_empty():
		_empty("Will-o'-wisps appear when one side has no training wheels.")
		return
	var ymap := func(v: float) -> float: return pr.end.y - clampf(v, 0.0, 1.0) * pr.size.y
	for v in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var y: float = ymap.call(v)
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), GRID, 1.0)
		_text(Vector2(pr.position.x - 100, y + 8), "%.2f" % v, DIM, 20, HORIZONTAL_ALIGNMENT_RIGHT, 90)
	_text(Vector2(pr.end.x + 10, pr.position.y + 16), "you resist even", DIM, 18)
	_text(Vector2(pr.end.x + 10, pr.position.y + 38), "strong tricks ↑", DIM, 18)
	var xs := _x_positions(data.size(), pr)
	_date_labels(xs, pr)
	for i in data.size():
		var f: Dictionary = data[i]
		var thr := float(f.get("soglia_forza", -1.0))
		if thr > 0.0:
			draw_circle(Vector2(xs[i], ymap.call(thr)), 11.0, Color(0.55, 1.0, 0.85))
		else:
			draw_arc(Vector2(xs[i], ymap.call(float(f.get("forza", 0.0)))), 10.0, 0.0, TAU, 24, Color(0.55, 1.0, 0.85, 0.7), 2.0)
		var c: Array = f.get("conflitto", [0, 0])
		_text(Vector2(xs[i] - 50, pr.end.y + 52), "%d/%d" % [c[0], c[1]], DIM, 16, HORIZONTAL_ALIGNMENT_CENTER, 100)


# ---------------------------------------------------------------- calendario

func _draw_calendar() -> void:
	var weeks: Array = extra.get("settimane", [])        # lunedì, dal più vecchio
	var days: Dictionary = extra.get("giorni", {})
	var today: String = extra.get("oggi", "")
	if weeks.is_empty():
		_empty("The calendar fills up as you play.")
		return
	var x0 := 180.0
	var y0 := 80.0
	var cell := minf(80.0, (size.y - y0 - 20.0) / weeks.size() - 6.0)
	var names := ["M", "T", "W", "T", "F", "S", "S"]
	for j in 7:
		_text(Vector2(x0 + j * (cell + 8) + cell * 0.5 - 8, y0 - 12), names[j], DIM, 20)
	for i in weeks.size():
		var w: String = weeks[i]
		var y := y0 + i * (cell + 6)
		_text(Vector2(20, y + cell * 0.6), "%s %d" % [MONTHS[clampi(w.substr(5, 2).to_int(), 1, 12) - 1], w.substr(8, 2).to_int()], DIM, 20)
		var lit := 0
		var t0 := Time.get_unix_time_from_datetime_string(w + "T12:00:00")
		for j in 7:
			var d := Time.get_date_string_from_unix_time(t0 + j * 86400)
			var m := float(days.get(d, 0.0))
			var rect := Rect2(Vector2(x0 + j * (cell + 8), y), Vector2(cell, cell))
			var col := Color(0.12, 0.14, 0.2, 0.9)
			if m >= 10.0:
				lit += 1
				col = Color(0.35, 0.28, 0.1).lerp(GOLD, clampf((m - 10.0) / 30.0, 0.0, 1.0) * 0.8 + 0.2)
			elif m > 0.0:
				col = Color(0.3, 0.27, 0.2, 0.9)
			draw_rect(rect, col)
			if m >= 10.0:
				draw_circle(rect.get_center(), cell * 0.18, Color(1.0, 0.97, 0.8, 0.9))
			if d == today:
				draw_rect(rect, INK, false, 3.0)
			if d > today:
				draw_rect(rect, Color(0, 0, 0, 0.45))
		var done := lit >= 3
		_text(Vector2(x0 + 7 * (cell + 8) + 20, y + cell * 0.6), "%d/3%s" % [mini(lit, 3), "  ✦" if done else ""], GOLD if done else DIM, 22)


# ---------------------------------------------------------------- rovine (0.5)

const WIND := Color(0.6, 0.9, 1.0)
const MOSAIC := Color(0.85, 0.6, 1.0)      # 0.5.6: sentiero del mosaico


func _draw_probes() -> void:
	var pr := _plot_rect()
	var pts := []
	for s in data:
		if int(s["sonde"]["n"]) > 0:
			pts.append(s)
	if pts.is_empty():
		_empty("No probes yet: one trial in five in the ruins is bare stone.")
		return
	var ymap := func(v: float) -> float: return pr.end.y - clampf(v, 0.0, 1.0) * pr.size.y
	for v in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var y: float = ymap.call(v)
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), GRID if v != 0.25 else Color(INK, 0.7), 1.0 if v != 0.25 else 3.0)
		_text(Vector2(pr.position.x - 100, y + 8), "%d%%" % roundi(v * 100.0), DIM, 20, HORIZONTAL_ALIGNMENT_RIGHT, 90)
	_text(Vector2(pr.end.x + 10, ymap.call(0.25) - 12), "chance", DIM, 18)
	_text(Vector2(pr.end.x + 10, ymap.call(0.25) + 10), "(1 in 4)", DIM, 18)
	_text(Vector2(pr.end.x + 10, pr.position.y + 16), "the bare stone", DIM, 18)
	_text(Vector2(pr.end.x + 10, pr.position.y + 38), "responds ↑", DIM, 18)
	var saved := data
	data = pts
	var xs := _x_positions(pts.size(), pr)
	_date_labels(xs, pr)
	data = saved
	var k := 0
	var n := 0
	var prev := Vector2(-1, -1)
	for i in pts.size():
		var sd: Dictionary = pts[i]["sonde"]
		var x: float = xs[i]
		draw_line(Vector2(x, ymap.call(float(sd["ic"][0]))), Vector2(x, ymap.call(float(sd["ic"][1]))), Color(GOLD, 0.45), 3.0)
		draw_circle(Vector2(x, ymap.call(float(sd["quota"]))), 9.0, GOLD)
		_text(Vector2(x - 40, pr.end.y + 52), "%d/%d" % [sd["k"], sd["n"]], DIM, 16, HORIZONTAL_ALIGNMENT_CENTER, 80)
		k += int(sd["k"])
		n += int(sd["n"])
		var cum := Vector2(x, ymap.call(float(k) / n))
		if prev.x >= 0.0:
			draw_line(prev, cum, Color(0.6, 1.0, 0.85, 0.7), 2.0)
		draw_circle(cum, 4.0, Color(0.6, 1.0, 0.85, 0.9))
		prev = cum


func _draw_bridge() -> void:
	var pr := _plot_rect()
	var top := Misure.SCALE_LEVELS.size() - 1
	var any := false
	for s in data:
		for kind in ["scaglie", "movimento", "mosaico"]:
			if s.get(kind, {}).get("stimabile", false) or int(s.get("gradino_max", {}).get(kind, -1)) >= 0:
				any = true
	if not any:
		_empty("The bridge point settles after a few reversals on each path: a night or two.")
		return
	# 0.5.13: oltre la pietra nuda (gradino 9) l'asse si allunga fin dove è arrivato il mosaico, più uno (al massimo 21)
	var mtop := top
	for s in data:
		var em: Dictionary = s.get("mosaico", {})
		if em.get("stimabile", false):
			mtop = maxi(mtop, ceili(float(em["indice"])))
		mtop = maxi(mtop, int(s.get("gradino_max", {}).get("mosaico", -1)))
	if mtop > top:
		mtop = mini(mtop + 1, Misure.last_rung())
	var ymap := func(fi: float) -> float: return pr.end.y - clampf(fi, 0.0, float(mtop)) / mtop * pr.size.y
	# con l'asse più lungo le righe si stringono: un'etichetta ogni "every" righe, contando dalla pietra nuda
	var every := maxi(1, ceili(20.0 / (pr.size.y / mtop)))
	for i in range(0, mtop + 1):
		var y: float = ymap.call(float(i))
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), GRID if i != top else Color(INK, 0.7), 1.0 if i != top else 3.0)
		if i != top and absi(i - top) % every != 0:
			continue
		if i < top:
			var sc: float = Misure.SCALE_LEVELS[i] * 100.0
			_text(Vector2(pr.position.x - 100, y + 8), ("%d%%" % roundi(sc)) if sc >= 10.0 else ("%.1f%%" % sc), Color(GOLD, 0.6), 18, HORIZONTAL_ALIGNMENT_RIGHT, 90)
			_text(Vector2(pr.end.x + 10, y + 8), "mosaic %d" % i, Color(MOSAIC, 0.7), 18)
		elif i > top:
			_text(Vector2(pr.end.x + 10, y + 8), "%d″" % roundi(float(Misure.mosaic_rung(i)["disparity_arcsec"])), Color(MOSAIC, 0.7), 18)
	_text(Vector2(pr.end.x + 10, ymap.call(float(top)) + 8), "bare stone", INK, 18)
	var xs := _x_positions(data.size(), pr)
	_date_labels(xs, pr)
	# 0.5.6: il vento è uscito dalla rotazione; le sue sessioni restano, senza etichette sull'asse
	for kind in ["scaglie", "movimento", "mosaico"]:
		var col: Color = {"scaglie": GOLD, "movimento": Color(WIND, 0.55), "mosaico": MOSAIC}[kind]
		var off: float = {"scaglie": -7.0, "movimento": 7.0, "mosaico": 0.0}[kind]
		var prev := Vector2(-1, -1)
		for i in data.size():
			var e: Dictionary = data[i].get(kind, {})
			if e.get("esito", "") == "al_pieno":
				draw_arc(Vector2(float(xs[i]) + off, ymap.call(0.0)), 9.0, 0.0, TAU, 20, col, 2.0)
				continue
			if not e.get("stimabile", false):
				# 0.5.9: punto non ancora stabile: anello velato al gradino più avanzato raggiunto
				var gm := int(data[i].get("gradino_max", {}).get(kind, -1))
				if gm >= 0:
					var q := Vector2(float(xs[i]) + off, ymap.call(float(gm)))
					draw_circle(q, 7.0, Color(col, 0.22))
					draw_arc(q, 7.0, 0.0, TAU, 20, Color(col, 0.75), 2.0)
				continue
			var p := Vector2(float(xs[i]) + off, ymap.call(float(e["indice"])))
			if prev.x >= 0.0:
				draw_line(prev, p, Color(col, 0.5), 2.0)
			draw_circle(p, 9.0, col)
			prev = p
	# 0.5.6: la legenda sta sulla riga del titolo, a destra, e non copre più i punti
	var lx := size.x - 680.0
	_text(Vector2(lx, 30), "● scales (contrast)", GOLD, 18)
	_text(Vector2(lx + 200, 30), "● mosaic (step)", MOSAIC, 18)
	_text(Vector2(lx + 475, 30), "● wind (retired)", Color(WIND, 0.55), 18)
	# 0.5.9: cosa vogliono dire i tre segni, sotto l'asse delle date
	_text(Vector2(pr.position.x, size.y - 6), "filled: settled bridge point  ·  faded: furthest step, point not settled yet  ·  hollow at the bottom: stuck at full aid", DIM, 17)
