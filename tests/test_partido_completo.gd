extends "res://tests/prueba.gd"
## El partido 11 contra 11: equipos, formaciones, lo elegido en el menú, la máquina
## jugando sola y el cambio automático de jugador.

const DATOS_DE_PRUEBA := "res://tests/datos"

var partido: PartidoCompleto


func despues_de_cada() -> void:
	if is_instance_valid(partido):
		partido.queue_free()
	partido = null
	Catalogo.recargar()
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


func test_arma_once_contra_once_y_espera_el_saque() -> void:
	await crear_partido()
	afirmar(partido.jugadores.size() == 22, "no están los 22 (hay %d)" % partido.jugadores.size())
	for equipo in partido.equipos:
		afirmar(equipo.jugadores.size() == 11, "%s no tiene 11" % equipo.nombre)
		afirmar(equipo.puestos.count("ARQ") == 1, "%s no tiene un solo arquero" % equipo.nombre)
		for jugador in equipo.jugadores:
			var en_su_mitad := equipo.progreso(jugador.global_position) <= 0.5
			afirmar(en_su_mitad, "%s no arranca en su mitad" % jugador.nombre_jugador)
	var arbitro := partido.arbitro
	afirmar(arbitro.estado == Arbitro.Estado.SAQUE, "no arranca esperando el saque del medio")
	afirmar(arbitro.tipo_saque == Arbitro.Saque.INICIAL, "el primer saque no es del medio")
	afirmar(arbitro.ejecutor != null and arbitro.ejecutor.tiene_pelota(), "el que saca no tiene la pelota")
	afirmar(partido.pelota.global_position.length() < 1.0, "la pelota no está en el medio")


func test_las_tres_formaciones_estan_en_datos() -> void:
	var nombres := EquipoPartido.formaciones_disponibles()
	for nombre: String in ["4-4-2", "4-3-3", "3-5-2"]:
		afirmar(nombre in nombres, "falta la formación " + nombre)
		var puestos := EquipoPartido.leer_formacion(nombre)
		afirmar(puestos.size() == 11, "%s no tiene 11 puestos" % nombre)
		var arqueros := puestos.filter(func(p: Dictionary) -> bool: return p["rol"] == "ARQ")
		afirmar(arqueros.size() == 1, "%s no tiene un solo arquero" % nombre)


func test_cada_titular_va_a_su_puesto() -> void:
	Catalogo.recargar(DATOS_DE_PRUEBA)
	var equipo := EquipoPartido.new()
	afirmar(equipo.cargar_club("rojo_sc", 0), "no encontró el club de prueba")
	afirmar(equipo.formacion == "4-3-3", "no usó la formación del plantel")
	afirmar(equipo.titulares.size() == 11, "no hay 11 titulares")
	for i in 11:
		var datos := equipo.titulares[i]
		var es_arquero: bool = datos.get("posicion") == "ARQ"
		var bien := es_arquero == (equipo.puestos[i] == "ARQ")
		afirmar(bien, "%s quedó en el puesto %s" % [datos.get("nombre"), equipo.puestos[i]])


func test_cambiar_la_formacion_no_cambia_a_los_jugadores() -> void:
	await crear_partido()
	var equipo := partido.equipos[0]
	var antes := equipo.jugadores.duplicate()
	var arquero := equipo.arquero()
	partido.cambiar_formacion("3-5-2")
	afirmar(equipo.formacion == "3-5-2", "no cambió la formación")
	afirmar(equipo.jugadores.size() == 11, "se perdieron jugadores")
	for jugador in antes:
		afirmar(jugador in equipo.jugadores, "%s quedó afuera" % jugador.nombre_jugador)
	afirmar(equipo.arquero() == arquero, "cambió el arquero")


func test_arma_el_partido_con_lo_elegido_en_el_menu() -> void:
	Catalogo.recargar(DATOS_DE_PRUEBA)
	ConfigPartido.preparar("azul_fc", "rojo_sc")
	ConfigPartido.dificultad = 2
	var configuracion := ConfiguracionPartido.desde_menu()
	afirmar(configuracion.club_local == "azul_fc", "no tomó el club local")
	afirmar(configuracion.titulares_local.size() == 11, "no tomó los titulares")
	afirmar(configuracion.dificultad == ConfiguracionPartido.Dificultad.DIFICIL, "no tomó la dificultad")
	partido = PartidoCompleto.new()
	partido.con_cinematicas = false
	add_child(partido)
	await esperar_fisica(2)
	afirmar(partido.equipos[0].club_id == "azul_fc", "el local no es el club elegido")
	afirmar(partido.control != null and partido.control.equipo == 0, "la persona no maneja al local")
	var color := partido.equipos[0].color
	afirmar(color.is_equal_approx(ConfigPartido.color_camiseta("local")), "el local no tiene la camiseta elegida")
	ConfigPartido.local_id = ""
	ConfigPartido.visitante_id = ""


func test_la_maquina_juega_sola_sin_trabarse() -> void:
	await crear_partido()
	var posiciones := {}
	for jugador in partido.jugadores:
		posiciones[jugador] = jugador.global_position
	var patadas := [0]
	partido.pelota.pateada.connect(func(_p: Jugador, _d: Jugador) -> void: patadas[0] += 1)
	await esperar_fisica(60 * 8)
	afirmar(patadas[0] >= 3, "casi no patearon (%d patadas)" % patadas[0])
	var se_movieron := 0
	for jugador in partido.jugadores:
		if jugador.global_position.distance_to(posiciones[jugador]) > 2.0:
			se_movieron += 1
	afirmar(se_movieron >= 12, "se movieron pocos jugadores (%d)" % se_movieron)
	afirmar(partido.arbitro.segundos_jugados > 5.0, "el reloj no corrió")


func test_defendiendo_pasa_solo_al_que_esta_cerca() -> void:
	await crear_partido(0)
	for ia in partido.ias:
		ia.en_pausa = true
	var arbitro := partido.arbitro
	arbitro.ejecutor.patear(Jugador.Patada.PASE, 0.3, Vector3(-1, 0, 0))
	await esperar_fisica(2)
	var propio := partido.equipos[0]
	var rival := partido.equipos[1]
	# Lejos de la pelota maneja a uno, y el rival la tiene al lado de otro compañero.
	var lejos := propio.jugadores[9]
	var cerca := propio.jugadores[2]
	for jugador in partido.jugadores:
		jugador.entrada.limpiar()
	# Todos lejos de donde va a estar la pelota, menos uno.
	for i in propio.jugadores.size():
		var jugador := propio.jugadores[i]
		jugador.detener()
		jugador.global_position = Vector3(-40 + i, Jugador.ALTURA / 2, 28)
	cerca.global_position = Vector3(-20, Jugador.ALTURA / 2, -5)
	partido.pelota.colocar(Vector3(-40, Pelota.RADIO, 0))
	partido.control.cambiar_a(lejos)
	await esperar_fisica(70)
	var duenio := rival.jugadores[9]
	duenio.global_position = Vector3(-18, Jugador.ALTURA / 2, -5)
	partido.pelota.colocar(duenio.punto_de_conduccion())
	partido.pelota.dar_a(duenio)
	await esperar_fisica(10)
	afirmar(partido.control.jugador == cerca, "no pasó al compañero más cerca de la pelota")
