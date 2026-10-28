extends Node
## Pasa de una pantalla a otra con un fundido a negro, y maneja el botón "atrás"
## de Android: si la pantalla actual tiene `volver()`, lo llama.

const MENU_PRINCIPAL := "res://escenas/menus/menu_principal.tscn"
const SELECCION_EQUIPOS := "res://escenas/menus/seleccion_equipos.tscn"
const PREPARAR_PARTIDO := "res://escenas/menus/preparar_partido.tscn"
const OPCIONES := "res://escenas/menus/opciones.tscn"
const CREDITOS := "res://escenas/menus/creditos.tscn"
const PARTIDO := "res://escenas/partido/partido.tscn"
const RESULTADO := "res://escenas/menus/resultado.tscn"
## Intro corta del juego (área F). Si existe, se ve una vez al abrir el juego, antes
## del menú. Cuando termina o se saltea, tiene que llamar a `ir_a(MENU_PRINCIPAL)`.
const INTRO := "res://escenas/cinematicas/intro.tscn"
const DURACION_FUNDIDO := 0.18

## Las pruebas lo ponen en true: así no se cambia de escena de verdad y se puede
## revisar a dónde se quiso ir con `ultimo_destino`.
var simular := false
var ultimo_destino := ""

var _cortina: ColorRect
var _cambiando := false
var _intro_vista := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El botón "atrás" de Android no cierra el juego: lo maneja cada pantalla.
	get_tree().quit_on_go_back = false
	var capa := CanvasLayer.new()
	capa.layer = 100
	add_child(capa)
	_cortina = ColorRect.new()
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_cortina)
	_mostrar_intro_al_arrancar.call_deferred()


## La intro va una sola vez, al abrir el juego en el menú principal y si el área F
## ya la agregó. Abriendo otra escena desde el editor no aparece.
func debe_mostrar_intro(escena_inicial: String) -> bool:
	return not _intro_vista and escena_inicial == MENU_PRINCIPAL and ResourceLoader.exists(INTRO)


func _mostrar_intro_al_arrancar() -> void:
	var escena := get_tree().current_scene
	if escena == null or simular:
		return
	if debe_mostrar_intro(escena.scene_file_path):
		_intro_vista = true
		get_tree().change_scene_to_file(INTRO)
	_intro_vista = true


func ir_a(ruta: String) -> void:
	ultimo_destino = ruta
	if simular or _cambiando:
		return
	_cambiando = true
	_cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	var fundido := create_tween()
	fundido.tween_property(_cortina, "color:a", 1.0, DURACION_FUNDIDO)
	await fundido.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(ruta)
	await get_tree().process_frame
	var vuelta := create_tween()
	vuelta.tween_property(_cortina, "color:a", 0.0, DURACION_FUNDIDO)
	await vuelta.finished
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cambiando = false


## En la web y en el celular no hay botón de salir: la app la cierra el sistema.
func se_puede_salir() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("mobile")


func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_GO_BACK_REQUEST:
		var escena := get_tree().current_scene
		if escena and escena.has_method("volver"):
			escena.call("volver")
