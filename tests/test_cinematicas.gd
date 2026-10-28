extends "res://tests/prueba.gd"
## Cinemáticas: tomas de cámara, grabación de repeticiones y que cada cinemática
## del entrenamiento arranque, se pueda saltear y devuelva el control.

const Entrenamiento := preload("res://scripts/partido/entrenamiento.gd")
const ESCENA := preload("res://escenas/partido/entrenamiento.tscn")

var escena: Entrenamiento


func antes_de_cada() -> void:
	escena = ESCENA.instantiate() as Entrenamiento
	add_child(escena)
	await esperar_fisica(2)


func despues_de_cada() -> void:
	Engine.time_scale = 1.0
	for accion: String in ["pase", "tiro", "sprint", "repeticion"]:
		Input.action_release(accion)
	# Termina la cinemática que haya, así no queda nada esperando.
	escena.cinematicas.saltear()
	await _esperar_fin(escena.cinematicas, 3.0)
	escena.queue_free()
	await get_tree().process_frame


func test_toma_recorrido_y_orbita() -> void:
	var recorrido := Toma.recorrido(Vector3(0, 0, 0), Vector3(10, 0, 0), 2.0)
	afirmar(recorrido.posicion_en(0.0, Vector3.ZERO).is_equal_approx(Vector3.ZERO), "el recorrido no arranca en 'desde'")
	afirmar(recorrido.posicion_en(1.0, Vector3.ZERO).is_equal_approx(Vector3(10, 0, 0)), "el recorrido no llega a 'hasta'")
	var medio := recorrido.posicion_en(0.5, Vector3.ZERO)
	afirmar(is_equal_approx(medio.x, 5.0), "a mitad de toma no está en el medio (%.2f)" % medio.x)

	var orbita := Toma.orbita(Vector3.ZERO, Vector2(10, 10), Vector2(3, 3), Vector2(0, 90), 2.0)
	var inicio := orbita.posicion_en(0.0, Vector3.ZERO)
	var fin := orbita.posicion_en(1.0, Vector3.ZERO)
	afirmar(inicio.is_equal_approx(Vector3(10, 3, 0)), "la órbita no arranca en 0 grados: %s" % inicio)
	afirmar(fin.is_equal_approx(Vector3(0, 3, 10)), "la órbita no termina en 90 grados: %s" % fin)

	var siguiendo := Toma.recorrido(Vector3(0, 2, 5), Vector3(0, 2, 5), 1.0).siguiendo(escena.pelota)
	var ancla := Vector3(20, 0, 3)
	afirmar(siguiendo.posicion_en(0.5, ancla).is_equal_approx(Vector3(20, 2, 8)), "la toma no sigue al nodo")


func test_arranca_con_la_presentacion_y_se_saltea() -> void:
	await esperar_fisica(5)
	var director := escena.cinematicas
	afirmar(director != null, "no hay director de cinemáticas")
	afirmar(director.activa and director.nombre_actual == DirectorCinematicas.PRESENTACION, "no arrancó la presentación")
	afirmar(director.camara.current, "no se usa la cámara de cinemática")
	afirmar(escena.control.process_mode == Node.PROCESS_MODE_DISABLED, "se puede jugar durante la presentación")
	var interfaz := escena.get_node("Interfaz") as CanvasLayer
	afirmar(not interfaz.visible, "la interfaz del partido no se esconde")

	await _saltear_tocando(director)
	afirmar(not director.activa, "la presentación no se salteó con un toque")
	afirmar(escena.camara.current, "no volvió la cámara de TV")
	afirmar(escena.control.process_mode != Node.PROCESS_MODE_DISABLED, "no volvió el control")
	afirmar(interfaz.visible, "no volvió la interfaz")
	await esperar_fisica(20)
	afirmar(escena.control.jugador.tiene_pelota(), "después de la presentación no arrancás con la pelota")


func test_la_presentacion_completa_termina_sola() -> void:
	Engine.time_scale = 4.0
	var director := escena.cinematicas
	var terminada := await _esperar_fin(director, 25.0)
	afirmar(terminada, "la presentación no terminó sola")
	afirmar(escena.camara.current, "no volvió la cámara de TV")


func test_gol_con_festejo_y_repeticion() -> void:
	var director := escena.cinematicas
	await _saltear_tocando(director)
	await esperar_fisica(30)
	escena.pelota.colocar(Vector3(49.0, 0.5, 2.8))
	escena.pelota.ultimo_en_tocar = escena.jugadores[0]
	escena.pelota.linear_velocity = Vector3(15, 0, 0)
	var arranco := false
	for i in 90:
		await get_tree().physics_frame
		if director.activa:
			arranco = true
			break
	afirmar(arranco and director.nombre_actual == DirectorCinematicas.GOL, "el gol no arrancó el festejo")
	afirmar(escena.goles_local == 1, "el gol no se contó")
	afirmar(director.pantalla.titulo_visible() == "¡GOOOL!", "no aparece el cartel de gol")

	Engine.time_scale = 4.0
	var hubo_repeticion := false
	var limite := Time.get_ticks_msec() + 30000
	while director.activa and Time.get_ticks_msec() < limite:
		await get_tree().process_frame
		hubo_repeticion = hubo_repeticion or director.grabador.reproduciendo
	afirmar(not director.activa, "el festejo no terminó solo")
	afirmar(hubo_repeticion, "no hubo repetición del gol")
	await esperar_fisica(5)
	var distancia := escena.pelota.global_position.distance_to(Entrenamiento.POSICION_SAQUE)
	afirmar(distancia < 1.0, "después del gol la pelota no volvió al medio")
	afirmar(escena.camara.current, "no volvió la cámara de TV")


func test_repeticion_manual_vuelve_todo_a_su_lugar() -> void:
	var director := escena.cinematicas
	await _saltear_tocando(director)
	# Se juega un rato para tener algo grabado.
	Input.action_press("tiro")
	await esperar_fisica(40)
	Input.action_release("tiro")
	await esperar_fisica(30)
	afirmar(director.grabador.hay_grabacion(), "no se grabó la jugada")
	var posicion_pelota := escena.pelota.global_position
	var velocidad_pelota := escena.pelota.linear_velocity

	Input.action_press("repeticion")
	await esperar_fisica(3)
	Input.action_release("repeticion")
	afirmar(director.activa and director.nombre_actual == DirectorCinematicas.REPETICION, "R no pasó la repetición")
	afirmar(director.grabador.reproduciendo, "la repetición no muestra lo grabado")
	afirmar(escena.pelota.process_mode == Node.PROCESS_MODE_DISABLED, "la pelota sigue moviéndose en la repetición")

	await esperar_fisica(20)
	await _saltear_tocando(director)
	afirmar(not director.activa, "la repetición no se salteó")
	afirmar(escena.pelota.process_mode != Node.PROCESS_MODE_DISABLED, "la pelota quedó congelada")
	var corrida := escena.pelota.global_position.distance_to(posicion_pelota)
	afirmar(corrida < 0.5 + velocidad_pelota.length() * 0.2, "la pelota no volvió adonde estaba (%.1f m)" % corrida)


func test_final_del_partido_y_entretiempo() -> void:
	var director := escena.cinematicas
	await _saltear_tocando(director)
	escena.goles_local = 2
	escena.goles_visitante = 1
	Engine.time_scale = 4.0
	director.final_del_partido()
	afirmar(director.activa and director.nombre_actual == DirectorCinematicas.FINAL, "no arrancó el final")
	afirmar(director.pantalla.titulo_visible() == "FINAL DEL PARTIDO", "no aparece el cartel del final")
	afirmar(await _esperar_fin(director, 25.0), "el final no terminó solo")

	director.entretiempo()
	afirmar(director.nombre_actual == DirectorCinematicas.ENTRETIEMPO, "no arrancó el entretiempo")
	afirmar(await _esperar_fin(director, 15.0), "el entretiempo no terminó solo")


func test_no_se_saltea_apenas_empieza() -> void:
	var director := escena.cinematicas
	var toque := InputEventScreenTouch.new()
	toque.pressed = true
	director.pantalla._input(toque)
	afirmar(not director.salteada, "un toque que venía del partido salteó la cinemática")
	afirmar(PantallaCinematica.es_pedido_de_saltear(toque), "un toque no cuenta para saltear")
	var soltar := InputEventScreenTouch.new()
	soltar.pressed = false
	afirmar(not PantallaCinematica.es_pedido_de_saltear(soltar), "soltar el dedo cuenta para saltear")


func _saltear_tocando(director: DirectorCinematicas) -> void:
	# Pasa el tiempo en que no se puede saltear y toca la pantalla.
	var limite := Time.get_ticks_msec() + 3000
	while director.pantalla._tiempo_activa < PantallaCinematica.BLOQUEO_AL_EMPEZAR and Time.get_ticks_msec() < limite:
		await get_tree().process_frame
	var toque := InputEventScreenTouch.new()
	toque.pressed = true
	director.pantalla._input(toque)
	await _esperar_fin(director, 3.0)


func _esperar_fin(director: DirectorCinematicas, segundos_reales: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos_reales * 1000)
	while director.activa and Time.get_ticks_msec() < limite:
		await get_tree().process_frame
	# Un cuadro más para que el partido reaccione a la señal de fin.
	await get_tree().process_frame
	return not director.activa


func test_la_intro_termina_y_se_saltea() -> void:
	var escena_intro := (load("res://escenas/cinematicas/intro.tscn") as PackedScene).instantiate()
	escena_intro.set("cambiar_de_escena", false)
	var termino := [false]
	escena_intro.connect("terminada", func() -> void: termino[0] = true)
	add_child(escena_intro)
	var pantalla := escena_intro.get("pantalla") as PantallaCinematica
	afirmar(pantalla != null and pantalla.activa, "la intro no arrancó")
	var limite := Time.get_ticks_msec() + 3000
	while pantalla._tiempo_activa < PantallaCinematica.BLOQUEO_AL_EMPEZAR and Time.get_ticks_msec() < limite:
		await get_tree().process_frame
	var toque := InputEventScreenTouch.new()
	toque.pressed = true
	pantalla._input(toque)
	for i in 5:
		await get_tree().process_frame
	afirmar(termino[0], "la intro no se salteó con un toque")
	escena_intro.queue_free()
	await get_tree().process_frame


func test_festejo_con_cambio_de_lado() -> void:
	var director := escena.cinematicas
	await _saltear_tocando(director)
	# Segundo tiempo: el visitante (1) hace un gol en el arco de x positivo.
	escena.pelota.ultimo_en_tocar = escena.jugadores[4]
	director.festejar_gol(1, 1)
	afirmar(director.pantalla.titulo_visible() == "¡GOOOL!", "no arrancó el festejo")
	var subtitulo := director.pantalla._subtitulo.text
	afirmar(not subtitulo.contains("en contra"), "el gol del visitante salió como en contra: " + subtitulo)
