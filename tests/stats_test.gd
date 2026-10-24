extends SceneTree
## Funzioni statistiche contro valori di riferimento (SciPy 1.x).
## Uso: godot --headless --path . --xr-mode off --script res://tests/stats_test.gd

const Stats := preload("res://scripts/stats.gd")
var failures := 0


func near(got: float, want: float, tol: float, what: String) -> void:
	if not (absf(got - want) <= tol):
		failures += 1
		print("FAIL: %s: %.10f invece di %.10f" % [what, got, want])


func _initialize() -> void:
	near(Stats.lgamma(1.0), 0.0, 1e-12, "lgamma(1)")
	near(Stats.lgamma(10.0), log(362880.0), 1e-10, "lgamma(10)")
	near(Stats.lgamma(0.5), 0.5 * log(PI), 1e-10, "lgamma(0,5)")
	# N5: con conteggi grandi la 0.4 restituiva [1, 1]
	near(Stats.beta_quantile(600, 600, 0.025), 0.4717271, 1e-6, "Beta(600,600) q2,5%")
	near(Stats.beta_quantile(600, 600, 0.975), 0.5282729, 1e-6, "Beta(600,600) q97,5%")
	near(Stats.beta_quantile(1, 9, 0.025), 0.00280914, 1e-7, "Beta(1,9) q2,5%")
	near(Stats.beta_quantile(1, 9, 0.975), 0.33626712, 1e-7, "Beta(1,9) q97,5%")
	near(Stats.beta_quantile(3.5, 200.2, 0.5), 0.01562725547781419, 1e-8, "Beta(3,5;200,2) mediana")
	near(Stats.beta_quantile(20000, 20000, 0.975), 0.5048999, 1e-5, "Beta(2e4,2e4) q97,5%")
	# p esatti usati dalla review: 17/24 anelli p5, 7/14 a livello grossolano
	near(Stats.binom_upper(17, 24, 0.5), 0.03195732831954956, 1e-12, "P(X>=17 | 24, 0,5)")
	near(Stats.binom_upper(7, 14, 0.25), 0.03827075660228729, 1e-12, "P(X>=7 | 14, 0,25)")
	near(Stats.binom_upper(8, 10, 0.25), 0.000415802001953125, 1e-12, "P(X>=8 | 10, 0,25)")
	near(Stats.binom_upper(0, 10, 0.25), 1.0, 0.0, "P(X>=0)")
	var adj: Array = Stats.holm([0.03196, 0.0547, 0.2120])
	near(adj[0], 0.09588, 1e-9, "Holm: minimo")
	near(adj[1], 0.1094, 1e-9, "Holm: secondo")
	near(adj[2], 0.2120, 1e-9, "Holm: terzo")
	adj = Stats.holm([0.5, 0.001, 0.02, 0.04])
	near(adj[1], 0.004, 1e-12, "Holm: ordine d'ingresso conservato")
	near(adj[0], 0.5, 1e-12, "Holm: monotonia")
	print("PASS: stats" if failures == 0 else "FAIL: stats (%d)" % failures)
	quit(0 if failures == 0 else 1)
