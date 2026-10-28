extends "res://tests/prueba.gd"
## Pruebas del modelo provisorio del jugador.

const MAXIMO_TRIANGULOS := 1500
const KIT := {
	"patron": "rayas_verticales", "color_base": "#1F4FA8", "color_secundario": "#FFFFFF",
	"cuello": "#FFFFFF", "numero": "#151515", "pantalon": "#151515", "medias": "#1F4FA8", "sponsor_parodia": "",
}

var _modelo: ModeloJugador


func antes_de_cada() -> void:
	_modelo = ModeloJugador.new()
	add_child(_modelo)


func despues_de_cada() -> void:
	_modelo.queue_free()


func test_entra_en_el_presupuesto_del_celular() -> void:
	for pelo in ModeloJugador.ESTILOS_PELO:
		var malla := ModeloJugador.construir_malla(pelo, true)
		var triangulos := malla.get_faces().size() / 3
		afirmar(triangulos <= MAXIMO_TRIANGULOS, "el pelo %d tiene %d triángulos" % [pelo, triangulos])
		afirmar(malla.get_surface_count() == 2, "tiene que tener 2 superficies (equipo y cuerpo)")


func test_esqueleto_completo() -> void:
	afirmar(_modelo.esqueleto.get_bone_count() == ModeloJugador.NOMBRES_HUESOS.size(), "faltan huesos")
	afirmar(_modelo.esqueleto.find_bone("muslo_d") == ModeloJugador.Hueso.MUSLO_D, "huesos fuera de orden")


func test_vestir_pone_material_y_numero() -> void:
	var material := GeneradorCamiseta.crear_material(KIT)
	_modelo.vestir(material, 9, {"piel": 3, "pelo": 2, "color_pelo": 1, "barba": true})
	afirmar(_modelo.malla.get_surface_override_material(0) == material, "no se puso la camiseta")
	afirmar(_modelo.malla.get_instance_shader_parameter("numero") == 9, "no se puso el número")
	var piel: Color = _modelo.malla.get_instance_shader_parameter("color_piel")
	afirmar(piel.is_equal_approx(ModeloJugador.COLORES_PIEL[3]), "no se puso el color de piel")


func test_misma_apariencia_comparte_malla() -> void:
	var otro := ModeloJugador.new()
	add_child(otro)
	_modelo.aplicar_apariencia({"pelo": 3, "barba": false})
	otro.aplicar_apariencia({"pelo": 3, "barba": false})
	afirmar(_modelo.malla.mesh == otro.malla.mesh, "dos jugadores con el mismo pelo deberían compartir la malla")
	otro.aplicar_apariencia({"pelo": 2})
	afirmar(_modelo.malla.mesh != otro.malla.mesh, "un pelo distinto debería usar otra malla")
	otro.queue_free()


func test_apariencia_fuera_de_rango_no_rompe() -> void:
	_modelo.aplicar_apariencia({"piel": 99, "pelo": -4, "color_pelo": 12})
	afirmar(_modelo.malla.mesh != null, "se quedó sin malla")


func test_correr_mueve_las_piernas() -> void:
	_modelo.velocidad = 7.0
	_modelo.animar(0.1)
	var antes := _modelo.esqueleto.get_bone_pose_rotation(ModeloJugador.Hueso.MUSLO_D)
	_modelo.animar(0.1)
	var despues := _modelo.esqueleto.get_bone_pose_rotation(ModeloJugador.Hueso.MUSLO_D)
	afirmar(not antes.is_equal_approx(despues), "las piernas no se mueven al correr")


func test_patada_y_vuelta_a_la_normalidad() -> void:
	_modelo.patear()
	_modelo.animar(ModeloJugador.DURACION_PATADA * 0.6)
	var pierna := _modelo.esqueleto.get_bone_pose_rotation(ModeloJugador.Hueso.MUSLO_D)
	afirmar(pierna.get_euler().x > 0.3, "la pierna no va hacia adelante al patear")
	_modelo.animar(ModeloJugador.DURACION_PATADA)
	_modelo.animar(0.01)
	pierna = _modelo.esqueleto.get_bone_pose_rotation(ModeloJugador.Hueso.MUSLO_D)
	afirmar(absf(pierna.get_euler().x) < 0.1, "después de patear no vuelve a pararse")


func test_barrida_y_caida_bajan_al_piso() -> void:
	for accion: String in ["barrida", "caido"]:
		_modelo.hacer(accion)
		_modelo.animar(0.5)
		var cadera := _modelo.esqueleto.get_bone_pose_position(ModeloJugador.Hueso.CADERA)
		afirmar(cadera.y < 0.5, "con %s la cadera no baja (%.2f)" % [accion, cadera.y])
	_modelo.hacer("")
	_modelo.animar(0.1)
	afirmar(_modelo.esqueleto.get_bone_pose_position(ModeloJugador.Hueso.CADERA).y > 0.85, "no se levanta")


func test_escena_de_muestra_carga() -> void:
	var escena := load("res://escenas/arte/vestuario.tscn") as PackedScene
	afirmar(escena != null and escena.can_instantiate(), "no carga la escena del vestuario")
