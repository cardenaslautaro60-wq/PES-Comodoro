extends "res://tests/prueba.gd"
## Física de la pelota: roce, pique, efecto y los cálculos para pases.

var mundo: Node3D
var pelota: Pelota


func antes_de_cada() -> void:
	mundo = Node3D.new()
	add_child(mundo)
	mundo.add_child(Cancha.new())
	pelota = Pelota.new()
	pelota.position = Vector3(-30, Pelota.RADIO + 0.01, 0)
	mundo.add_child(pelota)
	await esperar_fisica(2)


func despues_de_cada() -> void:
	mundo.queue_free()
	await get_tree().process_frame


func test_rodando_se_frena_sola() -> void:
	pelota.linear_velocity = Vector3(10, 0, 0)
	await esperar_fisica(60 * 8)
	var velocidad := pelota.linear_velocity.length()
	afirmar(velocidad < 0.2, "la pelota sigue rodando después de 8 segundos (%.2f m/s)" % velocidad)


func test_la_velocidad_calculada_para_rodar_llega_a_la_distancia() -> void:
	var inicio := pelota.global_position
	var rapidez := pelota.velocidad_para_rodar(20.0, 0.0)
	pelota.linear_velocity = Vector3(rapidez, 0, 0)
	await esperar_fisica(60 * 8)
	var recorrido := pelota.global_position.x - inicio.x
	afirmar(absf(recorrido - 20.0) < 1.5, "tenía que rodar 20 m y rodó %.1f m" % recorrido)


func test_la_velocidad_calculada_para_volar_pica_donde_tiene_que_picar() -> void:
	var inicio := pelota.global_position
	var angulo := deg_to_rad(30)
	var rapidez := pelota.velocidad_para_volar(30.0, angulo)
	pelota.linear_velocity = Vector3(cos(angulo), sin(angulo), 0) * rapidez
	await esperar_fisica(10)
	for i in 60 * 4:
		await esperar_fisica(1)
		if pelota.global_position.y <= Pelota.RADIO + 0.03:
			break
	var recorrido := pelota.global_position.x - inicio.x
	afirmar(absf(recorrido - 30.0) < 2.0, "tenía que picar a 30 m y picó a %.1f m" % recorrido)


func test_el_efecto_curva_la_pelota() -> void:
	pelota.patear(Vector3(20, 6, 0), Vector3(0, 25, 0), null)
	await esperar_fisica(40)
	var z := pelota.global_position.z
	afirmar(z < -0.5, "la pelota con efecto no se curvó (z = %.2f)" % z)


func test_sin_efecto_va_derecho() -> void:
	pelota.patear(Vector3(20, 6, 0), Vector3.ZERO, null)
	await esperar_fisica(40)
	var z := pelota.global_position.z
	afirmar(absf(z) < 0.05, "la pelota sin efecto se desvió (z = %.2f)" % z)


func test_cae_y_queda_en_el_pasto() -> void:
	pelota.colocar(Vector3(10, 3, 10))
	await esperar_fisica(60 * 4)
	var altura := pelota.global_position.y
	afirmar(altura > 0.0 and altura < 0.3, "la pelota no quedó apoyada en el pasto (altura %.2f)" % altura)


func test_el_angulo_calculado_pasa_a_la_altura_pedida() -> void:
	var angulo := pelota.angulo_para_altura(25.0, 16.0, 1.5)
	var inicio := pelota.global_position
	pelota.linear_velocity = Vector3(cos(angulo), sin(angulo), 0) * 25.0
	var altura := -1.0
	for i in 60 * 3:
		await esperar_fisica(1)
		if pelota.global_position.x - inicio.x >= 16.0:
			altura = pelota.global_position.y
			break
	afirmar(absf(altura - 1.5) < 0.35, "tenía que pasar a 1,5 m de altura y pasó a %.2f m" % altura)
