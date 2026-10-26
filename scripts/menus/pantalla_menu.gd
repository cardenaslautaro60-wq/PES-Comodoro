extends Control
## Base de todas las pantallas de menú: pone el tema, el fondo y un margen que
## respeta el notch y los bordes redondeados del celular. Cada pantalla arma lo
## suyo en `armar()` dentro de `contenido`.

const TemaUI := preload("res://scripts/ui/tema.gd")
const FondoMenu := preload("res://scripts/ui/fondo_menu.gd")
const MARGEN := 28

var contenido: VBoxContainer
var _margenes: MarginContainer


func _ready() -> void:
	theme = TemaUI.tema()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := FondoMenu.new()
	fondo.name = "Fondo"
	add_child(fondo)

	_margenes = MarginContainer.new()
	_margenes.name = "Margenes"
	_margenes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margenes)
	contenido = VBoxContainer.new()
	contenido.name = "Contenido"
	contenido.add_theme_constant_override("separation", 18)
	_margenes.add_child(contenido)
	_ajustar_margenes()
	get_viewport().size_changed.connect(_ajustar_margenes)
	armar()
	_enfocar_primero.call_deferred()


## Cada pantalla pone acá sus botones y textos.
func armar() -> void:
	pass


## Lo llama el botón "atrás" de Android y la tecla Escape.
func volver() -> void:
	pass


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		volver()


## Botón grande que hace sonar el clic y llama a `accion`.
func boton(texto: String, accion: Callable, principal := false) -> Button:
	var nuevo := Button.new()
	nuevo.text = texto
	nuevo.custom_minimum_size = Vector2(0, TemaUI.ALTO_BOTON)
	if principal:
		nuevo.add_theme_stylebox_override("normal", TemaUI.caja(TemaUI.ACENTO))
		nuevo.add_theme_stylebox_override("hover", TemaUI.caja(TemaUI.ACENTO.lightened(0.12)))
		nuevo.add_theme_color_override("font_color", TemaUI.FONDO)
		nuevo.add_theme_color_override("font_hover_color", TemaUI.FONDO)
		nuevo.add_theme_color_override("font_focus_color", TemaUI.FONDO)
	nuevo.pressed.connect(func() -> void:
		Sonido.tocar_boton()
		accion.call()
	)
	return nuevo


## Fila de arriba con el botón "volver" y el título de la pantalla.
func encabezado(titulo: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.name = "Encabezado"
	fila.add_theme_constant_override("separation", 20)
	var atras := Button.new()
	atras.name = "Volver"
	atras.text = "◀"
	atras.custom_minimum_size = Vector2(TemaUI.ALTO_BOTON, TemaUI.ALTO_BOTON)
	atras.pressed.connect(func() -> void:
		Sonido.tocar_volver()
		volver()
	)
	fila.add_child(atras)
	var label := TemaUI.etiqueta(titulo, 44)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(label)
	contenido.add_child(fila)
	return fila


func espacio() -> Control:
	var relleno := Control.new()
	relleno.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenido.add_child(relleno)
	return relleno


## Con teclado o joystick hace falta un botón enfocado para empezar a moverse.
func _enfocar_primero() -> void:
	if DisplayServer.is_touchscreen_available():
		return
	var primero := _buscar_boton(contenido)
	if primero:
		primero.grab_focus()


func _buscar_boton(nodo: Node) -> Button:
	for hijo in nodo.get_children():
		if hijo is Button and (hijo as Button).name != "Volver" and not (hijo as Button).disabled:
			return hijo
		var encontrado := _buscar_boton(hijo)
		if encontrado:
			return encontrado
	return null


func _ajustar_margenes() -> void:
	var seguro := _zona_segura()
	_margenes.add_theme_constant_override("margin_left", int(maxf(MARGEN, seguro.position.x)))
	_margenes.add_theme_constant_override("margin_top", int(maxf(MARGEN * 0.7, seguro.position.y)))
	_margenes.add_theme_constant_override("margin_right", int(maxf(MARGEN, size.x - seguro.end.x)))
	_margenes.add_theme_constant_override("margin_bottom", int(maxf(MARGEN * 0.7, size.y - seguro.end.y)))


## Zona de la pantalla sin notch, pasada a las coordenadas del juego.
func _zona_segura() -> Rect2:
	var visible := get_viewport_rect()
	if not OS.has_feature("mobile"):
		return visible
	var ventana := Vector2(DisplayServer.window_get_size())
	if ventana.x <= 0 or ventana.y <= 0:
		return visible
	var escala := visible.size / ventana
	var segura := Rect2(DisplayServer.get_display_safe_area())
	return Rect2(segura.position * escala, segura.size * escala)
