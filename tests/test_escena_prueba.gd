extends "res://tests/prueba.gd"

const EscenaDePrueba := preload("res://scripts/prueba/prueba.gd")
const ESCENA := preload("res://escenas/prueba/prueba.tscn")

var escena: EscenaDePrueba


func antes_de_cada() -> void:
	escena = ESCENA.instantiate() as EscenaDePrueba
	add_child(escena)
	await esperar_fisica(2)


func despues_de_cada() -> void:
	Input.action_release("tiro")
	Input.action_release("pase")
	escena.queue_free()
	await get_tree().process_frame


func test_la_escena_arma_todo() -> void:
	afirmar(escena.pelota != null, "no hay pelota")
	afirmar(escena.jugador != null, "no hay jugador")
	afirmar(escena.camara != null and escena.camara.current, "la cámara de TV no está activa")
	afirmar(escena.get_node_or_null("ArcoDerecho/ZonaGol") != null, "falta el arco derecho")
	afirmar(escena.get_node_or_null("ArcoIzquierdo/ZonaGol") != null, "falta el arco izquierdo")


func test_la_pelota_cae_y_queda_en_el_pasto() -> void:
	escena.pelota.global_position = Vector3(10, 3, 10)
	# Se guarda la altura cada medio segundo para entender qué pasó si falla.
	var recorrido: Array[String] = []
	for i in 8:
		await esperar_fisica(30)
		var p := escena.pelota.global_position
		var v := escena.pelota.linear_velocity
		recorrido.append("pos %s vel %s" % [p.snapped(Vector3.ONE * 0.01), v.snapped(Vector3.ONE * 0.01)])
	var altura := escena.pelota.global_position.y
	afirmar(
		altura > 0.0 and altura < 0.3,
		"la pelota no quedó apoyada en el pasto (altura %.2f). Recorrido: %s" % [altura, " | ".join(recorrido)]
	)


func test_el_jugador_patea_la_pelota() -> void:
	escena.jugador.direccion_mirada = Vector3(1, 0, 0)
	var posicion := escena.jugador.global_position + Vector3(0.8, 0, 0)
	posicion.y = EscenaDePrueba.RADIO_PELOTA + 0.02
	escena.pelota.global_position = posicion
	escena.pelota.linear_velocity = Vector3.ZERO
	await esperar_fisica(2)
	Input.action_press("tiro")
	await esperar_fisica(2)
	Input.action_release("tiro")
	var velocidad := escena.pelota.linear_velocity.x
	afirmar(velocidad > 10.0, "la pelota no salió al patear (velocidad %.1f m/s)" % velocidad)


func test_un_gol_suma_en_el_marcador() -> void:
	escena.pelota.global_position = Vector3(49.0, 0.5, 0.0)
	escena.pelota.linear_velocity = Vector3(15, 0, 0)
	await esperar_fisica(60)
	afirmar(escena.goles_local == 1, "el gol no se contó (goles del local: %d)" % escena.goles_local)
	afirmar(escena.goles_visitante == 0, "se le sumó un gol al visitante")


func test_la_pelota_afuera_vuelve_al_centro() -> void:
	escena.pelota.global_position = Vector3(20, 0.5, EscenaDePrueba.ANCHO / 2 + 2.0)
	await esperar_fisica(120)
	var distancia := escena.pelota.global_position.distance_to(Vector3.ZERO)
	afirmar(distancia < 1.0, "la pelota no volvió al centro (está a %.1f m)" % distancia)
