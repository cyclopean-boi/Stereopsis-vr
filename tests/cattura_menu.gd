extends SceneTree
## Catture delle pagine del menu della capanna (verifiche visive, 0.5), con una finestra vera.
## Uso: godot --path . --xr-mode off --resolution 1920x1080 --script res://tests/cattura_menu.gd -- --dir=<cartella training> --out=<cartella>

const Progress := preload("res://scripts/training/progress.gd")
const Storia := preload("res://scripts/training/storia.gd")
const Obiettivi := preload("res://scripts/training/obiettivi.gd")
const Menu := preload("res://scripts/training/ui/menu.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var dir := ""
	var out := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
	var prog := Progress.new()
	prog.load_from(dir.path_join("profilo.json"))
	var storia := Storia.new()
	storia.load_all(dir, dir, prog.data)
	var ach := Obiettivi.evaluate(storia)
	var menu = Menu.new()
	root.add_child(menu)
	menu.setup(prog, storia, ach, [], "player", Time.get_date_string_from_system())
	for shot in [["capanna", "", ""], ["rovine", "", ""], ["diario", "rovine", ""], ["rovine", "", "arco"], ["obiettivi", "", ""], ["test", "", ""]]:
		if shot[1] != "":
			menu.diary_tab = shot[1]
		menu.ruin_detail = shot[2]
		menu._show_page(shot[0])
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var name := "menu_%s%s%s.png" % [shot[0], "_" + shot[1] if shot[1] != "" else "", "_" + shot[2] if shot[2] != "" else ""]
		root.get_texture().get_image().save_png(out.path_join(name))
		print("CATTURA " + name)
	quit()
