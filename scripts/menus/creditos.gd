extends "res://scripts/menus/pantalla_menu.gd"
## Créditos y aviso legal del proyecto de fans.

const TEXTO := """[b]Proyecto de fans[/b], hecho en Comodoro Rivadavia.

Inspirado en los juegos de fútbol de los 2000. No usa código, gráficos, sonidos \
ni datos de ningún juego comercial.

[b]Clubes:[/b] los nombres son los reales. Los escudos y camisetas oficiales se \
usan sólo con permiso de cada club; mientras tanto se ven versiones parodia.

[b]Jugadores:[/b] todos los nombres son inventados. Cualquier parecido con \
jugadores reales es casualidad.

[b]Sonidos:[/b] generados por código para este juego (pelota, silbato, hinchada \
y bombos).

[b]Motor:[/b] Godot Engine (licencia MIT)."""


func armar() -> void:
	encabezado("Créditos")
	var texto := RichTextLabel.new()
	texto.name = "Texto"
	texto.bbcode_enabled = true
	texto.text = TEXTO
	texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texto.add_theme_font_size_override("normal_font_size", TemaUI.TAMANO_CHICO + 4)
	texto.add_theme_font_size_override("bold_font_size", TemaUI.TAMANO_CHICO + 4)
	texto.add_theme_color_override("default_color", TemaUI.TEXTO)
	contenido.add_child(texto)


func volver() -> void:
	Navegacion.ir_a(Navegacion.MENU_PRINCIPAL)
