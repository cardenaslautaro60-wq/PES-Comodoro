class_name Pelota
extends RigidBody3D
## Pelota con física de fútbol.
##
## - Roce del aire (frena más cuanto más rápido va).
## - Efecto: la pelota con giro se curva en el aire (efecto Magnus).
## - Roce con el pasto: cuando rueda se va frenando sola.
## - Control "pegado al pie": mientras un jugador la conduce, la pelota lo acompaña
##   adelante de los pies, con toques más largos cuanto más rápido corre.
##
## También decide quién la toma cuando está suelta, los robos y los rebotes en los
## cuerpos (ver `CapasFisica`: la pelota no choca físicamente con los jugadores).

## La patearon. `destinatario` es el compañero al que iba el pase, o null.
signal pateada(pateador: Jugador, destinatario: Jugador)
## Cambió quién la tiene. `nuevo` es null cuando queda suelta.
signal poseedor_cambiado(nuevo: Jugador)

const RADIO := 0.11
const MASA := 0.43
## Altura máxima a la que un jugador la puede bajar con el pie o el pecho.
const ALTURA_CONTROL := 1.3
## Distancia (en el piso) a la que un jugador alcanza una pelota suelta.
const ALCANCE_CONTROL := 0.9
## Más rápido que esto (respecto del jugador), la pelota no se puede parar: rebota.
const VELOCIDAD_MAX_CONTROL := 24.0
## Distancia a la que un rival puede disputar la pelota que alguien conduce.
const ALCANCE_ROBO := 0.8
## Altura hasta la que un cuerpo desvía la pelota.
const ALTURA_CUERPO := 1.9
## Qué tan fuerte sigue la pelota el pie del que la conduce.
const RIGIDEZ_CONDUCCION := 14.0
## Paso de las simulaciones que calculan pases y tiros.
const PASO_SIMULACION := 1.0 / 60.0

## Roce del aire: frena v² por este factor. El de una pelota real ronda 0,013.
@export var roce_aire := 0.013
## Cuánto curva el efecto.
@export var fuerza_efecto := 0.007
## Freno fijo del pasto al rodar, en m/s².
@export var roce_pasto := 0.9
## Freno del pasto proporcional a la velocidad, en 1/s.
@export var roce_pasto_lineal := 0.2
## Cuánto se pierde el efecto por segundo en el aire.
@export var freno_efecto := 0.4

var poseedor: Jugador = null
var ultimo_en_tocar: Jugador = null
## Compañero al que iba el último pase (null si fue un tiro o un pase sin destino).
var destinatario: Jugador = null
## Giro de la pelota en rad/s. Es lo que la curva en el aire.
var efecto := Vector3.ZERO
## Dados de la pelota (robos). Las pruebas le fijan la semilla.
var rng := RandomNumberGenerator.new()

var _posicion_anterior := Vector3.ZERO


func _init() -> void:
	mass = MASA
	continuous_cd = true
	collision_layer = CapasFisica.PELOTA
	collision_mask = CapasFisica.MUNDO
	# Los frenos los calcula esta clase, no los de Godot.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	var material := PhysicsMaterial.new()
	material.bounce = 0.6
	# Sin roce físico: el roce con el pasto y el giro los maneja `_integrate_forces`.
	material.friction = 0.0
	physics_material_override = material


func _ready() -> void:
	add_to_group("pelota")
	if get_node_or_null("Forma") == null:
		var esfera := SphereShape3D.new()
		esfera.radius = RADIO
		var forma := CollisionShape3D.new()
		forma.name = "Forma"
		forma.shape = esfera
		add_child(forma)
	if get_node_or_null("Modelo") == null:
		_crear_modelo_provisorio()
	_posicion_anterior = global_position


func _crear_modelo_provisorio() -> void:
	var malla := SphereMesh.new()
	malla.radius = RADIO
	malla.height = RADIO * 2
	malla.radial_segments = 16
	malla.rings = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.roughness = 0.6
	malla.material = material
	var modelo := MeshInstance3D.new()
	modelo.name = "Modelo"
	modelo.mesh = malla
	add_child(modelo)
	# Un gajo oscuro para que se vea girar.
	var gajo := BoxMesh.new()
	gajo.size = Vector3(RADIO * 2.02, RADIO * 0.5, RADIO * 0.5)
	var material_gajo := StandardMaterial3D.new()
	material_gajo.albedo_color = Color(0.1, 0.1, 0.1)
	gajo.material = material_gajo
	var vista_gajo := MeshInstance3D.new()
	vista_gajo.mesh = gajo
	modelo.add_child(vista_gajo)


func _integrate_forces(estado: PhysicsDirectBodyState3D) -> void:
	var v := estado.linear_velocity
	var dt := estado.step
	var en_piso := _esta_en_el_piso(estado.transform.origin, v)

	if poseedor != null:
		var objetivo := poseedor.punto_de_conduccion()
		var diferencia := objetivo - estado.transform.origin
		var v_deseada := poseedor.velocity + diferencia * RIGIDEZ_CONDUCCION
		v.x = v_deseada.x
		v.z = v_deseada.z
		efecto = Vector3.ZERO
	else:
		v = _frenar(v, en_piso, dt, efecto)
		efecto *= exp(-(freno_efecto if not en_piso else 4.0) * dt)

	estado.linear_velocity = v
	# El giro que se ve: rodando en el piso, o el efecto en el aire.
	estado.angular_velocity = Vector3.UP.cross(v) / RADIO if en_piso else efecto


func _physics_process(delta: float) -> void:
	var posicion := global_position
	if poseedor == null:
		if not _desviar_en_cuerpos(_posicion_anterior, posicion):
			_buscar_quien_la_controla()
	else:
		_resolver_disputa(delta)
	_posicion_anterior = global_position


## Patea la pelota. Suelta al que la tenía.
func patear(velocidad: Vector3, giro: Vector3, pateador: Jugador, para: Jugador = null) -> void:
	_cambiar_poseedor(null)
	linear_velocity = velocidad
	efecto = giro
	ultimo_en_tocar = pateador
	destinatario = para
	pateada.emit(pateador, para)


## Le da la pelota a un jugador (la controla y la conduce).
func dar_a(jugador: Jugador) -> void:
	ultimo_en_tocar = jugador
	destinatario = null
	efecto = Vector3.ZERO
	_cambiar_poseedor(jugador)
	jugador.al_tomar_pelota()


## La pelota queda suelta donde está (por ejemplo, si derriban al que la tenía).
func soltar() -> void:
	_cambiar_poseedor(null)


## Pone la pelota quieta en un lugar, sin dueño.
func colocar(posicion: Vector3) -> void:
	_cambiar_poseedor(null)
	ultimo_en_tocar = null
	destinatario = null
	efecto = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = posicion
	_posicion_anterior = posicion
	sleeping = false


func esta_en_el_piso() -> bool:
	return _esta_en_el_piso(global_position, linear_velocity)


# --- Cálculos para pases y tiros ----------------------------------------------


## Velocidad inicial para que la pelota, rodando, recorra `distancia` y llegue
## con `velocidad_final`.
func velocidad_para_rodar(distancia: float, velocidad_final: float) -> float:
	var minimo := velocidad_final
	var maximo := 45.0
	for i in 18:
		var medio := (minimo + maximo) / 2
		if _distancia_rodando(medio, velocidad_final) < distancia:
			minimo = medio
		else:
			maximo = medio
	return (minimo + maximo) / 2


## Velocidad inicial para que la pelota, saliendo con ese ángulo (en radianes),
## pique por primera vez a `distancia` metros.
func velocidad_para_volar(distancia: float, angulo: float) -> float:
	var minimo := 1.0
	var maximo := 50.0
	for i in 18:
		var medio := (minimo + maximo) / 2
		var v := Vector3(cos(angulo), sin(angulo), 0) * medio
		if _distancia_hasta_picar(v) < distancia:
			minimo = medio
		else:
			maximo = medio
	return (minimo + maximo) / 2


## Ángulo de salida (en radianes) para que la pelota, saliendo a `rapidez`,
## pase a `altura` metros cuando recorrió `distancia` metros.
func angulo_para_altura(rapidez: float, distancia: float, altura: float) -> float:
	var minimo := -0.15
	var maximo := 0.7
	for i in 16:
		var medio := (minimo + maximo) / 2
		var v := Vector3(cos(medio), sin(medio), 0) * rapidez
		if _altura_a_distancia(v, distancia) < altura:
			minimo = medio
		else:
			maximo = medio
	return (minimo + maximo) / 2


func _distancia_rodando(velocidad_inicial: float, velocidad_final: float) -> float:
	var v := Vector3(velocidad_inicial, 0, 0)
	var recorrido := 0.0
	for i in 60 * 30:
		if v.x <= velocidad_final:
			break
		v = _frenar(v, true, PASO_SIMULACION)
		recorrido += v.x * PASO_SIMULACION
	return recorrido


func _distancia_hasta_picar(velocidad: Vector3) -> float:
	var v := velocidad
	var p := Vector3(0, RADIO, 0)
	var g := _gravedad()
	for i in 60 * 10:
		v.y -= g * PASO_SIMULACION
		v = _frenar(v, false, PASO_SIMULACION)
		p += v * PASO_SIMULACION
		if p.y <= RADIO and v.y < 0:
			break
	return p.x


func _altura_a_distancia(velocidad: Vector3, distancia: float) -> float:
	var v := velocidad
	var p := Vector3(0, RADIO, 0)
	var g := _gravedad()
	for i in 60 * 10:
		if p.x >= distancia:
			return p.y
		v.y -= g * PASO_SIMULACION
		v = _frenar(v, p.y <= RADIO + 0.01 and v.y <= 0.0, PASO_SIMULACION)
		p += v * PASO_SIMULACION
		if p.y < RADIO:
			p.y = RADIO
			v.y = 0.0
		if v.x <= 0.01:
			break
	return -1.0


# --- Internos -----------------------------------------------------------------


func _frenar(velocidad: Vector3, en_piso: bool, dt: float, giro := Vector3.ZERO) -> Vector3:
	var v := velocidad
	var rapidez := v.length()
	if rapidez > 0.001:
		v -= v * minf(roce_aire * rapidez * dt, 1.0)
	if en_piso:
		var horizontal := Vector2(v.x, v.z)
		var r := horizontal.length()
		if r > 0.0001:
			var nueva := maxf(r - (roce_pasto + roce_pasto_lineal * r) * dt, 0.0)
			horizontal *= nueva / r
			v.x = horizontal.x
			v.z = horizontal.y
	elif giro != Vector3.ZERO:
		v += giro.cross(v) * fuerza_efecto * dt
	return v


func _esta_en_el_piso(posicion: Vector3, velocidad: Vector3) -> bool:
	return posicion.y <= RADIO + 0.04 and absf(velocidad.y) < 1.5


func _gravedad() -> float:
	return ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * gravity_scale


func _cambiar_poseedor(nuevo: Jugador) -> void:
	if poseedor == nuevo:
		return
	poseedor = nuevo
	poseedor_cambiado.emit(nuevo)


func _jugadores() -> Array[Node]:
	return get_tree().get_nodes_in_group("jugadores")


func _buscar_quien_la_controla() -> void:
	var p := global_position
	if p.y > ALTURA_CONTROL:
		return
	var mejor: Jugador = null
	var mejor_distancia := INF
	for nodo in _jugadores():
		var jugador := nodo as Jugador
		if jugador == null or not jugador.puede_tomar_pelota():
			continue
		var distancia := _distancia_en_el_piso(jugador.global_position, p)
		if distancia > ALCANCE_CONTROL or distancia >= mejor_distancia:
			continue
		var relativa := linear_velocity - jugador.velocity
		if relativa.length() > VELOCIDAD_MAX_CONTROL:
			continue
		mejor = jugador
		mejor_distancia = distancia
	if mejor:
		dar_a(mejor)


## Una pelota que va demasiado rápido para controlarla rebota en el cuerpo
## de quien se cruce. Devuelve true si rebotó.
func _desviar_en_cuerpos(desde: Vector3, hasta: Vector3) -> bool:
	if linear_velocity.length() <= VELOCIDAD_MAX_CONTROL * 0.6 or hasta.y > ALTURA_CUERPO:
		return false
	for nodo in _jugadores():
		var jugador := nodo as Jugador
		if jugador == null or jugador == ultimo_en_tocar or not jugador.puede_tomar_pelota():
			continue
		var centro := jugador.global_position
		centro.y = hasta.y
		var punto := Geometry3D.get_closest_point_to_segment(centro, desde, hasta)
		if punto.distance_to(centro) > Jugador.RADIO + RADIO:
			continue
		var normal := punto - centro
		normal.y = 0.0
		normal = normal.normalized() if normal.length() > 0.01 else -linear_velocity.normalized()
		var v := linear_velocity
		var rebote := v - normal * 1.6 * v.dot(normal)
		linear_velocity = rebote * 0.35
		global_position = centro + normal * (Jugador.RADIO + RADIO + 0.02)
		efecto = Vector3.ZERO
		ultimo_en_tocar = jugador
		destinatario = null
		jugador.bloquear_control(0.25)
		return true
	return false


## Los rivales cerca del que conduce pueden sacarle la pelota.
func _resolver_disputa(delta: float) -> void:
	if not poseedor.esta_protegido():
		for nodo in _jugadores():
			var rival := nodo as Jugador
			if rival == null or rival.equipo == poseedor.equipo or not rival.puede_tomar_pelota():
				continue
			if _distancia_en_el_piso(rival.global_position, global_position) > ALCANCE_ROBO:
				continue
			var ventaja := 2.0 * rival.defensa / float(rival.defensa + poseedor.control_de_pelota())
			var por_segundo := (2.4 if rival.presionando else 0.5) * ventaja
			if rng.randf() < por_segundo * delta:
				poseedor.bloquear_control(0.6)
				dar_a(rival)
				return


func _distancia_en_el_piso(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
