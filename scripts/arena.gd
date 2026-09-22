extends Node3D
## Arena: match chalata hai - spawn, shrinking zone, jeet/haar.

const FIGHTER_SCENE := preload("res://scenes/fighter.tscn")
const BOT_COUNT := 11
const ARENA_HALF := 55.0

# wait_sec, shrink_sec, radius
const PHASES := [
	{"wait": 14.0, "shrink": 22.0, "radius": 38.0},
	{"wait": 10.0, "shrink": 18.0, "radius": 25.0},
	{"wait": 8.0, "shrink": 15.0, "radius": 14.0},
	{"wait": 8.0, "shrink": 14.0, "radius": 6.0},
	{"wait": 6.0, "shrink": 12.0, "radius": 0.5},
]

var fighters: Array = []
var player: Fighter
var hud: CanvasItem
var zone_center := Vector2.ZERO
var zone_radius := 55.0
var zone_from := 55.0
var zone_to := 38.0
var zone_phase := 0
var zone_t := 0.0
var zone_state := "wait"
var zone_dps := 6.0
var game_over := false


func _ready() -> void:
	randomize()
	_build_world()
	_build_zone_visual()
	_spawn_fighters()
	hud = get_node("HUD")
	hud.call("bind", player, self)


func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.1
	add_child(sun)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	add_child(env_node)

	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.16, 0.3, 0.16)
	ground_mat.roughness = 0.95
	var ground_body := StaticBody3D.new()
	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(130, 1, 130)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0, -0.5, 0)
	ground_body.add_child(ground_col)
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(130, 130)
	ground_mesh.mesh = plane
	ground_mesh.material_override = ground_mat
	ground_body.add_child(ground_mesh)
	add_child(ground_body)

	# Perimeter walls
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.25, 0.27, 0.3)
	for i in 4:
		var wall := StaticBody3D.new()
		var wc := CollisionShape3D.new()
		var ws := BoxShape3D.new()
		var wm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		if i < 2:
			ws.size = Vector3(124, 6, 2)
			bm.size = ws.size
			wc.position = Vector3(0, 3, -62.0 if i == 0 else 62.0)
			wm.position = wc.position
		else:
			ws.size = Vector3(2, 6, 124)
			bm.size = ws.size
			wc.position = Vector3(-62.0 if i == 2 else 62.0, 3, 0)
			wm.position = wc.position
		wc.shape = ws
		wm.mesh = bm
		wm.material_override = wall_mat
		wall.add_child(wc)
		wall.add_child(wm)
		add_child(wall)

	# Random obstacles (cover)
	var box_mat_a := StandardMaterial3D.new()
	box_mat_a.albedo_color = Color(0.45, 0.35, 0.22)
	var box_mat_b := StandardMaterial3D.new()
	box_mat_b.albedo_color = Color(0.3, 0.32, 0.36)
	for i in 42:
		var pos := Vector3(randf_range(-50, 50), 0, randf_range(-50, 50))
		if pos.length() < 8.0:
			continue
		var size := Vector3(randf_range(2, 6), randf_range(2, 7), randf_range(2, 6))
		var ob := StaticBody3D.new()
		var oc := CollisionShape3D.new()
		var os := BoxShape3D.new()
		os.size = size
		oc.shape = os
		oc.position = Vector3(pos.x, size.y / 2.0, pos.z)
		var om := MeshInstance3D.new()
		var obm := BoxMesh.new()
		obm.size = size
		om.mesh = obm
		om.position = oc.position
		om.material_override = box_mat_a if i % 2 == 0 else box_mat_b
		ob.add_child(oc)
		ob.add_child(om)
		add_child(ob)


var zone_shell: MeshInstance3D

func _build_zone_visual() -> void:
	zone_shell = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 34.0
	cyl.radial_segments = 48
	zone_shell.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.28)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	zone_shell.material_override = mat
	zone_shell.position = Vector3(0, 16, 0)
	add_child(zone_shell)
	_update_zone_visual()


func _update_zone_visual() -> void:
	if zone_shell == null:
		return
	zone_shell.scale = Vector3(zone_radius, 1, zone_radius)
	zone_shell.position = Vector3(zone_center.x, 16, zone_center.y)


func _spawn_fighters() -> void:
	var total := BOT_COUNT + 1
	for i in total:
		var f: Fighter = FIGHTER_SCENE.instantiate()
		var ang := TAU * float(i) / float(total)
		var r := 40.0 + randf_range(-4.0, 4.0)
		var pos := Vector3(cos(ang) * r, 1.0, sin(ang) * r)
		if i == 0:
			f.is_player = true
			f.body_color = Color(0.2, 0.6, 1.0)
			f.aim_yaw = atan2(-pos.x, -pos.z) + PI
			player = f
		else:
			var hue := randf()
			f.body_color = Color.from_hsv(hue, 0.65, 0.9)
			f.aim_yaw = randf() * TAU
		f.position = pos
		add_child(f)
		f.died.connect(_on_fighter_died)
		fighters.append(f)


func get_zone_info() -> Dictionary:
	return {"center": zone_center, "radius": zone_radius}


func _process(delta: float) -> void:
	if game_over:
		return
	_update_zone(delta)
	_zone_damage(delta)
	if hud != null:
		hud.call("refresh", fighters.size(), _zone_text(), player.hp if player != null and player.alive else 0.0, player.kills if player != null else 0)


func _update_zone(delta: float) -> void:
	if zone_phase >= PHASES.size():
		return
	var ph: Dictionary = PHASES[zone_phase]
	zone_t += delta
	if zone_state == "wait":
		if zone_t >= float(ph["wait"]):
			zone_t = 0.0
			zone_state = "shrink"
			zone_from = zone_radius
			zone_to = float(ph["radius"])
			# Naya center: purane circle ke andar kahin
			var max_off: float = maxf(zone_from - zone_to, 0.0) * 0.6
			var a := randf() * TAU
			var off: float = randf() * max_off
			zone_center += Vector2(cos(a), sin(a)) * off
	else:
		var dur: float = float(ph["shrink"])
		var k: float = clamp(zone_t / dur, 0.0, 1.0)
		zone_radius = lerpf(zone_from, zone_to, k)
		if k >= 1.0:
			zone_t = 0.0
			zone_state = "wait"
			zone_phase += 1
			zone_dps += 2.0
	_update_zone_visual()


func _zone_text() -> String:
	if zone_phase >= PHASES.size():
		return "FINAL ZONE!"
	if zone_state == "wait":
		var ph: Dictionary = PHASES[zone_phase]
		var left: int = int(ceil(float(ph["wait"]) - zone_t))
		return "Zone shrink: %ds" % left
	return "GET TO ZONE!"


func _zone_damage(delta: float) -> void:
	for f in fighters.duplicate():
		if f == null or not (f as Fighter).alive:
			continue
		var me := Vector2((f as Fighter).global_position.x, (f as Fighter).global_position.z)
		if me.distance_to(zone_center) > zone_radius:
			(f as Fighter).take_damage(zone_dps * delta, null)


func _on_fighter_died(f: Fighter) -> void:
	fighters.erase(f)
	var left := fighters.size()
	if f == player:
		game_over = true
		var rank := left + 1
		hud.call("show_end", false, rank, player.kills)
	elif left == 1 and player != null and player.alive:
		game_over = true
		hud.call("show_end", true, 1, player.kills)
