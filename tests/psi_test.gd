extends SceneTree
## Osservatori simulati: la procedura recupera la soglia quando c'è, e dichiara l'esito
## quando non è misurabile (al caso, prestazione piatta, tutto giusto, nessun dato).
## Uso: godot --headless --path . --script res://tests/psi_test.gd

const Psi := preload("res://scripts/psi.gd")
const RUNS := 12

var rng := RandomNumberGenerator.new()
var ok := true


func check(cond: bool, what: String) -> void:
	if not cond:
		ok = false
		print("FAIL: " + what)


## Una sessione simulata come nell'app (12% di prove al livello alto). observer(x) -> p(corretto).
func run(gamma: float, level_max: float, n: int, observer: Callable) -> Dictionary:
	var psi := Psi.new(gamma, level_max)
	for t in n:
		var li: int
		if rng.randf() < 0.12:
			li = psi.level_index(level_max - 0.1)
		else:
			li = psi.next_level_index()
		psi.update(li, rng.randf() < observer.call(psi.levels[li]))
	return psi.summary()


func recovery(name: String, gamma: float, level_max: float, n: int, alpha: float, beta: float, lapse: float, max_bias: float, max_rmse: float) -> void:
	var ref := Psi.new(gamma, level_max)
	var bias := 0.0
	var rmse := 0.0
	var covered := 0
	var measured := 0
	var t0 := Time.get_ticks_msec()
	for r in RUNS:
		var s := run(gamma, level_max, n, func(x: float) -> float: return ref.p_correct(x, alpha, beta, lapse))
		bias += (s["log_q50"] - alpha) / RUNS
		rmse += pow(s["log_q50"] - alpha, 2.0) / RUNS
		covered += 1 if s["log_q025"] <= alpha and alpha <= s["log_q975"] else 0
		measured += 1 if s["outcome"] in ["measured", "wide"] else 0
	rmse = sqrt(rmse)
	print("%s: n=%d bias=%.3f rmse=%.3f copertura=%d/%d con stima=%d/%d  %.0f ms/prova" % [name, n, bias, rmse, covered, RUNS, measured, RUNS, float(Time.get_ticks_msec() - t0) / (RUNS * n)])
	check(abs(bias) <= max_bias and rmse <= max_rmse and covered >= RUNS * 0.75, name + ": recupero della soglia")
	if lapse < 0.1:
		check(measured >= RUNS * 0.75, name + ": esito con stima")


func outcomes(name: String, gamma: float, level_max: float, n: int, observer: Callable, forbidden: Array) -> void:
	var counts := {}
	for r in RUNS:
		var s := run(gamma, level_max, n, observer)
		counts[s["outcome"]] = counts.get(s["outcome"], 0) + 1
	var bad := 0
	for o in forbidden:
		bad += counts.get(o, 0)
	print("%s: esiti %s" % [name, counts])
	check(bad <= RUNS * 0.1, name + ": esiti non ammessi %s" % [forbidden])


func _init() -> void:
	rng.seed = 20260929
	recovery("4AFC 40″", 0.25, 3.5, 60, 1.6, 2.0, 0.02, 0.12, 0.3)
	recovery("4AFC 316″", 0.25, 3.5, 60, 2.5, 2.0, 0.02, 0.12, 0.3)
	recovery("2AFC 251″", 0.5, 3.0, 70, 2.4, 2.0, 0.02, 0.15, 0.35)
	recovery("4AFC 794″ lapse 0,35, due sessioni", 0.25, 3.5, 120, 2.9, 2.0, 0.35, 0.25, 0.4)
	outcomes("4AFC al caso", 0.25, 3.5, 60, func(_x: float) -> float: return 0.25, ["measured", "wide", "below"])
	outcomes("4AFC piatto al 40%", 0.25, 3.5, 60, func(_x: float) -> float: return 0.40, ["measured", "below"])
	outcomes("4AFC piatto al 65%", 0.25, 3.5, 60, func(_x: float) -> float: return 0.65, ["measured", "below"])
	outcomes("2AFC al caso", 0.5, 3.0, 70, func(_x: float) -> float: return 0.5, ["measured", "wide", "below"])
	outcomes("2AFC piatto al 75%", 0.5, 3.0, 70, func(_x: float) -> float: return 0.75, ["measured", "below"])
	outcomes("4AFC tutto giusto", 0.25, 3.5, 60, func(_x: float) -> float: return 1.0, ["measured", "wide", "flat", "above", "inconclusive"])
	var empty := Psi.new(0.25, 3.5).summary()
	check(empty["outcome"] == "no_data", "nessun dato -> no_data")
	print("PASS: psi" if ok else "FAIL: psi")
	quit(0 if ok else 1)
