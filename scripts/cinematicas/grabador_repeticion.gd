class_name GrabadorRepeticion
extends Node
## Graba los últimos segundos de la jugada (dónde estaban la pelota y cada
## jugador) y los vuelve a mostrar para las repeticiones.
##
## Durante la reproducción, la pelota y los jugadores quedan "congelados": no
## corren su física ni su lógica, y este nodo les pone la posición grabada. Al
## terminar vuelven exactamente como estaban, con su velocidad, y el partido sigue.
##
## Graba 30 cuadros por segundo e interpola entre ellos, así se puede mostrar en
## cámara lenta sin saltos.

## Segundos que se guardan. Lo más viejo se va borrando.
@export var segundos_guardados := 10.0
## Cada cuántos cuadros de física se graba uno (2 = 30 por segundo a 60 Hz).
@export var cada_cuadros := 2

var grabando := true
var reproduciendo := false

var _nodos: Array[Node3D] = []
## Cada cuadro: [tiempo, Array de Transform3D en el mismo orden que `_nodos`].
var _cuadros: Array = []
var _tiempo := 0.0
var _contador := 0
## Lo que había antes de reproducir: [nodo, transform, velocidad, process_mode].
var _guardado: Array = []


func _ready() -> void:
	# Graba después de que todos se movieron en el cuadro.
	process_physics_priority = 100


## Qué nodos se graban. Volver a llamarlo borra lo grabado.
func registrar(nodos: Array) -> void:
	_nodos.clear()
	for nodo: Variant in nodos:
		if nodo is Node3D:
			_nodos.append(nodo)
	limpiar()


func limpiar() -> void:
	_cuadros.clear()
	_contador = 0


func _physics_process(delta: float) -> void:
	if reproduciendo:
		return
	_tiempo += delta
	if not grabando or _nodos.is_empty():
		return
	_contador += 1
	if _contador % cada_cuadros != 0:
		return
	var transformaciones: Array[Transform3D] = []
	for nodo in _nodos:
		transformaciones.append(nodo.global_transform if is_instance_valid(nodo) else Transform3D.IDENTITY)
	_cuadros.append([_tiempo, transformaciones])
	while _cuadros.size() > 2 and _tiempo - float(_cuadros[0][0]) > segundos_guardados:
		_cuadros.pop_front()


func hay_grabacion() -> bool:
	return _cuadros.size() >= 2


func tiempo_inicial() -> float:
	return float(_cuadros[0][0]) if not _cuadros.is_empty() else 0.0


func tiempo_final() -> float:
	return float(_cuadros[-1][0]) if not _cuadros.is_empty() else 0.0


func duracion() -> float:
	return tiempo_final() - tiempo_inicial()


## Congela la pelota y los jugadores para empezar a mostrar la grabación.
func empezar_reproduccion() -> void:
	if reproduciendo:
		return
	reproduciendo = true
	_guardado.clear()
	for nodo in _nodos:
		if not is_instance_valid(nodo):
			continue
		var velocidad := Vector3.ZERO
		if nodo is RigidBody3D:
			velocidad = (nodo as RigidBody3D).linear_velocity
		elif nodo is CharacterBody3D:
			velocidad = (nodo as CharacterBody3D).velocity
		_guardado.append([nodo, nodo.global_transform, velocidad, nodo.process_mode])
		nodo.process_mode = Node.PROCESS_MODE_DISABLED


## Pone a todos donde estaban en el instante `t` de la grabación.
func mostrar(t: float) -> void:
	if not reproduciendo or _cuadros.is_empty():
		return
	var i := _indice_antes_de(t)
	var a: Array = _cuadros[i]
	var b: Array = _cuadros[mini(i + 1, _cuadros.size() - 1)]
	var ta := float(a[0])
	var tb := float(b[0])
	var peso := clampf((t - ta) / (tb - ta), 0.0, 1.0) if tb > ta else 0.0
	var transformaciones_a: Array = a[1]
	var transformaciones_b: Array = b[1]
	for j in mini(_nodos.size(), transformaciones_a.size()):
		var nodo := _nodos[j]
		if not is_instance_valid(nodo):
			continue
		var desde: Transform3D = transformaciones_a[j]
		var hasta: Transform3D = transformaciones_b[j]
		# Si se teletransportó (reinicio de jugada), no se interpola: salta.
		if desde.origin.distance_to(hasta.origin) > 4.0:
			nodo.global_transform = desde if peso < 0.5 else hasta
		else:
			nodo.global_transform = desde.interpolate_with(hasta, peso)


## Vuelve todo a como estaba antes de la repetición y sigue el juego.
func terminar_reproduccion() -> void:
	if not reproduciendo:
		return
	for datos: Array in _guardado:
		var nodo: Node3D = datos[0]
		if not is_instance_valid(nodo):
			continue
		nodo.global_transform = datos[1]
		nodo.process_mode = datos[3]
		if nodo is RigidBody3D:
			(nodo as RigidBody3D).linear_velocity = datos[2]
		elif nodo is CharacterBody3D:
			(nodo as CharacterBody3D).velocity = datos[2]
	_guardado.clear()
	reproduciendo = false


## Posición grabada de un nodo en el instante `t` (sin moverlo).
func posicion_de(nodo: Node3D, t: float) -> Vector3:
	var j := _nodos.find(nodo)
	if j < 0 or _cuadros.is_empty():
		return nodo.global_position
	var transformaciones: Array = _cuadros[_indice_antes_de(t)][1]
	return (transformaciones[j] as Transform3D).origin


func _indice_antes_de(t: float) -> int:
	# Búsqueda binaria: el último cuadro con tiempo <= t.
	var bajo := 0
	var alto := _cuadros.size() - 1
	while bajo < alto:
		var medio := (bajo + alto + 1) >> 1
		if float(_cuadros[medio][0]) <= t:
			bajo = medio
		else:
			alto = medio - 1
	return bajo
