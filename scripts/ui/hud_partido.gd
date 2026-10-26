extends Control
## Lo que se ve durante el partido: marcador con reloj, nombre y estamina del
## jugador que manejás, barra de potencia del tiro, carteles ("¡GOL!") y el
## botón de pausa.
##
## No sabe nada de cómo se juega: el partido le pasa los datos con las funciones
## `mostrar_*`. Así el área B puede cambiar el jugador sin tocar la interfaz.

signal pausa_pedida

const TemaUI := preload("res://scripts/ui/tema.gd")
const ANCHO_BARRA := 360.0

var _goles_local: Label
var _goles_visitante: Label
var _reloj: Label
var _tiempo: Label
var _nombre_jugador: Label
var _estamina: ProgressBar
var _panel_jugador: Control
var _potencia: ProgressBar
var _cartel: Label
var _subcartel: Label
var _animacion_cartel: Tween


func _ready() -> void:
	theme = TemaUI.tema()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crear_marcador()
	_crear_panel_jugador()
	_crear_potencia()
	_crear_cartel()
	_crear_boton_pausa()


func mostrar_equipos(local: String, visitante: String, color_local: Color, color_visitante: Color) -> void:
	(get_node("Marcador/Fila/Local") as Label).text = local
	(get_node("Marcador/Fila/Visitante") as Label).text = visitante
	(get_node("Marcador/Fila/ColorLocal") as ColorRect).color = color_local
	(get_node("Marcador/Fila/ColorVisitante") as ColorRect).color = color_visitante


func mostrar_goles(local: int, visitante: int) -> void:
	_goles_local.text = str(local)
	_goles_visitante.text = str(visitante)


func mostrar_reloj(texto: String, tiempo: String) -> void:
	_reloj.text = texto
	_tiempo.text = tiempo


## `estamina` va de 0 a 1. Con un nombre vacío se esconde el panel.
func mostrar_jugador(nombre: String, estamina: float) -> void:
	_panel_jugador.visible = not nombre.is_empty()
	_nombre_jugador.text = nombre
	_estamina.value = clampf(estamina, 0.0, 1.0)
	var estilo := _estamina.get_theme_stylebox("fill") as StyleBoxFlat
	if estilo:
		estilo.bg_color = TemaUI.ROJO.lerp(TemaUI.VERDE, clampf(estamina * 1.6 - 0.3, 0.0, 1.0))


## `carga` va de 0 a 1. En 0 la barra se esconde.
func mostrar_potencia(carga: float) -> void:
	_potencia.visible = carga > 0.0
	_potencia.value = clampf(carga, 0.0, 1.0)


## Cartel grande en el centro, que se va solo después de `segundos`.
func mostrar_cartel(texto: String, detalle := "", segundos := 2.0, color := TemaUI.ACENTO) -> void:
	_cartel.text = texto
	_cartel.add_theme_color_override("font_color", color)
	_subcartel.text = detalle
	if _animacion_cartel:
		_animacion_cartel.kill()
	_cartel.modulate.a = 0.0
	_subcartel.modulate.a = 0.0
	_cartel.scale = Vector2(0.7, 0.7)
	_animacion_cartel = create_tween()
	_animacion_cartel.set_parallel(true)
	_animacion_cartel.tween_property(_cartel, "modulate:a", 1.0, 0.15)
	_animacion_cartel.tween_property(_subcartel, "modulate:a", 1.0, 0.25)
	_animacion_cartel.tween_property(_cartel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	_animacion_cartel.chain().tween_interval(segundos)
	_animacion_cartel.chain().tween_property(_cartel, "modulate:a", 0.0, 0.3)
	_animacion_cartel.parallel().tween_property(_subcartel, "modulate:a", 0.0, 0.3)


func texto_cartel() -> String:
	var animando := _animacion_cartel != null and _animacion_cartel.is_running()
	return _cartel.text if animando or _cartel.modulate.a > 0.0 else ""


func _crear_marcador() -> void:
	var panel := PanelContainer.new()
	panel.name = "Marcador"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", TemaUI.caja(Color(TemaUI.FONDO, 0.82), 6))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 12
	add_child(panel)
	var fila := HBoxContainer.new()
	fila.name = "Fila"
	fila.add_theme_constant_override("separation", 12)
	panel.add_child(fila)
	fila.add_child(_chip("ColorLocal"))
	fila.add_child(_texto("Local", "LOC", 28))
	_goles_local = _texto("GolesLocal", "0", 34, TemaUI.ACENTO)
	fila.add_child(_goles_local)
	fila.add_child(_texto("Guion", "-", 30, TemaUI.TEXTO_SUAVE))
	_goles_visitante = _texto("GolesVisitante", "0", 34, TemaUI.ACENTO)
	fila.add_child(_goles_visitante)
	fila.add_child(_texto("Visitante", "VIS", 28))
	fila.add_child(_chip("ColorVisitante"))
	var separador := ColorRect.new()
	separador.color = Color(1, 1, 1, 0.2)
	separador.custom_minimum_size = Vector2(2, 30)
	fila.add_child(separador)
	_reloj = _texto("Reloj", "00:00", 28)
	fila.add_child(_reloj)
	_tiempo = _texto("Tiempo", "1T", 20, TemaUI.TEXTO_SUAVE)
	fila.add_child(_tiempo)


func _crear_panel_jugador() -> void:
	var caja := VBoxContainer.new()
	caja.name = "Jugador"
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.position.y = 78
	caja.custom_minimum_size.x = 240
	caja.add_theme_constant_override("separation", 2)
	add_child(caja)
	_nombre_jugador = _texto("Nombre", "", 22)
	_nombre_jugador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_nombre_jugador)
	_estamina = _barra("Estamina", Vector2(240, 10), TemaUI.VERDE)
	caja.add_child(_estamina)
	_panel_jugador = caja
	caja.visible = false


func _crear_potencia() -> void:
	_potencia = _barra("Potencia", Vector2(ANCHO_BARRA, 26), TemaUI.ACENTO)
	# Centrada y un poco abajo de la mitad, entre el joystick y los botones.
	_potencia.anchor_left = 0.5
	_potencia.anchor_right = 0.5
	_potencia.anchor_top = 0.68
	_potencia.anchor_bottom = 0.68
	_potencia.offset_left = -ANCHO_BARRA / 2
	_potencia.offset_right = ANCHO_BARRA / 2
	_potencia.offset_top = 0
	_potencia.offset_bottom = 26
	_potencia.visible = false
	add_child(_potencia)


func _crear_cartel() -> void:
	_cartel = TemaUI.etiqueta("", 96, TemaUI.ACENTO)
	_cartel.name = "Cartel"
	_cartel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cartel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cartel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cartel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartel.add_theme_constant_override("outline_size", 18)
	_cartel.resized.connect(func() -> void: _cartel.pivot_offset = _cartel.size / 2)
	_cartel.modulate.a = 0.0
	add_child(_cartel)
	_subcartel = TemaUI.etiqueta("", TemaUI.TAMANO_LETRA)
	_subcartel.name = "Subcartel"
	_subcartel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_subcartel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subcartel.position.y += 70
	_subcartel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subcartel.add_theme_constant_override("outline_size", 8)
	_subcartel.modulate.a = 0.0
	add_child(_subcartel)


func _crear_boton_pausa() -> void:
	var boton := Button.new()
	boton.name = "Pausa"
	boton.text = "II"
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size = Vector2(76, 76)
	boton.add_theme_stylebox_override("normal", TemaUI.caja(Color(0, 0, 0, 0.35)))
	boton.add_theme_stylebox_override("hover", TemaUI.caja(Color(0, 0, 0, 0.45)))
	boton.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	boton.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	boton.position += Vector2(-20, 14)
	boton.pressed.connect(func() -> void: pausa_pedida.emit())
	add_child(boton)


func _texto(nombre: String, texto: String, tamano: int, color := TemaUI.TEXTO) -> Label:
	var label := TemaUI.etiqueta(texto, tamano, color)
	label.name = nombre
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _chip(nombre: String) -> ColorRect:
	var chip := ColorRect.new()
	chip.name = nombre
	chip.custom_minimum_size = Vector2(10, 30)
	return chip


func _barra(nombre: String, tamano: Vector2, color: Color) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.name = nombre
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.step = 0.0
	barra.show_percentage = false
	barra.custom_minimum_size = tamano
	barra.size = tamano
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0, 0, 0, 0.55)
	fondo.set_corner_radius_all(int(tamano.y / 2))
	fondo.border_color = Color(1, 1, 1, 0.4)
	fondo.set_border_width_all(1)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color
	relleno.set_corner_radius_all(int(tamano.y / 2))
	barra.add_theme_stylebox_override("background", fondo)
	barra.add_theme_stylebox_override("fill", relleno)
	return barra
