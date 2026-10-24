extends Control
## Il menu della capanna del custode (training 0.4): un'interfaccia 2D disegnata dentro un
## SubViewport e mostrata su un pannello nel visore. Pagine: Capanna, Diario, Rovine (0.5),
## Bestiario, Obiettivi, Impostazioni. Tutto costruito da codice.
## 0.6: la pagina "test" (dal pulsante della Capanna, non dalle schede) avvia le sessioni del test.
## I pulsanti chiamano le pagine in differita (call_deferred): una pagina si ricostruisce
## liberando i nodi vecchi, e non si può liberare un pulsante dentro il suo stesso segnale.

signal action(name: String)         # "bosco", "lampo", "rovine", "esci", "test:<tipo>" (0.6)

const Paths := preload("res://scripts/paths.gd")
const Progress := preload("res://scripts/training/progress.gd")
const Storia := preload("res://scripts/training/storia.gd")
const Obiettivi := preload("res://scripts/training/obiettivi.gd")
const Grafico := preload("res://scripts/training/ui/grafico.gd")
const Misure := preload("res://scripts/training/rovine_misure.gd")
const Cielo := preload("res://scripts/training/rovine_cielo.gd")

const W := 1920
const H := 1080
const INK := Color(0.95, 0.92, 0.83)
const DIM := Color(0.95, 0.92, 0.83, 0.6)
const GOLD := Color(1.0, 0.86, 0.45)
const BRONZE := Color(0.62, 0.47, 0.26)
const MINT := Color(0.6, 1.0, 0.85)
const CONTRAST_MODES := ["giorno", "settimana", "mai"]   # 0.5.7: anche una volta a settimana
const CONTRAST_MODE_NAMES := {"giorno": "once a day", "settimana": "once a week", "mai": "never"}
const PAGES := ["capanna", "diario", "rovine", "bestiario", "obiettivi", "impostazioni"]
const PAGE_NAMES := {"capanna": "Hut", "diario": "Journal", "rovine": "Ruins", "bestiario": "Bestiary", "obiettivi": "Achievements", "impostazioni": "Settings"}
const DIARY_TABS := {"cielo": "Night sky", "zero": "Bias", "occhi": "Eyes", "rovine": "Ruins", "calendario": "Calendar", "test": "Test"}
const NIGHT_OPTIONS := [8, 10, 12, 15]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var prog: Progress
var storia: Storia
var ach := {}
var fresh: Array = []
var participant := ""
var today := ""
var desktop_warning := ""     # versione esportata avviata senza visore: lo dice in cima alla capanna
var page := "capanna"
var diary_tab := "cielo"
var beast_detail := ""
var ruin_detail := ""
var tab_buttons := {}
var content: MarginContainer
var textures := {}
var sel_style: StyleBoxFlat


func setup(p_prog: Progress, p_storia: Storia, p_ach: Dictionary, p_fresh: Array, p_participant: String, p_today: String) -> void:
	prog = p_prog
	storia = p_storia
	ach = p_ach
	fresh = p_fresh
	participant = p_participant
	today = p_today
	size = Vector2(W, H)
	theme = _make_theme()
	_build_frame()
	_show_page("capanna")


# ---------------------------------------------------------------- stile e cornice

func _style(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 28
	t.set_stylebox("normal", "Button", _style(Color(0.07, 0.09, 0.14, 0.92), BRONZE))
	t.set_stylebox("hover", "Button", _style(Color(0.18, 0.15, 0.09, 0.95), GOLD))
	t.set_stylebox("pressed", "Button", _style(Color(0.3, 0.23, 0.1, 0.95), GOLD))
	t.set_stylebox("disabled", "Button", _style(Color(0.05, 0.05, 0.07, 0.8), Color(BRONZE, 0.4)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	sel_style = _style(Color(0.26, 0.2, 0.09, 0.95), GOLD)
	return t


func _tex(path: String, thumb := 0) -> Texture2D:
	var key := "%s@%d" % [path, thumb]
	if textures.has(key):
		return textures[key]
	var img := Image.load_from_file(Paths.globalize(path))
	if img == null or img.is_empty():
		return null
	if thumb > 0:
		img.resize(thumb, int(thumb * float(img.get_height()) / img.get_width()), Image.INTERPOLATE_LANCZOS)
	var tx := ImageTexture.create_from_image(img)
	textures[key] = tx
	return tx


func _build_frame() -> void:
	var bg := TextureRect.new()
	bg.texture = _tex("res://assets/2d/ambienti/capanna_custode.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(W, H)
	bg.modulate = Color(0.85, 0.85, 0.9)
	add_child(bg)
	var panel := Panel.new()
	panel.position = Vector2(290, 118)
	panel.size = Vector2(1340, 930)
	panel.add_theme_stylebox_override("panel", _style(Color(0.03, 0.045, 0.08, 0.86), BRONZE, 18))
	add_child(panel)
	content = MarginContainer.new()
	content.size = panel.size
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(content)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(290, 28)
	tabs.size = Vector2(1340, 72)
	tabs.add_theme_constant_override("separation", 12)
	add_child(tabs)
	for p in PAGES:
		var b := Button.new()
		b.text = PAGE_NAMES[p]
		b.custom_minimum_size = Vector2(210, 72)
		b.pressed.connect(_go.bind(p))
		tabs.add_child(b)
		tab_buttons[p] = b


func _go(p: String) -> void:
	beast_detail = ""
	ruin_detail = ""
	call_deferred("_show_page", p)


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.free()


func _show_page(p: String) -> void:
	page = p
	for k in tab_buttons:
		if k == p:
			tab_buttons[k].add_theme_stylebox_override("normal", sel_style)
		else:
			tab_buttons[k].remove_theme_stylebox_override("normal")
	_clear()
	match p:
		"capanna":
			_page_home()
		"diario":
			_page_diary()
		"rovine":
			_page_ruins()
		"bestiario":
			_page_bestiary()
		"obiettivi":
			_page_achievements()
		"impostazioni":
			_page_settings()
		"test":
			_page_tests()


func _button(text: String, min_size: Vector2, cb: Callable, font := 28) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	b.pressed.connect(cb)
	return b


func _rich(text: String, font := 26) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", font)
	r.add_theme_font_size_override("bold_font_size", font)
	r.text = text
	r.custom_minimum_size = Vector2(1260, 0)
	return r


func _label(text: String, font := 28, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", col)
	return l


static func fmt_date(d: String) -> String:
	return "%s %d" % [MONTHS[clampi(d.substr(5, 2).to_int(), 1, 12) - 1], d.substr(8, 2).to_int()] if d.length() >= 10 else d


# ---------------------------------------------------------------- capanna

func _week_lanterns() -> int:
	return int(storia.lantern_weeks().get(Storia.week_of(today), 0))


func status_text() -> String:
	var lines := []
	if desktop_warning != "":
		lines.append("[color=#ff9f80]%s[/color]" % desktop_warning)
	lines.append("[font_size=36]Welcome back, %s.[/font_size]" % participant.capitalize())
	var est := storia.estimable_sessions()
	if not est.is_empty():
		var s: Dictionary = est[-1]
		var f: Dictionary = s["stima"]
		lines.append("Last estimate (%s): sensitivity [color=#ffdb73]~%d″[/color] (rough interval %d–%d″), bias %+d″." % [
			fmt_date(s["data"]), roundi(f["soglia79"]), roundi(f["soglia79_ic"][0]), roundi(f["soglia79_ic"][1]), roundi(f["zero"])])
	else:
		lines.append("No estimate yet: the forest is waiting for you.")
	var wl := _week_lanterns()
	lines.append("This week: %d %s out of 3%s" % [mini(wl, 3), "lantern" if mini(wl, 3) == 1 else "lanterns", "." if wl < 3 else ": a full week!"])
	var m_today := float(storia.days.get(today, 0.0))
	if m_today >= 1.0:
		lines.append("Today you played %d %s%s" % [roundi(m_today), "minute" if roundi(m_today) == 1 else "minutes", "." if m_today < 60.0 else ": the forest suggests you rest your eyes for today."])
	lines.append(ruins_status())
	for o in fresh:
		lines.append("[color=#99ffd9]New achievement: %s[/color]" % o["nome"])
	return "\n".join(lines)


func _page_home() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	content.add_child(v)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", -16)
	v.add_child(head)
	var title := TextureRect.new()
	title.texture = _tex("res://assets/2d/ui/titolo.png", 1024)
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size = Vector2(1260, 205)
	head.add_child(title)
	var subtitle := _label("The Firefly Forest", 30, GOLD)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(subtitle)
	v.add_child(_rich(status_text(), 27))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	row.add_child(_button("Enter the forest", Vector2(400, 110), func(): action.emit("bosco"), 34))
	row.add_child(_button("Down to the ruins", Vector2(400, 110), func(): action.emit("rovine"), 34))
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row2)
	row2.add_theme_constant_override("separation", 30)
	row2.add_child(_button("Stereopsis test", Vector2(400, 64), _go.bind("test"), 26))
	row2.add_child(_button("Quit", Vector2(220, 64), func(): action.emit("esci"), 26))
	v.add_child(_rich("[color=#ffffff99]Stop and see an eye doctor if you see double outside the headset, if headaches or eye strain don't go away, or if your vision changes. In the headset: the wand points, the trigger selects, the thumbstick scrolls lists, the grip button brings the panel back in front of you.[/color]", 20))


# ---------------------------------------------------------------- diario

func _set_tab(t: String) -> void:
	diary_tab = t
	call_deferred("_show_page", "diario")


func _page_diary() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	content.add_child(v)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	for t in DIARY_TABS:
		var b := _button(DIARY_TABS[t], Vector2(200, 56), _set_tab.bind(t), 22)
		if t == diary_tab:
			b.add_theme_stylebox_override("normal", sel_style)
		tabs.add_child(b)
	match diary_tab:
		"cielo":
			var g := _chart(Vector2(1280, 590))
			g.set_data("cielo", storia.nights, {}, "One star per night")
			v.add_child(g)
			var n_no := 0
			for n in storia.nights:
				if not n["stima"].get("stimabile", false):
					n_no += 1
			v.add_child(_rich("Higher is finer: the depth difference you can tell apart 8 times out of 10, setting your side bias aside. The bar is the rough interval. [color=#9ebde6]Blue[/color] stars come from early versions of the game, with less controlled geometry. A single night can swing by about 20–25%%: the trend matters, not any one star. The dashed lines are the species thresholds.%s" % (
				("\nNights without an estimate (too short): %d." % n_no) if n_no > 0 else ""), 22))
		"zero":
			var g := _chart(Vector2(1280, 540))
			g.set_data("zero", storia.nights, {}, "Bias: how much nearer the right one looks at equal depth")
			v.add_child(g)
			var txt := "Zero means no bias. On its own it can't tell a difference in what you see from a preference in how you answer."
			var tw := []
			for s in storia.sessions:
				if int(s["gemelle"][1]) > 0:
					tw.append("%s %d/%d" % [fmt_date(s["data"]), s["gemelle"][0], s["gemelle"][1]])
			if not tw.is_empty():
				txt += "\nTwins at the same distance, touched on the right: " + ", ".join(tw) + "."
			for l in storia.lampo:
				txt += "\n[color=#ffdb73]Flash fireflies (%s):[/color] " % fmt_date(str(l.get("data", "")).substr(0, 10))
				for ex in ["lampo", "libero"]:
					var f: Dictionary = l.get(ex, {}).get("stima", {})
					txt += "%s: %s. " % ["with flash" if ex == "lampo" else "free viewing",
						("bias %+d″ (%+d…%+d″)" % [roundi(f["zero"]), roundi(f["zero_ic"][0]), roundi(f["zero_ic"][1])]) if f.get("stimabile", false) and f.has("zero_ic") else "no estimate available"]
			v.add_child(_rich(txt, 22))
		"occhi":
			var g1 := _chart(Vector2(1280, 330))
			g1.set_data("contrasto", storia.contrasto, {}, "Contrast between the eyes: the light it takes for two fireflies to look the same")
			v.add_child(g1)
			var g2 := _chart(Vector2(1280, 300))
			g2.set_data("fatui", storia.fatui, {}, "Will-o'-wisps: how strong a trick you resist (hollow ring: not settled yet)")
			v.add_child(g2)
			v.add_child(_rich("Contrast: each small dot is one repeat, the big one is the median of the valid repeats; it is an index to follow over time, not a diagnosis. A dashed line marks the start of a new series (the fireflies move to a new place): different series can't be compared. Gray rings are measurements marked invalid after the session, not buttons pressed during the match. Will-o'-wisps: under each session, the ones you unmasked out of the ones you met.", 21))
		"rovine":
			var g1 := _chart(Vector2(1280, 270))
			g1.set_data("sonde", storia.rovine, {}, "Bare stone: correct probes per session (the real target)")
			v.add_child(g1)
			var g2 := _chart(Vector2(1280, 290))
			g2.set_data("ponte", storia.rovine, {}, "The bridge: how far you get on each path")
			v.add_child(g2)
			v.add_child(_rich(ruins_diary_text(), 20))
		"calendario":
			var g := _chart(Vector2(1280, 620))
			g.set_data("calendario", [], {"settimane": calendar_weeks(), "giorni": storia.days, "oggi": today}, "Your lanterns, week by week")
			v.add_child(g)
			v.add_child(_rich("One lantern for each day with at least 10 minutes of play (forest or ruins). The goal is three days a week, the schedule of the training studies that worked.", 22))
		"test":
			v.add_child(_rich(tests_text(), 23))


## Settimane del calendario: dalla prima settimana di gioco (al più le ultime 8) fino a questa.
func calendar_weeks() -> Array:
	var w_now := Storia.week_of(today)
	var t_now := Time.get_unix_time_from_datetime_string(w_now + "T12:00:00")
	var first := storia.first_day()
	var t_first := t_now
	if first != "":
		t_first = minf(t_now, Time.get_unix_time_from_datetime_string(Storia.week_of(first) + "T12:00:00"))
	var n := clampi(roundi((t_now - t_first) / (7.0 * 86400.0)) + 1, 1, 8)
	var weeks := []
	for i in range(n - 1, -1, -1):
		weeks.append(Time.get_date_string_from_unix_time(t_now - i * 7 * 86400))
	return weeks


func _chart(sz: Vector2) -> Control:
	var g: Control = Grafico.new()
	g.custom_minimum_size = sz
	return g


## Pagina del test (0.6): le sessioni del test partono da qui e, finite, riportano nella capanna.
const TEST_SESSIONS := [
	["standard", "Standard", "rings and random-dot · ~20 min"],
]
const TEST_TYPE_NAMES := {"standard": "standard", "anelli": "fixed rings", "grossolana": "coarse", "mappa": "map",
	"grande": "large-disc check", "mille": "1000″ check"}


func _page_tests() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	content.add_child(v)
	v.add_child(_label("The stereopsis test", 40, GOLD))
	v.add_child(_rich("The measuring tool, kept apart from the game: rings (local stereopsis) and random-dot (global stereopsis). Take it once before you play and, if you keep training, every two weeks. When a session ends you come back here; to stop early, hold B or Y.", 24))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 18)
	v.add_child(grid)
	for t in TEST_SESSIONS:
		var b := _button("%s\n%s" % [t[1], t[2]], Vector2(620, 110), func(): action.emit("test:" + t[0]), 28)
		b.name = "test_" + t[0]
		grid.add_child(b)
	v.add_child(_rich(tests_text(4), 21))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(_button("Back to the hut", Vector2(360, 64), _go.bind("capanna"), 26))


func tests_text(last := 0) -> String:
	if storia.tests.is_empty():
		return "No stereopsis tests found."
	var names := {"measured": "measured", "above": "beyond the largest disparity tried", "below": "below the smallest tried",
		"flat": "not measurable", "inconclusive": "inconclusive", "wide": "estimate too uncertain",
		"unmeasurable": "not measurable", "uncertain": "too uncertain", "no_data": "no data"}
	var lines := ["[font_size=28]The stereopsis test, outside the forest[/font_size]", "This is where the training is checked: the same test, every two weeks. Rings measure local stereopsis, random-dot global stereopsis.", ""]
	if last > 0:
		lines = ["[font_size=26]Latest tests[/font_size]"]
	var shown: Array = storia.tests if last <= 0 else storia.tests.slice(maxi(0, storia.tests.size() - last))
	for t in shown:
		var parts := []
		if t.has("rings"):
			var r: Dictionary = t["rings"]
			parts.append("rings %s" % (("~%d″ (%d–%d″)" % [roundi(r["q50"]), roundi(r["q025"]), roundi(r["q975"])]) if r["esito"] == "measured" else names.get(r["esito"], r["esito"])))
		for c in ["rings_fixed", "rds", "rds_coarse", "rds_mappa", "rds_grande", "rds_grande_40", "rds_1000_40"]:
			if t.has(c):
				var d: Dictionary = t[c]
				var nm: String = {"rings_fixed": "fixed rings", "rds": "random-dot", "rds_coarse": "coarse random-dot", "rds_mappa": "random-dot map", "rds_grande": "large random-dot map", "rds_grande_40": "large-disc check", "rds_1000_40": "1000″ check"}[c]
				if d.has("esito"):
					parts.append("%s %s" % [nm, names.get(d["esito"], d["esito"])])
				else:
					var cells := []
					var keys: Array = d["celle"].keys()
					keys.sort()
					for k in keys:
						cells.append("%d″ %d/%d" % [roundi(pow(10.0, str(k).to_float())), int(d["celle"][k][0]), int(d["celle"][k][1])])
					parts.append("%s: %s (chance 1 in %d)" % [nm, ", ".join(cells), 2 if c == "rings_fixed" else 4])
		lines.append("[color=#ffdb73]%s[/color] · %s %s · %s" % [fmt_date(t["data"]), t["protocollo"], TEST_TYPE_NAMES.get(str(t["tipo"]), t["tipo"]), "; ".join(parts)])
	return "\n".join(lines)


# ---------------------------------------------------------------- rovine (0.5)

func ruins_status() -> String:
	var n_rest := Misure.restored_ids(prog.data).size()
	if storia.rovine.is_empty():
		return "[color=#99ffd9]The ruins are open.[/color] Four creatures in the stone, one in front: one trial in five is bare stone, like the random-dot in the test."
	var ap := Misure.all_probes(storia.rovine)
	return "Ruins: %d of %d pieces restored · bare stone %d of %d (%d%%, chance 25%%)." % [n_rest, Misure.PEZZI.size(),
		ap["k"], ap["n"], roundi(100.0 * float(ap["quota"]))]


## 0.5.13: oltre 100 il pezzo è già restaurato; il numero intero traboccava sopra 9,2·10^18.
static func fmt_e(e: float) -> String:
	return "over 100" if e >= 100.0 else ("%.1f" % e)


func ruins_diary_text() -> String:
	var ap := Misure.all_probes(storia.rovine)
	var rp := Misure.recent_probes(storia.rovine)
	# 0.5.13: tolta l'evidenza contro il caso (19/10); portale e torre la usano ancora per aprirsi
	var txt := "Bare stone: %s%s." % [Misure.fmt_probes(ap), ("; last 100: " + Misure.fmt_probes(rp)) if int(ap["n"]) > Misure.PROBE_WINDOW else ""]
	var av := Misure.all_seen(storia.rovine)
	if av["con_segno"]:
		var mos_av := int(av["mosaico"][0][1]) + int(av["mosaico"][1][1]) > 0
		txt += "\nReally seen (trigger), correct out of answered, over %d %s: probes %s; scales %s%s." % [av["sessioni"],
			"session" if int(av["sessioni"]) == 1 else "sessions", Misure.fmt_seen(av, "sonda"), Misure.fmt_seen(av, "scaglie"),
			("; mosaic " + Misure.fmt_seen(av, "mosaico")) if mos_av else ""]
	# 0.5.6: mosaico e polarità
	var best := -1
	for r in storia.rovine:
		best = maxi(best, int(r.get("mosaico_max", -1)))
	var apz := Misure.all_polarity(storia.rovine)
	var n_pol := int(apz["scuri"][1]) + int(apz["chiari"][1])
	if best >= 0 or n_pol > 0:
		txt += "\n" + "; ".join(([("Mosaic, furthest point: " + Misure.fmt_rung(best))] if best >= 0 else [])
			+ ([("polarity (outside the staircase): " + Misure.fmt_polarity(apz))] if n_pol > 0 else [])) + "."
	if not storia.rovine_escluse.is_empty():
		var ex := []
		for x in storia.rovine_escluse:
			ex.append("%s (%s)" % [x["file"], Misure.reason_en(str(x["motivo"]))])
		txt += "\n[color=#ff9f80]Files left out of the measurements: %s.[/color]" % "; ".join(ex)
	txt += "\n[color=#ffffff99]Probes: the test's random-dot, with no aids. Bridge: the aid you need to find the creature 8 times out of 10; on the mosaic, the step, from 0 (large format) to 9 (bare stone, 1000″) and beyond, up to 21 (251″).[/color]"
	return txt


## Tavola di un pezzo: quella dipinta (tavole_dipinte/<id>.png) se c'è, altrimenti la coppia
## procedurale restaurato/in rovina. Restituisce [texture, colore di modulazione].
func _piece_tex(id: String, done: bool, thumb: int) -> Array:
	var painted := "res://assets/2d/rovine/tavole_dipinte/%s.png" % id
	if FileAccess.file_exists(Paths.globalize(painted)):
		return [_tex(painted, thumb), Color.WHITE if done else Color(0.16, 0.16, 0.2)]
	# 0.5.13: l'osservatorio non ha tavole dipinte, e il suo sito in rovina, al buio, non si vedeva: da
	# restaurare si mostra la tappa che verrà, in penombra (come le tavole dipinte)
	for pz in Misure.PEZZI:
		if pz["id"] == id and pz.has("gruppo"):
			return [_tex("res://assets/2d/rovine/tavole/%s.png" % id, thumb), Color.WHITE if done else Color(0.4, 0.4, 0.48)]
	return [_tex("res://assets/2d/rovine/tavole/%s%s.png" % [id, "" if done else "_rovina"], thumb), Color.WHITE if done else Color(0.55, 0.55, 0.62)]


func _open_piece(id: String) -> void:
	ruin_detail = id
	call_deferred("_show_page", "rovine")


func _panorama_strip() -> Texture2D:
	var key := "panorama@" + ",".join(Misure.restored_ids(prog.data))
	if textures.has(key):
		return textures[key]
	var img := Cielo.compose(Misure.restored_ids(prog.data), 2048)
	if img == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = ImageTexture.create_from_image(img)
	at.region = Rect2(0, 330, 2048, 230)     # la fascia dell'orizzonte, con le rovine
	textures[key] = at
	return at


func _page_ruins() -> void:
	var restored := Misure.restored_ids(prog.data)
	if ruin_detail != "":
		for pz in Misure.PEZZI:
			if pz["id"] == ruin_detail:
				_piece_card(pz, pz["id"] in restored)
				return
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	content.add_child(v)
	v.add_child(_label("The Ruins: %d of %d pieces restored" % [restored.size(), Misure.PEZZI.size()], 30, GOLD))
	var strip := TextureRect.new()
	strip.texture = _panorama_strip()
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.custom_minimum_size = Vector2(1280, 144)
	v.add_child(strip)
	v.add_child(_rich("[color=#ffffffaa]Each piece rises again with measured progress: a bridge step passed in two sessions in a row, or the bare stone above chance with enough evidence. Without progress the ruins simply wait, and nothing is lost.[/color]", 20))
	# 0.5.13: dodici pezzi (con l'osservatorio) in due file da sei, invece di otto in due file da quattro
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var res := Misure.evaluate_pieces(storia.rovine)
	for pz in Misure.PEZZI:
		var done: bool = pz["id"] in restored
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var tb := TextureButton.new()
		var pt := _piece_tex(pz["id"], done, 200)
		tb.texture_normal = pt[0]
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.custom_minimum_size = Vector2(200, 176)
		tb.name = "pezzo_" + pz["id"]
		tb.modulate = pt[1]
		tb.pressed.connect(_open_piece.bind(pz["id"]))
		cell.add_child(tb)
		var l := _label(pz["nome"], 19, GOLD if done else INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(200, 50)
		cell.add_child(l)
		var r: Dictionary = res.get(pz["id"], {})
		var st := ""
		if done:
			st = "restored %s" % fmt_date(str(prog.data["rovine"]["pezzi"][pz["id"]]))
		elif r.has("e"):
			st = "evidence %s of 100" % fmt_e(float(r["e"]))
		else:
			st = "%d of %d sessions in a row" % [r.get("cur", 0), r.get("max", 1)]
		var sl := _label(st, 16, MINT if done else DIM)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(200, 0)
		cell.add_child(sl)
		grid.add_child(cell)


func _piece_card(pz: Dictionary, done: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	content.add_child(h)
	var img := TextureRect.new()
	var pt := _piece_tex(pz["id"], done, 620)
	img.texture = pt[0]
	img.modulate = pt[1]
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(620, 620)
	h.add_child(img)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	h.add_child(v)
	v.add_child(_label(pz["nome"], 38, GOLD))
	var r := _rich(pz["storia"] if done else "Still in ruins.", 26)
	r.custom_minimum_size = Vector2(600, 0)
	v.add_child(r)
	var hint := _rich("[color=#ffffff88]%s[/color]" % Misure.hint(pz), 21)
	hint.custom_minimum_size = Vector2(600, 0)
	v.add_child(hint)
	v.add_child(_button("Back to the ruins", Vector2(360, 70), _go.bind("rovine"), 26))


# ---------------------------------------------------------------- bestiario

func _open_beast(id: String) -> void:
	beast_detail = id
	call_deferred("_show_page", "bestiario")


static func unlock_hint(sp: Dictionary) -> String:
	var c: Dictionary = sp["soglia"]
	if c.is_empty():
		return "Here from the start."
	if c.has("catture"):
		return "Shows up after %d catches." % int(c["catture"])
	if c.has("senza_rotelle"):
		return "Shows up when you play without training wheels."
	if c.has("soglia_sotto"):
		return "Shows up when your estimated sensitivity is below %d″." % roundi(float(c["soglia_sotto"]))
	if c.has("fatui"):
		return "Shows up once you unmask a will-o'-wisp."
	return ""


func _page_bestiary() -> void:
	if beast_detail != "":
		for sp in Progress.SPECIES:
			if sp["id"] == beast_detail:
				_beast_card(sp)
				return
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	content.add_child(v)
	v.add_child(_label("Species discovered: %d of %d" % [storia.species.size(), Progress.SPECIES.size()], 30, GOLD))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for sp in Progress.SPECIES:
		var known: bool = sp["id"] in storia.species
		var cell := VBoxContainer.new()
		var tb := TextureButton.new()
		tb.texture_normal = _tex("res://assets/2d/bestiario/%s.png" % sp["id"], 300)
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.custom_minimum_size = Vector2(296, 296)
		if not known:
			tb.modulate = Color(0.06, 0.06, 0.09)
		tb.pressed.connect(_open_beast.bind(sp["id"]))
		tb.name = "specie_" + sp["id"]
		cell.add_child(tb)
		var l := _label(sp["nome"] if known else "???", 24, INK if known else DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(296, 0)
		cell.add_child(l)
		if not known:
			var hl := _label(unlock_hint(sp), 17, DIM)
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hl.custom_minimum_size = Vector2(296, 0)
			cell.add_child(hl)
		grid.add_child(cell)


func _beast_card(sp: Dictionary) -> void:
	var known: bool = sp["id"] in storia.species
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	content.add_child(h)
	var img := TextureRect.new()
	img.texture = _tex("res://assets/2d/bestiario/%s.png" % sp["id"], 640)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(640, 640)
	if not known:
		img.modulate = Color(0.06, 0.06, 0.09)
	h.add_child(img)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	h.add_child(v)
	v.add_child(_label(sp["nome"] if known else "Species not yet discovered", 40, GOLD))
	var r := _rich(sp["storia"] if known else unlock_hint(sp), 27)
	r.custom_minimum_size = Vector2(580, 0)
	v.add_child(r)
	if known:
		var hint := _rich("[color=#ffffff88]%s[/color]" % unlock_hint(sp), 21)
		hint.custom_minimum_size = Vector2(580, 0)
		v.add_child(hint)
	v.add_child(_button("Back to the Bestiary", Vector2(360, 70), _go.bind("bestiario"), 26))


# ---------------------------------------------------------------- obiettivi

func _page_achievements() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	content.add_child(v)
	var got: Dictionary = prog.data.get("obiettivi", {})
	v.add_child(_label("Achievements earned: %d of %d · the thumbstick scrolls the list" % [got.size(), Obiettivi.LIST.size()], 28, GOLD))
	var scroll := ScrollContainer.new()
	scroll.name = "lista"
	scroll.custom_minimum_size = Vector2(1280, 800)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	var fams := ["costanza", "scoperta", "abilita", "curiosita"]
	for fam in fams:
		for o in Obiettivi.LIST:
			if o["fam"] != fam:
				continue
			var ok: bool = got.has(o["id"])
			var hidden: bool = o.get("nascosto", false) and not ok
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 14)
			h.custom_minimum_size = Vector2(620, 92)
			var icon := TextureRect.new()
			icon.texture = _tex(Obiettivi.FAMILIES[fam]["icona"], 128)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(80, 80)
			if not ok:
				icon.modulate = Color(0.28, 0.28, 0.32)
			h.add_child(icon)
			var t := VBoxContainer.new()
			t.add_theme_constant_override("separation", 0)
			t.custom_minimum_size = Vector2(520, 0)
			h.add_child(t)
			t.add_child(_label("???" if hidden else o["nome"], 25, GOLD if ok else INK))
			var dl := _label("Hidden achievement: you'll find it by playing." if hidden else o["descr"], 19, DIM)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dl.custom_minimum_size = Vector2(520, 0)
			t.add_child(dl)
			var r: Dictionary = ach.get(o["id"], {})
			var st := ""
			if ok:
				st = "earned %s" % fmt_date(str(got[o["id"]]))
			elif not hidden and int(r.get("max", 1)) > 1:
				st = "%d of %d" % [int(r.get("cur", 0)), int(r.get("max", 1))]
			if st != "":
				t.add_child(_label(st, 18, MINT if ok else DIM))
			grid.add_child(h)


# ---------------------------------------------------------------- impostazioni

func _setting_rows() -> Array:
	var d: Dictionary = prog.data
	return [
		["Music", "%d%%" % roundi(float(d.get("musica_volume", 0.7)) * 100.0), "musica_volume"],
		["Sound effects", "%d%%" % roundi(float(d.get("suoni_volume", 0.5)) * 100.0), "suoni_volume"],
		["Firefly height", "%d° below eye level" % roundi(-float(d.get("elevazione", -12.0))), "elevazione"],
		["Night length", "%d minutes" % int(d.get("durata_notte_min", 12)), "durata_notte_min"],
		["Contrast match", CONTRAST_MODE_NAMES.get(str(d.get("contrasto_modo", "giorno")), "once a day"), "contrasto_modo"],
	]


func change_setting(key: String, dir: int) -> void:
	var d: Dictionary = prog.data
	match key:
		"musica_volume", "suoni_volume":
			d[key] = clampf(snappedf(float(d.get(key, 0.7 if key == "musica_volume" else 0.5)) + 0.1 * dir, 0.1), 0.0, 1.0)
		"elevazione":
			d[key] = clampf(float(d.get(key, -12.0)) + 2.0 * dir, -25.0, 0.0)
		"durata_notte_min":
			var i := NIGHT_OPTIONS.find(int(d.get(key, 12)))
			d[key] = NIGHT_OPTIONS[clampi((i if i >= 0 else 2) + dir, 0, NIGHT_OPTIONS.size() - 1)]
		"contrasto_modo":
			var ci := CONTRAST_MODES.find(str(d.get(key, "giorno")))
			d[key] = CONTRAST_MODES[clampi((ci if ci >= 0 else 0) + dir, 0, CONTRAST_MODES.size() - 1)]
	prog.save()
	call_deferred("_show_page", "impostazioni")


func _page_settings() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	content.add_child(v)
	v.add_child(_label("Forest settings", 34, GOLD))
	for row in _setting_rows():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		v.add_child(h)
		var l := _label(row[0], 30)
		l.custom_minimum_size = Vector2(440, 0)
		h.add_child(l)
		h.add_child(_button("−", Vector2(90, 72), change_setting.bind(row[2], -1), 34))
		var val := _label(row[1], 30, GOLD)
		val.custom_minimum_size = Vector2(380, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(val)
		h.add_child(_button("+", Vector2(90, 72), change_setting.bind(row[2], 1), 34))
	v.add_child(_rich("Changes apply from the next night. The length changes the dose: 12 minutes is the reference, and the end-of-session estimate stays comparable because it only uses trials without training wheels. The contrast match takes a minute and adds one more piece of data about your vision: keeping it on is recommended.", 22))
