extends CharacterBody3D
## Jugador provisorio para la escena de prueba: corre, conduce, pasa y patea.
## El área B lo reemplaza por el jugador definitivo.

const DISTANCIA_PARA_PATEAR := 1.4
const VELOCIDAD_PASE := 12.0
const VELOCIDAD_TIRO := 24.0
const ELEVACION_TIRO := 0.18
const EMPUJE_CONDUCCION := 0.25

@export var velocidad := 7.0
@export var velocidad_sprint := 9.5
@export var pelota: RigidBody3D

## Hacia dónde mira el jugador, siempre horizontal y de largo 1.
var direccion_mirada := Vector3(1, 0, 0)

var _gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _physics_process(delta: float) -> void:
	var entrada: Vector2 = Controles.vector_movimiento()
	var direccion := Vector3(entrada.x, 0.0, entrada.y)
	var rapidez := velocidad_sprint if Input.is_action_pressed("sprint") else velocidad

	if direccion.length() > 0.05:
		direccion_mirada = direccion.normalized()
		look_at(global_position + direccion_mirada, Vector3.UP)

	velocity.x = direccion.x * rapidez
	velocity.z = direccion.z * rapidez
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravedad * delta
	move_and_slide()

	_conducir_pelota()
	_patear_si_corresponde()


func _conducir_pelota() -> void:
	for i in get_slide_collision_count():
		var choque := get_slide_collision(i)
		var cuerpo := choque.get_collider() as RigidBody3D
		if cuerpo:
			var empuje := -choque.get_normal()
			empuje.y = 0.0
			cuerpo.apply_central_impulse(empuje.normalized() * EMPUJE_CONDUCCION)


func _patear_si_corresponde() -> void:
	if pelota == null:
		return
	var rapidez := 0.0
	var elevacion := 0.0
	if Input.is_action_just_pressed("tiro"):
		rapidez = VELOCIDAD_TIRO
		elevacion = ELEVACION_TIRO
	elif Input.is_action_just_pressed("pase"):
		rapidez = VELOCIDAD_PASE
	if rapidez == 0.0 or not pelota_cerca():
		return
	var direccion := (direccion_mirada + Vector3.UP * elevacion).normalized()
	pelota.linear_velocity = direccion * rapidez
	pelota.angular_velocity = Vector3.ZERO


func pelota_cerca() -> bool:
	return pelota != null and global_position.distance_to(pelota.global_position) <= DISTANCIA_PARA_PATEAR
