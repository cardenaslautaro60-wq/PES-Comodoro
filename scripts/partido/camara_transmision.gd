class_name CamaraTransmision
extends Camera3D
## Cámara de transmisión de TV: mira la cancha de costado y desde arriba, como
## desde la platea, y sigue la jugada.
##
## - Se adelanta hacia donde va la pelota, así se ve lo que viene.
## - Mira un poco al jugador que manejás, para que no quede fuera de cuadro.
## - Se aleja cuando la pelota va rápido (pases largos, tiros) y se acerca cuando
##   la jugada es lenta.
## - No se va más allá de los arcos.

@export var pelota: Node3D
## Jugador que maneja la persona (opcional).
@export var jugador: Node3D
@export var altura := 21.0
@export var distancia := 30.0
## Cuánto se aleja como máximo con la pelota rápida (1 = nada, 1.3 = 30 % más lejos).
@export var alejamiento_maximo := 1.3
## Segundos de adelanto: mira dónde va a estar la pelota dentro de este tiempo.
@export var adelanto := 0.45
## Peso del jugador manejado en el encuadre (0 = solo la pelota).
@export_range(0.0, 1.0) var peso_jugador := 0.25
## Cuánto acompaña a lo ancho de la cancha (0 = fija en el medio, 1 = siempre encima).
@export_range(0.0, 1.0) var seguimiento_ancho := 0.4
@export var suavizado := 2.5

var _foco := Vector3.ZERO
var _zoom := 1.0


func _ready() -> void:
	fov = 38.0
	near = 0.5
	far = 400.0
	_foco = _foco_deseado()
	_aplicar()


func _process(delta: float) -> void:
	if pelota == null:
		return
	var t := 1.0 - exp(-suavizado * delta)
	_foco = _foco.lerp(_foco_deseado(), t)
	var rapidez := _velocidad_pelota().length()
	var zoom_deseado := lerpf(1.0, alejamiento_maximo, clampf((rapidez - 8.0) / 18.0, 0.0, 1.0))
	_zoom = lerpf(_zoom, zoom_deseado, 1.0 - exp(-1.2 * delta))
	_aplicar()


## Salta al encuadre sin suavizado (después de un gol o de reubicar la pelota).
func cortar() -> void:
	if pelota == null:
		return
	_foco = _foco_deseado()
	_zoom = 1.0
	_aplicar()


func _foco_deseado() -> Vector3:
	if pelota == null:
		return Vector3.ZERO
	var foco := pelota.global_position + _velocidad_pelota() * adelanto
	if jugador:
		foco = foco.lerp(jugador.global_position, peso_jugador)
	var limite_x := Cancha.LARGO / 2 - 4.0
	foco.x = clampf(foco.x, -limite_x, limite_x)
	foco.z = clampf(foco.z, -Cancha.ANCHO / 2, Cancha.ANCHO / 2)
	foco.y = 0.0
	return foco


func _aplicar() -> void:
	var posicion := Vector3(_foco.x, altura * _zoom, _foco.z * seguimiento_ancho + distancia * _zoom)
	global_position = posicion
	look_at(Vector3(_foco.x, 0.0, _foco.z * 0.85), Vector3.UP)


func _velocidad_pelota() -> Vector3:
	var cuerpo := pelota as RigidBody3D
	if cuerpo == null:
		return Vector3.ZERO
	return Vector3(cuerpo.linear_velocity.x, 0, cuerpo.linear_velocity.z)
