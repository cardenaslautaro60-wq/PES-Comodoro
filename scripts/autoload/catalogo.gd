extends Node
## Catálogo de clubes, estadios y planteles.
##
## Lee los archivos JSON de `datos/` (los arma el área D) y los deja a mano para los
## menús y el partido. No hay ningún club escrito en el código: si falta un archivo,
## ese club simplemente no aparece. Los datos se leen la primera vez que se piden.

const CARPETA_POR_DEFECTO := "res://datos"

var carpeta_datos := CARPETA_POR_DEFECTO

var _clubes: Array[Dictionary] = []
var _clubes_por_id := {}
var _estadios: Array[Dictionary] = []
var _estadios_por_id := {}
var _planteles := {}
var _cargado := false


## Vuelve a leer todo. Las pruebas lo usan con una carpeta propia.
func recargar(carpeta := CARPETA_POR_DEFECTO) -> void:
	carpeta_datos = carpeta
	_clubes = _leer_carpeta(carpeta.path_join("clubes"))
	_clubes.sort_custom(_por_nombre)
	_clubes_por_id = _indexar(_clubes)
	_estadios = _leer_carpeta(carpeta.path_join("estadios"))
	_estadios.sort_custom(_por_nombre)
	_estadios_por_id = _indexar(_estadios)
	_planteles.clear()
	_cargado = true


## Todos los clubes, ordenados por nombre.
func clubes() -> Array[Dictionary]:
	_asegurar_carga()
	return _clubes


func club(id: String) -> Dictionary:
	_asegurar_carga()
	return _clubes_por_id.get(id, {})


## Todos los estadios, ordenados por nombre.
func estadios() -> Array[Dictionary]:
	_asegurar_carga()
	return _estadios


func estadio(id: String) -> Dictionary:
	_asegurar_carga()
	return _estadios_por_id.get(id, {})


## Plantel del club, o un diccionario vacío si no tiene.
func plantel(club_id: String) -> Dictionary:
	_asegurar_carga()
	if not _planteles.has(club_id):
		var ruta := carpeta_datos.path_join("planteles/%s.json" % club_id)
		_planteles[club_id] = _leer_json(ruta) if FileAccess.file_exists(ruta) else {}
	return _planteles[club_id]


## Datos de una camiseta ("titular", "suplente" o "arquero") del club.
static func camiseta(datos_club: Dictionary, cual: String) -> Dictionary:
	var camisetas: Dictionary = datos_club.get("camisetas", {})
	return camisetas.get(cual, camisetas.get("titular", {}))


## Lee un color "#RRGGBB" de un diccionario. Si no está o es null, usa `por_defecto`.
static func color(datos: Dictionary, clave: String, por_defecto := Color.WHITE) -> Color:
	var valor = datos.get(clave)
	if valor is String and Color.html_is_valid(valor):
		return Color.html(valor)
	return por_defecto


static func nombre_corto(datos_club: Dictionary) -> String:
	return str(datos_club.get("nombre_corto", datos_club.get("nombre_oficial", "?")))


static func abreviatura(datos_club: Dictionary) -> String:
	var abreviada := str(datos_club.get("abreviatura", ""))
	if abreviada.is_empty():
		abreviada = nombre_corto(datos_club).left(3)
	return abreviada.to_upper()


func _asegurar_carga() -> void:
	if not _cargado:
		recargar(carpeta_datos)


func _leer_carpeta(carpeta: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(carpeta):
		return lista
	for archivo in DirAccess.get_files_at(carpeta):
		if not archivo.ends_with(".json"):
			continue
		var datos := _leer_json(carpeta.path_join(archivo))
		if datos.has("id"):
			lista.append(datos)
		else:
			push_warning("Se salteó %s: no tiene \"id\"" % archivo)
	return lista


func _leer_json(ruta: String) -> Dictionary:
	var texto := FileAccess.get_file_as_string(ruta)
	var datos = JSON.parse_string(texto)
	if datos is Dictionary:
		return datos
	push_warning("No se pudo leer " + ruta)
	return {}


func _indexar(lista: Array[Dictionary]) -> Dictionary:
	var indice := {}
	for datos in lista:
		indice[str(datos["id"])] = datos
	return indice


func _por_nombre(a: Dictionary, b: Dictionary) -> bool:
	var nombre_a := str(a.get("nombre_corto", a.get("nombre", "")))
	var nombre_b := str(b.get("nombre_corto", b.get("nombre", "")))
	return nombre_a.naturalnocasecmp_to(nombre_b) < 0
