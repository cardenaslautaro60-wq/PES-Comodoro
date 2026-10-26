extends "res://tests/prueba.gd"
## El jugador: conducción, pases, tiros, barra de potencia, estamina, barridas y robos.

var mundo: Node3D
var cancha: Cancha
var pelota: Pelota
var goles: Array[int] = []


func antes_de_cada() -> void:
	goles.clear()
	mundo = Node3D.new()
	add_child(mundo)
	cancha = Cancha.new()
	cancha.gol.connect(func(lado: int) -> void: goles.append(lado))
	mundo.add_child(cancha)
	pelota = Pelota.new()
	pelota.position = Vector3(0, Pelota.RADIO + 0.01, -20)
	pelota.rng.seed = 1234
	mundo.add_child(pelota)
	await esperar_fisica(2)


func despues_de_cada() -> void:
	mundo.queue_free()
	await get_tree().process_frame


func crear(x: float, z: float, equipo := 0) -> Jugador:
	var jugador := Jugador.new()
	jugador.equipo = equipo
	jugador.pelota = pelota
	jugador.rng.seed = 99
	jugador.direccion_mirada = Vector3(1 if equipo == 0 else -1, 0, 0)
	jugador.position = Vector3(x, Jugador.ALTURA / 2, z)
	mundo.add_child(jugador)
	return jugador


func dar_pelota(jugador: Jugador) -> void:
	pelota.colocar(jugador.punto_de_conduccion())
	pelota.dar_a(jugador)


func test_toma_la_pelota_suelta_que_tiene_cerca() -> void:
	var jugador := crear(0, 0)
	pelota.colocar(Vector3(0.6, Pelota.RADIO, 0))
	await esperar_fisica(3)
	afirmar(jugador.tiene_pelota(), "no tomó la pelota que tenía al lado")


func test_conduce_con_la_pelota_pegada_al_pie() -> void:
	var jugador := crear(0, 0)
	dar_pelota(jugador)
	jugador.entrada.direccion = Vector3(1, 0, 0)
	var lejos := 0.0
	for i in 60 * 2:
		await esperar_fisica(1)
		lejos = maxf(lejos, jugador.global_position.distance_to(pelota.global_position))
	afirmar(jugador.global_position.x > 8.0, "el jugador casi no avanzó (x = %.1f)" % jugador.global_position.x)
	afirmar(jugador.tiene_pelota(), "perdió la pelota conduciendo")
	afirmar(lejos < 1.6, "la pelota se le fue lejos del pie (%.2f m)" % lejos)


func test_con_pelota_tiene_que_girar() -> void:
	var jugador := crear(0, 0)
	dar_pelota(jugador)
	jugador.entrada.direccion = Vector3(-1, 0, 0)
	await esperar_fisica(3)
	var angulo := rad_to_deg(jugador.direccion_mirada.angle_to(Vector3(-1, 0, 0)))
	afirmar(angulo > 60.0, "con la pelota se dio vuelta de golpe (le faltan %.0f grados)" % angulo)


func test_el_pase_llega_al_companero() -> void:
	var pasador := crear(0, 0)
	var receptor := crear(14, 6)
	pasador.pase = 99
	dar_pelota(pasador)
	await esperar_fisica(2)
	var destino := pasador.patear(Jugador.Patada.PASE, 0.4, Vector3(1, 0, 0.4))
	afirmar(destino == receptor, "el pase no eligió al compañero")
	for i in 60 * 4:
		await esperar_fisica(1)
		if receptor.tiene_pelota():
			break
	afirmar(receptor.tiene_pelota(), "el pase no le llegó al compañero")


func test_el_pase_largo_va_por_arriba() -> void:
	var pasador := crear(0, 0)
	crear(30, 0)
	dar_pelota(pasador)
	await esperar_fisica(2)
	pasador.patear(Jugador.Patada.PASE_LARGO, 0.6, Vector3(1, 0, 0))
	var altura := 0.0
	for i in 60:
		await esperar_fisica(1)
		altura = maxf(altura, pelota.global_position.y)
	afirmar(altura > 3.0, "el pase largo no levantó la pelota (altura máxima %.1f m)" % altura)


func test_tiro_desde_el_punto_penal_es_gol() -> void:
	var x := Cancha.LARGO / 2 - Cancha.DISTANCIA_PENAL - 1.0
	var pateador := crear(x, 0)
	pateador.tiro = 99
	dar_pelota(pateador)
	await esperar_fisica(2)
	pateador.patear(Jugador.Patada.TIRO, 0.6, Vector3(1, 0, 0))
	await esperar_fisica(90)
	afirmar(goles == [1], "el tiro desde el punto penal no fue gol (goles: %s)" % [goles])


func test_mantener_el_boton_carga_la_potencia_y_soltarlo_patea() -> void:
	var jugador := crear(0, 0)
	dar_pelota(jugador)
	await esperar_fisica(2)
	jugador.entrada.tiro = true
	await esperar_fisica(30)
	var cargada := jugador.potencia
	afirmar(cargada > 0.35 and cargada < 0.65, "la barra no se cargó como esperaba (%.2f)" % cargada)
	jugador.entrada.tiro = false
	await esperar_fisica(2)
	afirmar(not jugador.tiene_pelota(), "al soltar el botón no pateó")
	afirmar(pelota.linear_velocity.length() > 10.0, "el tiro salió muy flojo")
	afirmar(jugador.potencia < 0.0, "la barra quedó cargada después de patear")


func test_el_sprint_gasta_estamina_y_es_mas_rapido() -> void:
	var jugador := crear(0, 0)
	jugador.entrada.direccion = Vector3(1, 0, 0)
	jugador.entrada.sprint = true
	await esperar_fisica(120)
	var rapidez := Vector2(jugador.velocity.x, jugador.velocity.z).length()
	afirmar(jugador.estamina_actual < 0.95, "el sprint no gastó estamina (%.2f)" % jugador.estamina_actual)
	afirmar(rapidez > jugador.velocidad_maxima(false), "el sprint no es más rápido que correr")


func test_la_barrida_le_saca_la_pelota_al_rival() -> void:
	var defensor := crear(1.5, 0)
	var rival := crear(5, 0, 1)
	dar_pelota(rival)
	await esperar_fisica(40)
	defensor.barrer(Vector3(1, 0, 0))
	await esperar_fisica(40)
	afirmar(not rival.tiene_pelota(), "el rival sigue con la pelota después de la barrida")
	afirmar(pelota.ultimo_en_tocar == defensor, "la pelota no la tocó el que barrió")
	afirmar(rival.estado != Jugador.Estado.CAIDO, "una barrida limpia derribó al rival")


func test_la_barrida_al_cuerpo_es_falta() -> void:
	var defensor := crear(1.5, 0)
	var rival := crear(4.5, 0, 1)
	var faltas: Array[Jugador] = []
	defensor.falta_cometida.connect(func(victima: Jugador) -> void: faltas.append(victima))
	defensor.barrer(Vector3(1, 0, 0))
	await esperar_fisica(40)
	afirmar(faltas == [rival], "barrer al cuerpo no fue falta")
	afirmar(rival.estado == Jugador.Estado.CAIDO, "el rival no cayó")


func test_presionando_le_roba_la_pelota_al_rival() -> void:
	var defensor := crear(0, 0)
	var rival := crear(3, 0, 1)
	dar_pelota(rival)
	await esperar_fisica(2)
	defensor.entrada.pase = true
	await esperar_fisica(2)
	afirmar(defensor.presionando, "con el botón de pase defendiendo no presiona")
	for i in 60 * 5:
		await esperar_fisica(1)
		if defensor.tiene_pelota():
			break
	afirmar(defensor.tiene_pelota(), "presionando nunca le sacó la pelota")


func test_defendiendo_el_boton_de_tiro_barre() -> void:
	var defensor := crear(0, 0)
	var rival := crear(10, 0, 1)
	dar_pelota(rival)
	await esperar_fisica(2)
	defensor.entrada.tiro = true
	await esperar_fisica(2)
	afirmar(defensor.estado == Jugador.Estado.BARRIDA, "con el botón de tiro defendiendo no barrió")


func test_aplica_los_datos_del_plantel() -> void:
	var jugador := crear(0, 0)
	var datos := {
		"nombre": "Benjamín Aguirre",
		"apodo": null,
		"dorsal": 8,
		"atributos": {"velocidad": 90, "pase": 60, "tiro": 50, "defensa": 40, "estamina": 80},
	}
	jugador.aplicar_datos(datos)
	afirmar(jugador.nombre_jugador == "Benjamín Aguirre", "no tomó el nombre")
	afirmar(jugador.dorsal == 8 and jugador.velocidad == 90 and jugador.estamina == 80, "no tomó los atributos")
