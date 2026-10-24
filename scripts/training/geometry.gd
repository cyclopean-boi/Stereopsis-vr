extends RefCounted
## Geometria delle prove del bosco: posizioni delle lucciole date la disparità relativa voluta
## e le posizioni reali dei due occhi (IPD compresa).
## Disparità assoluta di un punto = angolo di vergenza (angolo fra le linee di vista dei due
## occhi). Disparità relativa fra due punti = differenza delle vergenze: positiva se il primo
## è più vicino.

const ARCSEC_PER_RAD := 206264.806


## 0.5.4: postura della testa, solo per la registrazione (non entra nella geometria delle prove).
## Rollio rispetto alla gravità, in gradi: positivo se la testa è inclinata verso la spalla destra,
## cioè se l'occhio destro sta più in basso del sinistro. Il riferimento di OpenXR ha l'asse Y
## verticale; se il visore sta storto sulla faccia, il valore assoluto ha uno scarto fisso.
static func head_roll_deg(eye_l: Vector3, eye_r: Vector3) -> float:
	var v := eye_r - eye_l
	if v.length() < 1e-6:
		return 0.0
	return rad_to_deg(asin(clampf(-v.normalized().y, -1.0, 1.0)))


## Beccheggio della testa, in gradi: positivo se la testa guarda verso l'alto.
static func head_pitch_deg(head_forward: Vector3) -> float:
	if head_forward.length() < 1e-6:
		return 0.0
	return rad_to_deg(asin(clampf(head_forward.normalized().y, -1.0, 1.0)))


static func vergence(p: Vector3, eye_l: Vector3, eye_r: Vector3) -> float:
	return (p - eye_l).angle_to(p - eye_r)


static func relative_disparity_arcsec(p_near: Vector3, p_far: Vector3, eye_l: Vector3, eye_r: Vector3) -> float:
	return (vergence(p_near, eye_l, eye_r) - vergence(p_far, eye_l, eye_r)) * ARCSEC_PER_RAD


## Direzione dall'occhio ciclopico, dati azimut ed elevazione (gradi) nel riferimento
## orizzontale della testa (forward = -Z di Godot, già proiettato sul piano orizzontale).
static func direction(forward: Vector3, azimuth_deg: float, elevation_deg: float) -> Vector3:
	var f := Vector3(forward.x, 0.0, forward.z).normalized()
	var right := f.cross(Vector3.UP).normalized()
	var a := deg_to_rad(azimuth_deg)
	var e := deg_to_rad(elevation_deg)
	return (right * sin(a) * cos(e) + Vector3.UP * sin(e) + f * cos(a) * cos(e)).normalized()


## Distanze (dal ciclopico) della lucciola vicina e di quella lontana, centrate su base,
## tali che la disparità relativa sia target_arcsec. Bisezione sulla differenza di profondità.
static func solve_pair(cyclopean: Vector3, dir_near: Vector3, dir_far: Vector3, base: float,
		target_arcsec: float, eye_l: Vector3, eye_r: Vector3) -> Array:
	var lo := 0.0
	var hi := minf(0.6, 1.8 * base)
	for i in 60:
		var mid := 0.5 * (lo + hi)
		var pn := cyclopean + dir_near * (base - 0.5 * mid)
		var pf := cyclopean + dir_far * (base + 0.5 * mid)
		if relative_disparity_arcsec(pn, pf, eye_l, eye_r) < target_arcsec:
			lo = mid
		else:
			hi = mid
	var delta := 0.5 * (lo + hi)
	return [base - 0.5 * delta, base + 0.5 * delta]


## Riferimento della prova costruito sugli occhi reali (0.2.1, review T1): "destra" è l'asse
## interoculare, "avanti" la direzione della testa resa ortogonale a esso, "su" il terzo asse.
## Due punti a pari distanza dal ciclopico e ad azimut ±a in questo riferimento sono simmetrici
## rispetto ai due occhi, quindi hanno la stessa vergenza anche con la testa inclinata.
## L'elevazione resta riferita all'orizzonte del mondo: "su" è il più vicino possibile alla verticale.
static func eye_frame(eye_l: Vector3, eye_r: Vector3, head_forward: Vector3) -> Basis:
	var right := (eye_r - eye_l).normalized()
	var up := Vector3.UP - right * Vector3.UP.dot(right)
	if up.length() < 1e-6:
		up = right.cross(head_forward)
	up = up.normalized()
	var fwd := up.cross(right).normalized()           # destra × su × avanti destrorso: avanti = su × destra
	if fwd.dot(head_forward) < 0.0:
		fwd = -fwd
	return Basis(right, up, fwd)


static func direction_in(frame: Basis, azimuth_deg: float, elevation_deg: float) -> Vector3:
	var a := deg_to_rad(azimuth_deg)
	var e := deg_to_rad(elevation_deg)
	return (frame.x * sin(a) * cos(e) + frame.y * sin(e) + frame.z * cos(a) * cos(e)).normalized()


## Come solve_pair, ma la differenza di profondità può avere entrambi i segni e il risultato
## dice se la disparità voluta è stata raggiunta entro la tolleranza (0,5″ o 1%).
## Restituisce {"near": distanza, "far": distanza, "got": disparità ottenuta, "ok": bool}.
static func solve_pair_checked(cyclopean: Vector3, dir_near: Vector3, dir_far: Vector3, base: float,
		target_arcsec: float, eye_l: Vector3, eye_r: Vector3) -> Dictionary:
	var span := minf(0.6, 1.8 * base)
	var lo := -span
	var hi := span
	for i in 70:
		var mid := 0.5 * (lo + hi)
		var pn := cyclopean + dir_near * (base - 0.5 * mid)
		var pf := cyclopean + dir_far * (base + 0.5 * mid)
		if relative_disparity_arcsec(pn, pf, eye_l, eye_r) < target_arcsec:
			lo = mid
		else:
			hi = mid
	var delta := 0.5 * (lo + hi)
	var dn := base - 0.5 * delta
	var df := base + 0.5 * delta
	var got := relative_disparity_arcsec(cyclopean + dir_near * dn, cyclopean + dir_far * df, eye_l, eye_r)
	var tol := maxf(0.5, 0.01 * absf(target_arcsec))
	return {"near": dn, "far": df, "got": got, "ok": absf(got - target_arcsec) <= tol}

