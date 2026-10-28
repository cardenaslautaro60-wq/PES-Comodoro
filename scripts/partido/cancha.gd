class_name Cancha
extends Node3D
## Cancha de fútbol con medidas reglamentarias: pasto, líneas, arcos con red y
## las zonas que detectan el gol.
##
## Se arma por código, así no hace falta ningún modelo. El área E (arte) puede
## poner un estadio alrededor o reemplazar el pasto, sin tocar las medidas.

## La pelota entró en un arco. `lado` es 1 para el arco de x positivo (donde ataca
## el local) y -1 para el de x negativo.
signal gol(lado: int)

# Medidas en metros (reglamento FIFA).
const LARGO := 105.0
const ANCHO := 68.0
const ANCHO_ARCO := 7.32
const ALTO_ARCO := 2.44
const FONDO_ARCO := 2.0
const GROSOR_POSTE := 0.12
const GROSOR_LINEA := 0.12
const RADIO_CIRCULO_CENTRAL := 9.15
const FONDO_AREA_GRANDE := 16.5
const ANCHO_AREA_GRANDE := 40.32
const FONDO_AREA_CHICA := 5.5
const ANCHO_AREA_CHICA := 18.32
const DISTANCIA_PENAL := 11.0
## Pasto que sobra alrededor de las líneas.
const MARGEN := 12.0

const VERDE_CLARO := Color(0.30, 0.58, 0.22)
const VERDE_OSCURO := Color(0.25, 0.51, 0.18)
const VERDE_BORDE := Color(0.20, 0.42, 0.15)
const BLANCO := Color(0.95, 0.95, 0.95)

var _materiales := {}


func _ready() -> void:
	_crear_piso()
	_crear_lineas()
	_crear_arco(1)
	_crear_arco(-1)


## True si la pelota (su centro) salió de la cancha por un costado o por el fondo
## sin entrar al arco.
static func esta_afuera(posicion: Vector3, radio_pelota := Pelota.RADIO) -> bool:
	var por_costado := absf(posicion.z) > ANCHO / 2 + radio_pelota
	var por_el_fondo := absf(posicion.x) > LARGO / 2 + radio_pelota
	var dentro_del_arco := absf(posicion.z) < ANCHO_ARCO / 2 and posicion.y < ALTO_ARCO
	return por_costado or (por_el_fondo and not dentro_del_arco)


## Centro de la línea de gol del arco de ese lado (1 o -1).
static func centro_del_arco(lado: int) -> Vector3:
	return Vector3(lado * LARGO / 2, 0, 0)


func _crear_piso() -> void:
	var piso := StaticBody3D.new()
	piso.name = "Piso"
	piso.collision_layer = CapasFisica.MUNDO
	var material_piso := PhysicsMaterial.new()
	material_piso.friction = 0.8
	# Godot suma el rebote de los dos cuerpos que chocan. Con el piso en 0, el rebote
	# lo define solo la pelota (si la suma pasa de 1, la pelota gana altura en cada pique).
	material_piso.bounce = 0.0
	piso.physics_material_override = material_piso
	var caja := BoxShape3D.new()
	caja.size = Vector3(LARGO + MARGEN * 2, 1, ANCHO + MARGEN * 2)
	var forma := CollisionShape3D.new()
	forma.shape = caja
	forma.position.y = -0.5
	piso.add_child(forma)
	add_child(piso)

	_plano(Vector3(0, -0.01, 0), Vector2(LARGO + MARGEN * 2, ANCHO + MARGEN * 2), VERDE_BORDE)
	# Franjas del pasto, como en una cancha cortada.
	var franjas := 14
	var ancho_franja := LARGO / franjas
	for i in franjas:
		var x := -LARGO / 2 + ancho_franja * (i + 0.5)
		_plano(Vector3(x, 0.0, 0), Vector2(ancho_franja, ANCHO), VERDE_CLARO if i % 2 == 0 else VERDE_OSCURO)


func _crear_lineas() -> void:
	var mitad_largo := LARGO / 2
	_rectangulo(Vector3.ZERO, Vector2(LARGO, ANCHO))
	_linea(Vector3.ZERO, Vector2(GROSOR_LINEA, ANCHO))
	_circulo(Vector3.ZERO, RADIO_CIRCULO_CENTRAL)
	_linea(Vector3.ZERO, Vector2(0.3, 0.3))
	for lado: int in [-1, 1]:
		_rectangulo(
			Vector3(lado * (mitad_largo - FONDO_AREA_GRANDE / 2), 0, 0), Vector2(FONDO_AREA_GRANDE, ANCHO_AREA_GRANDE)
		)
		_rectangulo(
			Vector3(lado * (mitad_largo - FONDO_AREA_CHICA / 2), 0, 0), Vector2(FONDO_AREA_CHICA, ANCHO_AREA_CHICA)
		)
		_linea(Vector3(lado * (mitad_largo - DISTANCIA_PENAL), 0, 0), Vector2(0.25, 0.25))


func _rectangulo(centro: Vector3, tamano: Vector2) -> void:
	var g := GROSOR_LINEA
	var mx := tamano.x / 2
	var mz := tamano.y / 2
	_linea(centro + Vector3(0, 0, -mz), Vector2(tamano.x + g, g))
	_linea(centro + Vector3(0, 0, mz), Vector2(tamano.x + g, g))
	_linea(centro + Vector3(-mx, 0, 0), Vector2(g, tamano.y + g))
	_linea(centro + Vector3(mx, 0, 0), Vector2(g, tamano.y + g))


func _circulo(centro: Vector3, radio: float) -> void:
	var segmentos := 64
	var largo_segmento := TAU * radio / segmentos + 0.02
	for i in segmentos:
		var angulo := TAU * i / segmentos
		var punto := centro + Vector3(cos(angulo), 0, sin(angulo)) * radio
		var segmento := _linea(punto, Vector2(GROSOR_LINEA, largo_segmento))
		segmento.rotation.y = -angulo


func _linea(centro: Vector3, tamano: Vector2) -> MeshInstance3D:
	return _plano(centro + Vector3(0, 0.01, 0), tamano, BLANCO)


func _plano(centro: Vector3, tamano: Vector2, color: Color) -> MeshInstance3D:
	var malla := PlaneMesh.new()
	malla.size = tamano
	malla.material = _material(color)
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.position = centro
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instancia)
	return instancia


## Reusa un material por color, así hay menos llamadas de dibujo en el celular.
func _material(color: Color, transparente := false) -> StandardMaterial3D:
	var clave := "%s-%s" % [color.to_html(), transparente]
	if not _materiales.has(clave):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		if transparente:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiales[clave] = material
	return _materiales[clave]


func _crear_arco(lado: int) -> void:
	var arco := StaticBody3D.new()
	arco.name = "ArcoDerecho" if lado > 0 else "ArcoIzquierdo"
	arco.collision_layer = CapasFisica.MUNDO
	add_child(arco)

	var linea := lado * LARGO / 2
	var x_palos := linea + lado * GROSOR_POSTE / 2
	var z_palo := ANCHO_ARCO / 2 + GROSOR_POSTE / 2
	var poste := Vector3(GROSOR_POSTE, ALTO_ARCO, GROSOR_POSTE)
	_pieza(arco, Vector3(x_palos, ALTO_ARCO / 2, -z_palo), poste, BLANCO)
	_pieza(arco, Vector3(x_palos, ALTO_ARCO / 2, z_palo), poste, BLANCO)
	var travesano := Vector3(GROSOR_POSTE, GROSOR_POSTE, ANCHO_ARCO + GROSOR_POSTE * 2)
	_pieza(arco, Vector3(x_palos, ALTO_ARCO + GROSOR_POSTE / 2, 0), travesano, BLANCO)

	# Red: fondo, costados y techo. Frena la pelota sin hacerla rebotar mucho.
	var red := PhysicsMaterial.new()
	red.bounce = 0.1
	red.absorbent = true
	red.friction = 1.0
	arco.physics_material_override = red
	var color_red := Color(1, 1, 1, 0.35)
	var x_medio := linea + lado * FONDO_ARCO / 2
	_pieza(arco, Vector3(linea + lado * FONDO_ARCO, ALTO_ARCO / 2, 0), Vector3(0.05, ALTO_ARCO, ANCHO_ARCO), color_red)
	_pieza(arco, Vector3(x_medio, ALTO_ARCO / 2, -ANCHO_ARCO / 2), Vector3(FONDO_ARCO, ALTO_ARCO, 0.05), color_red)
	_pieza(arco, Vector3(x_medio, ALTO_ARCO / 2, ANCHO_ARCO / 2), Vector3(FONDO_ARCO, ALTO_ARCO, 0.05), color_red)
	_pieza(arco, Vector3(x_medio, ALTO_ARCO, 0), Vector3(FONDO_ARCO, 0.05, ANCHO_ARCO), color_red)

	# Zona de gol. Empieza a dos radios de la línea: la pelota la toca recién
	# cuando cruzó la línea entera, como dice el reglamento.
	var caja := BoxShape3D.new()
	caja.size = Vector3(FONDO_ARCO - Pelota.RADIO * 2, ALTO_ARCO, ANCHO_ARCO)
	var forma := CollisionShape3D.new()
	forma.shape = caja
	var zona := Area3D.new()
	zona.name = "ZonaGol"
	zona.collision_layer = 0
	zona.collision_mask = CapasFisica.PELOTA
	zona.position = Vector3(linea + lado * (FONDO_ARCO / 2 + Pelota.RADIO), ALTO_ARCO / 2, 0)
	zona.add_child(forma)
	zona.body_entered.connect(_al_entrar_en_arco.bind(lado))
	arco.add_child(zona)


func _al_entrar_en_arco(cuerpo: Node3D, lado: int) -> void:
	if cuerpo is Pelota:
		gol.emit(lado)


func _pieza(padre: Node3D, centro: Vector3, tamano: Vector3, color: Color) -> void:
	var caja := BoxShape3D.new()
	caja.size = tamano
	var forma := CollisionShape3D.new()
	forma.shape = caja
	forma.position = centro
	padre.add_child(forma)

	var malla := BoxMesh.new()
	malla.size = tamano
	malla.material = _material(color, color.a < 1.0)
	var vista := MeshInstance3D.new()
	vista.mesh = malla
	vista.position = centro
	padre.add_child(vista)
