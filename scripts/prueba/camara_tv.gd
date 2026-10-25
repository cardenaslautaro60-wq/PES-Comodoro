extends Camera3D
## Cámara de transmisión de TV: mira la cancha de costado, desde arriba,
## y sigue la pelota con suavidad.

@export var objetivo: Node3D
@export var altura := 20.0
@export var distancia := 38.0
## Cuánto acompaña la cámara a la pelota a lo largo (0 = quieta, 1 = siempre encima).
@export_range(0.0, 1.0) var seguimiento_largo := 0.85
@export_range(0.0, 1.0) var seguimiento_ancho := 0.35
@export var suavizado := 3.0


func _ready() -> void:
	fov = 38.0
	if objetivo:
		global_position = _posicion_deseada()
		_mirar()


func _process(delta: float) -> void:
	if objetivo == null:
		return
	global_position = global_position.lerp(_posicion_deseada(), 1.0 - exp(-suavizado * delta))
	_mirar()


func _posicion_deseada() -> Vector3:
	var p := objetivo.global_position
	return Vector3(p.x * seguimiento_largo, altura, p.z * seguimiento_ancho + distancia)


func _mirar() -> void:
	var p := objetivo.global_position
	look_at(Vector3(p.x, 0.0, p.z * 0.8), Vector3.UP)
