extends "res://tests/prueba.gd"
## Cómo se siente: inercia al arrancar y al girar, toques largos en sprint, primer
## toque de los pases fuertes y la comba de los tiros.

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
	pelota.rng.seed = 4321
	mundo.add_child(pelota)
	await esperar_fisica(2)


func despues_de_cada() -> void:
	mundo.queue_free()
	await get_tree().process_frame


func crear(x: float, z: float, equipo := 0) -> Jugador:
	var jugador := Jugador.new()
	jugador.equipo = equipo
	jugador.pelota = pelota
	jugador.rng.seed = 7
	jugador.direccion_mirada = Vector3(1 if equipo == 0 else -1, 0, 0)
	jugador.position = Vector3(x, Jugador.ALTURA / 2, z)
	mundo.add_child(jugador)
	return jugador


func dar_pelota(jugador: Jugador) -> void:
	pelota.colocar(jugador.punto_de_conduccion())
	pelota.dar_a(jugador)


func rapidez(jugador: Jugador) -> float:
	return Vector2(jugador.velocity.x, jugador.velocity.z).length()


func test_arranca_rapido_pero_tarda_en_llegar_al_maximo() -> void:
	var jugador := crear(-30, 0)
	jugador.entrada.direccion = Vector3(1, 0, 0)
	jugador.entrada.sprint = true
	var maxima := jugador.velocidad_maxima(true)
	await esperar_fisica(18)
	afirmar(rapidez(jugador) > maxima * 0.4, "arranca muy lento (%.1f m/s en 0,3 s)" % rapidez(jugador))
	afirmar(rapidez(jugador) < maxima * 0.85, "llega a fondo de golpe (%.1f m/s en 0,3 s)" % rapidez(jugador))
	await esperar_fisica(90)
	afirmar(rapidez(jugador) > maxima * 0.95, "nunca llega a la velocidad máxima (%.1f m/s)" % rapidez(jugador))


func test_giro_cerrado_en_sprint_planta_el_pie() -> void:
	var jugador := crear(-30, 0)
	jugador.entrada.direccion = Vector3(1, 0, 0)
	jugador.entrada.sprint = true
	await esperar_fisica(120)
	var antes := rapidez(jugador)
	jugador.entrada.direccion = Vector3(-1, 0, 0)
	var minima := antes
	for i in 40:
		await esperar_fisica(1)
		minima = minf(minima, rapidez(jugador))
	afirmar(minima < antes * 0.35, "dio la vuelta sin frenar (bajó de %.1f a %.1f m/s)" % [antes, minima])
	afirmar(jugador.velocity.x < 0.0, "después de frenar no salió para el otro lado")


func test_en_sprint_abre_el_giro() -> void:
	var jugador := crear(-30, 0)
	jugador.entrada.direccion = Vector3(1, 0, 0)
	jugador.entrada.sprint = true
	await esperar_fisica(120)
	jugador.entrada.direccion = Vector3(0, 0, 1)
	await esperar_fisica(6)
	var angulo := rad_to_deg(Vector3(1, 0, 0).angle_to(Vector3(jugador.velocity.x, 0, jugador.velocity.z)))
	afirmar(angulo < 70.0, "en sprint dobló 90° casi en el lugar (ya giró %.0f°)" % angulo)


func test_en_sprint_la_pelota_va_mas_lejos_del_pie() -> void:
	var jugador := crear(-30, 0)
	dar_pelota(jugador)
	jugador.entrada.direccion = Vector3(1, 0, 0)
	await esperar_fisica(120)
	var trotando := 0.0
	for i in 60:
		await esperar_fisica(1)
		trotando = maxf(trotando, jugador.punto_de_conduccion().distance_to(jugador.global_position))
	jugador.entrada.sprint = true
	var en_sprint := 0.0
	for i in 120:
		await esperar_fisica(1)
		en_sprint = maxf(en_sprint, jugador.punto_de_conduccion().distance_to(jugador.global_position))
	afirmar(jugador.tiene_pelota(), "perdió la pelota en sprint sin que nadie lo marque")
	afirmar(en_sprint > trotando + 0.15, "en sprint no la empuja más lejos (%.2f contra %.2f)" % [en_sprint, trotando])


func test_el_pase_fuerte_cuesta_mas_pararlo() -> void:
	var torpe := crear(0, 0)
	torpe.pase = 30
	torpe.velocidad = 40
	var habil := crear(0, 5)
	habil.pase = 99
	habil.velocidad = 99
	var fallas_lento := 0
	var fallas_torpe := 0
	var fallas_habil := 0
	for i in 200:
		fallas_lento += 1 if pelota._se_le_escapa(torpe, 9.0) else 0
		fallas_torpe += 1 if pelota._se_le_escapa(torpe, 22.0) else 0
		fallas_habil += 1 if pelota._se_le_escapa(habil, 22.0) else 0
	afirmar(fallas_lento == 0, "un pase suave también se le escapa (%d de 200)" % fallas_lento)
	afirmar(fallas_torpe > 60, "un pase fuerte casi nunca se le escapa al torpe (%d de 200)" % fallas_torpe)
	var mensaje := "el hábil controla igual de mal (%d contra %d)" % [fallas_habil, fallas_torpe]
	afirmar(fallas_habil < fallas_torpe / 2, mensaje)


func test_el_tiro_colocado_dobla_y_entra() -> void:
	var pateador := crear(Cancha.LARGO / 2 - 18.0, 9.0)
	pateador.tiro = 99
	dar_pelota(pateador)
	await esperar_fisica(2)
	# Hacia arriba en la pantalla (z negativo): al palo lejano.
	pateador.patear(Jugador.Patada.TIRO, 0.3, Vector3(1, 0, -0.8))
	afirmar(pelota.efecto.length() > 5.0, "el tiro colocado salió sin efecto")
	await esperar_fisica(150)
	afirmar(goles == [1], "el tiro colocado con comba no entró (goles: %s)" % [goles])


func test_el_tiro_fuerte_casi_no_tiene_efecto() -> void:
	var pateador := crear(Cancha.LARGO / 2 - 18.0, 9.0)
	dar_pelota(pateador)
	await esperar_fisica(2)
	pateador.patear(Jugador.Patada.TIRO, 0.85, Vector3(1, 0, -0.8))
	afirmar(pelota.efecto.length() < 7.0, "el tiro fuerte salió con mucho efecto (%.1f)" % pelota.efecto.length())


func test_la_simulacion_coincide_con_la_pelota_de_verdad() -> void:
	var desde := Vector3(0, Pelota.RADIO + 0.01, 0)
	var velocidad := Vector3(20, 6, 3)
	var giro := Vector3(0, -20, 10)
	var puntos := pelota.trayectoria(desde, velocidad, giro, 1.0)
	pelota.colocar(desde)
	pelota.patear(velocidad, giro, null)
	await esperar_fisica(60)
	var esperada := puntos[59]
	var error := pelota.global_position.distance_to(esperada)
	afirmar(error < 0.8, "la simulación se desvía %.2f m de la pelota real en 1 s" % error)
