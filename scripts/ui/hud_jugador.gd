extends Control
## Datos del jugador que manejás, dibujados sobre su cabeza: dorsal y nombre,
## barra de estamina y, mientras cargás una patada, la barra de potencia.
##
## Es provisorio hasta el HUD definitivo del área G, que puede leer los mismos
## datos: `Jugador.potencia`, `Jugador.estamina_actual` y `Jugador.nombre_jugador`.

const ANCHO_BARRA := 90.0
const ALTO_POTENCIA := 12.0
const ALTO_ESTAMINA := 6.0

var camara: Camera3D
var control_humano: ControlHumano


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if camara == null or control_humano == null or control_humano.jugador == null:
		return
	var jugador := control_humano.jugador
	var cabeza := jugador.global_position + Vector3.UP * (Jugador.ALTURA / 2 + 0.4)
	if camara.is_position_behind(cabeza):
		return
	var punto := camara.unproject_position(cabeza)
	var fuente := get_theme_default_font()
	var texto := "%d  %s" % [jugador.dorsal, jugador.nombre_jugador]
	var ancho_texto := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var posicion_texto := punto + Vector2(-ancho_texto / 2, -14)
	draw_string_outline(fuente, posicion_texto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
	draw_string(fuente, posicion_texto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# Estamina: verde cuando está descansado, roja cuando está agotado.
	var estamina := Rect2(punto + Vector2(-ANCHO_BARRA / 2, -6), Vector2(ANCHO_BARRA, ALTO_ESTAMINA))
	_barra(estamina, jugador.estamina_actual, Color.RED.lerp(Color(0.2, 0.9, 0.3), jugador.estamina_actual))

	if jugador.potencia >= 0.0:
		var potencia := Rect2(punto + Vector2(-ANCHO_BARRA / 2, -50), Vector2(ANCHO_BARRA, ALTO_POTENCIA))
		_barra(potencia, jugador.potencia, Color(1.0, 0.9, 0.1).lerp(Color(1.0, 0.2, 0.1), jugador.potencia))


func _barra(rect: Rect2, valor: float, color: Color) -> void:
	draw_rect(rect.grow(2), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(valor, 0.0, 1.0), rect.size.y)), color)
