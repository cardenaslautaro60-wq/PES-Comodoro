extends RefCounted
## Colores, tamaños y tema visual de los menús.
##
## Pensado para el dedo: botones de 84 px de alto como mínimo (con la pantalla de
## 1280x720 de referencia), letras grandes y mucho contraste para jugar al sol.

const FONDO := Color("0e1a2b")
const FONDO_CLARO := Color("1b3150")
const PANEL := Color("152740")
const PANEL_CLARO := Color("21395a")
const ACENTO := Color("f2b705")
const TEXTO := Color("f4f1ea")
const TEXTO_SUAVE := Color("9fb2cc")
const VERDE := Color("3fbf6a")
const ROJO := Color("e5484d")

const ALTO_BOTON := 84
const TAMANO_LETRA := 30
const TAMANO_TITULO := 56
const TAMANO_CHICO := 22
const RADIO := 16

static var _tema: Theme


## Tema compartido por todas las pantallas (se arma una sola vez).
static func tema() -> Theme:
	if _tema:
		return _tema
	var t := Theme.new()
	t.default_font_size = TAMANO_LETRA

	t.set_stylebox("normal", "Button", caja(PANEL_CLARO))
	t.set_stylebox("hover", "Button", caja(PANEL_CLARO.lightened(0.12)))
	t.set_stylebox("pressed", "Button", caja(ACENTO))
	t.set_stylebox("hover_pressed", "Button", caja(ACENTO.lightened(0.1)))
	t.set_stylebox("disabled", "Button", caja(PANEL.darkened(0.2)))
	t.set_stylebox("focus", "Button", borde(ACENTO))
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", TEXTO)
	t.set_color("font_focus_color", "Button", TEXTO)
	t.set_color("font_pressed_color", "Button", FONDO)
	t.set_color("font_hover_pressed_color", "Button", FONDO)
	t.set_color("font_disabled_color", "Button", TEXTO_SUAVE.darkened(0.3))

	t.set_color("font_color", "Label", TEXTO)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_stylebox("panel", "PanelContainer", caja(PANEL, 22))
	t.set_stylebox("panel", "Panel", caja(PANEL, 22))

	# Barra de desplazamiento ancha, para poder agarrarla con el dedo.
	t.set_stylebox("scroll", "VScrollBar", caja(Color(1, 1, 1, 0.06), 6))
	t.set_stylebox("grabber", "VScrollBar", caja(Color(1, 1, 1, 0.3), 6))
	t.set_stylebox("grabber_highlight", "VScrollBar", caja(Color(1, 1, 1, 0.45), 6))
	t.set_stylebox("grabber_pressed", "VScrollBar", caja(ACENTO, 6))
	_tema = t
	return t


static func caja(color: Color, margen := 14) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(RADIO)
	estilo.content_margin_left = margen + 8
	estilo.content_margin_right = margen + 8
	estilo.content_margin_top = margen
	estilo.content_margin_bottom = margen
	estilo.anti_aliasing = true
	return estilo


static func borde(color: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.draw_center = false
	estilo.border_color = color
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(RADIO + 2)
	estilo.expand_margin_left = 3
	estilo.expand_margin_right = 3
	estilo.expand_margin_top = 3
	estilo.expand_margin_bottom = 3
	return estilo


## Texto con borde oscuro, que se lee arriba de la cancha.
static func etiqueta(texto: String, tamano := TAMANO_LETRA, color := TEXTO) -> Label:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", maxi(4, tamano / 6))
	return label


## Estrellas de nivel del club, de 1 a 5.
static func estrellas(nivel: int) -> String:
	var n := clampi(nivel, 0, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)
