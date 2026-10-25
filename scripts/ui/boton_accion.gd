extends Button
## Botón táctil que aprieta una acción de `InputMap` mientras está presionado,
## así el juego lo lee igual que una tecla.

@export var accion := "pase"


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(func() -> void: Input.action_press(accion))
	button_up.connect(func() -> void: Input.action_release(accion))


func _exit_tree() -> void:
	Input.action_release(accion)
