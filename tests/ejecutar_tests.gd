extends Node
## Corre todas las pruebas y cierra Godot con código 0 si pasaron o 1 si algo falló.
##
## Uso: godot --headless --path . res://tests/ejecutar_tests.tscn
## Se corre como escena (y no con -s) para que los autoloads, como Controles, estén cargados.

const ARCHIVOS_DE_PRUEBA := [
	"res://tests/test_controles.gd",
	"res://tests/test_pelota.gd",
	"res://tests/test_jugador.gd",
	"res://tests/test_entrenamiento.gd",
	"res://tests/test_cinematicas.gd",
	"res://tests/test_catalogo_y_partido.gd",
	"res://tests/test_opciones_y_sonido.gd",
	"res://tests/test_menus.gd",
	"res://tests/test_partido_completo.gd",
	"res://tests/test_arbitro.gd",
	"res://tests/test_ia.gd",
	"res://tests/test_camisetas.gd",
	"res://tests/test_modelo_jugador.gd",
	"res://tests/test_sensacion.gd",
	"res://tests/test_tiro_libre.gd",
	"res://tests/test_tarjetas.gd",
]
const CARPETAS_CON_SCRIPTS := ["res://scripts"]

var _fallas: Array[String] = []
var _pasaron := 0


func _ready() -> void:
	await get_tree().process_frame
	for carpeta: String in CARPETAS_CON_SCRIPTS:
		_verificar_scripts(carpeta)
	for ruta: String in ARCHIVOS_DE_PRUEBA:
		await _correr_archivo(ruta)

	print("Pruebas que pasaron: %d" % _pasaron)
	if _fallas.is_empty():
		print("OK: todo anduvo bien")
		get_tree().quit(0)
	else:
		for falla in _fallas:
			printerr("FALLÓ: " + falla)
		get_tree().quit(1)


## Comprueba que cada script compile, aunque ninguna prueba lo use.
func _verificar_scripts(carpeta: String) -> void:
	for archivo in DirAccess.get_files_at(carpeta):
		if archivo.ends_with(".gd"):
			var ruta := carpeta.path_join(archivo)
			var script := load(ruta) as GDScript
			if script == null or not script.can_instantiate():
				_fallas.append("el script no compila: " + ruta)
	for subcarpeta in DirAccess.get_directories_at(carpeta):
		_verificar_scripts(carpeta.path_join(subcarpeta))


func _correr_archivo(ruta: String) -> void:
	var script := load(ruta) as GDScript
	if script == null or not script.can_instantiate():
		_fallas.append("no se pudo cargar " + ruta)
		return
	var prueba: Node = script.new()
	add_child(prueba)

	for metodo in prueba.get_method_list():
		var nombre: String = metodo["name"]
		if not nombre.begins_with("test_"):
			continue
		prueba.set("errores", [] as Array[String])
		if prueba.has_method("antes_de_cada"):
			await prueba.call("antes_de_cada")
		await prueba.call(nombre)
		if prueba.has_method("despues_de_cada"):
			await prueba.call("despues_de_cada")

		var errores: Array[String] = prueba.get("errores")
		if errores.is_empty():
			_pasaron += 1
			print("  ok  %s > %s" % [ruta.get_file(), nombre])
		else:
			for error in errores:
				_fallas.append("%s > %s: %s" % [ruta.get_file(), nombre, error])

	prueba.queue_free()
	await get_tree().process_frame
