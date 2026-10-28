extends Control
## Menú de pausa del partido: seguir, cambios, formación, opciones y salir.
##
## Frena el juego con `get_tree().paused`. Este menú sigue andando en pausa
## porque su `process_mode` es "siempre".

signal reanudado
signal salir_pedido
signal formacion_cambiada(formacion: String)
signal repeticion_pedida

const TemaUI := preload("res://scripts/ui/tema.gd")
const Selector := preload("res://scripts/ui/selector.gd")
const PizarraFormacion := preload("res://scripts/ui/pizarra_formacion.gd")
const ESCENA_OPCIONES := preload("res://escenas/menus/opciones.tscn")

var abierta := false
## El partido lo pone en true si la escena de juego tiene repetición manual (área F).
var hay_repeticion := false
## Id del titular elegido para salir, mientras se elige quién entra.
var sale_elegido := ""

var _panel: PanelContainer
var _contenido: VBoxContainer
var _opciones: Control
var _confirmar_salida := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = TemaUI.tema()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.6)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(velo)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 150
	_panel.offset_right = -150
	_panel.offset_top = 40
	_panel.offset_bottom = -40
	add_child(_panel)
	_contenido = VBoxContainer.new()
	_contenido.add_theme_constant_override("separation", 14)
	_panel.add_child(_contenido)
	visible = false


func _unhandled_input(evento: InputEvent) -> void:
	if abierta and (evento.is_action_pressed("pausa") or evento.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		volver()


func abrir() -> void:
	if abierta:
		return
	abierta = true
	visible = true
	get_tree().paused = true
	Sonido.tocar_boton()
	mostrar_inicio()


func cerrar() -> void:
	if not abierta:
		return
	if _opciones:
		_opciones.queue_free()
		_opciones = null
	abierta = false
	visible = false
	get_tree().paused = false
	reanudado.emit()


## Atrás: de una sección vuelve al inicio de la pausa, y del inicio, al partido.
func volver() -> void:
	if _opciones:
		_cerrar_opciones()
	elif _contenido.has_node("Inicio"):
		cerrar()
	else:
		mostrar_inicio()


func mostrar_inicio() -> void:
	_vaciar()
	_confirmar_salida = false
	sale_elegido = ""
	var marca := Control.new()
	marca.name = "Inicio"
	_contenido.add_child(marca)
	_titulo("Pausa")
	var resultado := "%s  %d - %d  %s" % [
		ConfigPartido.nombre_de("local"), ConfigPartido.goles["local"],
		ConfigPartido.goles["visitante"], ConfigPartido.nombre_de("visitante"),
	]
	var linea := TemaUI.etiqueta(resultado, TemaUI.TAMANO_LETRA, TemaUI.TEXTO_SUAVE)
	linea.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenido.add_child(linea)
	var seguir := _boton("Seguir jugando", cerrar, true)
	seguir.name = "Seguir"
	var restantes := ConfigPartido.cambios_restantes("local")
	var cambios := _boton("Cambios (quedan %d)" % restantes, mostrar_cambios)
	cambios.name = "Cambios"
	cambios.disabled = restantes <= 0 or ConfigPartido.suplentes["local"].is_empty()
	if hay_repeticion:
		_boton("Ver la repetición", _pedir_repeticion).name = "Repeticion"
	_boton("Formación", mostrar_formacion).name = "Formacion"
	_boton("Opciones", _abrir_opciones).name = "Opciones"
	var salir := _boton("Salir del partido", _pedir_salida)
	salir.name = "Salir"
	if not DisplayServer.is_touchscreen_available():
		seguir.grab_focus()


func mostrar_cambios() -> void:
	_vaciar()
	_titulo("Cambios · quedan %d" % ConfigPartido.cambios_restantes("local"))
	var ayuda := "Tocá al que sale y después al que entra." if sale_elegido.is_empty() else "¿Quién entra?"
	_contenido.add_child(TemaUI.etiqueta(ayuda, TemaUI.TAMANO_CHICO, TemaUI.TEXTO_SUAVE))
	var columnas := HBoxContainer.new()
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columnas.add_theme_constant_override("separation", 16)
	_contenido.add_child(columnas)
	columnas.add_child(_lista_jugadores("EnCancha", "En cancha", ConfigPartido.titulares["local"], true))
	columnas.add_child(_lista_jugadores("Banco", "Suplentes", ConfigPartido.suplentes["local"], false))
	_boton("Listo", mostrar_inicio)


func mostrar_formacion() -> void:
	_vaciar()
	_titulo("Formación")
	var fila := HBoxContainer.new()
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("separation", 20)
	_contenido.add_child(fila)
	var pizarra := PizarraFormacion.new()
	pizarra.custom_minimum_size = Vector2(380, 250)
	pizarra.formacion = ConfigPartido.formacion["local"]
	pizarra.color_equipo = ConfigPartido.color_camiseta("local")
	var selector := Selector.new()
	selector.name = "SelectorFormacion"
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var formaciones: Array[String] = []
	formaciones.assign(ConfigPartido.FORMACIONES)
	selector.configurar(formaciones, ConfigPartido.FORMACIONES.find(ConfigPartido.formacion["local"]))
	selector.cambio.connect(func(i: int) -> void:
		ConfigPartido.cambiar_formacion("local", ConfigPartido.FORMACIONES[i])
		pizarra.formacion = ConfigPartido.formacion["local"]
		formacion_cambiada.emit(ConfigPartido.formacion["local"])
	)
	fila.add_child(selector)
	fila.add_child(pizarra)
	_boton("Listo", mostrar_inicio)


## Toque sobre un jugador de la lista de cambios.
func elegir_jugador(id: String, esta_en_cancha: bool) -> void:
	if esta_en_cancha:
		sale_elegido = "" if sale_elegido == id else id
	elif not sale_elegido.is_empty():
		if ConfigPartido.hacer_cambio("local", sale_elegido, id):
			Sonido.reproducir("silbato_corto", -6.0)
		sale_elegido = ""
	mostrar_cambios()


func _lista_jugadores(nombre: String, titulo: String, ids: Array, en_cancha: bool) -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.name = nombre
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_child(TemaUI.etiqueta(titulo, TemaUI.TAMANO_CHICO, TemaUI.ACENTO))
	var desplazable := ScrollContainer.new()
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(desplazable)
	var lista := VBoxContainer.new()
	lista.name = "Lista"
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazable.add_child(lista)
	for id: String in ids:
		var datos := ConfigPartido.jugador("local", id)
		var boton := Button.new()
		boton.name = id
		boton.text = "%2d  %s  ·  %s" % [int(datos.get("dorsal", 0)), datos.get("nombre", id), datos.get("posicion", "")]
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.custom_minimum_size.y = 58
		boton.add_theme_font_size_override("font_size", TemaUI.TAMANO_CHICO)
		boton.toggle_mode = true
		boton.button_pressed = en_cancha and id == sale_elegido
		boton.disabled = not en_cancha and sale_elegido.is_empty()
		boton.pressed.connect(elegir_jugador.bind(id, en_cancha))
		lista.add_child(boton)
	return columna


func _pedir_repeticion() -> void:
	cerrar()
	repeticion_pedida.emit()


func _abrir_opciones() -> void:
	_opciones = ESCENA_OPCIONES.instantiate()
	_opciones.set("dentro_del_partido", true)
	_opciones.connect("cerrada", _cerrar_opciones)
	add_child(_opciones)


func _cerrar_opciones() -> void:
	if _opciones:
		Opciones.guardar()
		_opciones.queue_free()
		_opciones = null
	mostrar_inicio()


func _pedir_salida() -> void:
	# Pide un segundo toque para no salir por error.
	if not _confirmar_salida:
		_confirmar_salida = true
		var salir := _contenido.get_node("Salir") as Button
		salir.text = "¿Seguro? Tocá de nuevo para salir"
		salir.add_theme_color_override("font_color", TemaUI.ROJO)
		return
	salir_pedido.emit()


func _vaciar() -> void:
	for hijo in _contenido.get_children():
		_contenido.remove_child(hijo)
		hijo.queue_free()


func _titulo(texto: String) -> void:
	var label := TemaUI.etiqueta(texto, 44, TemaUI.ACENTO)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenido.add_child(label)


func _boton(texto: String, accion: Callable, principal := false) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size.y = 62
	if principal:
		boton.add_theme_stylebox_override("normal", TemaUI.caja(TemaUI.ACENTO))
		boton.add_theme_color_override("font_color", TemaUI.FONDO)
	boton.pressed.connect(func() -> void:
		Sonido.tocar_boton()
		accion.call()
	)
	_contenido.add_child(boton)
	return boton
