extends RefCounted
## Scala dei fuochi fatui (training 0.3): la forza dell'inganno c va da C_MIN a 1.
## A c = 1 la lucciola vicina ha la luce e la grandezza di una lontana, al massimo delle rotelle.
## Si muove solo sulle prove in conflitto: 3 volte di fila la disparità vince → c sale;
## una volta vince l'inganno → c scende. Converge dove si segue la disparità ~79% delle volte:
## più è alta, più ci si fida della stereopsi rispetto agli indizi a un occhio solo.

const C_MIN := 0.1
const C_MAX := 1.0
const STEP := 0.1
const N_UP := 3

var c := 0.3
var streak := 0
var last_dir := 0
var reversals: Array = []
var at_max := 0                 # risposte giuste consecutive già a c = 1


func record(followed_disparity: bool) -> void:
	var dir := 0
	if followed_disparity:
		streak += 1
		if streak >= N_UP:
			streak = 0
			if c >= C_MAX - 1e-6:
				at_max += N_UP
			else:
				dir = 1
	else:
		streak = 0
		at_max = 0
		if c > C_MIN + 1e-6:
			dir = -1
	if dir != 0:
		if last_dir != 0 and dir != last_dir:
			reversals.append(c)
		last_dir = dir
		c = clampf(snappedf(c + dir * STEP, 0.01), C_MIN, C_MAX)


## Forza dell'inganno a cui si resiste ~79% delle volte: media delle ultime 6 inversioni (almeno 4).
## -1 se non ancora stabile; 1 se si resiste anche al massimo (almeno 6 giuste di fila a c = 1).
func threshold() -> float:
	if at_max >= 6:
		return C_MAX
	if reversals.size() < 4:
		return -1.0
	var last := reversals.slice(maxi(0, reversals.size() - 6))
	var sum := 0.0
	for v in last:
		sum += float(v)
	return sum / last.size()


func to_dict() -> Dictionary:
	return {"c": c, "streak": streak, "last_dir": last_dir, "reversals": reversals.duplicate(), "at_max": at_max}


func from_dict(d: Dictionary) -> void:
	c = clampf(float(d.get("c", c)), C_MIN, C_MAX)
	last_dir = int(d.get("last_dir", 0))
	reversals = Array(d.get("reversals", [])).slice(-12)
	at_max = int(d.get("at_max", 0))
	streak = 0
