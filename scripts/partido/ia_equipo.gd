class_name IAEquipo
extends Node
## La máquina manejando a un equipo: a los 11 si juega sola, o a los 10 que no
## maneja la persona (`excluido`).
##
## Maneja cada `Jugador` igual que una persona: llena su `entrada` (dirección,
## sprint, presión) y llama a `patear()` o `barrer()`. Cada jugador tiene un papel
## que se recalcula todo el tiempo:
## - **Con la pelota:** tira si está cerca del arco, centra desde la banda, pasa al
##   compañero más libre que lo deje mejor parado o conduce esquivando rivales.
## - **Atacando sin la pelota:** se acomoda en su lugar de la formación, adelantado,
##   y se desmarca (los delanteros pican al vacío, los volantes ofrecen el pase).
## - **Defendiendo:** el que llega primero va a presionar y a veces barre, el
##   segundo cubre entre la pelota y el arco, y el resto marca en su zona.
## - **Arquero:** se para entre la pelota y el centro del arco, sale a buscar las
##   pelotas sueltas en el área, ataja los tiros (según su atributo `atajada`) y
##   saca rápido para un compañero.
##
## La dificultad cambia el tiempo de reacción, la presión, las barridas, el
## arquero y la puntería al elegir el pase (ver `PARAMETROS`).

## El arquero atajó (`agarrada` = se quedó con la pelota) o la desvió.
signal atajada(arquero: Jugador, agarrada: bool)

## Por dificultad (fácil, normal, difícil):
## - reaccion: segundos entre decisiones con la pelota.
## - presion: probabilidad de que el que marca apriete de verdad (botón de presión).
## - barridas: barridas por segundo cuando está pegado al que tiene la pelota.
## - arquero: multiplica las chances de atajar.
## - distancia_tiro: desde cuántos metros se anima a tirar.
## - error: probabilidad de elegir un pase peor que el mejor.
## - atributos: se suma a los atributos de sus jugadores.
const PARAMETROS := [
	{
		"reaccion": 0.5,
		"presion": 0.45,
		"barridas": 0.15,
		"arquero": 0.8,
		"distancia_tiro": 19.0,
		"error": 0.4,
		"atributos": -8,
	},
	{
		"reaccion": 0.32,
		"presion": 0.75,
		"barridas": 0.3,
		"arquero": 0.93,
		"distancia_tiro": 22.0,
		"error": 0.2,
		"atributos": 0,
	},
	{
		"reaccion": 0.2,
		"presion": 0.95,
		"barridas": 0.45,
		"arquero": 1.0,
		"distancia_tiro": 26.0,
		"error": 0.06,
		"atributos": 6,
	},
]
## Distancia para frenar al llegar a un punto.
const RADIO_LLEGADA := 2.5
## Cada cuánto cambia el desmarque de cada jugador (segundos).
const CADA_DESMARQUE := Vector2(1.2, 2.6)
## Tiempo que tarda en patear el que saca (para que los demás se acomoden).
const ESPERA_SAQUE := Vector2(1.0, 1.8)


## Lo que "piensa" cada jugador.
class Mente:
	var objetivo := Vector3.ZERO
	var sprint := false
	var presionar := false
	var aprieta := false
	var proxima_decision := 0.0
	var desmarque := Vector3.ZERO
	var proximo_desmarque := 0.0
	var con_pelota := 0.0
	var tiro_visto := -1
	var va_a_atajar := false
	## Segundos que espera antes de sacar (-1 = todavía no se sorteó).
	var espera_saque := -1.0
	var en_saque := 0.0


var equipo: EquipoPartido
var rival: EquipoPartido
var pelota: Pelota
## Si es null, la IA juega siempre (por ejemplo, en una prueba).
var arbitro: Arbitro
var dificultad := ConfiguracionPartido.Dificultad.NORMAL
## El jugador que maneja la persona. La IA no lo toca.
var excluido: Jugador
## Mientras es true la IA no toca a nadie (durante las cinemáticas los mueve el director).
var en_pausa := false
var rng := RandomNumberGenerator.new()

var _mentes := {}
var _tiempo := 0.0
## Cuenta las patadas, para que el arquero decida una sola vez por tiro.
var _patadas := 0


func _ready() -> void:
	# Después del control humano (-10) y antes que los jugadores (0).
	process_physics_priority = -5


## Le pasa el equipo, el rival y la pelota. Llamar con todo ya en el árbol.
func configurar(propio: EquipoPartido, contrario: EquipoPartido, nueva_pelota: Pelota, nuevo_arbitro: Arbitro) -> void:
	equipo = propio
	rival = contrario
	pelota = nueva_pelota
	arbitro = nuevo_arbitro
	pelota.pateada.connect(func(_p: Jugador, _d: Jugador) -> void: _patadas += 1)


## Cambia quién maneja la persona. El anterior vuelve a manos de la IA.
func excluir(jugador: Jugador) -> void:
	excluido = jugador
	if jugador and _mentes.has(jugador):
		_mentes[jugador].presionar = false


func parametro(nombre: String) -> Variant:
	return PARAMETROS[dificultad][nombre]


func _physics_process(delta: float) -> void:
	if equipo == null or pelota == null or en_pausa:
		return
	_tiempo += delta
	var estado := arbitro.estado if arbitro else Arbitro.Estado.EN_JUEGO
	match estado:
		Arbitro.Estado.EN_JUEGO:
			_jugar(delta)
		Arbitro.Estado.SAQUE:
			_esperar_saque(delta)
		Arbitro.Estado.DETENIDO, Arbitro.Estado.FESTEJO:
			_reacomodarse()
		_:
			_quedarse_quietos()
	for jugador in equipo.jugadores:
		if jugador != excluido:
			_aplicar(jugador, _mente(jugador))


# --- En juego -----------------------------------------------------------------


func _jugar(delta: float) -> void:
	var poseedor := pelota.poseedor
	var nuestra := poseedor != null and poseedor.equipo == equipo.indice
	var de_ellos := poseedor != null and not nuestra
	var ultimo := pelota.ultimo_en_tocar
	var atacando := nuestra or (poseedor == null and ultimo != null and ultimo.equipo == equipo.indice)

	# Quién va a buscar la pelota y quién lo cubre.
	var perseguidor: Jugador = null
	var segundo: Jugador = null
	if not nuestra:
		var destinatario := pelota.destinatario
		if poseedor == null and destinatario and destinatario.equipo == equipo.indice:
			perseguidor = destinatario
		else:
			var orden := _ordenar_por_llegada()
			if orden.size() > 0:
				perseguidor = orden[0]
			if orden.size() > 1 and de_ellos:
				segundo = orden[1]

	for i in equipo.jugadores.size():
		var jugador := equipo.jugadores[i]
		if jugador == excluido:
			continue
		var mente := _mente(jugador)
		mente.presionar = false
		mente.sprint = false
		if not jugador.tiene_pelota():
			mente.con_pelota = 0.0
		if equipo.puestos[i] == "ARQ":
			_arquero(jugador, mente, delta)
		elif jugador.tiene_pelota():
			_con_pelota(jugador, mente, delta)
		elif jugador == perseguidor:
			_ir_a_la_pelota(jugador, mente, de_ellos, delta)
		elif jugador == segundo:
			_cubrir(jugador, mente)
		elif atacando:
			_apoyar(jugador, i, mente)
		else:
			_marcar(jugador, i, mente)


## Los jugadores de campo, del que llega antes a la pelota al que llega después.
func _ordenar_por_llegada() -> Array[Jugador]:
	var lista: Array[Jugador] = []
	for jugador in equipo.jugadores:
		if jugador != equipo.arquero() and jugador.estado == Jugador.Estado.NORMAL:
			lista.append(jugador)
	var tiempos := {}
	for jugador in lista:
		tiempos[jugador] = _tiempo_de_llegada(jugador)
	lista.sort_custom(func(a: Jugador, b: Jugador) -> bool: return tiempos[a] < tiempos[b])
	return lista


func _ir_a_la_pelota(jugador: Jugador, mente: Mente, de_ellos: bool, delta: float) -> void:
	mente.objetivo = _punto_de_intercepcion(jugador)
	mente.sprint = jugador.estamina_actual > 0.15
	if not de_ellos:
		return
	# Apretar de verdad o solo acompañar: se decide de a ratos, según la dificultad.
	if _tiempo >= mente.proxima_decision:
		mente.proxima_decision = _tiempo + 0.6
		mente.aprieta = rng.randf() < parametro("presion")
	mente.presionar = mente.aprieta
	var duenio := pelota.poseedor
	if duenio == rival.arquero():
		return
	var distancia := _en_el_piso(jugador.global_position, duenio.global_position)
	if distancia > 2.3 or distancia < 0.7:
		return
	# No barre de atrás (casi siempre es falta).
	var corre := Vector3(duenio.velocity.x, 0, duenio.velocity.z)
	if corre.length() > 1.0 and corre.normalized().dot(_hacia(duenio.global_position, jugador.global_position)) < -0.3:
		return
	var por_segundo: float = parametro("barridas")
	if equipo.en_area_propia(jugador.global_position):
		por_segundo *= 0.3
	if rng.randf() < por_segundo * delta:
		jugador.barrer(_hacia(jugador.global_position, pelota.global_position + duenio.velocity * 0.15))


## Se para entre la pelota y el arco propio, a unos metros.
func _cubrir(jugador: Jugador, mente: Mente) -> void:
	var b := _pelota_en_el_piso()
	var hacia_arco := (equipo.arco_propio() - b).normalized()
	mente.objetivo = b + hacia_arco * 7.0
	mente.sprint = _en_el_piso(jugador.global_position, mente.objetivo) > 6.0


func _apoyar(jugador: Jugador, i: int, mente: Mente) -> void:
	var b := _pelota_en_el_piso()
	if _tiempo >= mente.proximo_desmarque:
		mente.proximo_desmarque = _tiempo + rng.randf_range(CADA_DESMARQUE.x, CADA_DESMARQUE.y)
		var adelante := 0.0
		var costado := rng.randf_range(-3.0, 3.0)
		match equipo.grupo(i):
			"DEL":
				adelante = rng.randf_range(0.0, 7.0)
				costado = rng.randf_range(-5.0, 5.0)
			"MED":
				adelante = rng.randf_range(-3.0, 4.0)
				costado = rng.randf_range(-5.0, 5.0)
		mente.desmarque = Vector3(equipo.sentido * adelante, 0, costado)
	var objetivo := equipo.posicion_tactica(i, b, true) + mente.desmarque
	# Lejos del rival que lo marca, así queda libre para el pase.
	var marcador := _rival_mas_cerca(objetivo)
	if marcador and _en_el_piso(marcador.global_position, objetivo) < 3.0:
		objetivo += _hacia(marcador.global_position, objetivo) * 2.5
	# No amontonarse encima del que tiene la pelota.
	if pelota.poseedor and _en_el_piso(objetivo, b) < 7.0:
		objetivo = b + _hacia(b, objetivo) * 7.0
	if arbitro and arbitro.configuracion.offside and equipo.grupo(i) != "DEF":
		var limite := _linea_del_offside() - 0.01
		if equipo.progreso(objetivo) > limite:
			objetivo.x = equipo.a_mundo(limite, 0).x
	mente.objetivo = _dentro_de_la_cancha(objetivo)
	mente.sprint = _en_el_piso(jugador.global_position, mente.objetivo) > 9.0


func _marcar(jugador: Jugador, i: int, mente: Mente) -> void:
	var b := _pelota_en_el_piso()
	var zona := equipo.posicion_tactica(i, b, false)
	var objetivo := zona
	# Si un rival anda por su zona, se pone entre ese rival y el arco.
	var marcado := _rival_mas_cerca(zona, true)
	if marcado and _en_el_piso(marcado.global_position, zona) < 10.0:
		var r := marcado.global_position
		var goal_side := r + (equipo.arco_propio() - r).normalized() * 1.8
		objetivo = zona.lerp(goal_side, 0.7)
	mente.objetivo = _dentro_de_la_cancha(objetivo)
	mente.sprint = _en_el_piso(jugador.global_position, mente.objetivo) > 10.0


# --- Con la pelota --------------------------------------------------------------


func _con_pelota(jugador: Jugador, mente: Mente, delta: float) -> void:
	mente.con_pelota += delta
	var reaccion: float = parametro("reaccion")
	if mente.con_pelota > reaccion * 0.5 and _tiempo >= mente.proxima_decision:
		mente.proxima_decision = _tiempo + reaccion * rng.randf_range(0.7, 1.3)
		if _decidir_patada(jugador):
			return
	var direccion := _direccion_de_conduccion(jugador)
	mente.objetivo = jugador.global_position + direccion * 6.0
	var libre := _rival_mas_cerca_adelante(jugador, direccion) > 6.0
	mente.sprint = libre and jugador.estamina_actual > 0.35


## Tira, centra o pasa. Devuelve true si pateó.
func _decidir_patada(jugador: Jugador) -> bool:
	var p := jugador.global_position
	var hasta_el_arco := _en_el_piso(p, equipo.arco_rival())
	var presion := _distancia_al_rival_mas_cerca(p)
	var adelante := equipo.progreso(p)

	var distancia_tiro: float = parametro("distancia_tiro")
	if hasta_el_arco < distancia_tiro and absf(p.z) < 20.0:
		# Cerca tira siempre; de lejos, solo si tiene el arco a la vista y de a ratos.
		var a_la_vista := _linea_libre(p, equipo.arco_rival()) > 1.5
		if hasta_el_arco < 14.0 or a_la_vista and rng.randf() < 0.25:
			_tirar(jugador)
			return true

	if adelante > 0.8 and absf(p.z) > 13.0:
		_centrar(jugador)
		return true

	var pase := _mejor_pase(jugador)
	var umbral := 0.45 if presion > 5.0 else (0.1 if presion > 2.5 else -0.4)
	if not pase.is_empty() and pase["puntaje"] > umbral:
		jugador.patear(pase["tipo"], pase["fuerza"], pase["direccion"])
		return true

	# Apretado en su campo y sin a quién dársela: la revienta.
	if presion < 1.6 and adelante < 0.3:
		jugador.patear(Jugador.Patada.PASE_LARGO, 0.85, Vector3(equipo.sentido, 0, rng.randf_range(-0.4, 0.4)))
		return true
	return false


func _tirar(jugador: Jugador) -> void:
	var p := jugador.global_position
	var distancia := _en_el_piso(p, equipo.arco_rival())
	var fuerza := clampf(0.3 + distancia / 50.0 + rng.randf_range(-0.08, 0.08), 0.35, 0.8)
	# Apunta al arco con un poco de variedad (el palo lo elige `Jugador` según el ángulo).
	var apunte := equipo.arco_rival() + Vector3(0, 0, rng.randf_range(-3.0, 3.0))
	jugador.patear(Jugador.Patada.TIRO, fuerza, _hacia(p, apunte))


func _centrar(jugador: Jugador) -> void:
	var p := jugador.global_position
	var x := equipo.arco_rival().x - equipo.sentido * rng.randf_range(6.0, 12.0)
	var destino := Vector3(x, 0, rng.randf_range(-6.0, 6.0))
	jugador.patear(Jugador.Patada.PASE_LARGO, 0.55, _hacia(p, destino))


## El mejor pase posible: {jugador, tipo, fuerza, direccion, puntaje}, o vacío.
func _mejor_pase(jugador: Jugador, permitir_arquero := false) -> Dictionary:
	var p := jugador.global_position
	var desde := equipo.progreso(p)
	var opciones: Array[Dictionary] = []
	for companero in equipo.jugadores:
		if companero == jugador or companero.estado != Jugador.Estado.NORMAL:
			continue
		var es_arquero := companero == equipo.arquero()
		if es_arquero and not permitir_arquero:
			continue
		var q := companero.global_position
		var distancia := _en_el_piso(p, q)
		if distancia < 5.0 or distancia > 45.0:
			continue
		var linea_libre := _linea_libre(p, q)
		if linea_libre < 1.4:
			continue
		var avance := (equipo.progreso(q) - desde) * Cancha.LARGO
		var marca := _distancia_al_rival_mas_cerca(q)
		var puntaje := avance / 15.0 + minf(marca, 8.0) / 8.0 * 0.6 + minf(linea_libre, 5.0) / 5.0 * 0.3
		puntaje -= distancia / 45.0 * 0.3
		var tipo := Jugador.Patada.PASE
		var fuerza := clampf(0.25 + distancia / 40.0 * 0.5, 0.25, 0.8)
		var grupo := equipo.grupo_de(companero)
		if distancia > 30.0:
			tipo = Jugador.Patada.PASE_LARGO
			fuerza = 0.5
			puntaje -= 0.15
		elif (grupo == "DEL" or grupo == "MED") and avance > 6.0 and marca > 3.0 and equipo.progreso(q) > 0.6:
			tipo = Jugador.Patada.PASE_HUECO
			fuerza = 0.35
			puntaje += 0.2
		opciones.append(
			{
				"jugador": companero,
				"tipo": tipo,
				"fuerza": fuerza,
				"direccion": _hacia(p, q),
				"puntaje": puntaje,
			}
		)
	if opciones.is_empty():
		return {}
	opciones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["puntaje"] > b["puntaje"])
	# A veces no ve el mejor pase (más seguido en fácil).
	if opciones.size() > 1 and rng.randf() < parametro("error"):
		return opciones[1]
	return opciones[0]


func _direccion_de_conduccion(jugador: Jugador) -> Vector3:
	var p := jugador.global_position
	var direccion := Vector3(equipo.sentido, 0, 0)
	if equipo.progreso(p) > 0.65:
		direccion = _hacia(p, equipo.arco_rival())
	for otro in rival.jugadores:
		var hacia := Vector3(otro.global_position.x - p.x, 0, otro.global_position.z - p.z)
		var distancia := hacia.length()
		if distancia > 7.0 or distancia < 0.01 or hacia.normalized().dot(direccion) < -0.2:
			continue
		# Lo esquiva para el costado.
		var lado := Vector3(-hacia.z, 0, hacia.x).normalized()
		if lado.dot(direccion) < 0.0:
			lado = -lado
		direccion += (lado * 0.9 - hacia.normalized() * 0.4) * (7.0 - distancia) / 7.0
	if absf(p.z) > Cancha.ANCHO / 2 - 4.0:
		direccion.z -= signf(p.z) * 0.8
	if equipo.progreso(p) > 0.93:
		direccion.x -= equipo.sentido * 0.5
	direccion.y = 0
	return direccion.normalized() if direccion.length() > 0.01 else Vector3(equipo.sentido, 0, 0)


# --- Arquero --------------------------------------------------------------------


func _arquero(jugador: Jugador, mente: Mente, delta: float) -> void:
	if jugador.tiene_pelota():
		_arquero_con_pelota(jugador, mente, delta)
		return
	if _intentar_atajar(jugador, mente):
		return
	var b := _pelota_en_el_piso()
	var arco := equipo.arco_propio()
	# Sale a buscar la pelota suelta en el área si llega antes que los rivales.
	if pelota.poseedor == null and equipo.en_area_propia(b) and pelota.global_position.y < 1.5:
		var propio := _tiempo_de_llegada(jugador)
		var mejor_rival := INF
		for otro in rival.jugadores:
			mejor_rival = minf(mejor_rival, _tiempo_de_llegada(otro))
		if propio < mejor_rival:
			mente.objetivo = _punto_de_intercepcion(jugador)
			mente.sprint = true
			return
	var hacia := Vector3(b.x - arco.x, 0, b.z - arco.z)
	var salida := clampf(hacia.length() * 0.1, 0.8, 4.0)
	var punto := arco + hacia.normalized() * salida
	punto.z = clampf(punto.z, -Cancha.ANCHO_ARCO / 2 + 0.4, Cancha.ANCHO_ARCO / 2 - 0.4)
	mente.objetivo = punto
	mente.sprint = _en_el_piso(jugador.global_position, punto) > 3.0


func _arquero_con_pelota(jugador: Jugador, mente: Mente, delta: float) -> void:
	mente.objetivo = jugador.global_position
	mente.con_pelota += delta
	# Con la pelota en las manos mira hacia la cancha (el árbitro no deja que se la saquen).
	jugador.direccion_mirada = Vector3(equipo.sentido, 0, 0)
	if mente.con_pelota < 1.2:
		return
	_sacar_el_arquero(jugador)


func _sacar_el_arquero(jugador: Jugador) -> void:
	var pase := _mejor_pase(jugador)
	if not pase.is_empty() and pase["puntaje"] > 0.2 and pase["tipo"] == Jugador.Patada.PASE:
		jugador.patear(pase["tipo"], pase["fuerza"], pase["direccion"])
	else:
		jugador.patear(Jugador.Patada.PASE_LARGO, 0.8, Vector3(equipo.sentido, 0, rng.randf_range(-0.35, 0.35)))


## Si viene un tiro al arco, va a cortarlo y decide (una vez por tiro) si lo ataja.
func _intentar_atajar(jugador: Jugador, mente: Mente) -> bool:
	if pelota.poseedor != null:
		return false
	var v := pelota.linear_velocity
	var hacia_el_arco := -equipo.sentido
	if v.x * hacia_el_arco < 6.0:
		return false
	var p := pelota.global_position
	var k := jugador.global_position
	var t := (k.x - p.x) / v.x
	var t_linea := (equipo.arco_propio().x - p.x) / v.x
	if t < -0.05 or t > 1.6:
		return false
	var z_linea := p.z + v.z * t_linea
	var y_linea := p.y + v.y * t_linea - 4.9 * t_linea * t_linea
	var z_arquero := p.z + v.z * t
	var y_arquero := p.y + v.y * t - 4.9 * t * t
	if pelota.efecto.length() > 1.0:
		# Con efecto la pelota dobla: el arquero lee la curva (con la física de la pelota).
		var puntos := pelota.trayectoria(p, v, pelota.efecto, clampf(t_linea + 0.1, 0.1, 2.0))
		var en_linea := Pelota.cruce_con_plano_x(puntos, p, equipo.arco_propio().x)
		var en_arquero := Pelota.cruce_con_plano_x(puntos, p, k.x)
		if en_linea != Vector3.INF:
			z_linea = en_linea.z
			y_linea = en_linea.y
		if en_arquero != Vector3.INF:
			z_arquero = en_arquero.z
			y_arquero = en_arquero.y
	if absf(z_linea) > Cancha.ANCHO_ARCO / 2 + 0.6 or y_linea > Cancha.ALTO_ARCO + 0.4:
		return false
	var z := clampf(z_arquero, -Cancha.ANCHO_ARCO / 2 - 0.3, Cancha.ANCHO_ARCO / 2 + 0.3)
	var y := maxf(y_arquero, Pelota.RADIO)
	mente.objetivo = Vector3(k.x, 0, z)
	mente.sprint = true

	var alcance := 0.6 + 2.2 * (0.4 + 0.6 * jugador.atajada / 99.0)
	if mente.tiro_visto != _patadas:
		mente.tiro_visto = _patadas
		var lateral := absf(z - k.z)
		var dificil := clampf(lateral / alcance, 0.0, 1.0) * 0.25 + clampf((v.length() - 20.0) / 20.0, 0.0, 1.0) * 0.15
		if y > 2.1:
			dificil += 0.08
		var chance: float = (0.7 + 0.3 * jugador.atajada / 99.0) * parametro("arquero") * (1.0 - dificil)
		mente.va_a_atajar = rng.randf() < clampf(chance, 0.05, 0.95)
		if not mente.va_a_atajar:
			# No llega: tampoco puede pararla con el cuerpo.
			jugador.bloquear_control(t + 0.3)
	if mente.va_a_atajar and t <= 0.04:
		mente.va_a_atajar = false
		if absf(z - k.z) <= alcance and y < Cancha.ALTO_ARCO + 0.3:
			_atajar(jugador, v, z)

	return true


func _atajar(jugador: Jugador, v: Vector3, z: float) -> void:
	# La estirada: se tira hacia la pelota (el área E le pone la animación).
	var k := jugador.global_position
	jugador.global_position = Vector3(k.x, k.y, move_toward(k.z, z, 2.5))
	var agarra := v.length() < 22.0 and rng.randf() < 0.3 + 0.5 * jugador.atajada / 99.0
	if agarra:
		jugador.detener()
		jugador.direccion_mirada = Vector3(equipo.sentido, 0, 0)
		pelota.colocar(jugador.punto_de_conduccion())
		pelota.dar_a(jugador)
	else:
		var costado := signf(pelota.global_position.z) if absf(pelota.global_position.z) > 0.2 else 1.0
		# La manda al costado, lejos del arco (muchas veces sale al córner).
		var rebote := Vector3(
			equipo.sentido * rng.randf_range(0.5, 3.0), rng.randf_range(2.0, 5.0), costado * rng.randf_range(9.0, 14.0)
		)
		pelota.patear(rebote, Vector3.ZERO, jugador)
		jugador.bloquear_control(0.4)
	atajada.emit(jugador, agarra)


# --- Saques -------------------------------------------------------------------


func _esperar_saque(delta: float) -> void:
	var b := _pelota_en_el_piso()
	var sacamos := arbitro.equipo_saque == equipo.indice
	for i in equipo.jugadores.size():
		var jugador := equipo.jugadores[i]
		if jugador == excluido:
			continue
		var mente := _mente(jugador)
		mente.presionar = false
		mente.sprint = false
		if jugador == arbitro.ejecutor:
			mente.objetivo = jugador.global_position
			if mente.espera_saque < 0.0:
				mente.espera_saque = rng.randf_range(ESPERA_SAQUE.x, ESPERA_SAQUE.y)
				mente.en_saque = 0.0
			mente.en_saque += delta
			if mente.en_saque >= mente.espera_saque:
				mente.espera_saque = -1.0
				_sacar(jugador)
			continue
		mente.espera_saque = -1.0
		var punto: Vector3
		if equipo.puestos[i] == "ARQ":
			var arco := equipo.arco_propio()
			punto = arco + Vector3(equipo.sentido * 0.6, 0, 0)
			if arbitro.tipo_saque != Arbitro.Saque.PENAL:
				punto = arco + _hacia(arco, b) * 1.5
		else:
			punto = equipo.posicion_tactica(i, b, sacamos)
			if sacamos and arbitro.tipo_saque == Arbitro.Saque.LATERAL and _en_el_piso(punto, b) > 14.0:
				# Alguien se acerca para recibir el lateral.
				punto = punto.lerp(b, 0.4)
		mente.objetivo = arbitro.restringir_posicion(jugador, punto)
		mente.sprint = _en_el_piso(jugador.global_position, mente.objetivo) > 12.0


func _sacar(jugador: Jugador) -> void:
	var p := jugador.global_position
	match arbitro.tipo_saque:
		Arbitro.Saque.INICIAL:
			var cercano := _companero_mas_cerca(jugador)
			if cercano:
				jugador.patear(Jugador.Patada.PASE, 0.3, _hacia(p, cercano.global_position))
			else:
				jugador.patear(Jugador.Patada.PASE, 0.3, Vector3(-equipo.sentido, 0, 0))
		Arbitro.Saque.CORNER:
			_centrar(jugador)
		Arbitro.Saque.ARCO:
			_sacar_el_arquero(jugador)
		Arbitro.Saque.PENAL:
			var esquina := equipo.arco_rival() + Vector3(0, 0, rng.randf_range(-3.0, 3.0))
			jugador.patear(Jugador.Patada.TIRO, rng.randf_range(0.55, 0.8), _hacia(p, esquina))
		Arbitro.Saque.TIRO_LIBRE:
			if jugador.tiro_libre_directo and _patear_tiro_libre(jugador):
				return
			if _en_el_piso(p, equipo.arco_rival()) < 27.0 and absf(p.z) < 18.0:
				_tirar(jugador)
			else:
				_pasar_como_sea(jugador)
		_:
			_pasar_como_sea(jugador)


## Tiro libre directo por encima de la barrera (ver `TiroLibre.planear`). Más lejos
## de 27 m casi siempre la toca para un compañero. Devuelve false si no pateó.
func _patear_tiro_libre(jugador: Jugador) -> bool:
	var desde := pelota.global_position
	var distancia := _en_el_piso(desde, equipo.arco_rival())
	if distancia > 27.0 and rng.randf() < 0.8:
		return false
	var plan := TiroLibre.planear(pelota, desde, equipo.arco_rival(), jugador.tiro, rng)
	if plan.is_empty():
		return false
	# La máquina no es perfecta: un poco de error en la potencia y el efecto.
	var error := float(parametro("error"))
	var fuerza := float(plan["fuerza"]) + rng.randfn(0.0, 0.07 * (0.5 + error))
	var comba := float(plan["comba"]) + rng.randfn(0.0, 0.18 * (0.5 + error))
	jugador.patear_tiro_libre(plan["direccion"], fuerza, comba, plan["picado"])
	return true


func _pasar_como_sea(jugador: Jugador) -> void:
	var pase := _mejor_pase(jugador)
	if not pase.is_empty():
		jugador.patear(pase["tipo"], pase["fuerza"], pase["direccion"])
		return
	var cercano := _companero_mas_cerca(jugador)
	var direccion := Vector3(equipo.sentido, 0, 0)
	if cercano:
		direccion = _hacia(jugador.global_position, cercano.global_position)
	jugador.patear(Jugador.Patada.PASE, 0.4, direccion)


# --- Pausas -------------------------------------------------------------------


func _reacomodarse() -> void:
	var b := _pelota_en_el_piso()
	var ultimo := pelota.ultimo_en_tocar
	var atacando := ultimo != null and ultimo.equipo == equipo.indice
	for i in equipo.jugadores.size():
		var mente := _mente(equipo.jugadores[i])
		mente.presionar = false
		mente.sprint = false
		mente.objetivo = equipo.posicion_tactica(i, b, atacando)


func _quedarse_quietos() -> void:
	for jugador in equipo.jugadores:
		var mente := _mente(jugador)
		mente.presionar = false
		mente.sprint = false
		mente.objetivo = jugador.global_position


# --- Auxiliares ---------------------------------------------------------------


func _aplicar(jugador: Jugador, mente: Mente) -> void:
	var entrada := jugador.entrada
	var hacia := Vector3(mente.objetivo.x - jugador.global_position.x, 0, mente.objetivo.z - jugador.global_position.z)
	var distancia := hacia.length()
	if distancia < 0.3:
		entrada.direccion = Vector3.ZERO
	else:
		entrada.direccion = hacia / distancia * clampf(distancia / RADIO_LLEGADA, 0.25, 1.0)
	entrada.sprint = mente.sprint and distancia > 3.0
	entrada.pase = mente.presionar
	entrada.tiro = false
	entrada.pase_largo = false
	entrada.pase_hueco = false


func _mente(jugador: Jugador) -> Mente:
	if not _mentes.has(jugador):
		var mente := Mente.new()
		mente.objetivo = jugador.global_position
		mente.proximo_desmarque = rng.randf_range(0.0, CADA_DESMARQUE.y)
		_mentes[jugador] = mente
	return _mentes[jugador]


func _pelota_en_el_piso() -> Vector3:
	var b := pelota.global_position
	return Vector3(b.x, 0, b.z)


## Dónde va a estar la pelota dentro de `t` segundos (aproximado: va frenando).
func _pelota_en(t: float) -> Vector3:
	const FRENO := 0.6
	var v := pelota.linear_velocity
	if pelota.poseedor:
		v = pelota.poseedor.velocity
	var recorrido := (1.0 - exp(-FRENO * t)) / FRENO
	var p := pelota.global_position + Vector3(v.x, 0, v.z) * recorrido
	return _dentro_de_la_cancha(Vector3(p.x, 0, p.z))


## El punto más cercano en el que el jugador puede alcanzar la pelota.
func _punto_de_intercepcion(jugador: Jugador) -> Vector3:
	var rapidez := jugador.velocidad_maxima(true)
	var t := 0.0
	while t < 2.5:
		var punto := _pelota_en(t)
		if _en_el_piso(jugador.global_position, punto) <= rapidez * t + 0.6:
			return punto
		t += 0.1
	return _pelota_en(2.5)


func _tiempo_de_llegada(jugador: Jugador) -> float:
	var punto := _punto_de_intercepcion(jugador)
	return _en_el_piso(jugador.global_position, punto) / jugador.velocidad_maxima(true)


func _distancia_al_rival_mas_cerca(punto: Vector3) -> float:
	var otro := _rival_mas_cerca(punto)
	return _en_el_piso(otro.global_position, punto) if otro else INF


func _rival_mas_cerca(punto: Vector3, sin_arquero := false) -> Jugador:
	var mejor: Jugador = null
	var mejor_distancia := INF
	for otro in rival.jugadores:
		if sin_arquero and otro == rival.arquero():
			continue
		var distancia := _en_el_piso(otro.global_position, punto)
		if distancia < mejor_distancia:
			mejor = otro
			mejor_distancia = distancia
	return mejor


func _rival_mas_cerca_adelante(jugador: Jugador, direccion: Vector3) -> float:
	var mejor := INF
	for otro in rival.jugadores:
		var hacia := otro.global_position - jugador.global_position
		hacia.y = 0.0
		if hacia.length() > 0.01 and hacia.normalized().dot(direccion) > 0.3:
			mejor = minf(mejor, hacia.length())
	return mejor


func _companero_mas_cerca(jugador: Jugador) -> Jugador:
	var mejor: Jugador = null
	var mejor_distancia := INF
	for otro in equipo.jugadores:
		if otro == jugador or otro == equipo.arquero():
			continue
		var distancia := _en_el_piso(otro.global_position, jugador.global_position)
		if distancia < mejor_distancia:
			mejor = otro
			mejor_distancia = distancia
	return mejor


## Qué tan lejos pasa el rival más cercano de la línea del pase (en metros).
func _linea_libre(desde: Vector3, hasta: Vector3) -> float:
	var a := Vector3(desde.x, 0, desde.z)
	var b := Vector3(hasta.x, 0, hasta.z)
	var minimo := INF
	for otro in rival.jugadores:
		var r := Vector3(otro.global_position.x, 0, otro.global_position.z)
		var punto := Geometry3D.get_closest_point_to_segment(r, a, b)
		minimo = minf(minimo, punto.distance_to(r))
	return minimo


## Dónde está el penúltimo rival, en progreso de este equipo.
func _linea_del_offside() -> float:
	var valores: Array[float] = []
	for otro in rival.jugadores:
		valores.append(equipo.progreso(otro.global_position))
	valores.sort()
	var penultimo := valores[valores.size() - 2] if valores.size() >= 2 else 1.0
	return maxf(maxf(penultimo, 0.5), equipo.progreso(pelota.global_position))


func _dentro_de_la_cancha(p: Vector3) -> Vector3:
	return Vector3(
		clampf(p.x, -Cancha.LARGO / 2 + 1.0, Cancha.LARGO / 2 - 1.0),
		0,
		clampf(p.z, -Cancha.ANCHO / 2 + 1.0, Cancha.ANCHO / 2 - 1.0)
	)


static func _hacia(desde: Vector3, hasta: Vector3) -> Vector3:
	var v := Vector3(hasta.x - desde.x, 0, hasta.z - desde.z)
	return v.normalized() if v.length() > 0.01 else Vector3.ZERO


static func _en_el_piso(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
