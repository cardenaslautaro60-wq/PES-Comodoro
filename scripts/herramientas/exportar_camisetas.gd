extends SceneTree
## Genera las texturas de camisetas de un archivo y las guarda como PNG para
## revisarlas sin abrir el juego. Acepta un archivo de club (usa su campo
## "camisetas") o un diccionario de camisetas sueltas.
##
## Uso, desde la raíz del proyecto (sin --headless para que salga el sponsor):
##   godot --path . --script res://scripts/herramientas/exportar_camisetas.gd -- <archivo.json> <carpeta_salida>

const ENTRADA_POR_DEFECTO := "res://arte/camisetas/ejemplos/camisetas_ejemplo.json"
const ESCUDO_EJEMPLO := "res://arte/camisetas/ejemplos/escudo_ejemplo.png"


func _initialize() -> void:
	_exportar.call_deferred()


func _exportar() -> void:
	var args := OS.get_cmdline_user_args()
	var entrada: String = args[0] if args.size() > 0 else ENTRADA_POR_DEFECTO
	var salida: String = args[1] if args.size() > 1 else "user://camisetas"
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(entrada))
	if not datos is Dictionary:
		push_error("No se pudo leer %s" % entrada)
		quit(1)
		return
	var camisetas: Dictionary = datos.get("camisetas", datos)
	var escudo := _escudo(datos)
	DirAccess.make_dir_recursive_absolute(salida)
	for nombre: String in camisetas:
		if nombre.begins_with("_"):
			continue
		var kit: Dictionary = camisetas[nombre]
		var sponsor := await GeneradorCamiseta.imagen_sponsor(self, kit)
		var img := GeneradorCamiseta.generar_imagen(kit, escudo, sponsor)
		var ruta := salida.path_join(nombre + ".png")
		img.save_png(ruta)
		print("Guardada: ", ProjectSettings.globalize_path(ruta))
	quit()


## El escudo del club si hay archivo (oficial o parodia); el de ejemplo si el
## archivo no es de un club.
func _escudo(datos: Dictionary) -> Image:
	if not datos.has("camisetas"):
		return Image.load_from_file(ESCUDO_EJEMPLO)
	var escudo: Dictionary = datos.get("escudo", {})
	var parodia: Dictionary = escudo.get("parodia", {})
	for ruta: Variant in [escudo.get("archivo_oficial"), parodia.get("archivo")]:
		if ruta is String and FileAccess.file_exists(ruta):
			return Image.load_from_file(ruta)
	return null
