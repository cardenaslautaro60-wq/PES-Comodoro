extends "res://tests/prueba.gd"

const ACCIONES := ["mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo", "pase", "tiro", "sprint"]


func despues_de_cada() -> void:
	Controles.vector_tactil = Vector2.ZERO


func test_acciones_registradas() -> void:
	for accion: String in ACCIONES:
		afirmar(InputMap.has_action(accion), "falta la acción " + accion)
		afirmar(not InputMap.action_get_events(accion).is_empty(), "la acción %s no tiene teclas" % accion)


func test_registrar_dos_veces_no_duplica_teclas() -> void:
	var antes := InputMap.action_get_events("pase").size()
	Controles.registrar_acciones()
	var despues := InputMap.action_get_events("pase").size()
	afirmar(despues == antes, "registrar_acciones duplicó eventos (%d antes, %d después)" % [antes, despues])


func test_pase_tiene_teclado_y_joystick() -> void:
	var hay_tecla := false
	var hay_boton := false
	for evento in InputMap.action_get_events("pase"):
		hay_tecla = hay_tecla or evento is InputEventKey
		hay_boton = hay_boton or evento is InputEventJoypadButton
	afirmar(hay_tecla, "el pase no tiene tecla")
	afirmar(hay_boton, "el pase no tiene botón de joystick")


func test_gana_el_joystick_tactil() -> void:
	Controles.vector_tactil = Vector2(0.8, 0)
	var movimiento: Vector2 = Controles.vector_movimiento()
	afirmar(movimiento.is_equal_approx(Vector2(0.8, 0)), "no se usó el joystick táctil")


func test_sin_tocar_nada_no_hay_movimiento() -> void:
	var movimiento: Vector2 = Controles.vector_movimiento()
	afirmar(movimiento == Vector2.ZERO, "hay movimiento sin tocar nada: %s" % movimiento)
