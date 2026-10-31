class_name TiroLibre
extends RefCounted
## Cálculos de los tiros libres: cómo sale la pelota según la potencia y el efecto,
## cuántos van a la barrera y dónde se paran, y el plan de la máquina para patear
## por encima de la barrera.
##
## Cómo se patea (persona o máquina): se apunta, se carga la potencia y se elige el
## efecto. Más potencia sale más fuerte y más alta. La comba la hace doblar para un
## costado y la picada (efecto hacia adelante) la hace bajar de golpe después de la
## barrera; con efecto hacia atrás flota.

## Rapidez de la pelota con potencia 0 y 1, en m/s.
const RAPIDEZ := Vector2(17.0, 30.0)
## Ángulo de salida con potencia 0 y 1, en grados.
const ANGULO := Vector2(7.0, 26.0)
## Giro máximo, en rad/s, para la comba (eje vertical) y la picada (eje horizontal).
const COMBA_MAXIMA := 36.0
const PICADO_MAXIMO := 30.0
## Más lejos que esto del arco (en metros), el tiro libre no es para patear al arco.
const DISTANCIA_MAXIMA := 35.0
## Separación entre los jugadores de la barrera.
const SEPARACION_BARRERA := 0.65
## Altura que tapa la barrera saltando (la cabeza llega a unos 2,4 m en lo más alto
## del salto, pero cuando llega la pelota ya está bajando).
const ALTURA_BARRERA := 2.3
## Hasta dónde se puede ir del palo hacia adentro sin que sea demasiado fácil para el arquero.
const MARGEN_PALO := 0.45


## Velocidad de salida de un tiro libre hacia `dir` (horizontal, de largo 1).
static func velocidad(dir: Vector3, fuerza: float, tiro := 70) -> Vector3:
	var rapidez := lerpf(RAPIDEZ.x, RAPIDEZ.y, fuerza) * lerpf(0.9, 1.0, tiro / 99.0)
	var angulo := deg_to_rad(lerpf(ANGULO.x, ANGULO.y, fuerza))
	return dir * rapidez * cos(angulo) + Vector3.UP * rapidez * sin(angulo)


## Giro de la pelota. `comba` de -1 a 1 (+ dobla a la derecha del que patea) y
## `picado` de -1 a 1 (+ baja de golpe, - flota). Un buen pateador le da más efecto.
static func giro(dir: Vector3, comba: float, picado: float, tiro := 70) -> Vector3:
	var calidad := lerpf(0.6, 1.0, tiro / 99.0)
	var derecha := dir.cross(Vector3.UP)
	# Girando alrededor de "arriba" con signo negativo, la pelota dobla a la derecha.
	var lateral := Vector3.UP * (-clampf(comba, -1.0, 1.0) * COMBA_MAXIMA * calidad)
	# Alrededor de "derecha": positivo levanta (flota), negativo hace bajar (picada).
	var vertical := derecha * (-clampf(picado, -1.0, 1.0) * PICADO_MAXIMO * calidad)
	return lateral + vertical


## Gira la velocidad (sin cambiar la rapidez ni la altura) hasta que la pelota, con
## ese giro, cruce el plano x = `plano_x` en z = `z_objetivo`.
static func corregir_direccion(
	pelota: Pelota, desde: Vector3, velocidad_inicial: Vector3, giro_inicial: Vector3, plano_x: float, z_objetivo: float
) -> Vector3:
	var v := velocidad_inicial
	var horizontal := Vector3(v.x, 0, v.z)
	var distancia := absf(plano_x - desde.x)
	var segundos := clampf(distancia / maxf(absf(horizontal.x) * 0.7, 1.0) + 0.3, 0.5, 4.0)
	for i in 3:
		var w := _girar_como(giro_inicial, Vector3(velocidad_inicial.x, 0, velocidad_inicial.z), horizontal)
		var cruce := Pelota.cruce_con_plano_x(pelota.trayectoria(desde, v, w, segundos), desde, plano_x)
		if cruce == Vector3.INF:
			break
		var error := z_objetivo - cruce.z
		if absf(error) < 0.05:
			break
		var largo := Vector2(cruce.x - desde.x, cruce.z - desde.z).length()
		horizontal = horizontal.rotated(Vector3.UP, -atan2(error, largo) * signf(plano_x - desde.x))
		v = Vector3(horizontal.x, v.y, horizontal.z)
	return v


## Lo mismo para el giro: si se corrige la dirección, el giro gira con ella.
static func giro_corregido(giro_inicial: Vector3, velocidad_inicial: Vector3, velocidad_final: Vector3) -> Vector3:
	return _girar_como(
		giro_inicial,
		Vector3(velocidad_inicial.x, 0, velocidad_inicial.z),
		Vector3(velocidad_final.x, 0, velocidad_final.z)
	)


# --- Barrera --------------------------------------------------------------------


## Cuántos van a la barrera según dónde está la pelota: de 2 a 5, o 0 si está muy
## lejos para patear al arco.
static func jugadores_en_barrera(lugar: Vector3, arco: Vector3) -> int:
	var distancia := Vector2(lugar.x - arco.x, lugar.z - arco.z).length()
	if distancia > DISTANCIA_MAXIMA:
		return 0
	var frente := absf(lugar.x - arco.x)
	var angulo := rad_to_deg(atan2(absf(lugar.z - arco.z), frente))
	if angulo > 60.0:
		return 2
	if distancia < 22.0:
		return 5 if angulo < 20.0 else 4
	if distancia < 28.0:
		return 4 if angulo < 30.0 else 3
	return 3 if angulo < 30.0 else 2


## Dónde se para cada uno de la barrera: a 9,15 m de la pelota, tapando el palo
## más cercano y parte del medio. Los devuelve del palo cercano hacia afuera.
static func puntos_de_barrera(lugar: Vector3, arco: Vector3, cantidad: int) -> Array[Vector3]:
	var puntos: Array[Vector3] = []
	if cantidad <= 0:
		return puntos
	var lado := signf(lugar.z - arco.z)
	var palo_cercano := arco + Vector3(0, 0, lado * Cancha.ANCHO_ARCO / 2)
	var centro_arco := Vector3(arco.x, 0, arco.z)
	var desde := Vector3(lugar.x, 0, lugar.z)
	# El primero tapa el palo cercano; el resto se abre hacia el medio del arco.
	var hacia_palo := (palo_cercano - desde).normalized()
	var hacia_centro := (centro_arco - desde).normalized()
	var primero := desde + hacia_palo * Arbitro.DISTANCIA_REGLAMENTARIA
	var a_lo_ancho := hacia_centro.cross(Vector3.UP).normalized()
	# Que la fila avance hacia el centro del arco.
	if (desde + hacia_centro * Arbitro.DISTANCIA_REGLAMENTARIA - primero).dot(a_lo_ancho) < 0.0:
		a_lo_ancho = -a_lo_ancho
	for i in cantidad:
		var p := primero + a_lo_ancho * SEPARACION_BARRERA * (i - 0.5)
		# Todos a 9,15 m de la pelota (un poquito más, para no quedar en el límite).
		p = desde + (p - desde).normalized() * (Arbitro.DISTANCIA_REGLAMENTARIA + 0.05)
		puntos.append(Vector3(p.x, 0, p.z))
	return puntos


# --- La máquina -------------------------------------------------------------------


## Busca potencia, comba y picada para pasar por encima de la barrera y meterla en
## un ángulo. Devuelve {direccion, fuerza, comba, picado, objetivo} o vacío si no
## encontró un tiro que entre.
static func planear(pelota: Pelota, desde: Vector3, arco: Vector3, tiro: int, rng: RandomNumberGenerator) -> Dictionary:
	var hay_barrera := jugadores_en_barrera(desde, arco) > 0
	var lados: Array[float] = [1.0, -1.0]
	if rng.randf() < 0.5:
		lados.reverse()
	var mejor := {}
	var mejor_puntaje := INF
	for lado in lados:
		var objetivo := arco + Vector3(0, 0, lado * (Cancha.ANCHO_ARCO / 2 - MARGEN_PALO))
		var hacia := Vector3(objetivo.x - desde.x, 0, objetivo.z - desde.z).normalized()
		var derecha := hacia.cross(Vector3.UP)
		# Dobla de afuera hacia adentro del arco: para el lado del ángulo elegido.
		var comba := 0.7 * signf((objetivo - arco).dot(derecha))
		for picado: float in [0.5, 0.8, 1.0]:
			for paso in 14:
				var fuerza := 0.3 + paso * 0.05
				var resultado := _probar(pelota, desde, objetivo, fuerza, comba, picado, tiro, hay_barrera)
				if resultado.is_empty():
					continue
				var puntaje := absf(float(resultado["altura"]) - 1.85) + fuerza * 0.2
				if puntaje < mejor_puntaje:
					mejor_puntaje = puntaje
					mejor = resultado
		if not mejor.is_empty():
			return mejor
	return mejor


static func _probar(
	pelota: Pelota,
	desde: Vector3,
	objetivo: Vector3,
	fuerza: float,
	comba: float,
	picado: float,
	tiro: int,
	hay_barrera: bool
) -> Dictionary:
	var hacia := Vector3(objetivo.x - desde.x, 0, objetivo.z - desde.z).normalized()
	var v := velocidad(hacia, fuerza, tiro)
	var w := giro(hacia, comba, picado, tiro)
	var corregida := corregir_direccion(pelota, desde, v, w, objetivo.x, objetivo.z)
	w = giro_corregido(w, v, corregida)
	var distancia := Vector2(objetivo.x - desde.x, objetivo.z - desde.z).length()
	var puntos := pelota.trayectoria(desde, corregida, w, distancia / 15.0 + 0.5)
	var cruce := Pelota.cruce_con_plano_x(puntos, desde, objetivo.x)
	if cruce == Vector3.INF or absf(cruce.z - objetivo.z) > 0.4:
		return {}
	if cruce.y < 0.5 or cruce.y > Cancha.ALTO_ARCO - 0.2:
		return {}
	if hay_barrera:
		var en_la_barrera := Pelota.altura_a_distancia_simulada(puntos, desde, Arbitro.DISTANCIA_REGLAMENTARIA)
		if en_la_barrera < ALTURA_BARRERA + 0.1:
			return {}
	var direccion := Vector3(corregida.x, 0, corregida.z).normalized()
	return {
		"direccion": direccion,
		"fuerza": fuerza,
		"comba": comba,
		"picado": picado,
		"objetivo": objetivo,
		"altura": cruce.y,
	}


static func _girar_como(vector: Vector3, antes: Vector3, despues: Vector3) -> Vector3:
	if antes.length() < 0.01 or despues.length() < 0.01:
		return vector
	return vector.rotated(Vector3.UP, antes.signed_angle_to(despues, Vector3.UP))
