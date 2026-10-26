class_name CamaraCinematica
extends Camera3D
## Cámara de las cinemáticas y las repeticiones: reproduce una `Toma` por vez.
##
## Lo que sigue y lo que mira se suavizan, así la cámara no tiembla cuando el
## jugador o la pelota cambian de dirección de golpe.

signal toma_terminada

var toma: Toma = null
var tiempo := 0.0

var _ancla := Vector3.ZERO
var _mirada := Vector3.ZERO


func _ready() -> void:
	near = 0.1
	far = 600.0


func _process(delta: float) -> void:
	if toma == null:
		return
	tiempo += delta
	_aplicar(delta)
	if tiempo >= toma.duracion:
		toma = null
		toma_terminada.emit()


## Empieza una toma desde cero, con un corte (sin suavizar desde la anterior).
func tomar(nueva: Toma) -> void:
	toma = nueva
	tiempo = 0.0
	_ancla = _posicion_de(nueva.seguir) if nueva.seguir else Vector3.ZERO
	_mirada = _objetivo_mirada()
	_aplicar(0.0)


## Fracción de la toma que ya pasó (0 a 1).
func progreso() -> float:
	if toma == null or toma.duracion <= 0.0:
		return 1.0
	return clampf(tiempo / toma.duracion, 0.0, 1.0)


func _aplicar(delta: float) -> void:
	var t := progreso()
	var peso := 1.0 - exp(-toma.suavizado * delta) if delta > 0.0 else 1.0
	if toma.seguir and is_instance_valid(toma.seguir):
		_ancla = _ancla.lerp(_posicion_de(toma.seguir), peso)
	_mirada = _mirada.lerp(_objetivo_mirada(), peso)
	global_position = toma.posicion_en(t, _ancla)
	fov = toma.fov_en(t)
	var hacia := _mirada - global_position
	if hacia.length() > 0.01 and absf(hacia.normalized().dot(Vector3.UP)) < 0.999:
		look_at(_mirada, Vector3.UP)


func _objetivo_mirada() -> Vector3:
	var punto := toma.punto_mirada_en(progreso())
	if toma.mirar and is_instance_valid(toma.mirar):
		punto = _posicion_de(toma.mirar)
	elif toma.seguir and is_instance_valid(toma.seguir) and toma.tipo == Toma.Tipo.ORBITA:
		punto = _posicion_de(toma.seguir)
	return punto + Vector3(0, toma.altura_mirada, 0)


## Posición al nivel del piso: los jugadores tienen el origen en la cintura.
static func _posicion_de(nodo: Node3D) -> Vector3:
	var p := nodo.global_position
	if nodo is Jugador:
		p.y -= Jugador.ALTURA / 2
	return p
