class_name EquipoPartido
extends RefCounted
## Un equipo en el partido: nombre, colores, los 11 titulares, la formación, hacia
## qué lado ataca y dónde tiene que pararse cada jugador según dónde esté la pelota.
##
## Lee el club y el plantel del `Catalogo` (que sale de `datos/clubes/` y
## `datos/planteles/`) y la formación de `datos/formaciones/`. Si falta el club, arma
## un equipo genérico.
##
## Medidas "de equipo": `progreso` va de 0 (su arco) a 1 (el arco rival) y el ancho
## va de -1 (izquierda, mirando al arco rival) a 1 (derecha).

const CARPETA_FORMACIONES := "res://datos/formaciones/"
const FORMACION_POR_DEFECTO := "4-4-2"
## Grupo de cada puesto de `datos/planteles/`: arquero, defensa, medio o delantero.
const GRUPOS := {
	"ARQ": "ARQ",
	"DFC": "DEF",
	"LAT": "DEF",
	"MC": "MED",
	"MP": "MED",
	"EXT": "MED",
	"DC": "DEL",
}
const COLORES_GENERICOS := [Color(0.80, 0.12, 0.15), Color(0.15, 0.30, 0.80)]
const COLOR_ARQUERO_GENERICO := Color(0.15, 0.62, 0.30)

## 0 = local, 1 = visitante. Es el `equipo` de sus jugadores.
var indice := 0
var club_id := ""
var nombre := "Local"
var abreviatura := "LOC"
var color := Color.RED
var color_suplente := Color.WHITE
var color_arquero := COLOR_ARQUERO_GENERICO
var formacion := FORMACION_POR_DEFECTO
## Los 11 en cancha, en el orden de los puestos de la formación.
var jugadores: Array[Jugador] = []
## Puesto de cada jugador ("ARQ", "DFC", "LAT", "MC", "MP", "EXT" o "DC").
var puestos: Array[String] = []
## Lugar de cada uno en la formación: x de 0 (su arco) a 0,5 (la mitad), y el ancho de -1 a 1.
var lugares: Array[Vector2] = []
## Datos de los 11 titulares, en el mismo orden.
var titulares: Array[Dictionary] = []
## 1 = ataca hacia x positivo, -1 = hacia x negativo.
var sentido := 1
var goles := 0


## Arma el equipo con un club del catálogo. `ids_titulares` (opcional) son los ids
## del plantel que salen a la cancha; si no se pasan, van los marcados como titulares.
## Devuelve false si no encontró el club y armó uno genérico.
func cargar_club(id: String, indice_equipo: int, formacion_elegida := "", ids_titulares: Array = []) -> bool:
	indice = indice_equipo
	sentido = 1 if indice == 0 else -1
	club_id = id
	var club := Catalogo.club(id) if id != "" else {}
	var plantel := Catalogo.plantel(id) if id != "" else {}
	if club.is_empty():
		_armar_generico(formacion_elegida)
		return false
	nombre = str(club.get("nombre_corto", id))
	abreviatura = str(club.get("abreviatura", nombre.left(3))).to_upper()
	var camisetas: Dictionary = club.get("camisetas", {})
	color = _color_de(camisetas.get("titular"), COLORES_GENERICOS[indice])
	color_suplente = _color_de(camisetas.get("suplente"), Color.WHITE)
	color_arquero = _color_de(camisetas.get("arquero"), COLOR_ARQUERO_GENERICO)
	var lista: Array = plantel.get("jugadores", [])
	if formacion_elegida == "":
		formacion_elegida = str(plantel.get("formacion", ""))
	if not ids_titulares.is_empty():
		var elegidos: Array = []
		for id_jugador: Variant in ids_titulares:
			for datos: Dictionary in lista:
				if str(datos.get("id")) == str(id_jugador):
					elegidos.append(datos)
		lista = elegidos
	_aplicar_formacion_y_titulares(formacion_elegida, lista)
	return true


## Mete a un jugador del banco en lugar del que está en el puesto `i` (mismo nodo,
## datos nuevos y descansado).
func reemplazar(i: int, datos: Dictionary) -> void:
	titulares[i] = datos
	var jugador := jugadores[i]
	jugador.aplicar_datos(datos)
	jugador.estamina_actual = 1.0


## Cambia la formación. Los mismos 11 se reparten en los puestos nuevos.
func cambiar_formacion(nombre_formacion: String) -> void:
	var antes := jugadores.duplicate()
	var datos_antes := titulares.duplicate()
	_aplicar_formacion_y_titulares(nombre_formacion, datos_antes)
	if antes.is_empty():
		return
	var nuevos: Array[Jugador] = []
	for datos: Dictionary in titulares:
		nuevos.append(antes[datos_antes.find(datos)])
	jugadores = nuevos


## Las formaciones que hay en `datos/formaciones/`.
static func formaciones_disponibles() -> Array[String]:
	var nombres: Array[String] = []
	for archivo in DirAccess.get_files_at(CARPETA_FORMACIONES):
		if archivo.ends_with(".json"):
			nombres.append(archivo.get_basename())
	nombres.sort()
	return nombres


## Los puestos de una formación: [{rol, x, z}, ...]. Vacío si no existe.
static func leer_formacion(nombre_formacion: String) -> Array:
	var datos: Variant = leer_json(CARPETA_FORMACIONES + nombre_formacion + ".json")
	if datos is Dictionary and datos.get("puestos") is Array and datos["puestos"].size() == 11:
		return datos["puestos"]
	return []


static func leer_json(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(ruta))


# --- Posiciones -----------------------------------------------------------------


## Pasa una posición "de equipo" a la cancha.
func a_mundo(progreso_equipo: float, ancho: float) -> Vector3:
	return Vector3(sentido * (progreso_equipo - 0.5) * Cancha.LARGO, 0, sentido * ancho * Cancha.ANCHO / 2)


## Qué tan adelante está un punto, para este equipo: 0 en su arco, 1 en el arco rival.
func progreso(punto: Vector3) -> float:
	return (punto.x * sentido + Cancha.LARGO / 2) / Cancha.LARGO


## Centro de la línea de su propio arco.
func arco_propio() -> Vector3:
	return Cancha.centro_del_arco(-sentido)


func arco_rival() -> Vector3:
	return Cancha.centro_del_arco(sentido)


func grupo(i: int) -> String:
	return GRUPOS.get(puestos[i], "MED")


func grupo_de(jugador: Jugador) -> String:
	var i := jugadores.find(jugador)
	return grupo(i) if i >= 0 else ""


func arquero() -> Jugador:
	var i := puestos.find("ARQ")
	return jugadores[i] if i >= 0 else null


## True si el punto está dentro del área grande de su propio arco.
func en_area_propia(punto: Vector3) -> bool:
	var fondo := Cancha.FONDO_AREA_GRANDE / Cancha.LARGO
	return progreso(punto) < fondo and absf(punto.z) < Cancha.ANCHO_AREA_GRANDE / 2


## Dónde se para en la salida del medio: su lugar de la formación, en su mitad.
func posicion_inicial(i: int) -> Vector3:
	var lugar := lugares[i]
	return a_mundo(minf(lugar.x, 0.47), lugar.y)


## Dónde tiene que estar el jugador `i` según dónde está la pelota. Atacando, el
## equipo se adelanta y se abre; defendiendo, se junta y los defensores quedan
## entre la pelota y el arco.
func posicion_tactica(i: int, pelota: Vector3, atacando: bool) -> Vector3:
	var lugar := lugares[i]
	if puestos[i] == "ARQ":
		return a_mundo(0.02, 0)
	var p := clampf(progreso(pelota), 0.0, 1.0)
	var adelante: float
	var ancho: float
	if atacando:
		adelante = lugar.x + (p - 0.3) * 0.75 + 0.05
		ancho = lugar.y * 0.95
	else:
		adelante = lugar.x + 0.08 + (p - 0.5) * 0.6
		ancho = lugar.y * 0.75
		if grupo(i) == "DEF":
			adelante = minf(adelante, maxf(p - 0.03, 0.06))
	adelante = clampf(adelante, 0.06, 0.9)
	# Todo el equipo se corre un poco hacia el lado de la pelota.
	var hacia_pelota := clampf(pelota.z / (Cancha.ANCHO / 2), -1.0, 1.0) * sentido
	ancho = clampf(ancho + hacia_pelota * (0.2 if atacando else 0.32), -0.95, 0.95)
	return a_mundo(adelante, ancho)


# --- Armado -------------------------------------------------------------------


func _aplicar_formacion_y_titulares(nombre_formacion: String, lista: Array) -> void:
	var puestos_formacion := leer_formacion(nombre_formacion)
	if puestos_formacion.is_empty():
		nombre_formacion = FORMACION_POR_DEFECTO
		puestos_formacion = leer_formacion(nombre_formacion)
	formacion = nombre_formacion
	puestos.clear()
	lugares.clear()
	for puesto: Dictionary in puestos_formacion:
		puestos.append(str(puesto.get("rol", "MC")))
		lugares.append(Vector2(float(puesto.get("x", 0.3)), float(puesto.get("z", 0.0))))
	titulares = _elegir_titulares(lista)


## Reparte los jugadores del plantel en los puestos: primero el mismo puesto, después
## el mismo grupo (defensa, medio...), después cualquiera. Los titulares van primero.
func _elegir_titulares(lista: Array) -> Array[Dictionary]:
	var candidatos: Array[Dictionary] = []
	for datos: Variant in lista:
		if datos is Dictionary and datos.get("titular", true):
			candidatos.append(datos)
	for datos: Variant in lista:
		if datos is Dictionary and not datos.get("titular", true):
			candidatos.append(datos)
	var elegidos: Array[Dictionary] = []
	elegidos.resize(11)
	var usados := {}
	var reglas := [
		func(d: Dictionary, p: String) -> bool: return d.get("posicion") == p,
		func(d: Dictionary, p: String) -> bool: return GRUPOS.get(d.get("posicion"), "") == GRUPOS.get(p, "-"),
		func(d: Dictionary, p: String) -> bool: return (d.get("posicion") == "ARQ") == (p == "ARQ"),
	]
	for regla: Callable in reglas:
		for i in 11:
			if not elegidos[i].is_empty():
				continue
			for k in candidatos.size():
				if not usados.has(k) and regla.call(candidatos[k], puestos[i]):
					elegidos[i] = candidatos[k]
					usados[k] = true
					break
	for i in 11:
		if elegidos[i].is_empty():
			elegidos[i] = _jugador_generico(i)
	return elegidos


func _armar_generico(formacion_elegida: String) -> void:
	nombre = "Local" if indice == 0 else "Visitante"
	abreviatura = "LOC" if indice == 0 else "VIS"
	color = COLORES_GENERICOS[indice]
	color_suplente = Color.WHITE
	color_arquero = COLOR_ARQUERO_GENERICO
	_aplicar_formacion_y_titulares(formacion_elegida, [])


func _jugador_generico(i: int) -> Dictionary:
	var dorsal := i + 1
	return {
		"nombre": "%s %d" % [abreviatura, dorsal],
		"dorsal": dorsal,
		"posicion": puestos[i],
		"atributos": {"velocidad": 65, "pase": 65, "tiro": 65, "defensa": 65, "estamina": 70, "atajada": 65},
	}


static func _color_de(camiseta: Variant, por_defecto: Color) -> Color:
	if camiseta is Dictionary and camiseta.get("color_base") is String:
		return Color.from_string(camiseta["color_base"], por_defecto)
	return por_defecto
