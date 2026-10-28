class_name Gestos
extends RefCounted
## Gestos de los jugadores en las cinemáticas: festejar, lamentarse, saludar y
## aplaudir.
##
## Si el `Modelo` del jugador tiene un `AnimationPlayer` con una animación de ese
## nombre ("festejo", "lamento", "saludo" o "aplauso"), se usa esa (la hace el
## área E). Si no, se hace un movimiento simple sobre el modelo provisorio:
## saltitos para festejar, cabeza gacha para lamentarse, un balanceo para saludar.

const FESTEJO := "festejo"
const LAMENTO := "lamento"
const SALUDO := "saludo"
const APLAUSO := "aplauso"
const META_ORIGINAL := "transform_original_gestos"
const META_TWEEN := "tween_gestos"


## Hace el gesto `nombre` durante unos `segundos` (lo de la animación, si hay).
static func hacer(jugador: Jugador, nombre: String, segundos := 2.0) -> void:
	var modelo := jugador.get_node_or_null("Modelo") as Node3D
	if modelo == null:
		return
	var animador := _animador(modelo)
	if animador and animador.has_animation(nombre):
		animador.play(nombre)
		return
	_guardar_original(modelo)
	var tween := _nuevo_tween(jugador, modelo)
	var original: Transform3D = modelo.get_meta(META_ORIGINAL)
	match nombre:
		FESTEJO:
			# Saltitos con los brazos al cielo (en el provisorio: el cuerpo entero).
			var saltos := maxi(int(segundos / 0.45), 1)
			for i in saltos:
				tween.tween_property(modelo, "position:y", original.origin.y + 0.45, 0.2).set_trans(Tween.TRANS_QUAD)
				tween.tween_property(modelo, "position:y", original.origin.y, 0.25).set_trans(Tween.TRANS_BOUNCE)
		LAMENTO:
			tween.set_parallel()
			tween.tween_property(modelo, "rotation:x", original.basis.get_euler().x - 0.35, 0.6)
			tween.tween_property(modelo, "position:y", original.origin.y - 0.08, 0.6)
		SALUDO:
			var vueltas := maxi(int(segundos / 0.8), 1)
			for i in vueltas:
				tween.tween_property(modelo, "rotation:z", 0.12, 0.4).set_trans(Tween.TRANS_SINE)
				tween.tween_property(modelo, "rotation:z", -0.12, 0.4).set_trans(Tween.TRANS_SINE)
			tween.tween_property(modelo, "rotation:z", 0.0, 0.2)
		APLAUSO:
			var golpes := maxi(int(segundos / 0.3), 1)
			for i in golpes:
				tween.tween_property(modelo, "position:y", original.origin.y + 0.06, 0.15)
				tween.tween_property(modelo, "position:y", original.origin.y, 0.15)


## Corta cualquier gesto y deja el modelo como estaba.
static func quitar(jugador: Jugador) -> void:
	var modelo := jugador.get_node_or_null("Modelo") as Node3D
	if modelo == null:
		return
	var animador := _animador(modelo)
	if animador and animador.is_playing():
		animador.stop()
	if modelo.has_meta(META_TWEEN):
		var tween: Tween = modelo.get_meta(META_TWEEN)
		if tween and tween.is_valid():
			tween.kill()
		modelo.remove_meta(META_TWEEN)
	if modelo.has_meta(META_ORIGINAL):
		modelo.transform = modelo.get_meta(META_ORIGINAL)


static func _guardar_original(modelo: Node3D) -> void:
	if not modelo.has_meta(META_ORIGINAL):
		modelo.set_meta(META_ORIGINAL, modelo.transform)


static func _nuevo_tween(jugador: Jugador, modelo: Node3D) -> Tween:
	quitar(jugador)
	var tween := jugador.create_tween()
	modelo.set_meta(META_TWEEN, tween)
	return tween


static func _animador(modelo: Node3D) -> AnimationPlayer:
	var animador := modelo.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animador:
		return animador
	return modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
