extends "res://tests/prueba.gd"
## Pantallas de menú y partido: que se armen, que naveguen a donde corresponde
## y que el marcador, el reloj y la pausa funcionen.

const DATOS_DE_PRUEBA := "res://tests/datos"

var pantalla: Node


func antes_de_cada() -> void:
	Navegacion.simular = true
	Navegacion.ultimo_destino = ""
	Catalogo.recargar(DATOS_DE_PRUEBA)
	ConfigPartido.preparar("azul_fc", "rojo_sc")


func despues_de_cada() -> void:
	get_tree().paused = false
	if is_instance_valid(pantalla):
		pantalla.queue_free()
	await get_tree().process_frame
	Sonido.detener_todo()
	Navegacion.simular = false
	Catalogo.recargar()
	ConfigPartido.local_id = ""


func abrir(ruta: String) -> Node:
	pantalla = (load(ruta) as PackedScene).instantiate()
	add_child(pantalla)
	await get_tree().process_frame
	await get_tree().process_frame
	return pantalla


func test_menu_principal_lleva_al_amistoso() -> void:
	await abrir(Navegacion.MENU_PRINCIPAL)
	var amistoso := pantalla.find_child("Amistoso", true, false) as Button
	afirmar(amistoso != null, "falta el botón Amistoso")
	if amistoso:
		amistoso.pressed.emit()
	afirmar(Navegacion.ultimo_destino == Navegacion.SELECCION_EQUIPOS, "Amistoso no lleva a elegir equipos")


func test_todas_las_pantallas_abren() -> void:
	for ruta: String in [Navegacion.OPCIONES, Navegacion.CREDITOS, Navegacion.RESULTADO, Navegacion.PREPARAR_PARTIDO]:
		await abrir(ruta)
		afirmar(pantalla.find_child("Contenido", true, false) != null, "no se armó " + ruta)
		pantalla.queue_free()
		await get_tree().process_frame


func test_seleccion_cambia_de_club_y_sigue() -> void:
	await abrir(Navegacion.SELECCION_EQUIPOS)
	afirmar(ConfigPartido.local_id == "azul_fc", "debería arrancar con la elección anterior")
	pantalla.call("cambiar_club", "local", 1)
	afirmar(ConfigPartido.local_id == "celeste", "la flecha no cambió el club local")
	afirmar(ConfigPartido.camiseta["local"] == "titular", "el local siempre arranca de titular")
	pantalla.call("cambiar_club", "local", -2)
	afirmar(ConfigPartido.local_id == "rojo_sc", "la flecha para atrás debería dar la vuelta")
	var antes: String = ConfigPartido.camiseta["visitante"]
	pantalla.call("cambiar_camiseta", "visitante")
	afirmar(ConfigPartido.camiseta["visitante"] != antes, "no cambió la camiseta")
	(pantalla.find_child("Siguiente", true, false) as Button).pressed.emit()
	afirmar(Navegacion.ultimo_destino == Navegacion.PREPARAR_PARTIDO, "Siguiente no lleva a preparar el partido")
	pantalla.call("volver")
	afirmar(Navegacion.ultimo_destino == Navegacion.MENU_PRINCIPAL, "atrás debería volver al menú")


func test_seleccion_sin_clubes_avisa() -> void:
	Catalogo.recargar("res://tests/no_existe")
	await abrir(Navegacion.SELECCION_EQUIPOS)
	afirmar(pantalla.find_child("SinClubes", true, false) != null, "debería avisar que no hay clubes")


func test_preparar_partido_cambia_formacion_y_juega() -> void:
	await abrir(Navegacion.PREPARAR_PARTIDO)
	var selector: Node = pantalla.get("selector_formacion")
	selector.call("mover", 1)
	afirmar(ConfigPartido.formacion["local"] == "3-5-2", "no cambió la formación (%s)" % ConfigPartido.formacion["local"])
	pantalla.get("selector_minutos").call("mover", 1)
	afirmar(ConfigPartido.minutos_por_tiempo == 7, "no cambió la duración")
	(pantalla.find_child("Jugar", true, false) as Button).pressed.emit()
	afirmar(Navegacion.ultimo_destino == Navegacion.PARTIDO, "¡A jugar! no lleva al partido")


func test_partido_cuenta_goles_en_el_marcador() -> void:
	await abrir(Navegacion.PARTIDO)
	var juego: Node = pantalla.get("juego")
	juego.emit_signal("gol", "local")
	juego.emit_signal("gol", "visitante")
	juego.emit_signal("gol", "local")
	afirmar(ConfigPartido.goles["local"] == 2 and ConfigPartido.goles["visitante"] == 1, "no contó bien los goles")
	var hud: Node = pantalla.get("hud")
	var goles_local := hud.find_child("GolesLocal", true, false) as Label
	afirmar(goles_local.text == "2", "el marcador muestra %s" % goles_local.text)
	afirmar(hud.call("texto_cartel") == "¡GOOOL!", "no apareció el cartel de gol")
	var viejo := juego.get_node_or_null("Interfaz/Marcador") as CanvasItem
	afirmar(viejo == null or not viejo.visible, "el marcador de la escena de prueba debería esconderse")


func test_partido_termina_con_el_reloj() -> void:
	await abrir(Navegacion.PARTIDO)
	var reloj: Node = pantalla.get("reloj")
	reloj.call("avanzar", ConfigPartido.minutos_por_tiempo * 60.0)
	afirmar(pantalla.get("hud").call("texto_cartel") == "Entretiempo", "no avisó el entretiempo")
	reloj.call("avanzar", ConfigPartido.minutos_por_tiempo * 60.0)
	afirmar(ConfigPartido.terminado, "el partido debería haber terminado")
	pantalla.get("juego").emit_signal("gol", "local")
	afirmar(ConfigPartido.goles["local"] == 0, "no debería contar goles después del final")


func test_pausa_frena_y_hace_cambios() -> void:
	await abrir(Navegacion.PARTIDO)
	var pausa: Node = pantalla.get("pausa")
	pantalla.call("volver")
	afirmar(get_tree().paused and pausa.get("abierta"), "atrás debería abrir la pausa")
	pausa.call("mostrar_cambios")
	var sale: String = ConfigPartido.titulares["local"][2]
	var entra: String = ConfigPartido.suplentes["local"][0]
	pausa.call("elegir_jugador", sale, true)
	pausa.call("elegir_jugador", entra, false)
	afirmar(ConfigPartido.titulares["local"].has(entra), "no se hizo el cambio")
	afirmar(ConfigPartido.cambios_restantes("local") == ConfigPartido.MAX_CAMBIOS - 1, "no se descontó el cambio")
	pausa.call("volver")
	pausa.call("volver")
	afirmar(not get_tree().paused, "dos veces atrás debería volver al partido")


func test_salir_del_partido_pide_confirmacion() -> void:
	await abrir(Navegacion.PARTIDO)
	var pausa: Node = pantalla.get("pausa")
	pausa.call("abrir")
	var salir := pausa.find_child("Salir", true, false) as Button
	salir.pressed.emit()
	afirmar(Navegacion.ultimo_destino == "", "salió sin confirmar")
	salir.pressed.emit()
	afirmar(Navegacion.ultimo_destino == Navegacion.MENU_PRINCIPAL, "no salió al menú")


func test_partido_viste_a_los_jugadores_con_el_club_elegido() -> void:
	await abrir(Navegacion.PARTIDO)
	var juego: Node = pantalla.get("juego")
	var primero: Node = juego.get("jugadores")[0]
	afirmar(primero.get("nombre_jugador") == "Jugador 10", "el 10 debería llamarse como en el plantel")
	var color: Color = primero.get("color_equipo")
	afirmar(color.is_equal_approx(ConfigPartido.color_camiseta("local")), "el local no tiene el color de su camiseta")
