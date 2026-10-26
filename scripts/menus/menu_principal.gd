extends "res://scripts/menus/pantalla_menu.gd"
## Menú principal: amistoso, opciones, créditos y salir.


func armar() -> void:
	Sonido.musica_de_menu()
	espacio()
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 40)
	contenido.add_child(fila)

	var titulos := VBoxContainer.new()
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulos.alignment = BoxContainer.ALIGNMENT_CENTER
	# El nombre sale de la configuración del proyecto, así se cambia en un solo lugar.
	var nombre := str(ProjectSettings.get_setting("application/config/name", "Comodoro"))
	var titulo := TemaUI.etiqueta(nombre, 76, TemaUI.ACENTO)
	titulo.name = "Titulo"
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulos.add_child(titulo)
	titulos.add_child(TemaUI.etiqueta("Fútbol de la Liga de Comodoro Rivadavia", TemaUI.TAMANO_LETRA, TemaUI.TEXTO))
	var version := "v" + str(ProjectSettings.get_setting("application/config/version", "0"))
	titulos.add_child(TemaUI.etiqueta(version, TemaUI.TAMANO_CHICO, TemaUI.TEXTO_SUAVE))
	fila.add_child(titulos)

	var botones := VBoxContainer.new()
	botones.name = "Botones"
	botones.custom_minimum_size.x = 400
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 16)
	var amistoso := boton("Amistoso", Navegacion.ir_a.bind(Navegacion.SELECCION_EQUIPOS), true)
	amistoso.name = "Amistoso"
	botones.add_child(amistoso)
	var opciones := boton("Opciones", Navegacion.ir_a.bind(Navegacion.OPCIONES))
	opciones.name = "Opciones"
	botones.add_child(opciones)
	var creditos := boton("Créditos", Navegacion.ir_a.bind(Navegacion.CREDITOS))
	creditos.name = "Creditos"
	botones.add_child(creditos)
	if Navegacion.se_puede_salir():
		var salir := boton("Salir", get_tree().quit)
		salir.name = "Salir"
		botones.add_child(salir)
	fila.add_child(botones)
	espacio()


func volver() -> void:
	# En Android, "atrás" en el menú principal cierra el juego, como cualquier app.
	if OS.has_feature("mobile"):
		get_tree().quit()
