extends RefCounted
## Metodo Psi (Kontsevich & Tyler, 1999) nella variante marginale (Prins, 2013).
## A ogni prova sceglie il livello di disparità che minimizza l'entropia attesa del
## posterior sulla soglia; pendenza e lapse sono parametri di disturbo marginalizzati.
##
## Modello: Weibull su log10(disparità in arcsec)
##   p(corretto | x) = gamma + (1 - gamma - lapse) * (1 - exp(-10^(beta * (x - alpha))))
## gamma = 1 / numero di alternative. alpha è la disparità a cui si raggiunge il 63,2%
## dell'ampiezza sopra il caso. La prestazione massima è 1 - lapse.
##
## Accanto al modello psicometrico tiene l'evidenza di un modello nullo (accuratezza
## costante, indipendente dalla disparità) per decidere se la soglia è identificabile.

const LEVEL_MIN := 1.0    # 10″
const LEVEL_STEP := 0.05
const ALPHA_MIN := 0.6
const ALPHA_MAX := 4.0
const ALPHA_STEP := 0.025
const BETAS := [0.6, 0.85, 1.2, 1.7, 2.4, 3.4, 4.8]
const N_LAPSES := 10            # nodi equispaziati fra 0 e lapse_max: prior discreto ~uniforme
const N_NULL := 31              # nodi dell'accuratezza costante fra gamma e 1
const BAND_EDGES := [2.3, 2.78, 3.3]  # fasce descrittive: <200″, 200-600″, 600-2000″, >=2000″

var levels := PackedFloat64Array()
var alphas := PackedFloat64Array()
var betas := PackedFloat64Array()
var lapses := PackedFloat64Array()
var gamma := 0.25
var lapse_max := 0.45
var level_max := 3.3
var post := PackedFloat64Array()    # indice: (a * n_b + b) * n_l + l
var pc_table: Array[PackedFloat64Array] = []
var n_trials := 0
var log_evidence := 0.0             # log p(dati | modello psicometrico)
var null_ps := PackedFloat64Array()
var null_post := PackedFloat64Array()
var log_evidence_null := 0.0        # log p(dati | accuratezza costante)
var history := []                   # [livello presentato, corretta] per ogni prova usata


func _init(p_gamma := 0.25, p_level_max := 3.3) -> void:
	gamma = p_gamma
	level_max = p_level_max
	lapse_max = 0.6 * (1.0 - gamma)   # prestazione massima almeno gamma + 0,4 * (1 - gamma)
	var n_levels := int(round((level_max - LEVEL_MIN) / LEVEL_STEP)) + 1
	for i in n_levels:
		levels.append(LEVEL_MIN + i * LEVEL_STEP)
	var n_alphas := int(round((ALPHA_MAX - ALPHA_MIN) / ALPHA_STEP)) + 1
	for i in n_alphas:
		alphas.append(ALPHA_MIN + i * ALPHA_STEP)
	for b in BETAS:
		betas.append(float(b))
	for i in N_LAPSES:
		lapses.append(lapse_max * i / (N_LAPSES - 1))
	var n_b := betas.size()
	var n_l := lapses.size()
	var n_cells := alphas.size() * n_b * n_l
	post.resize(n_cells)
	post.fill(1.0 / n_cells)  # piatto su alpha, log(beta) e lapse (nodi equispaziati)
	for x in levels:
		var row := PackedFloat64Array()
		row.resize(n_cells)
		for a in alphas.size():
			for b in n_b:
				for l in n_l:
					row[(a * n_b + b) * n_l + l] = p_correct(x, alphas[a], betas[b], lapses[l])
		pc_table.append(row)
	for i in N_NULL:
		null_ps.append(gamma + (1.0 - gamma) * (i + 0.5) / N_NULL)
	null_post.resize(N_NULL)
	null_post.fill(1.0 / N_NULL)


func p_correct(x: float, alpha: float, beta: float, lapse := 0.0) -> float:
	return gamma + (1.0 - gamma - lapse) * (1.0 - exp(-pow(10.0, beta * (x - alpha))))


func level_index(x: float) -> int:
	return clampi(int(round((x - LEVEL_MIN) / LEVEL_STEP)), 0, levels.size() - 1)


func next_level_index() -> int:
	var n_a := alphas.size()
	var block := betas.size() * lapses.size()  # celle contigue con lo stesso alpha
	var best := 0
	var best_h := INF
	var ma_c := PackedFloat64Array()
	var ma_i := PackedFloat64Array()
	ma_c.resize(n_a)
	ma_i.resize(n_a)
	for li in levels.size():
		var pc: PackedFloat64Array = pc_table[li]
		var total_c := 0.0
		for a in n_a:
			var sc := 0.0
			var si := 0.0
			var base := a * block
			for j in block:
				var w: float = post[base + j]
				var q: float = pc[base + j]
				sc += w * q
				si += w * (1.0 - q)
			ma_c[a] = sc
			ma_i[a] = si
			total_c += sc
		var h := total_c * _entropy(ma_c, total_c) + (1.0 - total_c) * _entropy(ma_i, 1.0 - total_c)
		if h < best_h:
			best_h = h
			best = li
	return best


func update(li: int, correct: bool) -> void:
	var pc: PackedFloat64Array = pc_table[li]
	var total := 0.0
	for k in post.size():
		var v: float = post[k] * (pc[k] if correct else 1.0 - pc[k])
		post[k] = v
		total += v
	if total <= 0.0:
		return
	log_evidence += log(total)  # predittiva della risposta osservata, dato il passato
	for k in post.size():
		post[k] = post[k] / total
	var total_null := 0.0
	for i in N_NULL:
		var v: float = null_post[i] * (null_ps[i] if correct else 1.0 - null_ps[i])
		null_post[i] = v
		total_null += v
	log_evidence_null += log(total_null)
	for i in N_NULL:
		null_post[i] = null_post[i] / total_null
	n_trials += 1
	history.append([levels[li], correct])


## Prove per fascia di disparità: [[giuste, prove], ...] secondo BAND_EDGES. Serve a dire
## dove il test ha davvero guardato: il Psi presume una curva crescente e, se le risposte
## sono al caso, sale al massimo lasciando scoperte le fasce intermedie (review 0.4.1, N1).
func bands() -> Array:
	var out := []
	for i in BAND_EDGES.size() + 1:
		out.append([0, 0])
	for h in history:
		var b := 0
		while b < BAND_EDGES.size() and h[0] >= BAND_EDGES[b] - 1e-9:
			b += 1
		out[b][0] += 1 if h[1] else 0
		out[b][1] += 1
	return out


func alpha_marginal() -> PackedFloat64Array:
	var m := PackedFloat64Array()
	m.resize(alphas.size())
	var block := betas.size() * lapses.size()
	for a in alphas.size():
		var s := 0.0
		for j in block:
			s += post[a * block + j]
		m[a] = s
	return m


func lapse_marginal() -> PackedFloat64Array:
	var m := PackedFloat64Array()
	var n_l := lapses.size()
	m.resize(n_l)
	for k in post.size():
		m[k % n_l] += post[k]
	return m


## Riassunto con esito esplicito: "no_data", "above", "below", "flat", "inconclusive",
## "wide" o "measured" (vedi l'albero di decisione in fondo alla funzione).
func summary() -> Dictionary:
	var out := {"n": n_trials, "gamma": gamma, "level_max_arcsec": pow(10.0, level_max),
		"level_min_arcsec": pow(10.0, LEVEL_MIN), "bands": bands()}
	if n_trials == 0:
		out["outcome"] = "no_data"
		return out
	var m := alpha_marginal()
	var mean := 0.0
	for a in alphas.size():
		mean += m[a] * alphas[a]
	var var_ := 0.0
	for a in alphas.size():
		var_ += m[a] * pow(alphas[a] - mean, 2.0)
	var q025 := _quantile(m, 0.025)
	var q50 := _quantile(m, 0.5)
	var q975 := _quantile(m, 0.975)
	var lm := lapse_marginal()
	var pmax := PackedFloat64Array()
	for l in lapses:
		pmax.append(1.0 - l)
	var log10_bf := (log_evidence - log_evidence_null) / log(10.0)
	out.merge({
		"log_mean": mean, "log_sd": sqrt(var_),
		"log_q025": q025, "log_q50": q50, "log_q975": q975,
		"arcsec_q025": pow(10.0, q025), "arcsec_q50": pow(10.0, q50), "arcsec_q975": pow(10.0, q975),
		"pmax_mean": _weighted_mean(lm, pmax),
		"pmax_q025": _grid_quantile(lm, pmax, 0.975),  # pmax decresce col lapse
		"pmax_q975": _grid_quantile(lm, pmax, 0.025),
		"lapse_marginal": lm,
		"log10_bf_psychometric_vs_constant": log10_bf,
	})
	# Albero di decisione (in quest'ordine):
	#  above: la soglia sta oltre il massimo presentato (non rilevata nel range);
	#  below: sotto il minimo presentato, solo se la prestazione massima è alta (IC95% sopra l'80%);
	#  flat: BF < 1/3, più evidenza per un'accuratezza costante che per una curva;
	#  inconclusive: BF fra 1/3 e ~3, evidenza debole che la prestazione dipenda dalla disparità;
	#  wide: IC95% di alpha più largo di un fattore 10; measured: altrimenti.
	if q50 > level_max:
		out["outcome"] = "above"
	elif q50 < LEVEL_MIN and out["pmax_q025"] >= 0.8:
		out["outcome"] = "below"
	elif log10_bf < -0.5:
		out["outcome"] = "flat"
	elif log10_bf < 0.5 or q50 < LEVEL_MIN:
		out["outcome"] = "inconclusive"
	elif q975 - q025 > 1.0:
		out["outcome"] = "wide"
	else:
		out["outcome"] = "measured"
	out["upper_open"] = q975 > level_max
	out["lower_open"] = q025 < LEVEL_MIN
	return out


func _quantile(m: PackedFloat64Array, p: float) -> float:
	# CDF lineare a tratti sulla griglia (massa di ogni cella centrata sul nodo).
	var cum := 0.0
	for a in alphas.size():
		var next := cum + m[a]
		if next >= p:
			var frac: float = (p - cum) / maxf(m[a], 1e-300)
			return alphas[a] - 0.5 * ALPHA_STEP + frac * ALPHA_STEP
		cum = next
	return alphas[alphas.size() - 1]


static func _weighted_mean(w: PackedFloat64Array, v: PackedFloat64Array) -> float:
	var s := 0.0
	for i in w.size():
		s += w[i] * v[i]
	return s


static func _grid_quantile(w: PackedFloat64Array, v: PackedFloat64Array, p: float) -> float:
	# quantile discreto di v sotto i pesi w (v ordinato in modo monotono lungo la griglia)
	var cum := 0.0
	for i in w.size():
		cum += w[i]
		if cum >= p:
			return v[i]
	return v[v.size() - 1]


static func _entropy(v: PackedFloat64Array, total: float) -> float:
	if total <= 0.0:
		return 0.0
	var h := 0.0
	for x in v:
		if x > 0.0:
			var p := x / total
			h -= p * log(p)
	return h
