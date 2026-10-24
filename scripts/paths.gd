extends RefCounted
## Where files live.
## Run from source (Godot editor binary), res:// is the project folder, as usual.
## In an exported build, assets/, musica/ and results/ are NOT packed: they sit next to the
## executable, so res:// paths that must be read or listed as plain files are mapped there.

static func globalize(p: String) -> String:
	if OS.has_feature("editor") or not p.begins_with("res://"):
		return ProjectSettings.globalize_path(p)
	return OS.get_executable_path().get_base_dir().path_join(p.trim_prefix("res://"))


## Folder with all sessions: results/<participant>/... (one folder per participant).
static func results_root() -> String:
	return globalize("res://results/")
