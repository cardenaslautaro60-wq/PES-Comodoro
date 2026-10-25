extends Node3D
## Escena de prueba de la base del proyecto.
##
## Arma por código una cancha con medidas reglamentarias, los arcos, la pelota,
## un jugador provisorio, la cámara de TV y los controles táctiles. Sirve para
## comprobar que el proyecto anda en la compu y en el celular, y para medir FPS.
## Las áreas B (jugabilidad) y E (arte) reemplazan estas piezas por las definitivas.

signal gol(equipo: String)

const JugadorPrueba := preload("res://scripts/prueba/jugador_prueba.gd")
const CamaraTV := preload("res://scripts/prueba/camara_tv.gd")
const JoystickVirtual := preload("res://scripts/ui/joystick_virtual.gd")
const BotonAccion := preload("res://scripts/ui/boton_accion.gd")

# Medidas en metros (reglamento FIFA).
const LARGO := 105.0
const ANCHO := 68.0
const ANCHO_ARCO := 7.32
const ALTO_ARCO := 2.44
const FONDO_ARCO := 2.0
const GROSOR_POSTE := 0.12
const GROSOR_LINEA := 0.12
const RADIO_CIRCULO_CENTRAL := 9.15
const RADIO_PELOTA := 0.11
const MASA_PELOTA := 0.43
const ALTO_JUGADOR := 1.8
const RADIO_JUGADOR := 0.35

const VERDE_CLARO := Color(0.30, 0.58, 0.22)
const VERDE_OSCURO := Color(0.25, 0.51, 0.18)
const VERDE_BORDE := Color(0.20, 0.42, 0.15)
const BLANCO := Color(0.95, 0.95, 0.95)
const COLOR_LOCAL := Color(0.80, 0.12, 0.15)

var goles_local := 0
var goles_visitante := 0

var pelota: RigidBody3D
var jugador: JugadorPrueba
var camara: CamaraTV

var _esperando_reinicio := false
var _temporizador_reinicio: Timer
var _materiales := {}
var _marcador: Label
var _contador_fps: Label


func _ready() -> void:
	_temporizador_reinicio = Timer.new()
	_temporizador_reinicio.name = "TemporizadorReinicio"
	_temporizador_reinicio.one_shot = true
	_temporizador_reinicio.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_temporizador_reinicio.timeout.connect(_al_terminar_espera)
	add_child(_temporizador_reinicio)
	_crear_ambiente()
	_crear_cancha()
	_crear_arco(1)
	_crear_arco(-1)
	_crear_pelota()
	_crear_jugador()
	_crear_camara()
	_crear_interfaz()
	reiniciar_jugada()


func _process(_delta: float) -> void:
	_contador_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _physics_process(_delta: float) -> void:
	if _esperando_reinicio:
		return
	var p := pelota.global_position
	var fuera_lateral := absf(p.z) > ANCHO / 2 + RADIO_PELOTA
	var fuera_fondo := absf(p.x) > LARGO / 2 + RADIO_PELOTA and absf(p.z) > ANCHO_ARCO / 2
	var muy_lejos := absf(p.x) > LARGO / 2 + FONDO_ARCO + 1.0 or p.y < -1.0
	if fuera_lateral or fuera_fondo or muy_lejos:
		_programar_reinicio(1.0)


## Pone la pelota en el centro y al jugador al lado, listos para sacar.
func reiniciar_jugada() -> void:
	pelota.linear_velocity = Vector3.ZERO
	pelota.angular_velocity = Vector3.ZERO
	pelota.global_position = Vector3(0, RADIO_PELOTA + 0.02, 0)
	pelota.sleeping = false
	jugador.global_position = Vector3(-1.5, ALTO_JUGADOR / 2, 0)
	jugador.velocity = Vector3.ZERO
	jugador.direccion_mirada = Vector3(1, 0, 0)


func _programar_reinicio(segundos: float) -> void:
	_esperando_reinicio = true
	_temporizador_reinicio.start(segundos)


func _al_terminar_espera() -> void:
	reiniciar_jugada()
	_esperando_reinicio = false


func _al_entrar_en_arco(cuerpo: Node3D, lado: int) -> void:
	if cuerpo != pelota or _esperando_reinicio:
		return
	# El local ataca hacia la derecha (x positivo).
	var equipo := "local" if lado > 0 else "visitante"
	if lado > 0:
		goles_local += 1
	else:
		goles_visitante += 1
	_actualizar_marcador()
	gol.emit(equipo)
	_programar_reinicio(2.0)


func _actualizar_marcador() -> void:
	_marcador.text = "LOCAL  %d - %d  VISITANTE" % [goles_local, goles_visitante]


# --- Ambiente -----------------------------------------------------------------


func _crear_ambiente() -> void:
	var material_cielo := ProceduralSkyMaterial.new()
	material_cielo.sky_top_color = Color(0.32, 0.52, 0.85)
	material_cielo.sky_horizon_color = Color(0.74, 0.82, 0.92)
	material_cielo.ground_horizon_color = Color(0.74, 0.82, 0.92)
	material_cielo.ground_bottom_color = Color(0.35, 0.33, 0.30)
	var cielo := Sky.new()
	cielo.sky_material = material_cielo

	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = cielo
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var mundo := WorldEnvironment.new()
	mundo.name = "Ambiente"
	mundo.environment = entorno
	add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-50, -30, 0)
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 90.0
	add_child(sol)


# --- Cancha -------------------------------------------------------------------


func _crear_cancha() -> void:
	var piso := StaticBody3D.new()
	piso.name = "Piso"
	var material_piso := PhysicsMaterial.new()
	material_piso.friction = 0.8
	material_piso.bounce = 0.5
	piso.physics_material_override = material_piso
	var caja := BoxShape3D.new()
	caja.size = Vector3(LARGO + 24, 1, ANCHO + 24)
	var forma := CollisionShape3D.new()
	forma.shape = caja
	forma.position.y = -0.5
	piso.add_child(forma)
	add_child(piso)

	_plano(Vector3(0, -0.01, 0), Vector2(LARGO + 24, ANCHO + 24), VERDE_BORDE)

	# Franjas del pasto, como en una cancha cortada.
	var franjas := 14
	var ancho_franja := LARGO / franjas
	for i in franjas:
		var x := -LARGO / 2 + ancho_franja * (i + 0.5)
		var color := VERDE_CLARO if i % 2 == 0 else VERDE_OSCURO
		_plano(Vector3(x, 0.0, 0), Vector2(ancho_franja, ANCHO), color)

	_crear_lineas()


func _crear_lineas() -> void:
	var g := GROSOR_LINEA
	var mitad_largo := LARGO / 2
	_rectangulo(Vector3.ZERO, Vector2(LARGO, ANCHO))
	_linea(Vector3.ZERO, Vector2(g, ANCHO))
	_circulo(Vector3.ZERO, RADIO_CIRCULO_CENTRAL)
	_linea(Vector3.ZERO, Vector2(0.3, 0.3))
	for lado: int in [-1, 1]:
		# Área grande: 16,5 m de fondo por 40,32 m de ancho.
		_rectangulo(Vector3(lado * (mitad_largo - 16.5 / 2), 0, 0), Vector2(16.5, 40.32))
		# Área chica: 5,5 m de fondo por 18,32 m de ancho.
		_rectangulo(Vector3(lado * (mitad_largo - 5.5 / 2), 0, 0), Vector2(5.5, 18.32))
		# Punto penal a 11 m del arco.
		_linea(Vector3(lado * (mitad_largo - 11.0), 0, 0), Vector2(0.25, 0.25))


func _rectangulo(centro: Vector3, tamano: Vector2) -> void:
	var g := GROSOR_LINEA
	var mx := tamano.x / 2
	var mz := tamano.y / 2
	_linea(centro + Vector3(0, 0, -mz), Vector2(tamano.x + g, g))
	_linea(centro + Vector3(0, 0, mz), Vector2(tamano.x + g, g))
	_linea(centro + Vector3(-mx, 0, 0), Vector2(g, tamano.y + g))
	_linea(centro + Vector3(mx, 0, 0), Vector2(g, tamano.y + g))


func _circulo(centro: Vector3, radio: float) -> void:
	var segmentos := 64
	var largo_segmento := TAU * radio / segmentos + 0.02
	for i in segmentos:
		var angulo := TAU * i / segmentos
		var punto := centro + Vector3(cos(angulo), 0, sin(angulo)) * radio
		var segmento := _linea(punto, Vector2(GROSOR_LINEA, largo_segmento))
		segmento.rotation.y = -angulo


func _linea(centro: Vector3, tamano: Vector2) -> MeshInstance3D:
	return _plano(centro + Vector3(0, 0.01, 0), tamano, BLANCO)


func _plano(centro: Vector3, tamano: Vector2, color: Color) -> MeshInstance3D:
	var malla := PlaneMesh.new()
	malla.size = tamano
	malla.material = _material(color)
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.position = centro
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instancia)
	return instancia


## Reusa un material por color, así hay menos llamadas de dibujo en el celular.
func _material(color: Color, transparente := false) -> StandardMaterial3D:
	var clave := "%s-%s" % [color.to_html(), transparente]
	if not _materiales.has(clave):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		if transparente:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiales[clave] = material
	return _materiales[clave]


# --- Arcos --------------------------------------------------------------------


func _crear_arco(lado: int) -> void:
	var arco := StaticBody3D.new()
	arco.name = "ArcoDerecho" if lado > 0 else "ArcoIzquierdo"
	add_child(arco)

	var linea := lado * LARGO / 2
	var x_palos := linea + lado * GROSOR_POSTE / 2
	var z_palo := ANCHO_ARCO / 2 + GROSOR_POSTE / 2
	var poste := Vector3(GROSOR_POSTE, ALTO_ARCO, GROSOR_POSTE)
	_pieza(arco, Vector3(x_palos, ALTO_ARCO / 2, -z_palo), poste, BLANCO)
	_pieza(arco, Vector3(x_palos, ALTO_ARCO / 2, z_palo), poste, BLANCO)
	var travesano := Vector3(GROSOR_POSTE, GROSOR_POSTE, ANCHO_ARCO + GROSOR_POSTE * 2)
	_pieza(arco, Vector3(x_palos, ALTO_ARCO + GROSOR_POSTE / 2, 0), travesano, BLANCO)

	# Red: fondo, costados y techo. Frena la pelota sin hacerla rebotar mucho.
	var red := PhysicsMaterial.new()
	red.bounce = 0.1
	red.absorbent = true
	red.friction = 1.0
	arco.physics_material_override = red
	var color_red := Color(1, 1, 1, 0.35)
	var x_medio := linea + lado * FONDO_ARCO / 2
	_pieza(arco, Vector3(linea + lado * FONDO_ARCO, ALTO_ARCO / 2, 0), Vector3(0.05, ALTO_ARCO, ANCHO_ARCO), color_red)
	_pieza(arco, Vector3(x_medio, ALTO_ARCO / 2, -ANCHO_ARCO / 2), Vector3(FONDO_ARCO, ALTO_ARCO, 0.05), color_red)
	_pieza(arco, Vector3(x_medio, ALTO_ARCO / 2, ANCHO_ARCO / 2), Vector3(FONDO_ARCO, ALTO_ARCO, 0.05), color_red)
	_pieza(arco, Vector3(x_medio, ALTO_ARCO, 0), Vector3(FONDO_ARCO, 0.05, ANCHO_ARCO), color_red)

	# Zona de gol. Empieza a dos radios de la línea: la pelota la toca recién
	# cuando cruzó la línea entera, como dice el reglamento.
	var caja := BoxShape3D.new()
	caja.size = Vector3(FONDO_ARCO - RADIO_PELOTA * 2, ALTO_ARCO, ANCHO_ARCO)
	var forma := CollisionShape3D.new()
	forma.shape = caja
	var zona := Area3D.new()
	zona.name = "ZonaGol"
	zona.position = Vector3(linea + lado * (FONDO_ARCO / 2 + RADIO_PELOTA), ALTO_ARCO / 2, 0)
	zona.add_child(forma)
	zona.body_entered.connect(_al_entrar_en_arco.bind(lado))
	arco.add_child(zona)


func _pieza(padre: Node3D, centro: Vector3, tamano: Vector3, color: Color) -> void:
	var caja := BoxShape3D.new()
	caja.size = tamano
	var forma := CollisionShape3D.new()
	forma.shape = caja
	forma.position = centro
	padre.add_child(forma)

	var malla := BoxMesh.new()
	malla.size = tamano
	malla.material = _material(color, color.a < 1.0)
	var vista := MeshInstance3D.new()
	vista.mesh = malla
	vista.position = centro
	padre.add_child(vista)


# --- Pelota, jugador y cámara -------------------------------------------------


func _crear_pelota() -> void:
	pelota = RigidBody3D.new()
	pelota.name = "Pelota"
	pelota.mass = MASA_PELOTA
	pelota.linear_damp = 0.35
	pelota.angular_damp = 0.8
	pelota.continuous_cd = true
	var material := PhysicsMaterial.new()
	material.bounce = 0.6
	material.friction = 0.6
	pelota.physics_material_override = material

	var esfera := SphereShape3D.new()
	esfera.radius = RADIO_PELOTA
	var forma := CollisionShape3D.new()
	forma.shape = esfera
	pelota.add_child(forma)

	var malla := SphereMesh.new()
	malla.radius = RADIO_PELOTA
	malla.height = RADIO_PELOTA * 2
	malla.material = _material(Color.WHITE)
	var vista := MeshInstance3D.new()
	vista.mesh = malla
	pelota.add_child(vista)
	add_child(pelota)


func _crear_jugador() -> void:
	jugador = JugadorPrueba.new()
	jugador.name = "Jugador"
	jugador.pelota = pelota

	var capsula := CapsuleShape3D.new()
	capsula.radius = RADIO_JUGADOR
	capsula.height = ALTO_JUGADOR
	var forma := CollisionShape3D.new()
	forma.shape = capsula
	jugador.add_child(forma)

	var cuerpo := CapsuleMesh.new()
	cuerpo.radius = RADIO_JUGADOR
	cuerpo.height = ALTO_JUGADOR
	cuerpo.material = _material(COLOR_LOCAL)
	var vista := MeshInstance3D.new()
	vista.mesh = cuerpo
	jugador.add_child(vista)

	# Marca blanca en el pecho para ver hacia dónde mira.
	var marca := BoxMesh.new()
	marca.size = Vector3(0.25, 0.2, 0.1)
	marca.material = _material(BLANCO)
	var vista_marca := MeshInstance3D.new()
	vista_marca.mesh = marca
	vista_marca.position = Vector3(0, 0.35, -RADIO_JUGADOR)
	jugador.add_child(vista_marca)
	add_child(jugador)


func _crear_camara() -> void:
	camara = CamaraTV.new()
	camara.name = "CamaraTV"
	camara.objetivo = pelota
	add_child(camara)
	camara.current = true


# --- Interfaz -----------------------------------------------------------------


func _crear_interfaz() -> void:
	var capa := CanvasLayer.new()
	capa.name = "Interfaz"
	add_child(capa)

	_marcador = Label.new()
	_marcador.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_marcador.offset_top = 12
	_marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marcador.add_theme_font_size_override("font_size", 30)
	_marcador.add_theme_color_override("font_outline_color", Color.BLACK)
	_marcador.add_theme_constant_override("outline_size", 6)
	capa.add_child(_marcador)
	_actualizar_marcador()

	_contador_fps = Label.new()
	_contador_fps.position = Vector2(12, 8)
	_contador_fps.add_theme_font_size_override("font_size", 18)
	capa.add_child(_contador_fps)

	var joystick: Control = JoystickVirtual.new()
	joystick.name = "Joystick"
	capa.add_child(joystick)

	if es_tactil():
		_crear_botones(capa)
	else:
		var ayuda := Label.new()
		ayuda.text = "Mover: WASD o flechas   Pase: J o Espacio   Tiro: K   Sprint: Shift"
		ayuda.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		ayuda.offset_top = -40
		ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ayuda.add_theme_font_size_override("font_size", 18)
		capa.add_child(ayuda)


func _crear_botones(capa: CanvasLayer) -> void:
	var tamano := 140.0
	var separacion := 18.0
	var margen := 36.0
	var acciones := [["SPRINT", "sprint"], ["PASE", "pase"], ["TIRO", "tiro"]]

	var fila := HBoxContainer.new()
	fila.name = "Botones"
	fila.add_theme_constant_override("separation", int(separacion))
	var ancho_total := tamano * acciones.size() + separacion * (acciones.size() - 1)
	fila.anchor_left = 1.0
	fila.anchor_right = 1.0
	fila.anchor_top = 1.0
	fila.anchor_bottom = 1.0
	fila.offset_left = -ancho_total - margen
	fila.offset_right = -margen
	fila.offset_top = -tamano - margen
	fila.offset_bottom = -margen
	capa.add_child(fila)

	for datos: Array in acciones:
		var boton: Button = BotonAccion.new()
		boton.text = datos[0]
		boton.set("accion", datos[1])
		boton.custom_minimum_size = Vector2(tamano, tamano)
		boton.add_theme_font_size_override("font_size", 26)
		boton.add_theme_stylebox_override("normal", _estilo_boton(Color(0, 0, 0, 0.35)))
		boton.add_theme_stylebox_override("hover", _estilo_boton(Color(0, 0, 0, 0.35)))
		boton.add_theme_stylebox_override("pressed", _estilo_boton(Color(1, 1, 1, 0.35)))
		fila.add_child(boton)


func _estilo_boton(color: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(70)
	estilo.border_color = Color(1, 1, 1, 0.5)
	estilo.set_border_width_all(2)
	return estilo


func es_tactil() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
