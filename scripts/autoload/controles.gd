extends Node
## Controles del juego.
##
## Registra las acciones de teclado y joystick al arrancar, así no dependen
## del editor. El joystick táctil escribe en `vector_tactil` y el resto del
## juego lee el movimiento con `vector_movimiento()`, sin importar de dónde venga.
##
## Los botones dependen del momento (ver `Jugador`): con la pelota, "pase" y "tiro"
## pasan y patean; defendiendo, "pase" presiona y "tiro" barre.

const TECLAS := {
	"mover_izquierda": [KEY_A, KEY_LEFT],
	"mover_derecha": [KEY_D, KEY_RIGHT],
	"mover_arriba": [KEY_W, KEY_UP],
	"mover_abajo": [KEY_S, KEY_DOWN],
	"pase": [KEY_J, KEY_SPACE],
	"tiro": [KEY_K],
	"pase_largo": [KEY_L],
	"pase_hueco": [KEY_I],
	"sprint": [KEY_SHIFT],
	"cambiar_jugador": [KEY_Q],
	"pausa": [KEY_ESCAPE, KEY_P],
}

const BOTONES_JOYSTICK := {
	"pase": JOY_BUTTON_A,
	"tiro": JOY_BUTTON_B,
	"pase_largo": JOY_BUTTON_X,
	"pase_hueco": JOY_BUTTON_Y,
	"sprint": JOY_BUTTON_RIGHT_SHOULDER,
	"cambiar_jugador": JOY_BUTTON_LEFT_SHOULDER,
	"pausa": JOY_BUTTON_START,
}

const ZONA_MUERTA_JOYSTICK := 0.2

## Movimiento que manda el joystick táctil, de -1 a 1 en cada eje.
var vector_tactil := Vector2.ZERO
## Tamaño de los botones táctiles (1 = normal). Lo cambia el menú de opciones.
var escala_botones := 1.0
var vibracion_activada := true


func _ready() -> void:
	registrar_acciones()


func registrar_acciones() -> void:
	# Se parte de cero en cada acción, así llamar esto dos veces no duplica eventos.
	for accion: String in TECLAS.keys() + BOTONES_JOYSTICK.keys():
		_reiniciar_accion(accion)

	for accion: String in TECLAS:
		for tecla: int in TECLAS[accion]:
			var evento := InputEventKey.new()
			evento.physical_keycode = tecla
			InputMap.action_add_event(accion, evento)

	for accion: String in BOTONES_JOYSTICK:
		var evento := InputEventJoypadButton.new()
		evento.button_index = BOTONES_JOYSTICK[accion]
		InputMap.action_add_event(accion, evento)

	_agregar_eje("mover_izquierda", JOY_AXIS_LEFT_X, -1.0)
	_agregar_eje("mover_derecha", JOY_AXIS_LEFT_X, 1.0)
	_agregar_eje("mover_arriba", JOY_AXIS_LEFT_Y, -1.0)
	_agregar_eje("mover_abajo", JOY_AXIS_LEFT_Y, 1.0)


## Movimiento pedido por el jugador. Gana el que se mueva más:
## el joystick táctil o el teclado y el joystick físico.
func vector_movimiento() -> Vector2:
	var fisico := Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
	if vector_tactil.length() > fisico.length():
		return vector_tactil
	return fisico


## Vibra el celular unos milisegundos (no hace nada en la compu o si está desactivado).
func vibrar(milisegundos: int) -> void:
	if vibracion_activada and OS.has_feature("mobile"):
		Input.vibrate_handheld(milisegundos)


func _reiniciar_accion(accion: String) -> void:
	if InputMap.has_action(accion):
		InputMap.action_erase_events(accion)
	else:
		InputMap.add_action(accion, ZONA_MUERTA_JOYSTICK)


func _agregar_eje(accion: String, eje: JoyAxis, sentido: float) -> void:
	var evento := InputEventJoypadMotion.new()
	evento.axis = eje
	evento.axis_value = sentido
	InputMap.action_add_event(accion, evento)
