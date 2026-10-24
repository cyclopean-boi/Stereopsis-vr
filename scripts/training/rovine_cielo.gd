extends RefCounted
## Il panorama delle rovine (training 0.5): l'immagine di base con le macerie e, sopra, i pezzi
## restaurati. Ogni pezzo è un ritaglio trasparente con la sua posizione (assets/2d/rovine/pezzi.json).
## Le immagini si leggono dai byte, così funzionano anche senza l'importazione dell'editor. Se
## mancano, si torna a un cielo a tinta unita: il gioco resta giocabile.

const Paths := preload("res://scripts/paths.gd")
const DIR := "res://assets/2d/rovine/"
const SkyShader := preload("res://shaders/rovine_cielo.gdshader")


static func _img(path: String) -> Image:
	var p := Paths.globalize(path)
	if not FileAccess.file_exists(p):
		return null
	var img := Image.load_from_file(p)
	if img == null or img.is_empty():
		return null
	return img


static func offsets() -> Dictionary:
	var p := Paths.globalize(DIR + "pezzi.json")
	if not FileAccess.file_exists(p):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	return parsed if parsed is Dictionary else {}


## Panorama con i pezzi restaurati; null se l'immagine di base manca.
static func compose(restored: Array, max_width := 0) -> Image:
	var base := _img(DIR + "panorama.png")
	if base == null:
		return null
	base.convert(Image.FORMAT_RGBA8)
	var offs := offsets()
	for id in restored:
		var layer := _img(DIR + "pezzi/%s.png" % id)
		if layer == null or not offs.has(id):
			continue
		layer.convert(Image.FORMAT_RGBA8)
		var o: Dictionary = offs[id]
		base.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i(int(o.get("x", 0)), int(o.get("y", 0))))
	if max_width > 0 and base.get_width() > max_width:
		base.resize(max_width, max_width / 2, Image.INTERPOLATE_BILINEAR)
	return base


## Ambiente con il panorama come cielo.
static func environment(restored: Array) -> Environment:
	var env := Environment.new()
	var img := compose(restored)
	if img != null:
		img.generate_mipmaps()
		var mat := ShaderMaterial.new()
		mat.shader = SkyShader
		mat.set_shader_parameter("panorama", ImageTexture.create_from_image(img))
		var sky := Sky.new()
		sky.sky_material = mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.012, 0.02, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	return env


static func update(env: Environment, restored: Array) -> void:
	if env.sky == null or not env.sky.sky_material is ShaderMaterial:
		return
	var img := compose(restored)
	if img == null:
		return
	img.generate_mipmaps()
	(env.sky.sky_material as ShaderMaterial).set_shader_parameter("panorama", ImageTexture.create_from_image(img))


## Incisione di una creatura (per il riscontro), con le mipmap; null se manca.
static func creature(id: String) -> Texture2D:
	var img := _img(DIR + "creature/%s.png" % id)
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
