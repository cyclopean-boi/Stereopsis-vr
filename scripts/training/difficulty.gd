extends RefCounted
## Difficoltà del bosco: una scala 3 giuste / 1 sbagliata (~79% di riuscita, Levitt 1971) che
## prima toglie le rotelle e poi riduce la disparità.
## Rotelle (peso 0-1): luce (la più vicina più luminosa), misura (grandezza angolare legata alla
## distanza), parallasse (lucciole ferme nel mondo invece che solidali con gli spostamenti della testa).

const ORDER := ["luce", "misura", "parallasse"]   # ordine in cui sfumano
const STEP_W := 0.2
const STEP_L := 0.1
const STEP_L_START := 0.2   # passi più grandi finché, a rotelle finite, non ci sono 2 inversioni
const L_MIN := 1.0      # 10″
const L_MAX := 3.6      # ~4000″
const N_UP := 3

var level := 3.3        # log10 della disparità relativa in arcsec
var wheels := {"luce": 1.0, "misura": 1.0, "parallasse": 1.0}
var streak := 0
var last_dir := 0       # -1 più difficile, +1 più facile (solo cambi di disparità)
var reversals := []     # livelli alle inversioni, solo a rotelle finite, in questa sessione
var settled := false    # scala già assestata in una sessione precedente: passi piccoli da subito


func wheels_off() -> bool:
	for k in ORDER:
		if wheels[k] > 1e-6:
			return false
	return true


func mean_wheels() -> float:
	var s := 0.0
	for k in ORDER:
		s += wheels[k]
	return s / ORDER.size()


func record(correct: bool) -> void:
	if correct:
		streak += 1
		if streak >= N_UP:
			streak = 0
			_harder()
	else:
		streak = 0
		_easier()


func _harder() -> void:
	for k in ORDER:
		if wheels[k] > 1e-6:
			wheels[k] = maxf(0.0, snappedf(wheels[k] - STEP_W, 0.001))
			return
	_move_level(-1)


func _easier() -> void:
	if level < L_MAX - 1e-6:
		_move_level(1)
		return
	# disparità già al massimo: torna un po' di rotella, dall'ultima tolta
	for i in range(ORDER.size() - 1, -1, -1):
		var k: String = ORDER[i]
		if wheels[k] < 1.0 - 1e-6:
			wheels[k] = minf(1.0, snappedf(wheels[k] + STEP_W, 0.001))
			return


func _move_level(dir: int) -> void:
	if wheels_off() and last_dir != 0 and dir != last_dir:
		reversals.append(level)
	last_dir = dir
	var step := STEP_L if settled or reversals.size() >= 2 else STEP_L_START
	level = clampf(snappedf(level + dir * step, 0.001), L_MIN, L_MAX)


## Soglia di oggi: media (in log) delle ultime 6 inversioni a rotelle finite; -1 se meno di 4.
func threshold_arcsec() -> float:
	if reversals.size() < 4:
		return -1.0
	var tail: Array = reversals.slice(maxi(0, reversals.size() - 6))
	var s := 0.0
	for r in tail:
		s += r
	return pow(10.0, s / tail.size())


func to_dict() -> Dictionary:
	return {"level": level, "wheels": wheels.duplicate(), "settled": settled or reversals.size() >= 2}


func from_dict(d: Dictionary) -> void:
	level = clampf(float(d.get("level", level)), L_MIN, L_MAX)
	# fra una sessione e l'altra si riparte coi passi piccoli se la scala era già assestata
	settled = bool(d.get("settled", false))
	var w: Dictionary = d.get("wheels", {})
	for k in ORDER:
		wheels[k] = clampf(float(w.get(k, wheels[k])), 0.0, 1.0)
