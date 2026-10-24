extends RefCounted
## Profilo del giocatore nel bosco: difficoltà raggiunta, catture, specie sbloccate, record,
## storico delle sessioni. Un file per partecipante, scritto in modo atomico.

const SPECIES := [
	{"id": "comune", "nome": "Common Firefly", "colore": Color(0.78, 1.0, 0.36), "soglia": {},
		"storia": "The forest has been dark since the Keeper of the lanterns went away. The common fireflies are the first to return: they trust anyone who can tell which one is nearer."},
	{"id": "ambra", "nome": "Amber Firefly", "colore": Color(1.0, 0.74, 0.28), "soglia": {"catture": 150},
		"storia": "They live in the resin of old pines. The Keeper used them to read maps at night: their light never flickers."},
	{"id": "brina", "nome": "Frost Lantern", "colore": Color(0.62, 0.9, 1.0), "soglia": {"senza_rotelle": true},
		"storia": "With no tricks of light or size, all that is left is distance and your two eyes. Frost lanterns only let themselves be seen that way, and they are cold to the touch."},
	{"id": "crepuscolo", "nome": "Twilight Firefly", "colore": Color(1.0, 0.55, 0.68), "soglia": {"soglia_sotto": 1000.0},
		"storia": "They are born at sunset, when shadows grow long and distances blur. Whoever can tell them apart has begun to see the space between things."},
	{"id": "lunare", "nome": "Moon Moth", "colore": Color(0.86, 0.86, 1.0), "soglia": {"soglia_sotto": 600.0},
		"storia": "It is not a firefly, but no one has ever told it so. It always lands a finger's breadth beyond where you think."},
	{"id": "fatuo", "nome": "Will-o'-Wisp", "colore": Color(0.55, 1.0, 0.85), "soglia": {"fatui": 1},
		"storia": "They light up near travelers and pretend to be far away, or fade slowly to seem so. The Keeper used to say: light lies, size lies, two eyes together do not. From tonight the will-o'-wisps know you, and they roam the forest with the other fireflies."},
	{"id": "fantasma", "nome": "Ghost Spark", "colore": Color(0.8, 1.0, 0.85), "soglia": {"soglia_sotto": 400.0},
		"storia": "A spark so small that the forest itself does not know where it is. The Keeper called it 'the trial': whoever catches it may enter the Ruins."},
	{"id": "custode", "nome": "Keeper of the Path", "colore": Color(1.0, 0.95, 0.7), "soglia": {"soglia_sotto": 250.0},
		"storia": "The path to the Ruins lights up. Something stirs in the stone, but only when you look with both eyes."},
]

var path := ""
var data := {
	"versione": 1, "difficolta": {}, "catture": 0, "prove": 0, "specie": ["comune"],
	"record_punti": 0, "migliore_soglia": -1.0, "sessioni": [], "secondi_oggi": 0.0, "giorno": "",
	"contrasto": [], "diagnosi": [], "fatui": {},
}


func load_from(p: String) -> void:
	path = p
	if not FileAccess.file_exists(p):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Dictionary:
		for k in parsed:
			data[k] = parsed[k]


func save() -> bool:
	var tmp := path + ".tmp"
	var fa := FileAccess.open(tmp, FileAccess.WRITE)
	if fa == null:
		return false
	var ok := fa.store_string(JSON.stringify(data, "  "))
	fa.flush()
	var err := fa.get_error()
	fa.close()
	if not ok or err != OK:
		DirAccess.remove_absolute(tmp)
		return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.remove_absolute(tmp)
		return false
	return true


func unlocked(id: String) -> bool:
	return id in data["specie"]


func species_colors() -> Array:
	var out := []
	for s in SPECIES:
		if unlocked(s["id"]):
			out.append(s["colore"])
	return out


## Controlla i traguardi; restituisce le specie appena sbloccate. extra: fatti della sessione
## (per ora "fatui" = fuochi fatui smascherati).
func check_unlocks(wheels_off: bool, session_threshold: float, extra := {}) -> Array:
	var new := []
	for s in SPECIES:
		if unlocked(s["id"]):
			continue
		var cond: Dictionary = s["soglia"]
		var ok := true
		if cond.has("catture") and data["catture"] < cond["catture"]:
			ok = false
		if cond.has("senza_rotelle") and not wheels_off:
			ok = false
		if cond.has("soglia_sotto") and (session_threshold <= 0.0 or session_threshold >= cond["soglia_sotto"]):
			ok = false
		if cond.has("fatui") and int(extra.get("fatui", 0)) < int(cond["fatui"]):
			ok = false
		if ok:
			data["specie"].append(s["id"])
			new.append(s)
	return new


## Secondi giocati oggi (si azzerano al cambio di data).
func add_seconds(sec: float, today: String) -> void:
	if data["giorno"] != today:
		data["giorno"] = today
		data["secondi_oggi"] = 0.0
	data["secondi_oggi"] += sec
