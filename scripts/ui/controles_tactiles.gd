extends Control
## Controles para la pantalla táctil: joystick flotante a la izquierda y botones
## a la derecha que cambian según el momento.
##
## - Con la pelota (o cuando es de tu equipo): PASE, TIRO, LARGO, HUECO y SPRINT.
## - Defendiendo: PRESIÓN, BARRIDA, CAMBIAR y SPRINT.
##
## El tamaño de los botones sale de `Controles.escala_botones`.

const JoystickVirtual := preload("res://scripts/ui/joystick_virtual.gd")
const BotonAccion := preload("res://scripts/ui/boton_accion.gd")

## Cada botón: nombre, centro (desde la esquina de abajo a la derecha), diámetro,
## acción y texto al atacar, acción y texto al defender ("" = se esconde).
const BOTONES := [
	["Pase", Vector2(-95, -95), 150.0, "pase", "PASE", "pase", "PRESIÓN"],
	["Tiro", Vector2(-260, -70), 140.0, "tiro", "TIRO", "tiro", "BARRIDA"],
	["Largo", Vector2(-225, -225), 110.0, "pase_largo", "LARGO", "cambiar_jugador", "CAMBIAR"],
	["Hueco", Vector2(-75, -260), 110.0, "pase_hueco", "HUECO", "", ""],
	["Sprint", Vector2(-410, -60), 110.0, "sprint", "SPRINT", "sprint", "SPRINT"],
]
const MARGEN := Vector2(-20, -20)

var control_humano: ControlHumano

var _botones := {}
var _escala_actual := -1.0
var _atacando := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var joystick: Control = JoystickVirtual.new()
	joystick.name = "Joystick"
	add_child(joystick)
	for datos: Array in BOTONES:
		var boton: Button = BotonAccion.new()
		boton.name = datos[0]
		boton.set("accion", datos[3])
		boton.text = datos[4]
		boton.add_theme_stylebox_override("normal", _estilo(Color(0, 0, 0, 0.35)))
		boton.add_theme_stylebox_override("hover", _estilo(Color(0, 0, 0, 0.35)))
		boton.add_theme_stylebox_override("pressed", _estilo(Color(1, 1, 1, 0.35)))
		boton.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		add_child(boton)
		_botones[datos[0]] = boton
	_acomodar()


func _process(_delta: float) -> void:
	if not is_equal_approx(_escala_actual, Controles.escala_botones):
		_acomodar()
	var atacando := true
	if control_humano and control_humano.jugador:
		atacando = control_humano.jugador.en_ataque() or control_humano.jugador.tiene_pelota()
	if atacando != _atacando:
		_atacando = atacando
		_actualizar_textos()


## True si los botones están en modo ataque.
func esta_atacando() -> bool:
	return _atacando


func _actualizar_textos() -> void:
	for datos: Array in BOTONES:
		var boton: Button = _botones[datos[0]]
		var accion: String = datos[3] if _atacando else datos[5]
		var texto: String = datos[4] if _atacando else datos[6]
		boton.visible = accion != ""
		if accion != "":
			boton.call("cambiar_accion", accion, texto)


func _acomodar() -> void:
	_escala_actual = Controles.escala_botones
	for datos: Array in BOTONES:
		var boton: Button = _botones[datos[0]]
		var diametro: float = datos[2] * _escala_actual
		var centro: Vector2 = datos[1] * _escala_actual + MARGEN
		boton.anchor_left = 1.0
		boton.anchor_right = 1.0
		boton.anchor_top = 1.0
		boton.anchor_bottom = 1.0
		boton.offset_left = centro.x - diametro / 2
		boton.offset_right = centro.x + diametro / 2
		boton.offset_top = centro.y - diametro / 2
		boton.offset_bottom = centro.y + diametro / 2
		boton.add_theme_font_size_override("font_size", int(clampf(diametro * 0.17, 14, 30)))


func _estilo(color: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(200)
	estilo.border_color = Color(1, 1, 1, 0.5)
	estilo.set_border_width_all(2)
	return estilo
