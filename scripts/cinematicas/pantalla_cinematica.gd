class_name PantallaCinematica
extends CanvasLayer
## Lo que se dibuja encima de la imagen durante una cinemática: bandas negras de
## cine, títulos, el cartel de repetición, el fundido a negro y el aviso para
## saltear.
##
## Cualquier toque, clic, tecla o botón del joystick pide saltear (`saltear_pedido`).
## Los primeros instantes no cuentan, así un toque que venía del partido no saltea
## sin querer.

signal saltear_pedido

## Segundos del principio en que no se puede saltear.
const BLOQUEO_AL_EMPEZAR := 0.35
## Alto de cada banda negra, en fracción de la pantalla.
const ALTO_BANDA := 0.09
const COLOR_TITULO := Color(1, 1, 1)
const COLOR_DESTACADO := Color(1.0, 0.85, 0.1)

## Si es false, los toques no saltean (por ejemplo, en una repetición manual corta).
var se_puede_saltear := true
var activa := false

var _banda_arriba: ColorRect
var _banda_abajo: ColorRect
var _titulo: Label
var _subtitulo: Label
var _aviso: Label
var _cartel_repeticion: PanelContainer
var _punto_rojo: ColorRect
var _fundido: ColorRect
var _tiempo_activa := 0.0
var _tween_bandas: Tween
var _tween_titulo: Tween


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var raiz := Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	_banda_arriba = _banda(raiz, "BandaArriba", Control.PRESET_TOP_WIDE)
	_banda_abajo = _banda(raiz, "BandaAbajo", Control.PRESET_BOTTOM_WIDE)

	_titulo = _etiqueta(raiz, "Titulo", 64, 10)
	_titulo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_titulo.anchor_left = 0.0
	_titulo.anchor_right = 1.0
	_titulo.offset_left = 16
	_titulo.offset_right = -16
	_titulo.offset_top = -230
	_titulo.offset_bottom = -150
	_subtitulo = _etiqueta(raiz, "Subtitulo", 30, 6)
	_subtitulo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitulo.anchor_left = 0.0
	_subtitulo.anchor_right = 1.0
	_subtitulo.offset_left = 16
	_subtitulo.offset_right = -16
	_subtitulo.offset_top = -150
	_subtitulo.offset_bottom = -105

	_aviso = _etiqueta(raiz, "AvisoSaltear", 20, 4)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_aviso.offset_left = -420
	_aviso.offset_top = -48
	_aviso.offset_right = -24
	_aviso.offset_bottom = -16
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_aviso.modulate.a = 0.75
	_aviso.text = "Tocá la pantalla para saltear  ▸▸" if _es_tactil() else "Apretá cualquier tecla para saltear  ▸▸"

	_crear_cartel_repeticion(raiz)

	_fundido = ColorRect.new()
	_fundido.name = "Fundido"
	_fundido.color = Color(0, 0, 0, 0)
	_fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_fundido)
	ocultar_todo()


func _process(delta: float) -> void:
	if activa:
		_tiempo_activa += delta
	if _cartel_repeticion.visible:
		# El punto rojo titila, como el de las transmisiones.
		_punto_rojo.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.3 else 0.15


func _input(event: InputEvent) -> void:
	if not activa or not se_puede_saltear or _tiempo_activa < BLOQUEO_AL_EMPEZAR:
		return
	if es_pedido_de_saltear(event):
		get_viewport().set_input_as_handled()
		saltear_pedido.emit()


## True para un toque, un clic, una tecla o un botón del joystick recién apretados.
static func es_pedido_de_saltear(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton:
		return event.pressed
	return false


## Empieza una cinemática: muestra las bandas y el aviso de saltear.
func empezar(con_bandas := true) -> void:
	activa = true
	_tiempo_activa = 0.0
	_aviso.visible = se_puede_saltear
	if _tween_bandas:
		_tween_bandas.kill()
	var alto := _alto_banda() if con_bandas else 0.0
	_tween_bandas = create_tween().set_parallel()
	_tween_bandas.tween_property(_banda_arriba, "custom_minimum_size:y", alto, 0.4)
	_tween_bandas.tween_property(_banda_abajo, "custom_minimum_size:y", alto, 0.4)
	_banda_arriba.visible = true
	_banda_abajo.visible = true


func terminar() -> void:
	activa = false
	ocultar_todo()


func ocultar_todo() -> void:
	if _tween_bandas:
		_tween_bandas.kill()
	if _tween_titulo:
		_tween_titulo.kill()
	for banda: ColorRect in [_banda_arriba, _banda_abajo]:
		banda.custom_minimum_size.y = 0.0
		banda.visible = false
	_titulo.visible = false
	_subtitulo.visible = false
	_aviso.visible = false
	_cartel_repeticion.visible = false
	_fundido.color.a = 0.0


## Muestra un título grande (y uno más chico abajo) que entra con un pequeño golpe.
func mostrar_titulo(texto: String, subtitulo := "", destacado := false) -> void:
	_titulo.text = texto
	_titulo.add_theme_color_override("font_color", COLOR_DESTACADO if destacado else COLOR_TITULO)
	_subtitulo.text = subtitulo
	_titulo.visible = texto != ""
	_subtitulo.visible = subtitulo != ""
	if _tween_titulo:
		_tween_titulo.kill()
	_titulo.pivot_offset = _titulo.size / 2
	_titulo.scale = Vector2(1.25, 1.25) if destacado else Vector2.ONE
	_titulo.modulate.a = 0.0
	_subtitulo.modulate.a = 0.0
	_tween_titulo = create_tween().set_parallel()
	_tween_titulo.tween_property(_titulo, "modulate:a", 1.0, 0.25)
	_tween_titulo.tween_property(_titulo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	_tween_titulo.tween_property(_subtitulo, "modulate:a", 1.0, 0.25).set_delay(0.2)


func ocultar_titulo() -> void:
	_titulo.visible = false
	_subtitulo.visible = false


func mostrar_repeticion(visible_ahora: bool) -> void:
	_cartel_repeticion.visible = visible_ahora


## Funde a negro (alfa 1) o vuelve desde negro (alfa 0) en `segundos`.
func fundir(alfa: float, segundos: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fundido, "color:a", alfa, segundos)


func titulo_visible() -> String:
	return _titulo.text if _titulo.visible else ""


func _alto_banda() -> float:
	return get_viewport().get_visible_rect().size.y * ALTO_BANDA


func _banda(padre: Control, nombre: String, preset: Control.LayoutPreset) -> ColorRect:
	var banda := ColorRect.new()
	banda.name = nombre
	banda.color = Color.BLACK
	banda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banda.set_anchors_and_offsets_preset(preset)
	# Crece desde el borde de la pantalla hacia adentro.
	banda.grow_vertical = Control.GROW_DIRECTION_END if preset == Control.PRESET_TOP_WIDE else Control.GROW_DIRECTION_BEGIN
	padre.add_child(banda)
	return banda


func _etiqueta(padre: Control, nombre: String, tamano: int, borde: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.name = nombre
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	etiqueta.add_theme_constant_override("outline_size", borde)
	padre.add_child(etiqueta)
	return etiqueta


func _crear_cartel_repeticion(padre: Control) -> void:
	_cartel_repeticion = PanelContainer.new()
	_cartel_repeticion.name = "CartelRepeticion"
	_cartel_repeticion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartel_repeticion.position = Vector2(24, 80)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 14
	estilo.content_margin_right = 16
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	_cartel_repeticion.add_theme_stylebox_override("panel", estilo)
	padre.add_child(_cartel_repeticion)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	_cartel_repeticion.add_child(fila)
	_punto_rojo = ColorRect.new()
	_punto_rojo.color = Color(0.9, 0.1, 0.1)
	_punto_rojo.custom_minimum_size = Vector2(14, 14)
	_punto_rojo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(_punto_rojo)
	var texto := Label.new()
	texto.text = "REPETICIÓN"
	texto.add_theme_font_size_override("font_size", 24)
	fila.add_child(texto)


static func _es_tactil() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
