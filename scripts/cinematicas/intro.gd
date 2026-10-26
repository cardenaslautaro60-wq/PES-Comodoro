extends Node3D
## Intro corta del juego (unos 8 segundos): la cámara baja desde el cerro hacia
## la cancha, una pelota cruza la toma y aparece el título.
##
## Se ve una sola vez al abrir el juego, antes del menú principal (la llama el
## autoload `Navegacion` del área G si existe esta escena). Se saltea con un
## toque, un clic o cualquier tecla o botón.

## Terminó (o se salteó). Se avisa antes de cambiar de escena.
signal terminada

## Escena a la que se va si no está el autoload `Navegacion`.
const ESCENA_SIGUIENTE := "res://escenas/menus/menu_principal.tscn"
const ESCENA_SIN_MENU := "res://escenas/partido/entrenamiento.tscn"
const SUBTITULO := "Fútbol de la Liga de Comodoro Rivadavia"

## Las pruebas lo apagan para que la intro no cambie de escena.
@export var cambiar_de_escena := true

var camara: CamaraCinematica
var pantalla: PantallaCinematica
var pelota: Node3D

var _terminando := false
var _salteada := false


func _ready() -> void:
	_crear_ambiente()
	add_child(Cancha.new())
	add_child(FondoComodoroProvisorio.new())
	pelota = _crear_pelota()

	camara = CamaraCinematica.new()
	camara.name = "CamaraCinematica"
	add_child(camara)
	camara.current = true
	pantalla = PantallaCinematica.new()
	pantalla.name = "PantallaCinematica"
	pantalla.saltear_pedido.connect(func() -> void: _salteada = true)
	add_child(pantalla)

	var sonido := get_node_or_null("/root/Sonido")
	if sonido and sonido.has_method("musica_de_menu"):
		sonido.call("musica_de_menu")
	_pasar()


func _pasar() -> void:
	pantalla.empezar(true)
	pantalla.fundir(1.0, 0.0)
	pantalla.fundir(0.0, 0.8)
	# Baja desde lo alto, con el cerro de fondo, hasta la altura del pasto.
	camara.tomar(
		Toma.recorrido(Vector3(-30, 40, 70), Vector3(-14, 2.0, 12), 4.0)
		.mirando_recorrido(Vector3(0, 10, -120), Vector3(0, 1.0, 0)).con_fov(50, 40)
	)
	if await _esperar(3.2):
		_terminar()
		return
	# La pelota cruza la toma.
	var tween := create_tween()
	tween.tween_property(pelota, "position", Vector3(8, 0.4, -6), 1.4).from(Vector3(-22, 2.5, 18))
	tween.parallel().tween_property(pelota, "rotation:z", -12.0, 1.4).from(0.0)
	if await _esperar(1.0):
		_terminar()
		return
	var titulo := str(ProjectSettings.get_setting("application/config/name", "PES: Comodoro"))
	pantalla.mostrar_titulo(titulo, SUBTITULO, true)
	camara.tomar(
		Toma.orbita(Vector3(8, 0, -6), Vector2(9, 11), Vector2(1.6, 3.5), Vector2(110, 150), 3.6)
		.mirando(pelota, 0.0).con_fov(40, 44)
	)
	if await _esperar(3.2):
		_terminar()
		return
	pantalla.fundir(1.0, 0.4)
	await _esperar(0.4)
	_terminar()


func _terminar() -> void:
	if _terminando:
		return
	_terminando = true
	terminada.emit()
	if not cambiar_de_escena:
		return
	var navegacion := get_node_or_null("/root/Navegacion")
	if navegacion and navegacion.has_method("ir_a"):
		navegacion.call("ir_a", navegacion.get("MENU_PRINCIPAL"))
	elif ResourceLoader.exists(ESCENA_SIGUIENTE):
		get_tree().change_scene_to_file.call_deferred(ESCENA_SIGUIENTE)
	else:
		get_tree().change_scene_to_file.call_deferred(ESCENA_SIN_MENU)


## Espera `segundos` o hasta que se saltee. Devuelve true si se salteó.
func _esperar(segundos: float) -> bool:
	var t := 0.0
	while t < segundos and not _salteada:
		await get_tree().process_frame
		t += get_process_delta_time()
	return _salteada


func _crear_pelota() -> Node3D:
	var malla := SphereMesh.new()
	malla.radius = 0.35
	malla.height = 0.7
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	malla.material = material
	var vista := MeshInstance3D.new()
	vista.name = "Pelota"
	vista.mesh = malla
	vista.position = Vector3(-22, 2.5, 18)
	add_child(vista)
	return vista


func _crear_ambiente() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color(0.30, 0.50, 0.85)
	cielo.sky_horizon_color = Color(0.95, 0.78, 0.55)
	cielo.ground_horizon_color = Color(0.45, 0.42, 0.38)
	var sky := Sky.new()
	sky.sky_material = cielo
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = sky
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	add_child(mundo)
	var sol := DirectionalLight3D.new()
	# Sol bajo de la tarde, como el de Comodoro en verano.
	sol.rotation_degrees = Vector3(-22, -60, 0)
	sol.light_color = Color(1.0, 0.88, 0.72)
	sol.shadow_enabled = true
	add_child(sol)
	var tierra := PlaneMesh.new()
	tierra.size = Vector2(400, 400)
	var material_tierra := StandardMaterial3D.new()
	material_tierra.albedo_color = Color(0.42, 0.38, 0.30)
	tierra.material = material_tierra
	var vista_tierra := MeshInstance3D.new()
	vista_tierra.mesh = tierra
	vista_tierra.position.y = -0.03
	add_child(vista_tierra)
