extends "res://scripts/menus/pantalla_menu.gd"
## Elección de los dos equipos: escudo, camiseta, nombre, apodo y nivel.
##
## Se cambia de club con las flechas o deslizando el dedo sobre la tarjeta.
## Si las camisetas se confunden, el visitante pasa solo a la suplente.

const Escudo := preload("res://scripts/ui/escudo.gd")
const VistaCamiseta := preload("res://scripts/ui/vista_camiseta.gd")
const DESLIZAR_MINIMO := 70.0

var indices := {"local": 0, "visitante": 1}

var _clubes: Array[Dictionary] = []
var _tarjetas := {}
var _siguiente: Button
var _inicio_toque := {}


func armar() -> void:
	Sonido.musica_de_menu()
	encabezado("Elegí los equipos")
	_clubes = Catalogo.clubes()
	if _clubes.is_empty():
		var aviso := TemaUI.etiqueta(
			"No hay clubes cargados.\nTienen que estar en datos/clubes/ (un archivo JSON por club).",
			TemaUI.TAMANO_LETRA, TemaUI.TEXTO_SUAVE
		)
		aviso.name = "SinClubes"
		aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aviso.size_flags_vertical = Control.SIZE_EXPAND_FILL
		aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		contenido.add_child(aviso)
		return

	_tomar_eleccion_anterior()
	var fila := HBoxContainer.new()
	fila.name = "Equipos"
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("separation", 16)
	contenido.add_child(fila)
	fila.add_child(_crear_tarjeta("local", "LOCAL · Vos"))
	var versus := TemaUI.etiqueta("VS", 44, TemaUI.ACENTO)
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(versus)
	fila.add_child(_crear_tarjeta("visitante", "VISITANTE · Máquina"))

	var abajo := HBoxContainer.new()
	abajo.alignment = BoxContainer.ALIGNMENT_END
	_siguiente = boton("Siguiente  ▶", _confirmar, true)
	_siguiente.name = "Siguiente"
	_siguiente.custom_minimum_size.x = 340
	abajo.add_child(_siguiente)
	contenido.add_child(abajo)
	ConfigPartido.preparar(_id("local"), _id("visitante"))
	_mostrar("local")
	_mostrar("visitante")


func volver() -> void:
	Navegacion.ir_a(Navegacion.MENU_PRINCIPAL)


## Pasa al club anterior (-1) o siguiente (1) de ese lado.
func cambiar_club(lado: String, paso: int) -> void:
	if _clubes.is_empty():
		return
	indices[lado] = posmod(int(indices[lado]) + paso, _clubes.size())
	Sonido.tocar_boton()
	ConfigPartido.preparar(_id("local"), _id("visitante"))
	_mostrar("local")
	_mostrar("visitante")


func cambiar_camiseta(lado: String) -> void:
	ConfigPartido.cambiar_camiseta(lado)
	_mostrar(lado)


func _confirmar() -> void:
	Navegacion.ir_a(Navegacion.PREPARAR_PARTIDO)


func _id(lado: String) -> String:
	return str(_clubes[int(indices[lado])]["id"])


## Si se vuelve desde "preparar partido", quedan elegidos los mismos clubes.
func _tomar_eleccion_anterior() -> void:
	indices["visitante"] = mini(1, _clubes.size() - 1)
	for i in _clubes.size():
		if str(_clubes[i]["id"]) == ConfigPartido.local_id:
			indices["local"] = i
		if str(_clubes[i]["id"]) == ConfigPartido.visitante_id:
			indices["visitante"] = i


func _crear_tarjeta(lado: String, titulo: String) -> PanelContainer:
	var tarjeta := PanelContainer.new()
	tarjeta.name = lado.capitalize()
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tarjeta.gui_input.connect(_al_tocar_tarjeta.bind(lado))
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(columna)

	var cabecera := TemaUI.etiqueta(titulo, TemaUI.TAMANO_CHICO, TemaUI.TEXTO_SUAVE)
	cabecera.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(cabecera)

	var centro := HBoxContainer.new()
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.add_theme_constant_override("separation", 6)
	columna.add_child(centro)
	centro.add_child(_flecha("◀", lado, -1))
	var escudo := Escudo.new()
	escudo.name = "Escudo"
	escudo.custom_minimum_size = Vector2(130, 150)
	escudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.add_child(escudo)
	var camiseta := VistaCamiseta.new()
	camiseta.name = "Camiseta"
	camiseta.custom_minimum_size = Vector2(130, 150)
	camiseta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.add_child(camiseta)
	centro.add_child(_flecha("▶", lado, 1))

	var nombre := TemaUI.etiqueta("", 36)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	columna.add_child(nombre)
	var detalle := TemaUI.etiqueta("", TemaUI.TAMANO_CHICO, TemaUI.TEXTO_SUAVE)
	detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detalle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	columna.add_child(detalle)
	var cambiar := boton("", cambiar_camiseta.bind(lado))
	cambiar.name = "CambiarCamiseta"
	cambiar.custom_minimum_size.y = 64
	cambiar.add_theme_font_size_override("font_size", TemaUI.TAMANO_CHICO + 2)
	columna.add_child(cambiar)
	_tarjetas[lado] = {"escudo": escudo, "camiseta": camiseta, "nombre": nombre, "detalle": detalle, "boton": cambiar}
	return tarjeta


func _flecha(texto: String, lado: String, paso: int) -> Button:
	var flecha := Button.new()
	flecha.text = texto
	flecha.custom_minimum_size = Vector2(72, 120)
	flecha.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flecha.pressed.connect(cambiar_club.bind(lado, paso))
	return flecha


func _mostrar(lado: String) -> void:
	var partes: Dictionary = _tarjetas.get(lado, {})
	if partes.is_empty():
		return
	var club := ConfigPartido.club_de(lado)
	partes["escudo"].club = club
	partes["camiseta"].camiseta = ConfigPartido.datos_camiseta(lado)
	partes["nombre"].text = Catalogo.nombre_corto(club)
	var apodos: Array = club.get("apodos", [])
	var apodo := str(apodos[0]) if not apodos.is_empty() else str(club.get("barrio", ""))
	partes["detalle"].text = "%s   %s" % [apodo, TemaUI.estrellas(int(club.get("nivel", 3)))]
	var cual := "Titular" if ConfigPartido.camiseta[lado] == "titular" else "Suplente"
	partes["boton"].text = "Camiseta: %s  ⇄" % cual



func _al_tocar_tarjeta(evento: InputEvent, lado: String) -> void:
	# Deslizar el dedo a un lado o al otro cambia de club, como pasar fotos.
	var boton_mouse := evento as InputEventMouseButton
	if boton_mouse == null or boton_mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if boton_mouse.pressed:
		_inicio_toque[lado] = boton_mouse.position
	elif _inicio_toque.has(lado):
		var recorrido: float = boton_mouse.position.x - (_inicio_toque[lado] as Vector2).x
		_inicio_toque.erase(lado)
		if absf(recorrido) >= DESLIZAR_MINIMO:
			cambiar_club(lado, -1 if recorrido > 0 else 1)
