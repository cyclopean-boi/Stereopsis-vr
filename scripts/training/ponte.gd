extends RefCounted
## Un sentiero del ponte delle rovine (training 0.5): una scala a gradini dalla rotella piena al
## random-dot puro (l'ultimo gradino, valore 0; dalla 0.5.13 il mosaico prosegue oltre la pietra nuda,
## con valori negativi, fino al gradino 21), con la regola 3 giuste / 1 sbagliata (~79% di
## riuscita, Levitt 1971). "Più difficile" vuol dire un gradino verso il puro.
## La stima del punto del ponte è la media degli indici delle ultime 6 inversioni (almeno 4),
## riportata sul valore della rotella per interpolazione (in log fra valori positivi).
## 0.5.1 (review RV3): una mossa bloccata al bordo non cambia direzione e non conta come
## inversione; gli estremi hanno un esito proprio. Esiti della stima:
## - "interno": almeno 4 inversioni, punto del ponte dentro la scala;
## - "al_puro": almeno MIN_EDGE prove al gradino puro con almeno il 75% di giuste (la scala ci
##   resta, senza inversioni): il punto del ponte è la pietra nuda, valore 0;
## - "al_pieno": almeno MIN_EDGE prove al gradino più facile con meno della metà di giuste;
## - "insufficiente": nessuno dei tre.

const N_UP := 3
const MIN_REV := 4
const LAST_REV := 6
const MIN_EDGE := 12
const EDGE_OK := 0.75

var levels: Array = []
var index := 0
var streak := 0
var last_dir := 0          # +1 verso il puro, -1 verso la rotella piena
var reversals: Array = []  # indici dei gradini alle inversioni, in questa sessione
var moved := false


func _init(p_levels: Array = []) -> void:
	levels = p_levels


func value() -> float:
	return float(levels[index])


func top() -> int:
	return levels.size() - 1


func pure() -> bool:
	return index == top()


## Aggiorna la scala; restituisce {"dir": -1/0/+1, "reversal": bool}.
func record(correct: bool) -> Dictionary:
	moved = true
	var dir := 0
	if correct:
		streak += 1
		if streak >= N_UP:
			streak = 0
			dir = 1
	else:
		streak = 0
		dir = -1
	var rev := false
	if dir != 0 and index + dir >= 0 and index + dir <= top():
		if last_dir != 0 and dir != last_dir:
			reversals.append(index)
			rev = true
		last_dir = dir
		index += dir
	elif dir != 0:
		dir = 0          # mossa bloccata al bordo: nessun cambio di direzione, nessuna inversione
	return {"dir": dir, "reversal": rev}


## Valore della rotella a un indice frazionario.
func value_at(fi: float) -> float:
	return value_at_levels(levels, fi)


static func value_at_levels(p_levels: Array, fi: float) -> float:
	var last := p_levels.size() - 1
	var f := clampf(fi, 0.0, float(last))
	var i := int(floor(f))
	if i >= last:
		return float(p_levels[last])
	var t := f - i
	var a := float(p_levels[i])
	var b := float(p_levels[i + 1])
	if a > 0.0 and b > 0.0:
		return exp(lerpf(log(a), log(b), t))
	return lerpf(a, b, t)


## top_kn e bottom_kn: [giuste, risposte] al gradino puro e a quello più facile, nella sessione.
static func estimate_from(p_levels: Array, revs: Array, top_kn := [0, 0], bottom_kn := [0, 0]) -> Dictionary:
	var last := p_levels.size() - 1
	if revs.size() >= MIN_REV:
		var tail: Array = revs.slice(maxi(0, revs.size() - LAST_REV))
		var s := 0.0
		for r in tail:
			s += float(r)
		var fi := s / tail.size()
		return {"stimabile": true, "esito": "interno", "indice": fi, "valore": value_at_levels(p_levels, fi), "inversioni": revs.size()}
	if int(top_kn[1]) >= MIN_EDGE and float(top_kn[0]) / float(top_kn[1]) >= EDGE_OK:
		return {"stimabile": true, "esito": "al_puro", "indice": float(last), "valore": float(p_levels[last]),
			"inversioni": revs.size(), "puro": top_kn.duplicate()}
	if int(bottom_kn[1]) >= MIN_EDGE and float(bottom_kn[0]) / float(bottom_kn[1]) < 0.5:
		return {"stimabile": false, "esito": "al_pieno", "inversioni": revs.size(), "pieno": bottom_kn.duplicate(),
			"motivo": "anche con la rotella piena meno di metà giuste"}
	return {"stimabile": false, "esito": "insufficiente", "inversioni": revs.size(), "motivo": "meno di %d inversioni" % MIN_REV}


func to_dict() -> Dictionary:
	return {"index": index}


## Da una sessione precedente: si riparte WARMUP gradini più facili.
func from_dict(d: Dictionary, warmup := 2) -> void:
	index = clampi(int(d.get("index", 0)) - warmup, 0, top())
