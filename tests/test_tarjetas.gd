extends "res://tests/prueba.gd"
## Tarjetas, expulsión y ley de ventaja.

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


func test_falta_leve_sin_tarjeta() -> void:
	await crear_partido()
	falta(-20.0, 5.0, 0.0)
	await esperar_saque()
	afirmar(arbitro.tarjetas.is_empty(), "una falta leve tuvo tarjeta")


func test_falta_muy_fea_es_roja_y_el_equipo_queda_con_10() -> void:
	await crear_partido()
	var infractor := falta(-20.0, 5.0, 1.2)
	afirmar(arbitro.tarjetas.size() == 1 and arbitro.tarjetas[0]["roja"], "una falta muy fea no fue roja")
	await esperar_saque()
	afirmar(infractor.expulsado, "el expulsado sigue jugando")
	afirmar(local.jugadores.size() == 10, "el equipo no quedó con 10 (%d)" % local.jugadores.size())
	afirmar(not infractor.is_in_group("jugadores"), "el expulsado puede tocar la pelota")
	afirmar(arbitro.ejecutor.equipo == 1, "el tiro libre no es del que recibió la falta")


func test_doble_amarilla_es_roja() -> void:
	await crear_partido()
	var jugador := local.jugadores[3]
	arbitro._mostrar_tarjeta(jugador, false)
	afirmar(arbitro.amarillas_de(jugador) == 1, "no anotó la amarilla")
	afirmar(not arbitro.tarjetas[0]["roja"], "la primera amarilla fue roja")
	arbitro._mostrar_tarjeta(jugador, false)
	afirmar(arbitro.tarjetas.size() == 2 and arbitro.tarjetas[1]["roja"], "la segunda amarilla no fue roja")


func test_cortar_una_ocasion_clara_de_gol_es_roja_casi_siempre() -> void:
	await crear_partido()
	var victima := visitante.jugadores[9]
	var infractor := local.jugadores[2]
	# El visitante ataca hacia x negativo: solo contra el arquero.
	poner(victima, -Cancha.LARGO / 2 + 20.0, 2.0)
	for jugador in local.jugadores:
		if jugador != local.arquero() and jugador != infractor:
			poner(jugador, 10.0, jugador.global_position.z)
	afirmar(arbitro._era_ocasion_de_gol(victima, infractor) == false, "sin pelota igual es ocasión clara")
	infractor.ultima_falta = {"gravedad": 0.3, "con_pelota": true, "de_atras": true}
	afirmar(arbitro._era_ocasion_de_gol(victima, infractor), "solo contra el arquero no es ocasión clara")


func test_ley_de_ventaja_si_sigue_con_la_pelota() -> void:
	await crear_partido()
	var companero := visitante.jugadores[8]
	poner(companero, -20.0, 8.0)
	pelota.colocar(Vector3(-20.5, Pelota.RADIO, 8.0))
	falta(-20.0, 6.0)
	afirmar(arbitro.estado == Arbitro.Estado.EN_JUEGO, "no dio ventaja")
	pelota.dar_a(companero)
	await esperar_fisica(int(Arbitro.DURACION_VENTAJA * 60) + 20)
	afirmar(arbitro.estado == Arbitro.Estado.EN_JUEGO, "cobró la falta aunque la ventaja sirvió")


func test_ventaja_que_no_sirve_vuelve_al_tiro_libre() -> void:
	await crear_partido()
	var companero := visitante.jugadores[8]
	poner(companero, -20.0, 8.0)
	pelota.colocar(Vector3(-20.5, Pelota.RADIO, 8.0))
	falta(-20.0, 6.0)
	pelota.dar_a(local.jugadores[5])
	await esperar_saque()
	afirmar(arbitro.tipo_saque == Arbitro.Saque.TIRO_LIBRE, "perdió la pelota en la ventaja y no se cobró la falta")
	afirmar(arbitro.equipo_saque == 1, "el tiro libre no es del que recibió la falta")
	var lugar := Vector2(arbitro.lugar_saque.x + 20.0, arbitro.lugar_saque.z - 6.0).length()
	afirmar(lugar < 1.0, "el tiro libre no es donde fue la falta")
