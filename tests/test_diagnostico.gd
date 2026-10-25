extends "res://tests/prueba.gd"
## Temporal: diagnóstico de la pelota que sale despedida. Se borra cuando esté resuelto.

const ESCENA := preload("res://escenas/prueba/prueba.tscn")


func _caso(nombre: String, posicion: Vector3, ccd: bool, esperar_antes: int) -> void:
	var escena: Node3D = ESCENA.instantiate()
	add_child(escena)
	await esperar_fisica(esperar_antes)
	var pelota: RigidBody3D = escena.get("pelota")
	pelota.continuous_cd = ccd
	pelota.contact_monitor = true
	pelota.max_contacts_reported = 4
	print("DIAG %s antes: pos %s vel %s" % [nombre, pelota.global_position, pelota.linear_velocity])
	pelota.global_position = posicion
	for i in 12:
		await get_tree().physics_frame
		var choques := []
		for c in pelota.get_colliding_bodies():
			choques.append(c.name)
		print("DIAG %s f%d pos %s vel %s choca %s" % [nombre, i, pelota.global_position, pelota.linear_velocity, choques])
	escena.queue_free()
	await get_tree().process_frame


func test_diagnostico() -> void:
	await _caso("ccd_10_3_10", Vector3(10, 3, 10), true, 2)
	await _caso("sin_ccd_10_3_10", Vector3(10, 3, 10), false, 2)
	await _caso("ccd_0_3_0", Vector3(0, 3, 0), true, 2)
	await _caso("ccd_10_3_10_espera60", Vector3(10, 3, 10), true, 60)
	await _caso("ccd_30_3_-20", Vector3(30, 3, -20), true, 2)
