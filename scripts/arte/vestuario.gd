extends Node3D
## Escena de muestra del arte: dos clubes de Comodoro, con sus camisetas y la
## apariencia de sus planteles, trotando en una cancha con la cámara girando
## alrededor. Sirve para revisar el modelo del jugador, las camisetas y los FPS
## en el celular sin armar un partido.
##
## Abrir res://escenas/arte/vestuario.tscn y darle a "Ejecutar escena actual".

const POR_EQUIPO := 5
const RADIO_VUELTA := 6.0

## Clubes de datos/clubes/ y qué camiseta usa cada uno.
@export var club_local := "cai"
@export var club_visitante := "laprida"
@export_enum("titular", "suplente") var camiseta_visitante := "titular"

var modelos: Array[ModeloJugador] = []
var _camara: Camera3D
var _fps: Label
var _tiempo := 0.0


func _ready() -> void:
	_armar_ambiente()
	var clubes := [[club_local, "titular"], [club_visitante, camiseta_visitante]]
	for equipo in 2:
		var club := _leer("res://datos/clubes/%s.json" % clubes[equipo][0])
		var kit: Dictionary = club.get("camisetas", {}).get(clubes[equipo][1], {})
		var sponsor := await GeneradorCamiseta.imagen_sponsor(get_tree(), kit)
		var material := GeneradorCamiseta.crear_material(kit, null, sponsor)
		var plantel := _leer("res://datos/planteles/%s.json" % clubes[equipo][0])
		var jugadores := _jugadores_de_campo(plantel)
		for i in POR_EQUIPO:
			var datos: Dictionary = jugadores[i] if i < jugadores.size() else {}
			var modelo := ModeloJugador.new()
			add_child(modelo)
			var n := equipo * POR_EQUIPO + i
			modelo.vestir(material, int(datos.get("dorsal", i + 2)), datos.get("apariencia", {}))
			# La altura del plantel, entre 1,70 y 1,90 m más o menos.
			modelo.scale = Vector3.ONE * clampf(float(datos.get("altura_cm", 180)) / 180.0, 0.94, 1.06)
			modelo.set_meta("angulo", TAU * n / (2.0 * POR_EQUIPO))
			modelo.set_meta("ritmo", 2.0 + 5.0 * float(i) / POR_EQUIPO)
			modelos.append(modelo)


func _process(delta: float) -> void:
	_tiempo += delta
	for modelo in modelos:
		var ritmo: float = modelo.get_meta("ritmo")
		var angulo: float = modelo.get_meta("angulo") + _tiempo * ritmo / RADIO_VUELTA * 0.5
		modelo.position = Vector3(cos(angulo), 0, sin(angulo)) * RADIO_VUELTA
		# Mira hacia donde va: la tangente de la vuelta.
		modelo.basis = Basis.looking_at(Vector3(-sin(angulo), 0, cos(angulo)), Vector3.UP)
		modelo.velocidad = ritmo * 0.5
	# Cada tanto alguno patea.
	if int(_tiempo * 2.0) != int((_tiempo - delta) * 2.0) and not modelos.is_empty():
		modelos[randi() % modelos.size()].patear()
	var giro := _tiempo * 0.15
	_camara.position = Vector3(sin(giro) * 13.0, 4.5, cos(giro) * 13.0)
	_camara.look_at(Vector3(0, 0.9, 0))
	_fps.text = "%d FPS · %d jugadores" % [Engine.get_frames_per_second(), modelos.size()]


func _leer(ruta: String) -> Dictionary:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if not datos is Dictionary:
		push_error("No se pudo leer " + ruta)
		return {}
	return datos


func _jugadores_de_campo(plantel: Dictionary) -> Array:
	var lista := []
	for jugador: Dictionary in plantel.get("jugadores", []):
		if jugador.get("posicion") != "ARQ":
			lista.append(jugador)
	return lista


func _armar_ambiente() -> void:
	_camara = Camera3D.new()
	_camara.fov = 45
	add_child(_camara)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, 35, 0)
	luz.light_energy = 1.1
	add_child(luz)
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("#8fc6ea")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.6, 0.62, 0.68)
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	add_child(mundo)
	var pasto := PlaneMesh.new()
	pasto.size = Vector2(40, 40)
	var material_pasto := StandardMaterial3D.new()
	material_pasto.albedo_color = Color("#4f8a3a")
	material_pasto.roughness = 1.0
	pasto.material = material_pasto
	var vista_pasto := MeshInstance3D.new()
	vista_pasto.mesh = pasto
	add_child(vista_pasto)
	var capa := CanvasLayer.new()
	_fps = Label.new()
	_fps.position = Vector2(12, 8)
	_fps.add_theme_font_size_override("font_size", 22)
	capa.add_child(_fps)
	add_child(capa)
