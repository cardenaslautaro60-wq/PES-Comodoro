class_name ModeloJugador
extends Node3D
## Modelo 3D low poly de un futbolista, armado por código y con esqueleto.
##
## Es el modelo provisorio hasta tener el de Blender: ya respeta la distribución
## de la camiseta (docs/arte/estilo-arte-3d.md, sección 5), así que se viste con
## el material de GeneradorCamiseta, y cambia piel, pelo y botines según la
## `apariencia` de los planteles. Mira hacia -Z, como `Basis.looking_at`.
##
## Uso:
##     var modelo := ModeloJugador.new()
##     modelo.name = "Modelo"
##     jugador.add_child(modelo)
##     modelo.vestir(material_equipo, 10, {"piel": 2, "pelo": 1, "color_pelo": 0, "barba": false})
##
## Si el padre es un CharacterBody3D, el modelo toma solo su velocidad para
## trotar o correr. Si además tiene la señal `pateo` y la variable `estado`
## (como `Jugador`), patea, barre y se cae solo.

enum Hueso {
	CADERA, TORSO, CABEZA, BRAZO_D, ANTEBRAZO_D, BRAZO_I, ANTEBRAZO_I, MUSLO_D, PIERNA_D, MUSLO_I, PIERNA_I,
}

const NOMBRES_HUESOS := [
	"cadera", "torso", "cabeza", "brazo_d", "antebrazo_d", "brazo_i", "antebrazo_i",
	"muslo_d", "pierna_d", "muslo_i", "pierna_i",
]
const PADRES := [-1, 0, 1, 1, 3, 1, 5, 0, 7, 0, 9]
## Posición de cada hueso con el jugador parado (en metros, desde los pies).
## La derecha del jugador es +X porque mira hacia -Z.
const POSICIONES := [
	Vector3(0, 0.95, 0), Vector3(0, 1.05, 0), Vector3(0, 1.55, 0),
	Vector3(0.235, 1.43, 0), Vector3(0.25, 1.16, 0), Vector3(-0.235, 1.43, 0), Vector3(-0.25, 1.16, 0),
	Vector3(0.095, 0.9, 0), Vector3(0.095, 0.5, 0), Vector3(-0.095, 0.9, 0), Vector3(-0.095, 0.5, 0),
]

const COLORES_PIEL := [Color("#f0c8a4"), Color("#d49c72"), Color("#a5693f"), Color("#663e26")]
const COLORES_PELO := [Color("#17120f"), Color("#4a2e1d"), Color("#8a6038"), Color("#d6b26a")]
const COLORES_BOTINES := [Color("#111111"), Color("#f2f2f2"), Color("#e8421c"), Color("#1f6fe0")]
## 0 rapado, 1 corto, 2 rulos, 3 atado, 4 pelado, 5 largo.
const ESTILOS_PELO := 6

const MATERIAL_CUERPO := preload("res://arte/modelos/jugador/cuerpo.gdshader")

# Colores de vértice que lee cuerpo.gdshader.
const _PIEL := Color(1, 0, 0)
const _PELO := Color(0, 1, 0)
const _BOTIN := Color(0, 0, 1)
const _OSCURO := Color(0, 0, 0)
const _TEX := 512.0

## Velocidad (m/s) a la que el trote pasa a carrera completa.
const VELOCIDAD_CARRERA := 7.0
const DURACION_PATADA := 0.45

# Mallas y material compartidos. Se guardan como WeakRef para que se liberen
# solos cuando ya no queda ningún jugador que los use.
static var _mallas := {}
static var _material_cuerpo: WeakRef

## Velocidad horizontal en m/s. Si el padre es un CharacterBody3D se toma sola.
var velocidad := 0.0
var esqueleto: Skeleton3D
var malla: MeshInstance3D

var _fase := 0.0
var _tiempo_patada := -1.0
var _accion := ""
var _tiempo_accion := 0.0
var _estados_padre := {}


func _init() -> void:
	esqueleto = Skeleton3D.new()
	esqueleto.name = "Esqueleto"
	for i in NOMBRES_HUESOS.size():
		esqueleto.add_bone(NOMBRES_HUESOS[i])
		var padre: int = PADRES[i]
		if padre >= 0:
			esqueleto.set_bone_parent(i, padre)
		var local: Vector3 = POSICIONES[i] - (POSICIONES[padre] if padre >= 0 else Vector3.ZERO)
		esqueleto.set_bone_rest(i, Transform3D(Basis.IDENTITY, local))
		esqueleto.set_bone_pose_position(i, local)
	add_child(esqueleto)
	malla = MeshInstance3D.new()
	malla.name = "Malla"
	esqueleto.add_child(malla)
	malla.skeleton = NodePath("..")
	_poner_malla(1, false)
	malla.set_surface_override_material(1, _material_del_cuerpo())
	aplicar_apariencia({})


func _ready() -> void:
	var padre := get_parent()
	if padre and padre.has_signal("pateo"):
		padre.connect("pateo", func(_tipo: Variant, _potencia: float) -> void: patear())
	if padre and padre.get_script():
		var constantes: Dictionary = (padre.get_script() as Script).get_script_constant_map()
		if constantes.get("Estado") is Dictionary:
			_estados_padre = constantes["Estado"]


## Pone la camiseta del equipo, el número y la apariencia del jugador.
func vestir(material_equipo: Material, numero: int, apariencia: Dictionary = {}) -> void:
	malla.set_surface_override_material(0, material_equipo)
	malla.set_instance_shader_parameter("numero", numero)
	aplicar_apariencia(apariencia)


## `apariencia` como en los planteles: piel 0-3, pelo 0-5, color_pelo 0-3,
## barba (true/false o 0/1) y botines 0-3 (opcional).
func aplicar_apariencia(apariencia: Dictionary) -> void:
	var piel := clampi(int(apariencia.get("piel", 1)), 0, COLORES_PIEL.size() - 1)
	var pelo := clampi(int(apariencia.get("pelo", 1)), 0, ESTILOS_PELO - 1)
	var color_pelo := clampi(int(apariencia.get("color_pelo", 0)), 0, COLORES_PELO.size() - 1)
	var botines := clampi(int(apariencia.get("botines", 0)), 0, COLORES_BOTINES.size() - 1)
	var barba := bool(apariencia.get("barba", false))
	_poner_malla(pelo, barba)
	malla.set_instance_shader_parameter("color_piel", COLORES_PIEL[piel])
	malla.set_instance_shader_parameter("color_pelo", COLORES_PELO[color_pelo])
	malla.set_instance_shader_parameter("color_botines", COLORES_BOTINES[botines])


func patear() -> void:
	_tiempo_patada = 0.0


## "barrida", "caido" o "" para volver a la animación normal.
func hacer(accion: String) -> void:
	if accion != _accion:
		_accion = accion
		_tiempo_accion = 0.0


func _process(delta: float) -> void:
	var padre := get_parent()
	if padre is CharacterBody3D:
		var v := (padre as CharacterBody3D).velocity
		velocidad = Vector2(v.x, v.z).length()
		if not _estados_padre.is_empty():
			var estado: int = padre.get("estado")
			if estado == _estados_padre.get("BARRIDA", -1):
				hacer("barrida")
			elif estado == _estados_padre.get("CAIDO", -1):
				hacer("caido")
			else:
				hacer("")
	animar(delta)


## Avanza la animación. Se llama sola en `_process`; las pruebas la llaman a mano.
func animar(delta: float) -> void:
	_tiempo_accion += delta
	var ritmo := clampf(velocidad / VELOCIDAD_CARRERA, 0.0, 1.0)
	# Pasos por segundo: de 1,6 trotando despacio a 2,8 a fondo.
	_fase = fmod(_fase + delta * TAU * lerpf(1.6, 2.8, ritmo) * (1.0 if velocidad > 0.2 else 0.0), TAU)
	var pose := _pose_carrera(ritmo)
	if _tiempo_patada >= 0.0:
		_tiempo_patada += delta
		if _tiempo_patada > DURACION_PATADA:
			_tiempo_patada = -1.0
		else:
			_mezclar_patada(pose, _tiempo_patada / DURACION_PATADA)
	if _accion == "barrida":
		pose = _pose_barrida()
	elif _accion == "caido":
		pose = _pose_caido(minf(_tiempo_accion / 0.25, 1.0))
	_aplicar(pose)


# --- Poses -------------------------------------------------------------------
# Una pose es un diccionario hueso -> Vector3 con ángulos (x, y, z) en radianes.
# El ángulo x positivo lleva la pierna o el brazo hacia adelante (-Z).


func _pose_carrera(ritmo: float) -> Dictionary:
	var s := sin(_fase)
	var c := cos(_fase)
	var amplitud := lerpf(0.05, 0.75, ritmo) if velocidad > 0.2 else 0.0
	var pose := {
		Hueso.CADERA: Vector3(0, 0, 0),
		Hueso.TORSO: Vector3(lerpf(0.02, 0.2, ritmo) if velocidad > 0.2 else 0.02, 0.1 * s * amplitud, 0),
		Hueso.CABEZA: Vector3(-0.5 * lerpf(0.02, 0.2, ritmo), 0, 0),
		Hueso.MUSLO_D: Vector3(s * amplitud, 0, 0),
		Hueso.MUSLO_I: Vector3(-s * amplitud, 0, 0),
		# La rodilla se dobla cuando la pierna vuelve hacia adelante.
		Hueso.PIERNA_D: Vector3(-maxf(0.0, -c) * amplitud * 1.6 - 0.05, 0, 0),
		Hueso.PIERNA_I: Vector3(-maxf(0.0, c) * amplitud * 1.6 - 0.05, 0, 0),
		Hueso.BRAZO_D: Vector3(-s * amplitud * 0.8, 0, 0.12),
		Hueso.BRAZO_I: Vector3(s * amplitud * 0.8, 0, -0.12),
		Hueso.ANTEBRAZO_D: Vector3(lerpf(0.15, 0.95, ritmo), 0, 0),
		Hueso.ANTEBRAZO_I: Vector3(lerpf(0.15, 0.95, ritmo), 0, 0),
	}
	# Rebote al pisar y respiración cuando está quieto.
	var altura := -absf(s) * 0.035 * ritmo if velocidad > 0.2 else 0.006 * sin(Time.get_ticks_msec() * 0.003)
	pose["altura"] = altura
	return pose


func _mezclar_patada(pose: Dictionary, t: float) -> void:
	# Lleva la pierna derecha atrás y la descarga hacia adelante.
	var atras := -0.9
	var adelante := 1.3
	var muslo := lerpf(0.0, atras, t / 0.4) if t < 0.4 else lerpf(atras, adelante, (t - 0.4) / 0.35)
	if t > 0.75:
		muslo = lerpf(adelante, 0.0, (t - 0.75) / 0.25)
	var rodilla := -1.4 if t < 0.4 else lerpf(-1.4, 0.0, clampf((t - 0.4) / 0.2, 0.0, 1.0))
	pose[Hueso.MUSLO_D] = Vector3(muslo, 0, 0)
	pose[Hueso.PIERNA_D] = Vector3(rodilla, 0, 0)
	pose[Hueso.MUSLO_I] = Vector3(-0.15, 0, 0)
	pose[Hueso.PIERNA_I] = Vector3(-0.2, 0, 0)
	pose[Hueso.BRAZO_I] = Vector3(0.5, 0, -0.6)
	pose[Hueso.BRAZO_D] = Vector3(-0.4, 0, 0.5)
	pose[Hueso.TORSO] = Vector3(-0.1 if t > 0.4 else 0.1, 0, 0)


func _pose_barrida() -> Dictionary:
	# Acostado de costado, con la pierna derecha estirada adelante.
	return {
		"altura": -0.62,
		Hueso.CADERA: Vector3(-1.1, 0, 0.35),
		Hueso.TORSO: Vector3(0.3, 0, 0),
		Hueso.CABEZA: Vector3(0.5, 0, 0),
		Hueso.MUSLO_D: Vector3(2.0, 0, 0),
		Hueso.PIERNA_D: Vector3(0, 0, 0),
		Hueso.MUSLO_I: Vector3(1.4, 0, 0),
		Hueso.PIERNA_I: Vector3(-1.4, 0, 0),
		Hueso.BRAZO_D: Vector3(1.0, 0, 0.9),
		Hueso.BRAZO_I: Vector3(-0.4, 0, -1.2),
		Hueso.ANTEBRAZO_D: Vector3(0.3, 0, 0),
		Hueso.ANTEBRAZO_I: Vector3(0.3, 0, 0),
	}


func _pose_caido(t: float) -> Dictionary:
	# Cae de espaldas; t va de 0 (parado) a 1 (en el piso).
	return {
		"altura": lerpf(0.0, -0.8, t),
		Hueso.CADERA: Vector3(lerpf(0.0, -1.45, t), 0, 0),
		Hueso.TORSO: Vector3(0.1 * t, 0, 0),
		Hueso.CABEZA: Vector3(0.2 * t, 0, 0),
		Hueso.MUSLO_D: Vector3(1.3 * t, 0, 0.1),
		Hueso.PIERNA_D: Vector3(-0.8 * t, 0, 0),
		Hueso.MUSLO_I: Vector3(1.6 * t, 0, -0.1),
		Hueso.PIERNA_I: Vector3(-0.3 * t, 0, 0),
		Hueso.BRAZO_D: Vector3(0, 0, 1.2 * t),
		Hueso.BRAZO_I: Vector3(0, 0, -1.2 * t),
		Hueso.ANTEBRAZO_D: Vector3(0.2, 0, 0),
		Hueso.ANTEBRAZO_I: Vector3(0.2, 0, 0),
	}


func _aplicar(pose: Dictionary) -> void:
	for i in NOMBRES_HUESOS.size():
		var angulos: Vector3 = pose.get(i, Vector3.ZERO)
		esqueleto.set_bone_pose_rotation(i, Quaternion.from_euler(angulos))
	var cadera: Vector3 = POSICIONES[Hueso.CADERA]
	esqueleto.set_bone_pose_position(Hueso.CADERA, cadera + Vector3(0, float(pose.get("altura", 0.0)), 0))


# --- Malla -------------------------------------------------------------------


func _poner_malla(pelo: int, barba: bool) -> void:
	var clave := "%d_%d" % [pelo, int(barba)]
	var compartida: ArrayMesh = _mallas[clave].get_ref() if _mallas.has(clave) else null
	if compartida == null:
		compartida = construir_malla(pelo, barba)
		_mallas[clave] = weakref(compartida)
	if malla.mesh != compartida:
		malla.mesh = compartida


static func _material_del_cuerpo() -> ShaderMaterial:
	var material: ShaderMaterial = _material_cuerpo.get_ref() if _material_cuerpo else null
	if material == null:
		material = ShaderMaterial.new()
		material.shader = MATERIAL_CUERPO
		_material_cuerpo = weakref(material)
	return material


## Arma la malla con dos superficies: 0 = equipo (UV de la camiseta) y
## 1 = cuerpo (colores de vértice). Es pública para las pruebas.
static func construir_malla(pelo: int, barba: bool) -> ArrayMesh:
	var equipo := SurfaceTool.new()
	equipo.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cuerpo := SurfaceTool.new()
	cuerpo.begin(Mesh.PRIMITIVE_TRIANGLES)

	_armar_torso(equipo, cuerpo)
	_armar_cabeza(cuerpo, pelo, barba)
	for lado in [1.0, -1.0]:
		_armar_brazo(equipo, cuerpo, lado)
		_armar_pierna(equipo, cuerpo, lado)

	var resultado := ArrayMesh.new()
	equipo.commit(resultado)
	cuerpo.commit(resultado)
	return resultado


static func _armar_torso(equipo: SurfaceTool, cuerpo: SurfaceTool) -> void:
	# Anillos: [y, radio x, radio z]. De los hombros a la cintura.
	var arriba := 1.49
	var abajo := 0.93
	var anillos := [
		[arriba, 0.11, 0.075], [1.455, 0.2, 0.1], [1.38, 0.205, 0.115], [1.25, 0.185, 0.115],
		[1.1, 0.165, 0.105], [abajo, 0.165, 0.105],
	]
	var uv_torso := func(_frac: float, x: float, de_frente: bool, y: float) -> Vector2:
		var v := (arriba - y) / (arriba - abajo)
		if de_frente:
			return Vector2((1.0 - x) * 0.5 * 256.0, v * 256.0) / _TEX
		return Vector2(256.0 + (1.0 + x) * 0.5 * 256.0, v * 256.0) / _TEX
	_prisma(equipo, _anillos(anillos, 0, 0), 12, 0.0, Hueso.TORSO, uv_torso, Color.WHITE, false, false)
	# Cuello de la camiseta (color de detalle) y cuello del jugador.
	var uv_cuello := func(frac: float, _x: float, _f: bool, _y: float) -> Vector2:
		return Vector2(frac * 256.0, 366.0) / _TEX
	var cuello := [[1.5, 0.075, 0.062], [1.475, 0.105, 0.075]]
	_prisma(equipo, _anillos(cuello, 0, 0), 10, 0.0, Hueso.TORSO, uv_cuello, Color.WHITE, true, false)
	var cogote := [[1.6, 0.052, 0.052], [1.48, 0.058, 0.058]]
	_prisma(cuerpo, _anillos(cogote, 0, 0.005), 8, 0.0, Hueso.TORSO, Callable(), _PIEL, false, false)
	# Short: cadera.
	var uv_short := func(frac: float, _x: float, _f: bool, y: float) -> Vector2:
		return Vector2(266.0 + frac * 236.0, 260.0 + (1.0 - y) * 0.0) / _TEX
	var cadera := [[1.0, 0.17, 0.11], [0.86, 0.18, 0.115]]
	_prisma(equipo, _anillos(cadera, 0, 0), 12, 0.0, Hueso.CADERA, uv_short, Color.WHITE, false, true)


static func _armar_cabeza(cuerpo: SurfaceTool, pelo: int, barba: bool) -> void:
	var centro := 1.68
	var radio := 0.112
	var anillos := []
	for i in 7:
		var angulo := PI * i / 6.0
		var r := maxf(sin(angulo), 0.08) * radio
		anillos.append([centro + cos(angulo) * radio * 1.15, r * 0.92, r])
	var color_cabeza := func(de_frente: bool, y: float) -> Color:
		if barba and de_frente and y < centro - 0.035:
			return _PELO
		return _PIEL
	_prisma(cuerpo, _anillos(anillos, 0, 0), 10, 0.0, Hueso.CABEZA, Callable(), color_cabeza, true, true)
	# Nariz y ojos: chiquitos, sirven para ver hacia dónde mira.
	_caja(cuerpo, Vector3(0, centro - 0.015, -radio - 0.012), Vector3(0.022, 0.035, 0.03), Hueso.CABEZA, _PIEL)
	for lado in [1.0, -1.0]:
		_caja(cuerpo, Vector3(0.04 * lado, centro + 0.02, -radio * 0.93), Vector3(0.02, 0.014, 0.01), Hueso.CABEZA, _OSCURO)
		# Orejas.
		_caja(cuerpo, Vector3(radio * 0.9 * lado, centro, 0.0), Vector3(0.02, 0.045, 0.03), Hueso.CABEZA, _PIEL)
	if pelo == 4:
		return
	# Casco de pelo: más grande o más chico según el estilo.
	var escala: float = [1.04, 1.1, 1.2, 1.1, 1.0, 1.12][pelo]
	var hasta: float = [0.5, 0.58, 0.62, 0.58, 0.0, 0.62][pelo]
	var casco := []
	for i in 5:
		var angulo := PI * hasta * i / 4.0
		var r := maxf(sin(angulo), 0.1) * radio * escala
		casco.append([centro + 0.012 + cos(angulo) * radio * 1.15 * escala, r * 0.95, r])
	_prisma(cuerpo, _anillos(casco, 0, 0.012), 10, 0.0, Hueso.CABEZA, Callable(), _PELO, true, false)
	if pelo == 2:
		# Rulos: unos bollos encima.
		for i in 6:
			var a := TAU * i / 6.0
			var punto := Vector3(sin(a) * 0.07, centro + 0.1, cos(a) * 0.07 + 0.01)
			_caja(cuerpo, punto, Vector3.ONE * 0.065, Hueso.CABEZA, _PELO)
	elif pelo == 3:
		# Atado: rodete atrás.
		_caja(cuerpo, Vector3(0, centro + 0.03, radio + 0.035), Vector3(0.07, 0.07, 0.06), Hueso.CABEZA, _PELO)
	elif pelo == 5:
		# Largo: cae por la nuca.
		_caja(cuerpo, Vector3(0, centro - 0.07, radio * 0.75), Vector3(0.19, 0.16, 0.05), Hueso.CABEZA, _PELO)


static func _armar_brazo(equipo: SurfaceTool, cuerpo: SurfaceTool, lado: float) -> void:
	var brazo := Hueso.BRAZO_D if lado > 0 else Hueso.BRAZO_I
	var antebrazo := Hueso.ANTEBRAZO_D if lado > 0 else Hueso.ANTEBRAZO_I
	var x := 0.235 * lado
	# Manga derecha en la mitad izquierda de la zona de mangas, como dice la guía.
	var u0 := 0.0 if lado > 0 else 128.0
	var arriba := 1.48
	var abajo := 1.27
	var uv_manga := func(frac: float, _x: float, _f: bool, y: float) -> Vector2:
		return Vector2(u0 + frac * 128.0, 256.0 + (arriba - y) / (arriba - abajo) * 92.0) / _TEX
	var manga := [[arriba, 0.06, 0.07], [1.4, 0.078, 0.078], [abajo, 0.07, 0.07]]
	_prisma(equipo, _anillos(manga, x, 0), 8, 0.0, brazo, uv_manga, Color.WHITE, true, false)
	var uv_puno := func(frac: float, _x: float, _f: bool, _y: float) -> Vector2:
		return Vector2(u0 + frac * 128.0, 368.0) / _TEX
	var puno := [[abajo, 0.071, 0.071], [1.245, 0.068, 0.068]]
	_prisma(equipo, _anillos(puno, x, 0), 8, 0.0, brazo, uv_puno, Color.WHITE, false, true)
	var piel_brazo := [[1.27, 0.05, 0.05], [1.16, 0.045, 0.045]]
	_prisma(cuerpo, _anillos(piel_brazo, x + 0.008 * lado, 0), 8, 0.0, brazo, Callable(), _PIEL, false, false)
	var piel_antebrazo := [[1.17, 0.045, 0.045], [0.97, 0.036, 0.036], [0.95, 0.04, 0.03], [0.86, 0.034, 0.02]]
	_prisma(cuerpo, _anillos(piel_antebrazo, x + 0.015 * lado, 0), 8, 0.0, antebrazo, Callable(), _PIEL, false, true)


static func _armar_pierna(equipo: SurfaceTool, cuerpo: SurfaceTool, lado: float) -> void:
	var muslo := Hueso.MUSLO_D if lado > 0 else Hueso.MUSLO_I
	var pierna := Hueso.PIERNA_D if lado > 0 else Hueso.PIERNA_I
	var x := 0.095 * lado
	# Short: pierna derecha en la mitad izquierda de la zona del short. El
	# lado de afuera de cada pierna cae en el borde, donde van los vivos.
	var u0 := 256.0 if lado > 0 else 384.0
	var inicio := PI * 0.5 if lado > 0 else -PI * 0.5
	var uv_short := func(frac: float, _x: float, _f: bool, y: float) -> Vector2:
		return Vector2(u0 + frac * 128.0, 256.0 + (0.9 - y) / 0.24 * 128.0) / _TEX
	var short := [[0.9, 0.095, 0.1], [0.78, 0.1, 0.1], [0.66, 0.095, 0.095]]
	_prisma(equipo, _anillos(short, x, 0), 10, inicio, muslo, uv_short, Color.WHITE, false, true)
	var piel_muslo := [[0.67, 0.078, 0.08], [0.52, 0.062, 0.065]]
	_prisma(cuerpo, _anillos(piel_muslo, x, 0), 8, 0.0, muslo, Callable(), _PIEL, false, false)
	var piel_rodilla := [[0.53, 0.062, 0.065], [0.47, 0.058, 0.06]]
	_prisma(cuerpo, _anillos(piel_rodilla, x, 0), 8, 0.0, pierna, Callable(), _PIEL, false, false)
	# Medias: derecha en la mitad izquierda de la zona de medias.
	var u_medias := 0.0 if lado > 0 else 128.0
	var uv_medias := func(frac: float, _x: float, _f: bool, y: float) -> Vector2:
		return Vector2(u_medias + frac * 128.0, 384.0 + (0.48 - y) / 0.4 * 128.0) / _TEX
	var medias := [
		[0.48, 0.06, 0.062], [0.46, 0.06, 0.062], [0.4, 0.056, 0.064], [0.25, 0.048, 0.052], [0.08, 0.036, 0.04],
	]
	_prisma(equipo, _anillos(medias, x, 0.005), 8, 0.0, pierna, uv_medias, Color.WHITE, false, false)
	# Botín: más largo hacia adelante.
	var botin := [
		[0.1, 0.042, 0.048, x, 0.0], [0.06, 0.05, 0.09, x, -0.035], [0.0, 0.05, 0.1, x, -0.04],
	]
	_prisma(cuerpo, botin, 8, 0.0, pierna, Callable(), _BOTIN, false, true)


## Pasa anillos [y, rx, rz] a [y, rx, rz, cx, cz] con un mismo centro.
static func _anillos(lista: Array, cx: float, cz: float) -> Array:
	var resultado := []
	for a: Array in lista:
		resultado.append([a[0], a[1], a[2], cx, cz])
	return resultado


## Un tubo de `lados` caras que une los anillos [y, rx, rz, cx, cz], de arriba
## hacia abajo. `uv` recibe (fracción de la vuelta, x de -1 a 1, si la cara mira
## adelante, y) y devuelve el UV. `color` es un Color o un Callable(de_frente, y).
static func _prisma(
		st: SurfaceTool, anillos: Array, lados: int, inicio: float, hueso: int,
		uv: Callable, color: Variant, tapa_arriba: bool, tapa_abajo: bool
) -> void:
	for k in anillos.size() - 1:
		var a: Array = anillos[k]
		var b: Array = anillos[k + 1]
		for j in lados:
			var a0 := inicio + TAU * j / lados
			var a1 := inicio + TAU * (j + 1) / lados
			var de_frente := cos((a0 + a1) * 0.5) > 0.0
			var c := _color_cara(color, de_frente, (a[0] + b[0]) * 0.5)
			var esquinas := [[a, a0, float(j) / lados], [a, a1, float(j + 1) / lados],
					[b, a1, float(j + 1) / lados], [b, a0, float(j) / lados]]
			var puntos := []
			for e: Array in esquinas:
				puntos.append(_vertice(e[0], e[1], e[2], de_frente, uv))
			# Dos triángulos por cara (en sentido horario visto desde afuera).
			for indice in [0, 2, 1, 0, 3, 2]:
				_emitir(st, puntos[indice], hueso, c)
	if tapa_arriba:
		_tapa(st, anillos[0], lados, inicio, hueso, uv, color, true)
	if tapa_abajo:
		_tapa(st, anillos[anillos.size() - 1], lados, inicio, hueso, uv, color, false)


static func _tapa(
		st: SurfaceTool, anillo: Array, lados: int, inicio: float, hueso: int,
		uv: Callable, color: Variant, arriba: bool
) -> void:
	var centro := Vector3(anillo[3], anillo[0], anillo[4])
	var normal := Vector3.UP if arriba else Vector3.DOWN
	for j in lados:
		var a0 := inicio + TAU * j / lados
		var a1 := inicio + TAU * (j + 1) / lados
		var de_frente := cos((a0 + a1) * 0.5) > 0.0
		var c := _color_cara(color, de_frente, anillo[0])
		var p0 := _vertice(anillo, a0, float(j) / lados, de_frente, uv)
		var p1 := _vertice(anillo, a1, float(j + 1) / lados, de_frente, uv)
		var pc := [centro, normal, p0[2]]
		p0[1] = normal
		p1[1] = normal
		var orden := [pc, p0, p1] if arriba else [pc, p1, p0]
		for p: Array in orden:
			_emitir(st, p, hueso, c)


static func _vertice(anillo: Array, angulo: float, frac: float, de_frente: bool, uv: Callable) -> Array:
	var sx := sin(angulo)
	var cz := cos(angulo)
	# El ángulo 0 mira hacia adelante (-Z) y PI/2 hacia la derecha (+X).
	var posicion := Vector3(anillo[3] + anillo[1] * sx, anillo[0], anillo[4] - anillo[2] * cz)
	var normal := Vector3(sx / anillo[1], 0, -cz / anillo[2]).normalized()
	var coordenada: Vector2 = uv.call(frac, sx, de_frente, anillo[0]) if uv.is_valid() else Vector2.ZERO
	return [posicion, normal, coordenada]


static func _emitir(st: SurfaceTool, punto: Array, hueso: int, color: Color) -> void:
	st.set_normal(punto[1])
	st.set_uv(punto[2])
	st.set_color(color)
	st.set_bones(PackedInt32Array([hueso, 0, 0, 0]))
	st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	st.add_vertex(punto[0])


static func _color_cara(color: Variant, de_frente: bool, y: float) -> Color:
	if color is Callable:
		return (color as Callable).call(de_frente, y)
	return color


## Una caja chica (orejas, nariz, rulos), en el color dado.
static func _caja(st: SurfaceTool, centro: Vector3, tamano: Vector3, hueso: int, color: Color) -> void:
	var m := tamano * 0.5
	var y0 := centro.y - m.y
	var y1 := centro.y + m.y
	var anillos := [[y1, m.x, m.z, centro.x, centro.z], [y0, m.x, m.z, centro.x, centro.z]]
	_prisma(st, anillos, 4, PI * 0.25, hueso, Callable(), color, true, true)
