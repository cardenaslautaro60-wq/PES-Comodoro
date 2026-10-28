class_name Ambiente
extends RefCounted
## Cielo, luz y tierra alrededor de la cancha, mientras el área E no pone el estadio.


static func crear(padre: Node) -> void:
	var material_cielo := ProceduralSkyMaterial.new()
	material_cielo.sky_top_color = Color(0.32, 0.52, 0.85)
	material_cielo.sky_horizon_color = Color(0.74, 0.82, 0.92)
	material_cielo.ground_horizon_color = Color(0.45, 0.42, 0.38)
	material_cielo.ground_bottom_color = Color(0.30, 0.28, 0.25)
	var cielo := Sky.new()
	cielo.sky_material = material_cielo

	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = cielo
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var mundo := WorldEnvironment.new()
	mundo.name = "Ambiente"
	mundo.environment = entorno
	padre.add_child(mundo)

	var tierra := PlaneMesh.new()
	tierra.size = Vector2(400, 400)
	var material_tierra := StandardMaterial3D.new()
	material_tierra.albedo_color = Color(0.42, 0.38, 0.30)
	material_tierra.roughness = 1.0
	tierra.material = material_tierra
	var vista_tierra := MeshInstance3D.new()
	vista_tierra.name = "Tierra"
	vista_tierra.mesh = tierra
	vista_tierra.position.y = -0.03
	vista_tierra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(vista_tierra)

	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-50, -30, 0)
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 90.0
	padre.add_child(sol)
