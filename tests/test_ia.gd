extends "res://tests/prueba.gd"
## La IA: el arquero ataja, el que llega primero presiona, con la pelota avanza o
## pasa, la dificultad cambia cómo juega y no toca al jugador de la persona.

var partido: PartidoCompleto
var local: EquipoPartido
var visitante: EquipoPartido


func despues_de_cada() -> void:
	if is_instance_valid(partido):
		partido.queue_free()
	partido = null
	await get_tree().process_frame


func crear_partido(humano := -1) -> void:
	var configuracion := ConfiguracionPartido.new()
	configuracion.club_local = ""
	configuracion.club_visitante = ""
	configuracion.equipo_humano = humano
	partido = PartidoCompleto.new()
	partido.configuracion = configuracion
	partido.con_cinematicas = false
	add_child(partido)
	await esperar_fisica(3)
	local = partido.equipos[0]
	visitante = partido.equipos[1]
	for ia in partido.ias:
		ia.rng.seed = 7
	# Saque del medio a mano, así la pelota queda en juego enseguida.
	var ejecutor := partido.arbitro.ejecutor
	ejecutor.patear(Jugador.Patada.PASE, 0.3, Vector3(-ejecutor.sentido_de_ataque(), 0, 0))
	await esperar_fisica(2)


## Deja quieta a la IA de un equipo (y suelta lo que estaba haciendo).
func pausar(equipo: int) -> void:
	partido.ias[equipo].en_pausa = true
	for jugador in partido.equipos[equipo].jugadores:
		jugador.entrada.limpiar()


func poner(jugador: Jugador, x: float, z: float) -> void:
	jugador.detener()
	jugador.global_position = Vector3(x, Jugador.ALTURA / 2, z)


func dar_pelota(jugador: Jugador) -> void:
	partido.pelota.colocar(jugador.punto_de_conduccion())
	partido.pelota.dar_a(jugador)


func test_el_arquero_ataja_un_tiro_flojo() -> void:
	await crear_partido()
	pausar(0)
	var arquero := visitante.arquero()
	var goles := [0]
	partido.gol.connect(func(_e: String) -> void: goles[0] += 1)
	var tirador := local.jugadores[9]
	poner(tirador, 36, 1)
	await esperar_fisica(2)
	partido.pelota.colocar(Vector3(37, Pelota.RADIO, 1))
	partido.pelota.patear(Vector3(14, 1.0, 0.5), Vector3.ZERO, tirador)
	var la_toco := [false]
	partido.ias[1].atajada.connect(func(_a: Jugador, _g: bool) -> void: la_toco[0] = true)
	for i in 90:
		await esperar_fisica(1)
		if arquero.tiene_pelota():
			la_toco[0] = true
	afirmar(goles[0] == 0, "el arquero no atajó un tiro flojo al medio")
	afirmar(la_toco[0], "el arquero ni la tocó")


func test_el_mas_cerca_va_a_presionar() -> void:
	await crear_partido()
	pausar(1)
	var duenio := visitante.jugadores[9]
	poner(duenio, -10, 0)
	dar_pelota(duenio)
	await esperar_fisica(2)
	var cercano: Jugador = null
	for jugador in local.jugadores:
		if jugador == local.arquero():
			continue
		if cercano == null or _distancia(jugador, duenio) < _distancia(cercano, duenio):
			cercano = jugador
	var antes := _distancia(cercano, duenio)
	await esperar_fisica(40)
	afirmar(_distancia(cercano, duenio) < antes - 2.0, "el más cercano no fue a buscar la pelota")


func test_con_la_pelota_avanza_o_la_pasa() -> void:
	await crear_partido()
	pausar(1)
	var volante := local.jugadores[6]
	poner(volante, -15, 0)
	dar_pelota(volante)
	var pateo := [false]
	volante.pateo.connect(func(_t: Jugador.Patada, _f: float) -> void: pateo[0] = true)
	await esperar_fisica(120)
	var avanzo := volante.global_position.x > -10.0
	afirmar(pateo[0] or avanzo, "el que tenía la pelota no hizo nada")


func test_la_dificultad_cambia_como_juega() -> void:
	var facil: Dictionary = IAEquipo.PARAMETROS[ConfiguracionPartido.Dificultad.FACIL]
	var dificil: Dictionary = IAEquipo.PARAMETROS[ConfiguracionPartido.Dificultad.DIFICIL]
	afirmar(facil["reaccion"] > dificil["reaccion"], "en fácil no reacciona más lento")
	afirmar(facil["presion"] < dificil["presion"], "en fácil no presiona menos")
	afirmar(facil["arquero"] < dificil["arquero"], "en fácil el arquero no es peor")
	afirmar(facil["atributos"] < 0 and dificil["atributos"] > 0, "los atributos no cambian con la dificultad")


func test_no_toca_al_jugador_de_la_persona() -> void:
	await crear_partido(0)
	var manejado := partido.control.jugador
	afirmar(partido.ias[0].excluido == manejado, "la IA no sabe a quién maneja la persona")
	afirmar(partido.ias[1].excluido == null, "la IA del rival excluye a alguien")
	var otro := local.jugadores[3]
	partido.control.cambiar_a(otro)
	afirmar(partido.ias[0].excluido == otro, "al cambiar de jugador la IA no se enteró")


func test_quieta_durante_una_cinematica() -> void:
	await crear_partido()
	for ia in partido.ias:
		ia.en_pausa = true
	partido.arbitro.en_pausa = true
	var jugador := local.jugadores[5]
	jugador.entrada.direccion = Vector3(0, 0, 1)
	await esperar_fisica(10)
	afirmar(jugador.entrada.direccion == Vector3(0, 0, 1), "la IA pisó la entrada durante la pausa")


func _distancia(a: Jugador, b: Jugador) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
