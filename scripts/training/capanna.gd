extends Node3D
## La capanna del custode (training 0.4): punto d'ingresso del training. Cielo notturno dipinto
## tutt'intorno (a distanza infinita: disparità nulla) e, davanti, un grande pannello con il menu
## disegnato in un SubViewport. Col visore si punta con la bacchetta (posa "aim") e si sceglie col
## grilletto; la levetta scorre le liste; il tasto laterale riporta il pannello davanti. Sul
## desktop si usa il mouse.
## Il bosco resta com'era: il cielo dipinto sta solo qui, perché lo sfondo del bosco fa parte
## della configurazione di riferimento delle prove.
## 0.5: da qui si scende anche nelle rovine (mondo 2, rovine.gd).
## 0.5.5 (con il test 0.6.0): è l'ingresso unico dell'app. Dalla pagina "Test della stereopsi" partono le sessioni del
## test (scenes/main.tscn), che a fine sessione riportano qui: niente riavvii di SteamVR.

const Paths := preload("res://scripts/paths.gd")
const VERSION := "training-0.5.5"
const Progress := preload("res://scripts/training/progress.gd")
const Storia := preload("res://scripts/training/storia.gd")
const Obiettivi := preload("res://scripts/training/obiettivi.gd")
const Menu := preload("res://scripts/training/ui/menu.gd")
const Misure := preload("res://scripts/training/rovine_misure.gd")

const PANEL_W := 3.2
const PANEL_H := 1.8
const PANEL_DIST := 2.1
const VIEW_W := 1920
const VIEW_H := 1080

var xr_active := false
var autotest := false
var participant := "player"
var mode_name := "desktop"
var results_dir := ""
var test_dir := ""
var prog := Progress.new()
var storia := Storia.new()
var ach := {}
var fresh: Array = []
var today := ""

var origin: XROrigin3D
var camera: Node3D
var controllers: Array[XRController3D] = []
var rays: Array[MeshInstance3D] = []
var dots: Array[MeshInstance3D] = []
var trigger_prev := {}
var grip_prev := {}
var by_prev := {}
var active_ctrl := 1
var panel: MeshInstance3D
var sub: SubViewport
var menu: Control
var placed := false
var place_timer := 0.4
var last_px := Vector2(-1, -1)
var mouse_down := false
var no_switch := false          # nei test: registra l'azione senza cambiare scena
var last_action := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	autotest = "--autotest" in args
	for a in args:
		if a.begins_with("--partecipante="):
			participant = a.split("=")[1]
	var opts: Dictionary = get_tree().root.get_meta("capanna_opts", {}) if get_tree().root.has_meta("capanna_opts") else {}
	participant = _sanitize(str(opts.get("partecipante", participant)))
	var xr := XRServer.find_interface("OpenXR") as OpenXRInterface
	xr_active = xr != null and xr.is_initialized() and not autotest
	mode_name = "autotest" if autotest else ("vr" if xr_active else "desktop")
	today = Time.get_date_string_from_system()
	var base := "res://results/"
	if mode_name == "desktop":
		results_dir = Paths.globalize(base + "desktop/" + participant + "/training/")
	elif mode_name == "autotest":
		results_dir = Paths.globalize(base + "autotest/training/")
	else:
		results_dir = Paths.globalize(base + participant + "/training/")
	test_dir = Paths.globalize(base + participant + "/")
	_load_data()
	_build_world()
	_build_panel()
	if autotest:
		print("CAPANNA_RESULT pagine=%d notti=%d obiettivi=%d" % [Menu.PAGES.size(), storia.nights.size(), prog.data.get("obiettivi", {}).size()])
		get_tree().quit()


static func _sanitize(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
	return "anonimo" if out.is_empty() else out


func _load_data() -> void:
	DirAccess.make_dir_recursive_absolute(results_dir)
	prog.load_from(results_dir + "profilo.json")
	storia.load_all(results_dir, test_dir, prog.data)
	# 0.5: il restauro si ricalcola anche dalla storia (vale per sessioni chiuse male)
	var fresh_pieces := Misure.update_pieces(prog.data, Misure.evaluate_pieces(storia.rovine), today)
	storia.pezzi_restaurati = Misure.restored_ids(prog.data).size()
	ach = Obiettivi.evaluate(storia)
	fresh = Obiettivi.update_profile(prog.data, ach, today)
	if not fresh.is_empty() or not fresh_pieces.is_empty():
		prog.save()


# ---------------------------------------------------------------- mondo

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var img := Image.load_from_file(Paths.globalize("res://assets/2d/ambienti/cielo_notturno.png"))
	if img != null and not img.is_empty():
		var sky_mat := PanoramaSkyMaterial.new()
		sky_mat.panorama = ImageTexture.create_from_image(img)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.environment.background_mode = Environment.BG_SKY
		env.environment.sky = sky
	else:
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.012, 0.02, 0.045)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	add_child(env)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 30.0
	disc.bottom_radius = 30.0
	disc.height = 0.02
	ground.mesh = disc
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.albedo_color = Color(0.006, 0.008, 0.012)
	ground.material_override = gmat
	ground.position = Vector3(0, -0.01, 0)
	add_child(ground)
	origin = XROrigin3D.new()
	add_child(origin)
	if xr_active:
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		origin.current = true
		var cam := XRCamera3D.new()
		cam.near = 0.03
		cam.far = 200.0
		origin.add_child(cam)
		cam.current = true
		camera = cam
		for hand in ["left_hand", "right_hand"]:
			var ctrl := XRController3D.new()
			ctrl.tracker = StringName(hand)
			ctrl.pose = &"aim"
			origin.add_child(ctrl)
			controllers.append(ctrl)
			trigger_prev[ctrl] = true      # il grilletto ancora giù dal bosco non deve cliccare
			grip_prev[ctrl] = true
			by_prev[ctrl] = true
			_make_ray(ctrl)
	else:
		var cam := Camera3D.new()
		cam.fov = 70.0
		cam.near = 0.03
		cam.far = 200.0
		cam.position = Vector3(0, 1.6, 0)
		origin.add_child(cam)
		cam.current = true
		camera = cam


func _make_ray(ctrl: XRController3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.9, 0.6, 0.45)
	var ray := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0015
	cyl.bottom_radius = 0.0015
	cyl.height = 1.0
	ray.mesh = cyl
	ray.material_override = mat
	ray.rotation_degrees = Vector3(90, 0, 0)
	ray.visible = false
	ctrl.add_child(ray)
	rays.append(ray)
	var dot := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.012
	sph.height = 0.024
	dot.mesh = sph
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color(1.0, 0.95, 0.75)
	dmat.no_depth_test = true
	dot.material_override = dmat
	dot.visible = false
	add_child(dot)
	dots.append(dot)


func _build_panel() -> void:
	sub = SubViewport.new()
	sub.size = Vector2i(VIEW_W, VIEW_H)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.transparent_bg = false
	sub.gui_embed_subwindows = true
	add_child(sub)
	menu = Menu.new()
	sub.add_child(menu)
	if mode_name == "desktop" and OS.has_feature("vr_release"):
		menu.desktop_warning = "VR is not active: this is only a desktop preview, not a measurement. Close this window, connect your headset, start SteamVR, and open the app with Start Stereopsis VR.cmd."
	menu.setup(prog, storia, ach, fresh, participant, today)
	menu.action.connect(_on_action)
	panel = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(PANEL_W, PANEL_H)
	panel.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = sub.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	panel.material_override = mat
	add_child(panel)
	_place_panel()


## Pannello davanti alla testa (solo la direzione orizzontale), poco sotto l'altezza degli occhi.
func _place_panel() -> void:
	var t := camera.global_transform
	var fwd := -t.basis.z
	fwd.y = 0.0
	if fwd.length() < 1e-3:
		fwd = Vector3(0, 0, -1)
	fwd = fwd.normalized()
	var center := t.origin + fwd * PANEL_DIST + Vector3(0, -0.12, 0)
	panel.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), center)   # la faccia (+Z) guarda chi gioca


# ---------------------------------------------------------------- puntatore

## Punto del pannello colpito da un raggio, in pixel del menu; (-1, -1) se fuori.
func hit_pixel(from: Vector3, dir: Vector3) -> Vector2:
	var inv := panel.global_transform.affine_inverse()
	var o := inv * from
	var d := inv.basis * dir
	if absf(d.z) < 1e-6:
		return Vector2(-1, -1)
	var k := -o.z / d.z
	if k <= 0.0:
		return Vector2(-1, -1)
	var p := o + d * k
	var u := p.x / PANEL_W + 0.5
	var v := 0.5 - p.y / PANEL_H
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2(-1, -1)
	return Vector2(u * VIEW_W, v * VIEW_H)


## Posizione nel mondo di un pixel del menu (per i test e per il punto del raggio).
func pixel_to_world(px: Vector2) -> Vector3:
	var local := Vector3((px.x / VIEW_W - 0.5) * PANEL_W, (0.5 - px.y / VIEW_H) * PANEL_H, 0.0)
	return panel.global_transform * local


func pointer(px: Vector2, pressed_now: bool, released_now: bool) -> void:
	if px.x < 0.0:
		return
	var mm := InputEventMouseMotion.new()
	mm.position = px
	mm.global_position = px
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT if mouse_down else 0
	if last_px.x >= 0.0:
		mm.relative = px - last_px
	sub.push_input(mm, true)
	last_px = px
	if pressed_now or released_now:
		var mb := InputEventMouseButton.new()
		mb.position = px
		mb.global_position = px
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed_now
		mouse_down = pressed_now
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed_now else 0
		sub.push_input(mb, true)


func click(px: Vector2) -> void:
	pointer(px, true, false)
	pointer(px, false, true)


func scroll(px: Vector2, amount: float) -> void:
	if px.x < 0.0:
		return
	var mb := InputEventMouseButton.new()
	mb.position = px
	mb.global_position = px
	mb.button_index = MOUSE_BUTTON_WHEEL_UP if amount > 0.0 else MOUSE_BUTTON_WHEEL_DOWN
	mb.factor = absf(amount)
	mb.pressed = true
	sub.push_input(mb, true)
	var mr := mb.duplicate()
	mr.pressed = false
	sub.push_input(mr, true)


func _process(delta: float) -> void:
	if xr_active and not placed:
		place_timer -= delta
		if place_timer <= 0.0:
			_place_panel()
			placed = true
	if not xr_active:
		return
	for i in controllers.size():
		var ctrl := controllers[i]
		if not ctrl.get_is_active():
			rays[i].visible = false
			dots[i].visible = false
			continue
		var t := ctrl.global_transform
		var px := hit_pixel(t.origin, -t.basis.z)
		var trig := ctrl.is_button_pressed("trigger_click") or ctrl.is_button_pressed("ax_button")
		var grip := ctrl.is_button_pressed("grip_click") or ctrl.get_float("grip") > 0.85
		var by := ctrl.is_button_pressed("by_button")
		if trig and not trigger_prev[ctrl]:
			active_ctrl = i
		if px.x >= 0.0:
			var hit := pixel_to_world(px)
			var dist := t.origin.distance_to(hit)
			rays[i].visible = true
			rays[i].scale = Vector3(1, dist, 1)
			rays[i].position = Vector3(0, 0, -dist * 0.5)
			dots[i].visible = true
			dots[i].global_position = hit
			if i == active_ctrl:
				pointer(px, trig and not trigger_prev[ctrl], not trig and trigger_prev[ctrl])
				var sy: float = ctrl.get_vector2("primary").y
				if absf(sy) > 0.5:
					scroll(px, sy * delta * 12.0)
		else:
			rays[i].visible = true
			rays[i].scale = Vector3(1, 1.5, 1)
			rays[i].position = Vector3(0, 0, -0.75)
			dots[i].visible = false
		if grip and not grip_prev[ctrl]:
			_place_panel()
		if by and not by_prev[ctrl] and menu.page != "capanna":
			menu._go("capanna")
		trigger_prev[ctrl] = trig
		grip_prev[ctrl] = grip
		by_prev[ctrl] = by


func _unhandled_input(event: InputEvent) -> void:
	if xr_active:
		return
	var mouse := event as InputEventMouse
	if mouse != null and camera is Camera3D:
		var cam := camera as Camera3D
		var px := hit_pixel(cam.project_ray_origin(mouse.position), cam.project_ray_normal(mouse.position))
		var mb := event as InputEventMouseButton
		if mb != null and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if mb.pressed:
				scroll(px, 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
			return
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			pointer(px, mb.pressed, not mb.pressed)
		else:
			pointer(px, false, false)
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_ESCAPE:
				if menu.page != "capanna":
					menu._go("capanna")
				else:
					_on_action("esci")
			KEY_ENTER, KEY_SPACE:
				_on_action("bosco")
			KEY_R:
				_on_action("rovine")
			KEY_T:
				menu._go("test")


# ---------------------------------------------------------------- azioni

func _on_action(a: String) -> void:
	last_action = a
	if no_switch:
		if a in ["bosco", "lampo"]:
			get_tree().root.set_meta("bosco_opts", {"partecipante": participant, "lampo": a == "lampo", "da_capanna": true})
		elif a == "rovine":
			get_tree().root.set_meta("rovine_opts", {"partecipante": participant, "da_capanna": true})
		elif a.begins_with("test:"):
			get_tree().root.set_meta("test_opts", {"partecipante": participant, "tipo": a.substr(5), "da_capanna": true})
		return
	if a.begins_with("test:"):
		get_tree().root.set_meta("test_opts", {"partecipante": participant, "tipo": a.substr(5), "da_capanna": true})
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")
		return
	match a:
		"bosco", "lampo":
			get_tree().root.set_meta("bosco_opts", {"partecipante": participant, "lampo": a == "lampo", "da_capanna": true})
			get_tree().call_deferred("change_scene_to_file", "res://scenes/training.tscn")
		"rovine":
			get_tree().root.set_meta("rovine_opts", {"partecipante": participant, "da_capanna": true})
			get_tree().call_deferred("change_scene_to_file", "res://scenes/rovine.tscn")
		"esci":
			get_tree().call_deferred("quit")
