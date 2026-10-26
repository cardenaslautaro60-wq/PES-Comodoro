class_name ControlHumano
extends Node3D
## Conecta a la persona con el jugador que maneja.
##
## Lee el movimiento y los botones de `Controles` (teclado, joystick o pantalla
## táctil) y los copia en la `entrada` del jugador elegido. Además:
## - Cambia de jugador con el botón "cambiar jugador" (al más cercano a la pelota).
## - Pasa el control al compañero que recibe un pase o que toma la pelota.
## - Dibuja un aro debajo del jugador que manejás.
## - Hace vibrar el celular al patear (si la vibración está activada).

signal jugador_cambiado(jugador: Jugador)

const COLOR_ARO := Color(1.0, 0.85, 0.1, 0.85)

@export var equipo := 0

var pelota: Pelota
var jugador: Jugador

var _aro: MeshInstance3D


func _ready() -> void:
	# Corre antes que los jugadores, así leen la entrada de este mismo cuadro.
	process_physics_priority = -10
	_aro = MeshInstance3D.new()
	_aro.name = "Aro"
	var malla := TorusMesh.new()
	malla.inner_radius = 0.5
	malla.outer_radius = 0.62
	malla.rings = 24
	malla.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_ARO
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	malla.material = material
	_aro.mesh = malla
	_aro.scale = Vector3(1, 0.05, 1)
	_aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aro.top_level = true
	add_child(_aro)


## Le da la pelota a seguir y el jugador con el que se empieza.
func configurar(nueva_pelota: Pelota, inicial: Jugador) -> void:
	pelota = nueva_pelota
	pelota.pateada.connect(_al_patear)
	pelota.poseedor_cambiado.connect(_al_cambiar_poseedor)
	cambiar_a(inicial)


func _physics_process(_delta: float) -> void:
	if jugador == null:
		return
	if Input.is_action_just_pressed("cambiar_jugador") and not jugador.en_ataque():
		var otro := companero_mas_cerca_de_la_pelota()
		if otro:
			cambiar_a(otro)
	_leer_entrada(jugador.entrada)


func _process(_delta: float) -> void:
	_aro.visible = jugador != null
	if jugador:
		var p := jugador.global_position
		_aro.global_position = Vector3(p.x, 0.03, p.z)


## Pasa a manejar a otro jugador. El anterior queda quieto (o en manos de la IA).
func cambiar_a(nuevo: Jugador) -> void:
	if nuevo == jugador or nuevo == null:
		return
	if jugador:
		jugador.entrada.limpiar()
		if jugador.pateo.is_connected(_al_patear_el_mio):
			jugador.pateo.disconnect(_al_patear_el_mio)
	jugador = nuevo
	_leer_entrada(jugador.entrada)
	jugador.recordar_botones()
	jugador.pateo.connect(_al_patear_el_mio)
	jugador_cambiado.emit(jugador)


## El compañero (que no sea el actual) más cerca de la pelota.
func companero_mas_cerca_de_la_pelota() -> Jugador:
	var mejor: Jugador = null
	var mejor_distancia := INF
	for nodo in get_tree().get_nodes_in_group("jugadores"):
		var otro := nodo as Jugador
		if otro == null or otro == jugador or otro.equipo != equipo:
			continue
		var distancia := otro.global_position.distance_to(pelota.global_position)
		if distancia < mejor_distancia:
			mejor = otro
			mejor_distancia = distancia
	return mejor


func _leer_entrada(entrada: EntradaJugador) -> void:
	var v: Vector2 = Controles.vector_movimiento()
	# La cámara mira la cancha de costado: derecha en pantalla es x positivo y
	# arriba en pantalla es z negativo.
	entrada.direccion = Vector3(v.x, 0, v.y).limit_length(1.0)
	entrada.sprint = Input.is_action_pressed("sprint")
	entrada.pase = Input.is_action_pressed("pase")
	entrada.tiro = Input.is_action_pressed("tiro")
	entrada.pase_largo = Input.is_action_pressed("pase_largo")
	entrada.pase_hueco = Input.is_action_pressed("pase_hueco")


func _al_patear(pateador: Jugador, destinatario: Jugador) -> void:
	if pateador == jugador and destinatario and destinatario.equipo == equipo:
		cambiar_a(destinatario)


func _al_cambiar_poseedor(nuevo: Jugador) -> void:
	if nuevo and nuevo.equipo == equipo:
		cambiar_a(nuevo)


func _al_patear_el_mio(_tipo: Jugador.Patada, fuerza: float) -> void:
	Controles.vibrar(int(lerpf(20, 60, fuerza)))
