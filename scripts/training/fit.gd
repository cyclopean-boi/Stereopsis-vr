extends RefCounted
## Stima di sensibilità e sbilanciamento dalle risposte del bosco (0.2.1, review T2).
## Modello: P(tocca la destra) = l/2 + (1 - l) Phi((d + zero) / sigma), con d positivo se la
## vicina è a destra. "zero" è lo SBILANCIAMENTO DELLE RISPOSTE NEL MODELLO: descrive la forma
## delle risposte e da solo non distingue una differenza percettiva da un criterio di scelta.
## Stima: regressione probit (punteggio di Fisher) con il lapse FISSO a 0 (dalla 0.5.9, scelta
## dell'8/10). Fino alla 0.5.8 il lapse si sceglieva per sessione fra {0, 0,02, 0,05, 0,1} a
## verosimiglianza massima: il 7/10 aveva scelto 0,1 e dato 229″, contro 241″ con lapse 0, e le
## sessioni non si confrontavano alla pari. Con il lapse fisso le soglie sono confrontabili fra
## sessioni; il prezzo è che una sessione con qualche risposta davvero distratta sembra un po'
## peggiore. LAPSES resta una lista per poter riaprire la scelta. La stima è "non stimabile" se:
## - ci sono meno di 40 risposte o meno di 3 disparità diverse;
## - la curva non batte una probabilità costante di scegliere la destra (AIC, margine 4; dalla 0.5.9
##   i parametri contati sono 2 contro 1, perché il lapse non si stima più);
## - le risposte sono separate perfettamente (sensibilità sotto i ~20″ o non identificata);
## - l'intervallo della pendenza include lo zero (curva non determinata).
## La soglia al 79% al netto dello sbilanciamento tiene conto del lapse. L'intervallo è di Wald
## sulla pendenza, condizionato al lapse scelto e alle disparità nominali: indicativo. Dalla 0.3
## c'è anche l'intervallo dello zero (metodo delta), altrettanto indicativo.

const LAPSES := [0.0]             # 0.5.9: fisso (era [0, 0,02, 0,05, 0,1])
const MIN_N := 40
const SCALE := 1000.0           # disparità in migliaia di ″ per la stabilità numerica
const SIGMA_MIN := 20.0         # sotto questa sigma le risposte sono di fatto separate
## Il "motivo" resta in italiano perché finisce nel profilo JSON (sessioni[].stima); questa è solo la
## sua forma da mostrare, per chi lo visualizza (reason_en).
const REASONS_EN := {
	"meno di 3 disparità diverse": "fewer than 3 different disparities",
	"informazione singolare": "singular information",
	"separazione": "separation",
	"non converge": "does not converge",
	"risposte separate: la curva non è identificata dalle disparità presentate": "separated responses: the disparities shown do not identify the curve",
	"pendenza non positiva": "non-positive slope",
	"la curva non spiega le risposte meglio di una scelta costante": "the curve explains the responses no better than a constant choice",
	"sensibilità sotto il minimo stimabile": "sensitivity below the minimum that can be estimated",
	"curva non determinata (intervallo della pendenza che include lo zero)": "curve not determined (the slope interval includes zero)",
}


static func reason_en(m: String) -> String:
	var parts := []
	for p in m.split(", "):
		parts.append("fewer than %d responses" % MIN_N if p == "meno di %d risposte" % MIN_N else str(REASONS_EN.get(p, p)))
	return ", ".join(parts)


static func phi(x: float) -> float:
	var t := 1.0 / (1.0 + 0.3275911 * absf(x) / sqrt(2.0))
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x / 2.0)
	return 0.5 * (1.0 + (y if x >= 0.0 else -y))


static func pdf(x: float) -> float:
	return exp(-0.5 * x * x) / sqrt(TAU)


static func phi_inv(p: float) -> float:
	var lo := -8.0
	var hi := 8.0
	for i in 80:
		var mid := 0.5 * (lo + hi)
		if phi(mid) < p:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)


static func _loglik(data: Array, a: float, b: float, l: float) -> float:
	var ll := 0.0
	for row in data:
		var p: float = l * 0.5 + (1.0 - l) * phi(a + b * float(row[0]) / SCALE)
		p = clampf(p, 1e-9, 1.0 - 1e-9)
		ll += log(p) if row[1] else log(1.0 - p)
	return ll


## Punteggio di Fisher per (a, b) a lapse fisso. Restituisce a, b, ll, informazione, esito.
static func _probit(data: Array, l: float) -> Dictionary:
	var a := 0.0
	var b := 1.0
	var info := [[0.0, 0.0], [0.0, 0.0]]
	var converged := false
	for it in 60:
		var g := [0.0, 0.0]
		info = [[0.0, 0.0], [0.0, 0.0]]
		for row in data:
			var x: float = float(row[0]) / SCALE
			var eta := a + b * x
			var p: float = clampf(l * 0.5 + (1.0 - l) * phi(eta), 1e-9, 1.0 - 1e-9)
			var dp: float = (1.0 - l) * pdf(eta)
			var y := 1.0 if row[1] else 0.0
			var score := (y - p) / (p * (1.0 - p)) * dp
			var w := dp * dp / (p * (1.0 - p))
			g[0] += score
			g[1] += score * x
			info[0][0] += w
			info[0][1] += w * x
			info[1][1] += w * x * x
		info[1][0] = info[0][1]
		var det: float = info[0][0] * info[1][1] - info[0][1] * info[1][0]
		if absf(det) < 1e-12:
			return {"ok": false, "motivo": "informazione singolare"}
		var da: float = (info[1][1] * g[0] - info[0][1] * g[1]) / det
		var db: float = (-info[1][0] * g[0] + info[0][0] * g[1]) / det
		a += da
		b += db
		if absf(b) > SCALE / SIGMA_MIN * 4.0:
			return {"ok": false, "motivo": "separazione", "a": a, "b": b}
		if absf(da) < 1e-7 and absf(db) < 1e-7:
			converged = true
			break
	if not converged:
		return {"ok": false, "motivo": "non converge", "a": a, "b": b}
	var det2: float = info[0][0] * info[1][1] - info[0][1] * info[1][0]
	return {"ok": true, "a": a, "b": b, "ll": _loglik(data, a, b, l), "var_b": info[0][0] / det2,
		"var_a": info[1][1] / det2, "cov_ab": -info[0][1] / det2}


static func fit(data: Array) -> Dictionary:
	var out := {"stimabile": false, "n": data.size(), "motivo": ""}
	if data.size() < MIN_N:
		out["motivo"] = "meno di %d risposte" % MIN_N
		return out
	var levels := {}
	var k := 0
	for row in data:
		levels[snappedf(absf(float(row[0])), 1.0)] = true
		k += 1 if row[1] else 0
	if levels.size() < 3:
		out["motivo"] = "meno di 3 disparità diverse"
		return out
	var n := float(data.size())
	var p0 := clampf(k / n, 1e-9, 1.0 - 1e-9)
	var ll0 := k * log(p0) + (n - k) * log(1.0 - p0)
	var best := {}
	var reasons := []
	for l in LAPSES:
		var r := _probit(data, l)
		if not r["ok"]:
			reasons.append(r["motivo"])
			continue
		if best.is_empty() or r["ll"] > best["ll"]:
			best = r
			best["lapse"] = l
	if best.is_empty():
		out["motivo"] = "risposte separate: la curva non è identificata dalle disparità presentate" if "separazione" in reasons else ", ".join(reasons)
		return out
	var b: float = best["b"]
	var sigma := SCALE / absf(b) if absf(b) > 1e-9 else INF
	var l: float = best["lapse"]
	# 0.5.9 (review dell'8/10, C4): parametri stimati = intercetta e pendenza, più il lapse solo se si
	# sceglie fra più valori. Con il lapse fisso sono 2 contro 1, quindi la penalità della differenza è 2.
	var k_par := 2 + (1 if LAPSES.size() > 1 else 0)
	var d_aic: float = 2.0 * (float(best["ll"]) - ll0) - 2.0 * float(k_par - 1)
	out.merge({"zero": best["a"] * sigma, "sigma": sigma, "lapse": l, "delta_aic": d_aic, "ll": best["ll"]}, true)
	var q := (0.79 - 0.5 * l) / (1.0 - l)
	if b <= 0.0:
		out["motivo"] = "pendenza non positiva"
		return out
	if d_aic < 4.0:
		out["motivo"] = "la curva non spiega le risposte meglio di una scelta costante"
		return out
	if sigma < SIGMA_MIN:
		out["motivo"] = "sensibilità sotto il minimo stimabile"
		return out
	var se_b := sqrt(maxf(float(best["var_b"]), 0.0))
	var b_lo := b - 1.96 * se_b
	var b_hi := b + 1.96 * se_b
	var z79 := phi_inv(q)
	out["soglia79"] = z79 * sigma
	if b_lo <= 0.0:
		out["motivo"] = "curva non determinata (intervallo della pendenza che include lo zero)"
		return out
	out["soglia79_ic"] = [z79 * SCALE / b_hi, z79 * SCALE / b_lo]
	# 0.3: intervallo dello sbilanciamento (zero = SCALE·a/b), metodo delta, indicativo come l'altro
	var a: float = best["a"]
	var g := a / b
	var var_g: float = float(best["var_a"]) / (b * b) + a * a * float(best["var_b"]) / pow(b, 4.0) - 2.0 * a * float(best["cov_ab"]) / pow(b, 3.0)
	var se_g := sqrt(maxf(var_g, 0.0))
	out["zero_ic"] = [SCALE * (g - 1.96 * se_g), SCALE * (g + 1.96 * se_g)]
	out["stimabile"] = true
	out["precisa"] = out["soglia79_ic"][1] / out["soglia79_ic"][0] <= 4.0
	return out


# ---------------------------------------------------------------- bacchetta (0.5.14)

## 0.5.14 (20/10, su richiesta): stima della bacchetta con lo ZERO PER BLOCCO e prima stima molto prima.
## Il 20/10 lo zero si è spostato di quasi 800″ dentro la notte d'istinto: con uno zero solo la stima della notte è
## passata da ~272″ a ~353″ e la bacchetta da 9 a 5 mezze tacche, mentre con lo zero per blocco la sensibilità era
## ~282″ (analisi/2026-10-20/deriva.py). La bacchetta è un riscontro, non una misura: diario, obiettivi e riepiloghi
## restano su fit() (uno zero per notte).
## Modello: P(destra) = Phi(a_k + b·d/1000), un'intercetta a_k per ogni blocco di `block` prove di riferimento della notte
## (in ordine), una pendenza comune b, lapse 0. Stima a posteriori massima con due priori deboli: log b ~ N(log b0, tau²),
## con b0 che corrisponde a `prior_s79` (la mediana delle ultime notti dello stesso tipo), e a_k ~ N(0, sa²). Il priore
## tiene la stima finita anche con poche prove, o separate, e pesa sempre meno con i dati (analisi/2026-10-20/bacchetta2.py,
## che replica questa funzione). Punteggio di Fisher con passo limitato. Restituisce la soglia al 79% (″), -1 se non converge.
static func fit_bacchetta(data: Array, prior_s79: float, block := 40, tau := 0.3, sa := 2.0) -> float:
	var n := data.size()
	if n == 0 or prior_s79 <= 0.0:
		return -1.0
	var z79 := phi_inv(0.79)
	var nk := (n + block - 1) / block
	var beta0 := log(z79 * SCALE / prior_s79)
	var a := []
	a.resize(nk)
	a.fill(0.0)
	var beta := beta0
	for it in 60:
		var b := exp(beta)
		var g := []
		g.resize(nk + 1)
		g.fill(0.0)
		var h := []
		for i in nk + 1:
			var row := []
			row.resize(nk + 1)
			row.fill(0.0)
			h.append(row)
		for i in n:
			var k: int = i / block
			var x: float = float(data[i][0]) / SCALE
			var eta: float = float(a[k]) + b * x
			var p := clampf(phi(eta), 1e-9, 1.0 - 1e-9)
			var dp := pdf(eta)
			var y := 1.0 if data[i][1] else 0.0
			var sc := (y - p) / (p * (1.0 - p)) * dp
			var w := dp * dp / (p * (1.0 - p))
			g[k] += sc
			g[nk] += sc * b * x
			h[k][k] += w
			h[k][nk] += w * b * x
			h[nk][nk] += w * b * x * b * x
		for k in nk:
			g[k] -= float(a[k]) / (sa * sa)
			h[k][k] += 1.0 / (sa * sa)
			h[nk][k] = h[k][nk]
		g[nk] -= (beta - beta0) / (tau * tau)
		h[nk][nk] += 1.0 / (tau * tau)
		var step := _risolvi(h, g)
		if step.is_empty():
			return -1.0
		var biggest := 0.0
		for k in nk + 1:
			step[k] = clampf(float(step[k]), -1.0, 1.0)
			biggest = maxf(biggest, absf(float(step[k])))
		for k in nk:
			a[k] = float(a[k]) + float(step[k])
		beta += float(step[nk])
		if biggest < 1e-7:
			break
	return z79 * SCALE / exp(beta)


## Sistema lineare h·x = g (simmetrico definito positivo) per eliminazione di Gauss con pivot parziale; [] se singolare.
static func _risolvi(h: Array, g: Array) -> Array:
	var m := g.size()
	var A := []
	for i in m:
		var row: Array = (h[i] as Array).duplicate()
		row.append(g[i])
		A.append(row)
	for c in m:
		var piv := c
		for r in range(c + 1, m):
			if absf(float(A[r][c])) > absf(float(A[piv][c])):
				piv = r
		if absf(float(A[piv][c])) < 1e-12:
			return []
		var t = A[c]
		A[c] = A[piv]
		A[piv] = t
		for r in range(c + 1, m):
			var f := float(A[r][c]) / float(A[c][c])
			for j in range(c, m + 1):
				A[r][j] = float(A[r][j]) - f * float(A[c][j])
	var x := []
	x.resize(m)
	for i in range(m - 1, -1, -1):
		var s := float(A[i][m])
		for j in range(i + 1, m):
			s -= float(A[i][j]) * float(x[j])
		x[i] = s / float(A[i][i])
	return x
