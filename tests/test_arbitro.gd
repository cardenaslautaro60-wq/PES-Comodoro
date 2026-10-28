extends "res://tests/prueba.gd"
## Las reglas: lateral, córner, saque de arco, faltas, penal, gol, offside, reloj,
## entretiempo con cambio de lado y final.

var partido: PartidoCompleto
var arbitro: Arbitro
var local: EquipoPartido
var visitante: EquipoPartido


func despues_de_cada() -> void:
	if is_instance_valid(partido):
		partido.queue_free()
	partido = null
	await get_tree().process_frame


## Partido de la máquina contra la máquina, con la IA quieta para armar cada jugada a mano.
func crear_partido(offside := false) -> void:
	var configuracion := ConfiguracionPartido.new()
	configuracion.club_local = ""
	configuracion.club_visitante = ""
	configuracion.equipo_humano = -1
	configuracion.offside = offside
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
	local = partido.equipos[0]
	visitante = partido.equipos[1]


## Saca del medio para que la pelota quede en juego.
func sacar_del_medio() -> void:
	arbitro.ejecutor.patear(Jugador.Patada.PASE, 0.3, Vector3(-arbitro.ejecutor.sentido_de_ataque(), 0, 0))
	await esperar_fisica(2)


func poner(jugador: Jugador, x: float, z: float) -> void:
	jugador.detener()
	jugador.global_position = Vector3(x, Jugador.ALTURA / 2, z)


## Tira la pelota afuera desde `desde` con esa velocidad, tocada último por `jugador`.
func tirar_afuera(jugador: Jugador, desde: Vector3, velocidad: Vector3) -> void:
	partido.pelota.colocar(desde)
	partido.pelota.patear(velocidad, Vector3.ZERO, jugador)


func esperar_saque() -> void:
	for i in 60 * 3:
		await esperar_fisica(1)
		if arbitro.estado == Arbitro.Estado.SAQUE:
			return


func test_lateral_para_el_rival_del_que_la_tiro() -> void:
	await crear_partido()
	await sacar_del_medio()
	var culpable := local.jugadores[5]
	tirar_afuera(culpable, Vector3(10, 0.2, Cancha.ANCHO / 2 - 1.0), Vector3(0, 0, 8))
	await esperar_saque()
	var cobrado: String = Arbitro.Saque.keys()[arbitro.tipo_saque]
	afirmar(arbitro.tipo_saque == Arbitro.Saque.LATERAL, "no cobró lateral (cobró %s)" % cobrado)
	afirmar(arbitro.equipo_saque == 1, "el lateral no es del rival")
	afirmar(arbitro.ejecutor.tiene_pelota() and arbitro.ejecutor.inmovil, "el que saca no está quieto con la pelota")
	afirmar(absf(partido.pelota.global_position.z) > Cancha.ANCHO / 2 - 0.5, "la pelota no está en la línea")


func test_corner_si_la_tira_afuera_el_que_defiende() -> void:
	await crear_partido()
	await sacar_del_medio()
	# En el primer tiempo el local defiende el arco de x negativo.
	var defensor := local.jugadores[2]
	tirar_afuera(defensor, Vector3(-Cancha.LARGO / 2 + 1.0, 0.2, 15), Vector3(-10, 0, 0))
	await esperar_saque()
	var cobrado: String = Arbitro.Saque.keys()[arbitro.tipo_saque]
	afirmar(arbitro.tipo_saque == Arbitro.Saque.CORNER, "no cobró córner (cobró %s)" % cobrado)
	afirmar(arbitro.equipo_saque == 1, "el córner no es del que ataca")
	var esquina := Vector3(-Cancha.LARGO / 2, 0, Cancha.ANCHO / 2)
	var pelota := partido.pelota.global_position
	afirmar(Vector2(pelota.x - esquina.x, pelota.z - esquina.z).length() < 1.0, "la pelota no está en la esquina")


func test_saque_de_arco_si_la_tira_afuera_el_que_ataca() -> void:
	await crear_partido()
	await sacar_del_medio()
	var delantero := visitante.jugadores[9]
	tirar_afuera(delantero, Vector3(-Cancha.LARGO / 2 + 1.0, 0.2, 15), Vector3(-10, 0, 0))
	await esperar_saque()
	afirmar(arbitro.tipo_saque == Arbitro.Saque.ARCO, "no cobró saque de arco")
	afirmar(arbitro.ejecutor == local.arquero(), "no saca el arquero")
	for jugador in visitante.jugadores:
		var adentro := local.en_area_propia(arbitro.restringir_posicion(jugador, jugador.global_position))
		afirmar(not adentro, "%s puede quedarse en el área en el saque de arco" % jugador.nombre_jugador)


func test_falta_afuera_del_area_es_tiro_libre() -> void:
	await crear_partido()
	await sacar_del_medio()
	var victima := visitante.jugadores[9]
	poner(victima, -20, 5)
	local.jugadores[2].falta_cometida.emit(victima)
	await esperar_saque()
	afirmar(arbitro.tipo_saque == Arbitro.Saque.TIRO_LIBRE, "no cobró tiro libre")
	afirmar(arbitro.equipo_saque == 1, "el tiro libre no es del que recibió la falta")
	afirmar(partido.pelota.global_position.distance_to(Vector3(-20, 0, 5)) < 1.0, "la pelota no está donde fue la falta")
	for jugador in local.jugadores:
		var distancia := Vector2(jugador.global_position.x + 20, jugador.global_position.z - 5).length()
		afirmar(distancia >= Arbitro.DISTANCIA_REGLAMENTARIA, "%s está a menos de 9,15 m" % jugador.nombre_jugador)


func test_falta_en_el_area_es_penal() -> void:
	await crear_partido()
	await sacar_del_medio()
	var victima := visitante.jugadores[9]
	poner(victima, -Cancha.LARGO / 2 + 8.0, 3)
	local.jugadores[2].falta_cometida.emit(victima)
	await esperar_saque()
	afirmar(arbitro.tipo_saque == Arbitro.Saque.PENAL, "no cobró penal")
	var punto := Vector3(-Cancha.LARGO / 2 + Cancha.DISTANCIA_PENAL, 0, 0)
	var pelota := partido.pelota.global_position
	afirmar(Vector2(pelota.x - punto.x, pelota.z).length() < 0.5, "la pelota no está en el punto penal")
	var arquero := local.arquero()
	afirmar(absf(arquero.global_position.x + Cancha.LARGO / 2) < 1.0, "el arquero no está en la línea")
	for jugador in partido.jugadores:
		if jugador == arquero or jugador == arbitro.ejecutor:
			continue
		var en_el_area := local.en_area_propia(jugador.global_position)
		afirmar(not en_el_area, "%s está en el área en el penal" % jugador.nombre_jugador)


func test_el_gol_suma_y_saca_el_que_lo_recibio() -> void:
	await crear_partido()
	await sacar_del_medio()
	var goles := []
	partido.gol.connect(func(equipo: String) -> void: goles.append(equipo))
	var autor := local.jugadores[9]
	poner(visitante.arquero(), Cancha.LARGO / 2 - 1.0, -3.0)
	partido.pelota.colocar(Vector3(Cancha.LARGO / 2 - 3.0, 0.5, 2.0))
	partido.pelota.patear(Vector3(15, 0, 0), Vector3.ZERO, autor)
	await esperar_fisica(30)
	afirmar(local.goles == 1, "el gol no se contó")
	afirmar(goles == ["local"], "la señal gol no dijo \"local\" (dijo %s)" % [goles])
	afirmar(arbitro.goles.size() == 1 and arbitro.goles[0]["autor"] == autor, "no se anotó quién lo hizo")
	for i in 60 * 5:
		await esperar_fisica(1)
		if arbitro.estado == Arbitro.Estado.SAQUE:
			break
	var del_medio := arbitro.tipo_saque == Arbitro.Saque.INICIAL and arbitro.equipo_saque == 1
	afirmar(del_medio, "no saca del medio el que lo recibió")


func test_entretiempo_cambia_de_lado_y_despues_termina() -> void:
	await crear_partido()
	arbitro.segundos_por_tiempo = 1.0
	await sacar_del_medio()
	var termino := [false]
	arbitro.partido_terminado.connect(func(_l: int, _v: int) -> void: termino[0] = true)
	await esperar_fisica(80)
	afirmar(arbitro.estado == Arbitro.Estado.ENTRETIEMPO, "no llegó el entretiempo")
	arbitro.continuar()
	await esperar_fisica(2)
	afirmar(arbitro.periodo == 2, "no empezó el segundo tiempo")
	afirmar(local.sentido == -1 and visitante.sentido == 1, "no cambiaron de lado")
	afirmar(local.jugadores[9].sentido_de_ataque() == -1, "los jugadores no saben que cambiaron de lado")
	var saca_el_otro := arbitro.tipo_saque == Arbitro.Saque.INICIAL and arbitro.equipo_saque == 1
	afirmar(saca_el_otro, "el segundo tiempo no lo saca el otro equipo")
	afirmar(arbitro.minuto() >= 45 and arbitro.minuto() < 50, "el reloj no arranca en 45' (marca %d')" % arbitro.minuto())
	await sacar_del_medio()
	await esperar_fisica(80)
	afirmar(termino[0], "no avisó que terminó el partido")
	afirmar(arbitro.estado == Arbitro.Estado.FINAL, "no quedó en el final")


func test_offside_si_esta_activado() -> void:
	await crear_partido(true)
	await sacar_del_medio()
	var pasador := local.jugadores[6]
	var adelantado := local.jugadores[9]
	poner(pasador, 5, 0)
	poner(adelantado, 40, 0)
	await esperar_fisica(2)
	var cobrado := [false]
	arbitro.offside_sancionado.connect(func(_j: Jugador) -> void: cobrado[0] = true)
	# El pase sale y lo recibe el que estaba adelantado.
	partido.pelota.colocar(pasador.punto_de_conduccion())
	partido.pelota.patear(Vector3(1, 0, 0), Vector3.ZERO, pasador)
	partido.pelota.colocar(adelantado.punto_de_conduccion())
	partido.pelota.dar_a(adelantado)
	await esperar_fisica(2)
	afirmar(cobrado[0], "no cobró el offside")
	await esperar_saque()
	afirmar(arbitro.tipo_saque == Arbitro.Saque.TIRO_LIBRE and arbitro.equipo_saque == 1, "no es tiro libre para el rival")


func test_sin_offside_no_se_cobra() -> void:
	await crear_partido(false)
	await sacar_del_medio()
	var pasador := local.jugadores[6]
	var adelantado := local.jugadores[9]
	poner(pasador, 5, 0)
	poner(adelantado, 40, 0)
	await esperar_fisica(2)
	partido.pelota.colocar(pasador.punto_de_conduccion())
	partido.pelota.patear(Vector3(1, 0, 0), Vector3.ZERO, pasador)
	partido.pelota.colocar(adelantado.punto_de_conduccion())
	partido.pelota.dar_a(adelantado)
	await esperar_fisica(2)
	afirmar(arbitro.estado == Arbitro.Estado.EN_JUEGO, "cobró algo con el offside apagado")


func test_al_patear_el_saque_sigue_el_juego() -> void:
	await crear_partido()
	var ejecutor := arbitro.ejecutor
	afirmar(ejecutor.inmovil, "el que saca puede moverse antes de patear")
	await sacar_del_medio()
	afirmar(arbitro.estado == Arbitro.Estado.EN_JUEGO, "el juego no siguió después del saque")
	afirmar(not ejecutor.inmovil, "el que sacó quedó quieto")
