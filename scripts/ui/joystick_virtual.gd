extends Control
## Joystick táctil "flotante": aparece donde el dedo toca la mitad
## izquierda de la pantalla y manda el movimiento a `Controles`.

@export var radio := 110.0
@export_range(0.0, 0.9) var zona_muerta := 0.15
@export var color_fondo := Color(1, 1, 1, 0.12)
@export var color_borde := Color(1, 1, 1, 0.45)
@export var color_palanca := Color(1, 1, 1, 0.55)

var _dedo := -1
var _centro := Vector2.ZERO
var _palanca := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _input(evento: InputEvent) -> void:
	if evento is InputEventScreenTouch:
		_al_tocar(evento as InputEventScreenTouch)
	elif evento is InputEventScreenDrag:
		_al_arrastrar(evento as InputEventScreenDrag)


func _al_tocar(toque: InputEventScreenTouch) -> void:
	if toque.pressed and _dedo == -1 and toque.position.x < size.x * 0.5:
		_dedo = toque.index
		_centro = toque.position
		_palanca = toque.position
		queue_redraw()
	elif not toque.pressed and toque.index == _dedo:
		soltar()


func _al_arrastrar(arrastre: InputEventScreenDrag) -> void:
	if arrastre.index != _dedo:
		return
	var desplazamiento := (arrastre.position - _centro).limit_length(radio)
	_palanca = _centro + desplazamiento
	var valor := desplazamiento / radio
	Controles.vector_tactil = valor if valor.length() > zona_muerta else Vector2.ZERO
	queue_redraw()


## Suelta el joystick y deja de mandar movimiento.
func soltar() -> void:
	_dedo = -1
	Controles.vector_tactil = Vector2.ZERO
	queue_redraw()


func _notification(que: int) -> void:
	# Si la app pasa a segundo plano con el dedo apoyado, no queda el jugador corriendo solo.
	if que == NOTIFICATION_APPLICATION_FOCUS_OUT:
		soltar()


func _draw() -> void:
	if _dedo == -1:
		return
	draw_circle(_centro, radio, color_fondo)
	draw_arc(_centro, radio, 0.0, TAU, 48, color_borde, 3.0, true)
	draw_circle(_palanca, radio * 0.4, color_palanca)
