extends RefCounted
## Funzioni statistiche numericamente stabili (0.5).
## - beta_quantile: quantile della Beta(a, b) invertendo la Beta incompleta regolarizzata
##   (frazione continua, Numerical Recipes 6.4), calcolata in log: niente underflow con
##   conteggi grandi (la 0.4 integrava x^(a-1)(1-x)^(b-1) su griglia e andava a zero da a=b~600).
## - binom_upper: P(X >= k | n, p) esatta, tramite I_p(k, n-k+1).
## - holm: p aggiustati di Holm (1979) per una famiglia di confronti dichiarata prima.


## log Gamma(x) per x > 0 (Lanczos, g = 7, n = 9; errore relativo ~1e-15).
static func lgamma(x: float) -> float:
	const G := [0.99999999999980993, 676.5203681218851, -1259.1392167224028,
		771.32342877765313, -176.61502916214059, 12.507343278686905,
		-0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7]
	if x < 0.5:
		# riflessione: Gamma(x) Gamma(1-x) = pi / sin(pi x)
		return log(PI / absf(sin(PI * x))) - lgamma(1.0 - x)
	var z := x - 1.0
	var a: float = G[0]
	var t := z + 7.5
	for i in range(1, 9):
		a += G[i] / (z + i)
	return 0.5 * log(TAU) + (z + 0.5) * log(t) - t + log(a)


static func _betacf(a: float, b: float, x: float) -> float:
	const FPMIN := 1e-300
	var qab := a + b
	var qap := a + 1.0
	var qam := a - 1.0
	var c := 1.0
	var d := 1.0 - qab * x / qap
	if absf(d) < FPMIN:
		d = FPMIN
	d = 1.0 / d
	var h := d
	for m in range(1, 1000):
		var m2 := 2.0 * m
		var aa := m * (b - m) * x / ((qam + m2) * (a + m2))
		d = 1.0 + aa * d
		if absf(d) < FPMIN:
			d = FPMIN
		c = 1.0 + aa / c
		if absf(c) < FPMIN:
			c = FPMIN
		d = 1.0 / d
		h *= d * c
		aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
		d = 1.0 + aa * d
		if absf(d) < FPMIN:
			d = FPMIN
		c = 1.0 + aa / c
		if absf(c) < FPMIN:
			c = FPMIN
		d = 1.0 / d
		var del := d * c
		h *= del
		if absf(del - 1.0) < 1e-15:
			break
	return h


## Beta incompleta regolarizzata I_x(a, b) = P(Beta(a, b) <= x).
static func betai(a: float, b: float, x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	var log_bt := lgamma(a + b) - lgamma(a) - lgamma(b) + a * log(x) + b * log(1.0 - x)
	var bt := exp(log_bt)
	if x < (a + 1.0) / (a + b + 2.0):
		return bt * _betacf(a, b, x) / a
	return 1.0 - bt * _betacf(b, a, 1.0 - x) / b


## Quantile q della Beta(a, b), per bisezione su betai (errore < 1e-12).
static func beta_quantile(a: float, b: float, q: float) -> float:
	var lo := 0.0
	var hi := 1.0
	for i in 60:
		var mid := 0.5 * (lo + hi)
		if betai(a, b, mid) < q:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)


## P(X >= k) per X ~ Binomiale(n, p): p-value esatto unilaterale "sopra il caso".
static func binom_upper(k: int, n: int, p: float) -> float:
	if k <= 0:
		return 1.0
	if k > n:
		return 0.0
	return betai(float(k), float(n - k + 1), p)


## p aggiustati di Holm, nello stesso ordine dell'ingresso.
static func holm(ps: Array) -> Array:
	var m := ps.size()
	var order := range(m)
	order.sort_custom(func(i, j): return ps[i] < ps[j])
	var adj := []
	adj.resize(m)
	var running := 0.0
	for rank in m:
		var i: int = order[rank]
		running = maxf(running, minf(1.0, (m - rank) * float(ps[i])))
		adj[i] = running
	return adj
