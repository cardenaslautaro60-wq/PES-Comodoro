extends "res://tests/prueba.gd"
## Opciones guardadas y sistema de sonido.

const RUTA_DE_PRUEBA := "user://opciones_prueba.cfg"


func antes_de_cada() -> void:
	Opciones.ruta = RUTA_DE_PRUEBA
	Opciones.restablecer()


func despues_de_cada() -> void:
	DirAccess.remove_absolute(RUTA_DE_PRUEBA)
	Opciones.ruta = Opciones.RUTA_POR_DEFECTO
	Opciones.cargar()


func test_las_opciones_se_guardan_y_se_leen() -> void:
	Opciones.cambiar_volumen("Efectos", 0.3)
	Opciones.cambiar_vibracion(false)
	Opciones.cambiar_escala_botones(1.3)
	Opciones.cambiar_minutos(10)
	Opciones.guardar()
	Opciones.restablecer()
	Opciones.cargar()
	afirmar(is_equal_approx(Opciones.volumen["Efectos"], 0.3), "no se guardó el volumen")
	afirmar(not Opciones.vibracion, "no se guardó la vibración")
	afirmar(is_equal_approx(Opciones.escala_botones, 1.3), "no se guardó el tamaño de los botones")
	afirmar(Opciones.minutos_por_tiempo == 10, "no se guardó la duración")


func test_valores_fuera_de_rango_se_corrigen() -> void:
	Opciones.cambiar_volumen("Master", 3.0)
	Opciones.cambiar_escala_botones(9.0)
	Opciones.cambiar_minutos(4)
	afirmar(Opciones.volumen["Master"] == 1.0, "el volumen no debería pasar de 1")
	afirmar(Opciones.escala_botones == Opciones.ESCALA_BOTONES_MAX, "la escala no debería pasar del máximo")
	afirmar(Opciones.minutos_por_tiempo == 5, "4 minutos no es una opción")


func test_existen_los_canales_de_audio() -> void:
	for bus: String in Opciones.BUSES:
		afirmar(AudioServer.get_bus_index(bus) != -1, "falta el canal " + bus)


func test_el_volumen_se_aplica_al_canal() -> void:
	Opciones.cambiar_volumen("Ambiente", 0.5)
	var indice := AudioServer.get_bus_index("Ambiente")
	afirmar(absf(AudioServer.get_bus_volume_db(indice) - linear_to_db(0.5)) < 0.01, "no se aplicó el volumen")
	Opciones.cambiar_volumen("Ambiente", 0.0)
	afirmar(AudioServer.is_bus_mute(indice), "en 0 el canal debería quedar muteado")


func test_estan_todos_los_sonidos() -> void:
	for nombre: String in Sonido.EFECTOS:
		afirmar(Sonido.tiene_efecto(nombre), "falta el sonido " + nombre)
	for nombre: String in Sonido.LOOPS:
		afirmar(Sonido.tiene_loop(nombre), "falta el loop " + nombre)
		var loop := load(Sonido.LOOPS[nombre]) as AudioStreamWAV
		afirmar(loop != null and loop.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s no se repite" % nombre)


func test_reproducir_no_falla() -> void:
	Sonido.reproducir("patada")
	Sonido.reproducir("no_existe")
	Sonido.ambiente_de_partido()
	Sonido.intensidad(2.0)
	Sonido.musica_de_menu()
	Sonido.detener_todo()
	afirmar(true, "")
