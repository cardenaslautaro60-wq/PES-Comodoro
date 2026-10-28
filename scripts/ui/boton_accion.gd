extends Button
## Botón táctil que aprieta una acción de `InputMap` mientras está presionado,
## así el juego lo lee igual que una tecla.

@export var accion := "pase"


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_al_apretar)
	button_up.connect(func() -> void: Input.action_release(accion))


## Cambia la acción y el texto (por ejemplo, de "PASE LARGO" a "CAMBIAR" al defender).
## Si estaba apretado, suelta la acción vieja.
func cambiar_accion(nueva: String, texto: String) -> void:
	if nueva == accion:
		text = texto
		return
	if button_pressed or Input.is_action_pressed(accion):
		Input.action_release(accion)
	accion = nueva
	text = texto


func _al_apretar() -> void:
	Input.action_press(accion)
	Controles.vibrar(15)


func _exit_tree() -> void:
	Input.action_release(accion)
