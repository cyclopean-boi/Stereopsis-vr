extends SceneTree
## Cattura della bacchetta del bosco con le tacche (verifica visiva, 0.5.11; dalla 0.5.12 con le mezze tacche),
## con una finestra vera. Quattro bacchette su sfondo scuro come il bosco: spenta, 2 e mezza (~422″, la notte
## d'istinto del 16/10), 3 e mezza (~312″, la riflessiva del 16/10) e 6 e mezza (~172″, oltre l'obiettivo), viste da dove
## stanno gli occhi quando la mano tocca (30 cm sopra e 35 cm dietro la mano), con un campo di 60° su 1280 pixel:
## circa 21 pixel per grado, come il Pico 4.
## Uso: godot --path . --xr-mode off --resolution 1280x720 --script res://tests/cattura_bacchetta.gd -- --out=<file.png>

const Bosco := preload("res://scripts/training/bosco.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out := "user://bacchetta.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.03, 0.05)
	env.environment = e
	root3d.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 34.0     # verticale: 60° in orizzontale su 1280x720
	root3d.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 0.30, 0.35), Vector3(0.0, 0.0, -0.10))
	cam.current = true
	var keep := []
	var counts := [0, 4, 6, 12]     # mezze tacche
	var nomi := ["spenta", "2 e mezza", "3 e mezza", "6 e mezza"]
	for j in counts.size():
		var b = Bosco.new()        # solo per le funzioni della bacchetta: non entra nell'albero
		keep.append(b)
		var ctrl := XRController3D.new()
		ctrl.position = Vector3((j - 1.5) * 0.06, 0.0, 0.0)
		root3d.add_child(ctrl)
		b._make_wand(ctrl)
		b.mezze = counts[j]
		b.tacche = Bosco.intere(counts[j])
		b._show_tacche()
		var lab := Label3D.new()
		lab.text = nomi[j]
		lab.font_size = 24
		lab.pixel_size = 0.0004
		lab.position = Vector3(0.0, -0.03 - 0.012 * (j % 2), 0.03)
		lab.modulate = Color(0.8, 0.8, 0.8)
		ctrl.add_child(lab)
	for i in 6:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("CATTURA ", out)
	for b in keep:
		b.free()
	quit()
