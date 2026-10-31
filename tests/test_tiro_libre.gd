extends "res://tests/prueba.gd"
## Tiros libres: comba y picada, barrera y el plan de la máquina. Las tarjetas y la
## ventaja están en test_tarjetas.gd.

var partido: PartidoCompleto
var arbitro: Arbitro
var local: EquipoPartido
var visitante: EquipoPartido
var mundo: Node3D
var pelota: Pelota
var goles: Array[int] = []


func despues_de_cada() -> void:
	if is_instance_valid(partido):
		partido.queue_free()
	partido = null
	if is_instance_valid(mundo):
		mundo.queue_free()
	mundo = null
	await get_tree().process_frame


## Cancha y pelota solas, para patear sin nadie que moleste.
func crear_cancha() -> void:
	goles.clear()
	mundo = Node3D.new()
	add_child(mundo)
	var cancha := Cancha.new()
	cancha.gol.connect(func(lado: int) -> void: goles.append(lado))
	mundo.add_child(cancha)
	pelota = Pelota.new()
	pelota.position = Vector3(0, Pelota.RADIO + 0.01, -20)
	mundo.add_child(pelota)
	await esperar_fisica(2)


## Partido de la máquina contra la máquina, con la IA quieta (como en test_arbitro).
func crear_partido() -> void:
	var configuracion := ConfiguracionPartido.new()
	configuracion.club_local = ""
	configuracion.club_visitante = ""
	configuracion.equipo_humano = -1
	partido = PartidoCompleto.new()
	partido.configuracion = configuracion
	partido.con_cinematicas = false
	add_child(partido)
	await esperar_fisica(3)
	for ia in partido.ias:
		ia.en_pausa = true
	for jugador in partido.jugadores:
		jugador.entrada.limpiar()
	arbitro = partido.arbitro
	arbitro.rng.seed = 5
	local = partido.equipos[0]
	visitante = partido.equipos[1]
	pelota = partido.pelota
	arbitro.ejecutor.patear(Jugador.Patada.PASE, 0.3, Vector3(-arbitro.ejecutor.sentido_de_ataque(), 0, 0))
	await esperar_fisica(2)


func poner(jugador: Jugador, x: float, z: float) -> void:
	jugador.detener()
	jugador.global_position = Vector3(x, Jugador.ALTURA / 2, z)


func esperar_saque() -> void:
	for i in 60 * 6:
		await esperar_fisica(1)
		if arbitro.estado == Arbitro.Estado.SAQUE:
			return


## Falta de un local (defiende el arco de x negativo) a un visitante en (x, z).
func falta(x: float, z: float, gravedad := 0.3) -> Jugador:
	var victima := visitante.jugadores[9]
	poner(victima, x, z)
	var infractor := local.jugadores[2]
	infractor.ultima_falta = {"gravedad": gravedad, "con_pelota": false, "de_atras": false}
	infractor.falta_cometida.emit(victima)
	return infractor


# --- Cómo sale la pelota ----------------------------------------------------------


func test_la_comba_dobla_para_el_lado_pedido() -> void:
	await crear_cancha()
	var desde := Vector3(0, Pelota.RADIO, 0)
	var dir := Vector3(1, 0, 0)
	var v := TiroLibre.velocidad(dir, 0.5)
	var derecho := Pelota.cruce_con_plano_x(pelota.trayectoria(desde, v, TiroLibre.giro(dir, 0, 0)), desde, 22.0)
	var a_la_derecha := Pelota.cruce_con_plano_x(pelota.trayectoria(desde, v, TiroLibre.giro(dir, 1, 0)), desde, 22.0)
	var a_la_izquierda := Pelota.cruce_con_plano_x(pelota.trayectoria(desde, v, TiroLibre.giro(dir, -1, 0)), desde, 22.0)
	# Mirando hacia x positivo, la derecha es z positivo.
	afirmar(absf(derecho.z) < 0.05, "sin efecto no va derecho (z = %.2f)" % derecho.z)
	afirmar(a_la_derecha.z > 1.5, "con comba a la derecha casi no dobla (z = %.2f)" % a_la_derecha.z)
	afirmar(a_la_izquierda.z < -1.5, "con comba a la izquierda casi no dobla (z = %.2f)" % a_la_izquierda.z)


func test_la_picada_baja_de_golpe_y_el_efecto_atras_flota() -> void:
	await crear_cancha()
	var desde := Vector3(0, Pelota.RADIO, 0)
	var dir := Vector3(1, 0, 0)
	var v := TiroLibre.velocidad(dir, 0.6)
	var normal := Pelota.cruce_con_plano_x(pelota.trayectoria(desde, v, TiroLibre.giro(dir, 0, 0)), desde, 22.0)
	var picada := Pelota.cruce_con_plano_x(pelota.trayectoria(desde, v, TiroLibre.giro(dir, 0, 1)), desde, 22.0)
	var flotada := Pelota.cruce_con_plano_x(pelota.trayectoria(desde, v, TiroLibre.giro(dir, 0, -1)), desde, 22.0)
	afirmar(picada.y < normal.y - 0.5, "la picada no baja (%.2f contra %.2f m)" % [picada.y, normal.y])
	afirmar(flotada.y > normal.y + 0.8, "con efecto atrás no flota (%.2f contra %.2f m)" % [flotada.y, normal.y])


# --- Barrera ----------------------------------------------------------------------


func test_la_barrera_depende_de_la_distancia() -> void:
	var arco := Cancha.centro_del_arco(1)
	afirmar(TiroLibre.jugadores_en_barrera(arco - Vector3(20, 0, 0), arco) >= 4, "de frente a 20 m van pocos")
	afirmar(TiroLibre.jugadores_en_barrera(arco - Vector3(30, 0, 0), arco) == 3, "a 30 m no van 3")
	afirmar(TiroLibre.jugadores_en_barrera(arco - Vector3(5, 0, 25), arco) == 2, "desde el costado no van 2")
	afirmar(TiroLibre.jugadores_en_barrera(arco - Vector3(45, 0, 0), arco) == 0, "a 45 m hay barrera")


func test_la_barrera_esta_a_9_metros_y_tapa_el_palo_cercano() -> void:
	var arco := Cancha.centro_del_arco(1)
	var lugar := arco - Vector3(22, 0, 8)
	var puntos := TiroLibre.puntos_de_barrera(lugar, arco, 4)
	afirmar(puntos.size() == 4, "no armó 4 lugares")
	for p in puntos:
		var distancia := Vector2(p.x - lugar.x, p.z - lugar.z).length()
		afirmar(distancia >= Arbitro.DISTANCIA_REGLAMENTARIA, "uno de la barrera está a %.2f m" % distancia)
	# El palo cercano (z negativo, del lado de la pelota) queda tapado por la barrera.
	var hacia_palo := Vector3(arco.x - lugar.x, 0, arco.z - Cancha.ANCHO_ARCO / 2 - lugar.z).normalized()
	var en_la_linea := lugar + hacia_palo * (Arbitro.DISTANCIA_REGLAMENTARIA + 0.05)
	var cerca := INF
	for p in puntos:
		cerca = minf(cerca, Vector2(p.x - en_la_linea.x, p.z - en_la_linea.z).length())
	afirmar(cerca < 0.5, "la barrera no tapa el palo cercano (%.2f m)" % cerca)


func test_el_arbitro_arma_la_barrera_y_salta_al_patear() -> void:
	await crear_partido()
	falta(-Cancha.LARGO / 2 + 22.0, 3.0)
	await esperar_saque()
	afirmar(arbitro.tipo_saque == Arbitro.Saque.TIRO_LIBRE, "no cobró tiro libre")
	afirmar(arbitro.ejecutor.tiro_libre_directo, "el tiro libre cerca del arco no es directo")
	afirmar(arbitro.barrera.size() >= 4, "la barrera tiene %d jugadores" % arbitro.barrera.size())
	var en_barrera := arbitro.barrera.duplicate()
	for jugador: Jugador in en_barrera:
		afirmar(jugador.equipo == 0, "en la barrera hay uno del equipo que patea")
		afirmar(jugador.inmovil, "uno de la barrera se puede mover")
		afirmar(jugador != local.arquero(), "el arquero está en la barrera")
	arbitro.ejecutor.patear_tiro_libre(Vector3(-1, 0, 0), 0.5, 0.0, 0.0)
	await esperar_fisica(8)
	afirmar(arbitro.estado == Arbitro.Estado.EN_JUEGO, "el juego no siguió después del tiro libre")
	afirmar(arbitro.barrera.is_empty(), "la barrera no se soltó")
	var saltaron := 0
	for jugador: Jugador in en_barrera:
		afirmar(not jugador.inmovil, "uno de la barrera quedó quieto")
		saltaron += 1 if jugador.global_position.y > Jugador.ALTURA / 2 + 0.1 else 0
	afirmar(saltaron > 0, "nadie de la barrera saltó")


func test_tiro_libre_al_cuerpo_de_la_barrera_rebota() -> void:
	await crear_partido()
	falta(-Cancha.LARGO / 2 + 22.0, 0.0)
	await esperar_saque()
	var objetivo: Jugador = arbitro.barrera[0]
	var hacia := objetivo.global_position - pelota.global_position
	hacia.y = 0.0
	# Fuerte y bajo, directo a la barrera.
	arbitro.ejecutor.patear_tiro_libre(hacia, 0.15, 0.0, 0.3)
	await esperar_fisica(40)
	var distancia := Vector2(pelota.global_position.x - arbitro.lugar_saque.x, pelota.global_position.z).length()
	afirmar(distancia < 14.0, "el tiro atravesó la barrera (la pelota está a %.1f m)" % distancia)


func test_offside_no_es_tiro_libre_directo() -> void:
	await crear_partido()
	arbitro._proximo_directo = false
	arbitro._detener(Arbitro.Motivo.OFFSIDE, Arbitro.Saque.TIRO_LIBRE, 1, Vector3(-Cancha.LARGO / 2 + 22.0, 0, 0))
	await esperar_saque()
	afirmar(not arbitro.ejecutor.tiro_libre_directo, "el tiro libre por offside es directo")
	afirmar(arbitro.barrera.is_empty(), "hay barrera en un tiro libre por offside")


# --- La máquina -------------------------------------------------------------------


func test_la_maquina_encuentra_un_tiro_por_arriba_de_la_barrera() -> void:
	await crear_cancha()
	var arco := Cancha.centro_del_arco(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for lugar: Vector3 in [arco - Vector3(21, 0, 2), arco - Vector3(25, 0, -7), arco - Vector3(19, 0, 10)]:
		var desde := Vector3(lugar.x, Pelota.RADIO, lugar.z)
		var plan := TiroLibre.planear(pelota, desde, arco, 85, rng)
		afirmar(not plan.is_empty(), "no encontró tiro desde %s" % [lugar])


func test_el_tiro_libre_planeado_es_gol_con_la_pelota_de_verdad() -> void:
	await crear_cancha()
	var arco := Cancha.centro_del_arco(1)
	var desde := Vector3(arco.x - 22.0, Pelota.RADIO + 0.01, 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var plan := TiroLibre.planear(pelota, desde, arco, 99, rng)
	afirmar(not plan.is_empty(), "no encontró tiro")
	if plan.is_empty():
		return
	var pateador := Jugador.new()
	pateador.pelota = pelota
	pateador.tiro = 99
	pateador.rng.seed = 1
	pateador.position = Vector3(desde.x - 0.7, Jugador.ALTURA / 2, desde.z)
	mundo.add_child(pateador)
	await esperar_fisica(1)
	pelota.colocar(desde)
	pelota.dar_a(pateador)
	pateador.patear_tiro_libre(plan["direccion"], plan["fuerza"], plan["comba"], plan["picado"])
	var en_la_barrera := 0.0
	for i in 150:
		await esperar_fisica(1)
		var recorrido := Vector2(pelota.global_position.x - desde.x, pelota.global_position.z - desde.z).length()
		if en_la_barrera == 0.0 and recorrido > Arbitro.DISTANCIA_REGLAMENTARIA:
			en_la_barrera = pelota.global_position.y
	afirmar(en_la_barrera > 2.2, "pasó la barrera a %.2f m de altura" % en_la_barrera)
	afirmar(goles == [1], "el tiro libre planeado no fue gol (goles: %s)" % [goles])
