extends "res://tests/prueba.gd"
## La escena de entrenamiento arma todo, cuenta goles y reubica la pelota.

const Entrenamiento := preload("res://scripts/partido/entrenamiento.gd")
const ESCENA := preload("res://escenas/partido/entrenamiento.tscn")

var escena: Entrenamiento


func antes_de_cada() -> void:
	escena = ESCENA.instantiate() as Entrenamiento
	escena.con_cinematicas = false
	add_child(escena)
	await esperar_fisica(2)


func despues_de_cada() -> void:
	for accion: String in ["pase", "tiro", "sprint"]:
		Input.action_release(accion)
	escena.queue_free()
	await get_tree().process_frame


func test_la_escena_arma_todo() -> void:
	afirmar(escena.pelota != null, "no hay pelota")
	afirmar(escena.jugadores.size() == 8, "no están los 8 jugadores")
	afirmar(escena.camara != null and escena.camara.current, "la cámara de transmisión no está activa")
	afirmar(escena.control.jugador == escena.jugadores[0], "no manejás al primer jugador")
	afirmar(escena.get_node_or_null("Cancha/ArcoDerecho/ZonaGol") != null, "falta el arco derecho")
	afirmar(escena.get_node_or_null("Cancha/ArcoIzquierdo/ZonaGol") != null, "falta el arco izquierdo")


func test_la_pelota_arranca_en_el_centro_con_tu_jugador() -> void:
	await esperar_fisica(10)
	var velocidad := escena.pelota.linear_velocity.length()
	var distancia := escena.pelota.global_position.distance_to(Entrenamiento.POSICION_SAQUE)
	afirmar(escena.control.jugador.tiene_pelota(), "tu jugador no arranca con la pelota")
	afirmar(velocidad < 1.5, "la pelota arranca disparada (%.1f m/s)" % velocidad)
	afirmar(distancia < 0.8, "la pelota no arranca en el centro (está a %.2f m)" % distancia)


func test_con_el_teclado_se_patea() -> void:
	var jugador := escena.control.jugador
	await esperar_fisica(30)
	afirmar(jugador.tiene_pelota(), "el jugador no tomó la pelota del medio")
	Input.action_press("tiro")
	await esperar_fisica(20)
	Input.action_release("tiro")
	await esperar_fisica(3)
	afirmar(escena.pelota.linear_velocity.length() > 10.0, "la pelota no salió al patear")


func test_al_pasar_manejas_al_que_recibe() -> void:
	var jugador := escena.control.jugador
	await esperar_fisica(30)
	var destino := jugador.patear(Jugador.Patada.PASE, 0.5, Vector3(1, 0, -0.6))
	afirmar(destino != null, "el pase no encontró compañero")
	afirmar(escena.control.jugador == destino, "el control no pasó al que recibe")


func test_un_gol_suma_en_el_marcador() -> void:
	# Al costado del arquero, que si no la ataja.
	escena.pelota.colocar(Vector3(49.0, 0.5, 2.8))
	escena.pelota.linear_velocity = Vector3(15, 0, 0)
	await esperar_fisica(60)
	afirmar(escena.goles_local == 1, "el gol no se contó (goles del local: %d)" % escena.goles_local)
	afirmar(escena.goles_visitante == 0, "se le sumó un gol al visitante")


func test_la_pelota_afuera_vuelve_al_centro() -> void:
	escena.pelota.colocar(Vector3(20, 0.5, Cancha.ANCHO / 2 + 2.0))
	await esperar_fisica(120)
	var distancia := escena.pelota.global_position.distance_to(Entrenamiento.POSICION_SAQUE)
	afirmar(distancia < 1.0, "la pelota no volvió al centro (está a %.1f m)" % distancia)
