extends "res://scripts/menus/pantalla_menu.gd"
## Pantalla del final: resultado y opciones para seguir.

const Escudo := preload("res://scripts/ui/escudo.gd")


func armar() -> void:
	Sonido.musica_de_menu()
	espacio()
	var titulo := TemaUI.etiqueta("Final del partido", 40, TemaUI.TEXTO_SUAVE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenido.add_child(titulo)

	var fila := HBoxContainer.new()
	fila.name = "Marcador"
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 28)
	contenido.add_child(fila)
	for lado: String in ConfigPartido.LADOS:
		var columna := VBoxContainer.new()
		columna.custom_minimum_size.x = 260
		var escudo := Escudo.new()
		escudo.custom_minimum_size = Vector2(150, 150)
		escudo.club = ConfigPartido.club_de(lado)
		columna.add_child(escudo)
		var nombre := TemaUI.etiqueta(ConfigPartido.nombre_de(lado), 32)
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columna.add_child(nombre)
		if lado == "visitante":
			var goles := TemaUI.etiqueta(
				"%d - %d" % [ConfigPartido.goles["local"], ConfigPartido.goles["visitante"]], 96, TemaUI.ACENTO
			)
			goles.name = "Goles"
			goles.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fila.add_child(goles)
		fila.add_child(columna)

	var frase := TemaUI.etiqueta(_frase(), TemaUI.TAMANO_LETRA)
	frase.name = "Frase"
	frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenido.add_child(frase)
	espacio()

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 16)
	var revancha := boton("Revancha", _revancha, true)
	revancha.name = "Revancha"
	botones.add_child(revancha)
	botones.add_child(boton("Otros equipos", Navegacion.ir_a.bind(Navegacion.SELECCION_EQUIPOS)))
	botones.add_child(boton("Menú principal", volver))
	for hijo in botones.get_children():
		(hijo as Control).custom_minimum_size.x = 300
	contenido.add_child(botones)


func volver() -> void:
	Navegacion.ir_a(Navegacion.MENU_PRINCIPAL)


func _revancha() -> void:
	ConfigPartido.reiniciar_resultado()
	Navegacion.ir_a(Navegacion.PARTIDO)


func _frase() -> String:
	var local: int = ConfigPartido.goles["local"]
	var visitante: int = ConfigPartido.goles["visitante"]
	if local > visitante:
		return "¡Ganó %s!" % ConfigPartido.nombre_de("local")
	if visitante > local:
		return "Ganó %s. Hay revancha." % ConfigPartido.nombre_de("visitante")
	return "Empate. Repartieron puntos."
