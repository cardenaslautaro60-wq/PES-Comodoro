class_name FondoComodoroProvisorio
extends Node3D
## Fondo provisorio de Comodoro para las tomas de presentación: un cerro de cima
## chata y ocre como el Chenque detrás de la tribuna de enfrente, y el mar del
## golfo San Jorge hacia un costado.
##
## Son pocas piezas low poly con un material por color. Cuando el área E haga el
## panorama del estadio (ver la guía de arte, "Fondo de Comodoro"), se saca.

const OCRE := Color(0.62, 0.50, 0.36)
const MARRON_GRIS := Color(0.48, 0.42, 0.36)
const ARENA := Color(0.70, 0.60, 0.45)
const MAR := Color(0.13, 0.36, 0.55)

## Cada pieza del cerro: centro (x, z), radio de abajo, de arriba, alto, color.
const PIEZAS_CERRO := [
	[Vector2(-40, -190), 70.0, 46.0, 38.0, OCRE],
	[Vector2(25, -200), 60.0, 40.0, 46.0, MARRON_GRIS],
	[Vector2(85, -185), 45.0, 24.0, 28.0, OCRE],
	[Vector2(-110, -175), 40.0, 18.0, 20.0, ARENA],
	[Vector2(135, -165), 35.0, 12.0, 15.0, MARRON_GRIS],
]

var _materiales := {}


func _ready() -> void:
	for datos: Array in PIEZAS_CERRO:
		_pieza_cerro(datos[0], datos[1], datos[2], datos[3], datos[4])
	var mar := PlaneMesh.new()
	mar.size = Vector2(160, 400)
	mar.material = _material(MAR, 0.3)
	var vista_mar := MeshInstance3D.new()
	vista_mar.name = "Mar"
	vista_mar.mesh = mar
	vista_mar.position = Vector3(-200, -0.01, 0)
	vista_mar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vista_mar)


func _pieza_cerro(centro: Vector2, abajo: float, arriba: float, alto: float, color: Color) -> void:
	var malla := CylinderMesh.new()
	malla.bottom_radius = abajo
	malla.top_radius = arriba
	malla.height = alto
	# Pocos lados: se ven las caras, como pide el estilo low poly.
	malla.radial_segments = 7
	malla.rings = 1
	malla.material = _material(color, 1.0)
	var vista := MeshInstance3D.new()
	vista.mesh = malla
	vista.position = Vector3(centro.x, alto / 2 - 1.0, centro.y)
	# Aplastado de frente: es un cordón largo, no un cono.
	vista.scale = Vector3(1.6, 1.0, 0.55)
	vista.rotation.y = centro.x * 0.01
	vista.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vista)


func _material(color: Color, rugosidad: float) -> StandardMaterial3D:
	var clave := color.to_html()
	if not _materiales.has(clave):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = rugosidad
		_materiales[clave] = material
	return _materiales[clave]
