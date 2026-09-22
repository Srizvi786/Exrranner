extends Node3D
## Arena V2: town, plane drop, loot, jeep, air-drop, red zone, sunset.

const FIGHTER_SCENE := preload("res://scenes/fighter.tscn")
const BOT_COUNT := 11
const ARENA_HALF := 60.0

const PHASES := [
	{"wait": 16.0, "shrink": 24.0, "radius": 40.0},
	{"wait": 12.0, "shrink": 20.0, "radius": 26.0},
	{"wait": 10.0, "shrink": 16.0, "radius": 15.0},
	{"wait": 8.0, "shrink": 14.0, "radius": 7.0},
	{"wait": 7.0, "shrink": 12.0, "radius": 0.5},
]

const BOT_NAMES := ["Viper", "Jinx", "Raka", "Sheru", "Ghost", "Toofan", "Kalia", "Zed", "Rogue", "Tiger", "Blaze", "Cobra"]
const LOOT_TABLE := ["smg", "smg", "ammo", "ammo", "medkit", "bandage", "bandage", "drink", "helmet", "vest", "grenade", "sniper", "extmag"]

var fighters: Array = []
var player: Fighter
var hud: CanvasItem
var state := "plane"  # plane -> play -> end
var match_t := 0.0

var zone_center := Vector2.ZERO
var zone_radius := 58.0
var zone_from := 58.0
var zone_to := 40.0
var zone_phase := 0
var zone_t := 0.0
var zone_state := "wait"
var zone_dps := 6.0

var houses: Array = []  # {pos:Vector2, size:Vector2}
var grass_spots: Array = []  # {pos:Vector2, r:float}
var jeeps: Array = []
var bullet_pool: Array = []
var dmg_labels: Array = []
var spark_count := 0
var particles_on := true

var plane: Node3D
var plane_t := 0.0
var plane_from := Vector3(-150, 60, -70)
var plane_to := Vector3(150, 60, 70)
var plane_dur := 22.0
var flight_cam: Camera3D
var jumped := false

var chute: Node3D
var airdrop_pos := Vector3.ZERO
var airdrop_active := false
var airdrop_done := false
var redzone := {"active": false, "center": Vector2.ZERO, "r": 15.0, "t": 0.0, "warn": true}
var redzone_done := false
var red_tick := 0.0

var sun: DirectionalLight3D
var env: Environment

const LOCATIONS := [
	{"n": "Milta Town", "p": Vector2(0, 0)},
	{"n": "Godown", "p": Vector2(28, -22)},
	{"n": "Pahadi", "p": Vector2(-35, 30)},
	{"n": "Khet", "p": Vector2(30, 32)},
]


func is_live() -> bool:
	return state == "play"


func _ready() -> void:
	randomize()
	_build_sky()
	_build_ground_roads()
	_build_town()
	_build_props()
	_build_zone_visual()
	_build_jeeps()
	_spawn_loot()
	_spawn_fighters()
	_start_plane()
	hud = get_node("HUD")
	hud.call("bind", player, self)
	_apply_graphics()


func _apply_graphics() -> void:
	var g := Settings.graphics
	sun.shadow_enabled = g > 0
	if g == 2:
		sun.directional_shadow_max_distance = 100.0
	else:
		sun.directional_shadow_max_distance = 55.0
	particles_on = g > 0
	if player != null and player.cam != null:
		player.cam.far = [150.0, 200.0, 260.0][clampi(g, 0, 2)]


# ---------- WORLD ----------

func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material, collide := true) -> StaticBody3D:
	var st := StaticBody3D.new()
	st.position = pos
	if collide:
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		c.shape = s
		st.add_child(c)
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	st.add_child(mi)
	parent.add_child(st)
	return st


func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _build_sky() -> void:
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1, 0.96, 0.9)
	add_child(sun)
	var env_node := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.55, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	add_child(env_node)


func _build_ground_roads() -> void:
	var ground_body := StaticBody3D.new()
	var gc := CollisionShape3D.new()
	var gs := BoxShape3D.new()
	gs.size = Vector3(140, 1, 140)
	gc.shape = gs
	gc.position = Vector3(0, -0.5, 0)
	ground_body.add_child(gc)
	var gm := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(140, 140)
	gm.mesh = plane
	gm.material_override = _mat(Color(0.25, 0.42, 0.2))
	ground_body.add_child(gm)
	add_child(ground_body)
	# Roads (cross)
	var road_m := _mat(Color(0.16, 0.16, 0.17))
	var dash_m := _mat(Color(0.85, 0.85, 0.8))
	for axis in ["x", "z"]:
		var r := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(132, 7) if axis == "x" else Vector2(7, 132)
		r.mesh = pm
		r.material_override = road_m
		r.position = Vector3(0, 0.03, 0)
		add_child(r)
		for d in range(-60, 61, 6):
			var dash := MeshInstance3D.new()
			var dm := BoxMesh.new()
			dm.size = Vector3(2, 0.02, 0.4) if axis == "x" else Vector3(0.4, 0.02, 2)
			dash.mesh = dm
			dash.material_override = dash_m
			dash.position = Vector3(d, 0.05, 0) if axis == "x" else Vector3(0, 0.05, d)
			add_child(dash)
	# Perimeter walls
	var wall_m := _mat(Color(0.3, 0.3, 0.32))
	for i in 4:
		if i < 2:
			_box(self, Vector3(128, 6, 2), Vector3(0, 3, -64.0 if i == 0 else 64.0), wall_m)
		else:
			_box(self, Vector3(2, 6, 128), Vector3(-64.0 if i == 2 else 64.0, 3, 0), wall_m)


func _wall_seg(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> void:
	# Ghar ki deewar (darwaza/khidki gap ke saath tukdon me)
	_box(parent, size, pos, mat)


func _house(pos: Vector3, yaw: float, w := 8.0, d := 7.0, h := 3.2) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var wall_m := _mat(Color(0.75, 0.68, 0.55))
	var trim_m := _mat(Color(0.5, 0.2, 0.15))
	var t := 0.3
	# Floor + roof
	_box(root, Vector3(w + 1, 0.2, d + 1), Vector3(0, 0.1, 0), _mat(Color(0.5, 0.47, 0.42)))
	_box(root, Vector3(w + 1.4, 0.3, d + 1.4), Vector3(0, h + 0.15, 0), trim_m)
	# Front wall (darwaza 1.6): do hisse + upar lintel
	var door := 1.6
	var seg := (w - door) / 2.0
	_wall_seg(root, Vector3(seg, h, t), Vector3(-(door / 2 + seg / 2), h / 2, -d / 2), wall_m)
	_wall_seg(root, Vector3(seg, h, t), Vector3(door / 2 + seg / 2, h / 2, -d / 2), wall_m)
	_wall_seg(root, Vector3(door, h - 2.2, t), Vector3(0, 2.2 + (h - 2.2) / 2, -d / 2), wall_m)
	# Back wall (khidki 1.4 center)
	var win := 1.4
	var segb := (w - win) / 2.0
	_wall_seg(root, Vector3(segb, h, t), Vector3(-(win / 2 + segb / 2), h / 2, d / 2), wall_m)
	_wall_seg(root, Vector3(segb, h, t), Vector3(win / 2 + segb / 2, h / 2, d / 2), wall_m)
	_wall_seg(root, Vector3(win, 1.0, t), Vector3(0, 0.5, d / 2), wall_m)
	_wall_seg(root, Vector3(win, h - 2.2, t), Vector3(0, 2.2 + (h - 2.2) / 2, d / 2), wall_m)
	# Side walls (poori, ek me khidki)
	for s in [-1.0, 1.0]:
		if s < 0.0:
			_wall_seg(root, Vector3(t, h, d), Vector3(-w / 2, h / 2, 0), wall_m)
		else:
			var segd := (d - win) / 2.0
			_wall_seg(root, Vector3(t, h, segd), Vector3(w / 2, h / 2, -(win / 2 + segd / 2)), wall_m)
			_wall_seg(root, Vector3(t, h, segd), Vector3(w / 2, h / 2, win / 2 + segd / 2), wall_m)
			_wall_seg(root, Vector3(t, 1.0, win), Vector3(w / 2, 0.5, 0), wall_m)
			_wall_seg(root, Vector3(t, h - 2.2, win), Vector3(w / 2, 2.2 + (h - 2.2) / 2, 0), wall_m)
	# Andar peti (cover)
	_box(root, Vector3(1.4, 1.4, 1.4), Vector3(w / 2 - 1.4, 0.9, d / 2 - 1.4), _mat(Color(0.45, 0.35, 0.22)))
	houses.append({"pos": Vector2(pos.x, pos.z), "size": Vector2(w, d)})


func _build_town() -> void:
	var spots := [
		[Vector3(-14, 0, -12), 0.2], [Vector3(12, 0, -14), -0.15], [Vector3(-13, 0, 14), 0.1],
		[Vector3(14, 0, 12), 0.3], [Vector3(-28, 0, 2), 1.57], [Vector3(28, 0, -22), 1.57],
		[Vector3(-30, 0, 32), 0.0], [Vector3(32, 0, 34), -0.2], [Vector3(2, 0, -32), 3.14],
		[Vector3(-4, 0, 30), 3.0],
	]
	for s in spots:
		_house(s[0], s[1])
	# Godown (bada, khula darwaza)
	var gp := Vector3(28, 0, -22)
	_box(self, Vector3(14, 0.2, 11), Vector3(gp.x, 0.1, gp.z), _mat(Color(0.45, 0.45, 0.48)))
	houses.append({"pos": Vector2(gp.x, gp.z), "size": Vector2(14, 11)})


func _build_props() -> void:
	var trunk_m := _mat(Color(0.35, 0.25, 0.15))
	var leaf_m := _mat(Color(0.15, 0.45, 0.18))
	var rock_m := _mat(Color(0.45, 0.45, 0.47))
	var bar_m := _mat(Color(0.6, 0.2, 0.15))
	var grass_m := _mat(Color(0.18, 0.38, 0.16))
	for i in 26:
		var pos := Vector3(randf_range(-55, 55), 0, randf_range(-55, 55))
		if abs(pos.x) < 6.0 or abs(pos.z) < 6.0:
			continue
		if pos.length() < 12.0:
			continue
		if i % 3 == 0:
			# Ped
			var tr := MeshInstance3D.new()
			var tc := CylinderMesh.new()
			tc.top_radius = 0.25
			tc.bottom_radius = 0.35
			tc.height = 3.0
			tr.mesh = tc
			tr.material_override = trunk_m
			tr.position = pos + Vector3(0, 1.5, 0)
			add_child(tr)
			var lf := MeshInstance3D.new()
			var ls := SphereMesh.new()
			ls.radius = 1.8
			ls.height = 3.2
			lf.mesh = ls
			lf.material_override = leaf_m
			lf.position = pos + Vector3(0, 4.2, 0)
			add_child(lf)
		elif i % 3 == 1:
			# Pathar
			var rk := MeshInstance3D.new()
			var rs := SphereMesh.new()
			rs.radius = randf_range(0.8, 1.6)
			rs.height = rs.radius * 1.2
			rk.mesh = rs
			rk.material_override = rock_m
			rk.position = pos + Vector3(0, 0.4, 0)
			add_child(rk)
		else:
			# Drum
			var dr := MeshInstance3D.new()
			var dc := CylinderMesh.new()
			dc.top_radius = 0.5
			dc.bottom_radius = 0.5
			dc.height = 1.2
			dr.mesh = dc
			dr.material_override = bar_m
			dr.position = pos + Vector3(0, 0.6, 0)
			add_child(dr)
	# Ghaas ke dhabbe (chhupne ki jagah)
	for i in 22:
		var gpos := Vector2(randf_range(-50, 50), randf_range(-50, 50))
		var r := randf_range(2.0, 3.5)
		var g := MeshInstance3D.new()
		var gc := CylinderMesh.new()
		gc.top_radius = r
		gc.bottom_radius = r
		gc.height = 0.08
		g.mesh = gc
		g.material_override = grass_m
		g.position = Vector3(gpos.x, 0.06, gpos.y)
		add_child(g)
		grass_spots.append({"pos": gpos, "r": r})
	# Streetlights (sirf chamak, roshni nahi - perf)
	var lamp_m := StandardMaterial3D.new()
	lamp_m.albedo_color = Color(1, 0.95, 0.8)
	lamp_m.emission_enabled = true
	lamp_m.emission = Color(1, 0.95, 0.8)
	lamp_m.emission_energy_multiplier = 2.0
	var pole_m := _mat(Color(0.2, 0.2, 0.22))
	for d in [-40, -20, 20, 40]:
		for off in [5.5, -5.5]:
			_box(self, Vector3(0.25, 6, 0.25), Vector3(d, 3, off), pole_m)
			var lamp := MeshInstance3D.new()
			var lb := BoxMesh.new()
			lb.size = Vector3(0.5, 0.3, 0.5)
			lamp.mesh = lb
			lamp.material_override = lamp_m
			lamp.position = Vector3(d, 6.1, off)
			add_child(lamp)


func is_in_grass(pos: Vector3) -> bool:
	var p := Vector2(pos.x, pos.z)
	for g in grass_spots:
		if p.distance_to(g["pos"]) < float(g["r"]):
			return true
	return false


func _build_zone_visual() -> void:
	var zone_shell := MeshInstance3D.new()
	zone_shell.name = "ZoneShell"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 36.0
	cyl.radial_segments = 48
	zone_shell.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.28)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	zone_shell.material_override = mat
	zone_shell.position = Vector3(0, 17, 0)
	add_child(zone_shell)
	_update_zone_visual()


func _update_zone_visual() -> void:
	var zs := get_node_or_null("ZoneShell") as MeshInstance3D
	if zs == null:
		return
	zs.scale = Vector3(zone_radius, 1, zone_radius)
	zs.position = Vector3(zone_center.x, 17, zone_center.y)


func _build_jeeps() -> void:
	var spots := [[Vector3(4, 1, -20), 0.0], [Vector3(-6, 1, 24), 3.14], [Vector3(24, 1, 4), 1.57]]
	for s in spots:
		var j := Jeep.make(s[0], s[1])
		add_child(j)
		jeeps.append(j)


func _spawn_loot() -> void:
	for h in houses:
		var hp: Vector2 = h["pos"]
		var n := 2 if randf() < 0.4 else 1
		for i in n:
			var kind: String = LOOT_TABLE[randi() % LOOT_TABLE.size()]
			var off := Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
			spawn_pickup(kind, Vector3(hp.x, 0.4, hp.y) + off, 0)
	# Shuru me kuch khule me bhi
	for i in 6:
		var kind2: String = LOOT_TABLE[randi() % LOOT_TABLE.size()]
		spawn_pickup(kind2, Vector3(randf_range(-40, 40), 0.4, randf_range(-40, 40)), 0)


func spawn_pickup(kind: String, pos: Vector3, amt := 0) -> void:
	var p := Pickup.make(kind, pos, amt)
	add_child(p)


func _spawn_fighters() -> void:
	var total := BOT_COUNT + 1
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	for i in total:
		var f: Fighter = FIGHTER_SCENE.instantiate()
		var ang := TAU * float(i) / float(total)
		var r := 42.0
		var pos := Vector3(cos(ang) * r, 1.0, sin(ang) * r)
		if i == 0:
			f.is_player = true
			f.fname = "YOU"
			f.body_color = Color(0.2, 0.6, 1.0)
			player = f
		else:
			f.fname = str(names[i % names.size()]) + "-" + str(i)
			f.body_color = Color.from_hsv(randf(), 0.65, 0.9)
			f.personality = randi() % 3
			f.grenades = 1
			f.aim_yaw = randf() * TAU
		f.position = pos
		f.set_physics_process(false)  # plane phase tak shaant
		add_child(f)
		f.died.connect(_on_fighter_died)
		fighters.append(f)


# ---------- PLANE + PARACHUTE ----------

func _start_plane() -> void:
	plane = Node3D.new()
	plane.position = plane_from
	add_child(plane)
	var gray := _mat(Color(0.55, 0.57, 0.6), 0.5)
	_box(plane, Vector3(3, 3, 22), Vector3.ZERO, gray, false)
	_box(plane, Vector3(20, 0.4, 3.5), Vector3(0, 0.5, 0), gray, false)
	_box(plane, Vector3(0.4, 4, 3), Vector3(0, 2, 10), gray, false)
	flight_cam = Camera3D.new()
	flight_cam.position = plane_from + Vector3(-18, 8, 0)
	flight_cam.look_at(plane_from)
	flight_cam.current = true
	add_child(flight_cam)
	player.global_position = plane_from
	if hud != null:
		pass


func _physics_process(delta: float) -> void:
	if state == "plane":
		plane_t += delta
		var k: float = clampf(plane_t / plane_dur, 0.0, 1.0)
		plane.position = plane_from.lerp(plane_to, k)
		player.global_position = plane.position + Vector3(0, -1, 0)
		flight_cam.position = plane.position + Vector3(-20, 9, 0)
		flight_cam.look_at(plane.position)
		if k >= 1.0 and not jumped:
			player_jump()


func player_jump() -> void:
	if state != "plane" or jumped:
		return
	jumped = true
	player.global_position = plane.position + Vector3(0, -2, 0)
	player.set_physics_process(false)
	# Parachute kholo
	chute = Node3D.new()
	var can := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.2
	sm.height = 1.6
	can.mesh = sm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(1, 0.45, 0.1)
	cm.roughness = 0.9
	can.material_override = cm
	can.scale = Vector3(1.4, 0.55, 1.4)
	can.position = Vector3(0, 4.2, 0)
	chute.add_child(can)
	player.add_child(chute)
	if flight_cam != null:
		flight_cam.queue_free()
		flight_cam = null
	player.cam.current = true
	state = "chute"
	toast("Parachute khula! Jagah chuno.")
	Sfx.play("chute")


func _process(delta: float) -> void:
	if state == "plane":
		return
	if state == "chute":
		_chute_fall(delta)
		return
	if state != "play":
		return
	match_t += delta
	_update_zone(delta)
	_zone_damage(delta)
	_update_events(delta)
	_update_sunset()
	if hud != null:
		var hpv := 0.0
		var kl := 0
		if player != null:
			if player.alive:
				hpv = player.hp
			kl = player.kills
		hud.call("refresh", fighters.size(), _zone_text(), hpv, kl)


func _chute_fall(delta: float) -> void:
	if player == null or not player.alive:
		return
	var steer := Vector3(player.move_input.x, 0, player.move_input.y)
	var wdir: Vector3 = Basis(Vector3.UP, player.aim_yaw) * steer
	player.global_position += (wdir * 8.0 + Vector3(0, -6.0, 0)) * delta
	player.rotation.y = player.aim_yaw
	if player.global_position.y <= 1.0:
		player.global_position.y = 1.0
		if chute != null:
			chute.queue_free()
			chute = null
		player.set_physics_process(true)
		player.velocity = Vector3.ZERO
		state = "play"
		for f in fighters:
			if f != player:
				(f as Fighter).set_physics_process(true)
		toast("Land ho gaye! Lado!")
		Sfx.play("warn")


# ---------- ZONE / EVENTS ----------

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
			var max_off: float = maxf(zone_from - zone_to, 0.0) * 0.6
			var a := randf() * TAU
			zone_center += Vector2(cos(a), sin(a)) * (randf() * max_off)
			toast("Zone chhota ho raha hai!")
			Sfx.play("warn")
	else:
		var dur: float = float(ph["shrink"])
		var k: float = clampf(zone_t / dur, 0.0, 1.0)
		zone_radius = lerpf(zone_from, zone_to, k)
		if k >= 1.0:
			zone_t = 0.0
			zone_state = "wait"
			zone_phase += 1
			zone_dps += 2.0
			if zone_phase == 2 and not airdrop_done:
				_start_airdrop()
			if zone_phase == 1 and not redzone_done:
				_start_redzone()
	_update_zone_visual()


func _zone_text() -> String:
	if zone_phase >= PHASES.size():
		return "FINAL ZONE!"
	if zone_state == "wait":
		var ph: Dictionary = PHASES[zone_phase]
		var left: int = int(ceil(float(ph["wait"]) - zone_t))
		return "Zone: %ds" % left
	return "GET TO ZONE!"


func _zone_damage(delta: float) -> void:
	for f in fighters.duplicate():
		if f == null or not (f as Fighter).alive:
			continue
		var me := Vector2((f as Fighter).global_position.x, (f as Fighter).global_position.z)
		if me.distance_to(zone_center) > zone_radius:
			(f as Fighter).take_damage(zone_dps * delta, null)


func get_zone_info() -> Dictionary:
	return {"center": zone_center, "radius": zone_radius}


func get_loot_point() -> Vector3:
	if airdrop_active:
		return airdrop_pos
	return Vector3(zone_center.x, 0, zone_center.y)


func nearby_jeep(p: Fighter):
	for j in jeeps:
		if (j as Jeep).dead or (j as Jeep).driver != null:
			continue
		if (j as Jeep).global_position.distance_to(p.global_position) < 4.0:
			return j
	return null


func _start_airdrop() -> void:
	airdrop_done = true
	var p := Vector3(zone_center.x + randf_range(-8, 8), 0, zone_center.y + randf_range(-8, 8))
	airdrop_pos = p
	airdrop_active = true
	# Peti parachute se utarti hai
	var crate := Node3D.new()
	crate.position = p + Vector3(0, 40, 0)
	add_child(crate)
	_box(crate, Vector3(1.6, 1.6, 1.6), Vector3.ZERO, _mat(Color(0.5, 0.35, 0.15)), false)
	var tw := create_tween()
	tw.tween_property(crate, "position:y", 0.8, 6.0)
	tw.tween_callback(func() -> void:
		airdrop_active = false
		spawn_pickup("sniper", p + Vector3(2, 0.4, 0), 0)
		spawn_pickup("vest", p + Vector3(-2, 0.4, 0), 0)
		spawn_pickup("medkit", p + Vector3(0, 0.4, 2), 0)
		crate.queue_free()
	)
	toast("AIR-DROP aaya! Best loot!")
	Sfx.play("warn")
	if hud != null:
		hud.call("flash_msg", "AIR-DROP INCOMING!")


func _start_redzone() -> void:
	redzone_done = true
	var c := zone_center + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	redzone = {"active": true, "center": c, "r": 15.0, "t": 18.0, "warn": true}
	toast("RED ZONE! Bahar niklo!")
	Sfx.play("warn")
	if hud != null:
		hud.call("flash_msg", "RED ZONE!")


func _update_events(delta: float) -> void:
	if bool(redzone["active"]):
		redzone["t"] = float(redzone["t"]) - delta
		red_tick -= delta
		if red_tick <= 0.0:
			red_tick = 0.7
			var c: Vector2 = redzone["center"]
			var r: float = float(redzone["r"])
			var p := Vector3(c.x + randf_range(-r, r), 0.5, c.y + randf_range(-r, r))
			explode(p, 38.0, 4.5, null)
		if float(redzone["t"]) <= 0.0:
			redzone["active"] = false


func _update_sunset() -> void:
	var k: float = clampf(match_t / 260.0, 0.0, 1.0)
	sun.rotation.x = lerpf(-0.9, -0.4, k)
	sun.light_color = Color(1, lerpf(0.96, 0.6, k), lerpf(0.9, 0.35, k))
	env.background_color = Color(lerpf(0.35, 0.45, k), lerpf(0.55, 0.3, k), lerpf(0.8, 0.35, k))
	env.ambient_light_energy = lerpf(0.9, 0.55, k)


# ---------- COMBAT HELPERS ----------

func get_bullet():
	for b in bullet_pool:
		if not b.active:
			return b
	if bullet_pool.size() >= 48:
		return null
	var nb = Fighter.BULLET_SCENE.instantiate()
	add_child(nb)
	nb.deactivate()
	bullet_pool.append(nb)
	return nb


func spawn_grenade(from_pos: Vector3, target: Vector3, shooter) -> void:
	var g := Grenade.make(from_pos, target, shooter)
	add_child(g)


func explode(pos: Vector3, dmg: float, radius: float, from) -> void:
	Sfx.play("boom")
	# Flash gola
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	flash.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1, 0.7, 0.3)
	fm.emission_enabled = true
	fm.emission = Color(1, 0.6, 0.2)
	fm.emission_energy_multiplier = 5.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = fm
	flash.position = pos + Vector3(0, 1, 0)
	add_child(flash)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * radius * 0.8, 0.25)
	tw.tween_property(fm, "emission_energy_multiplier", 0.0, 0.4)
	tw.chain().tween_callback(flash.queue_free)
	for n in get_tree().get_nodes_in_group("fighters"):
		var f := n as Fighter
		if f == null or not f.alive:
			continue
		var d: float = f.global_position.distance_to(pos)
		if d < radius:
			f.take_damage(dmg * (1.0 - d / radius * 0.6), from)
	for n in get_tree().get_nodes_in_group("jeeps"):
		var j := n as Jeep
		if j == null or j.dead:
			continue
		if j.global_position.distance_to(pos) < radius:
			j.take_damage(dmg * 0.7, from)
	if hud != null and player != null and player.alive:
		var pd: float = player.global_position.distance_to(pos)
		if pd < radius * 1.5:
			Sfx.buzz(50)


func spark(pos: Vector3) -> void:
	if not particles_on:
		return
	if spark_count > 12:
		return
	spark_count += 1
	var s := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 0.12)
	s.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.8, 0.3)
	m.emission_enabled = true
	m.emission = Color(1, 0.7, 0.2)
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.material_override = m
	s.position = pos
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 0.1, 0.18)
	tw.tween_callback(func() -> void:
		spark_count -= 1
		s.queue_free()
	)


func puff(pos: Vector3) -> void:
	if not particles_on:
		return
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	s.mesh = sm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.4, 0.4, 0.4, 0.6)
	s.material_override = m
	s.position = pos
	add_child(s)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "position:y", pos.y + 2.0, 1.0)
	tw.tween_property(s, "scale", Vector3.ONE * 2.0, 1.0)
	tw.chain().tween_callback(s.queue_free)


func damage_number(pos: Vector3, amount: float, mine: bool) -> void:
	if dmg_labels.size() > 10:
		return
	var lab := Label3D.new()
	lab.text = str(int(amount))
	lab.font_size = 64
	lab.pixel_size = 0.01
	lab.modulate = Color(1, 0.9, 0.2) if mine else Color(1, 0.4, 0.35)
	lab.outline_size = 10
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = pos + Vector3(randf_range(-0.3, 0.3), 2.2, 0)
	add_child(lab)
	dmg_labels.append(lab)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lab, "position:y", lab.position.y + 1.0, 0.7)
	tw.tween_property(lab, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(func() -> void:
		dmg_labels.erase(lab)
		lab.queue_free()
	)


func toast(msg: String) -> void:
	if hud != null:
		hud.call("toast", msg)


func killfeed(killer: String, victim: String) -> void:
	if hud != null:
		hud.call("feed", killer + "  ☠  " + victim)


# ---------- DEATH / END ----------

func _on_fighter_died(f: Fighter) -> void:
	fighters.erase(f)
	# Mara hua apni gun gira jata hai
	spawn_pickup(f.gun, f.global_position, 0)
	spawn_pickup("ammo", f.global_position + Vector3(1, 0, 0), 0)
	var left := fighters.size()
	if f == player:
		state = "end"
		var rank := left + 1
		Settings.record_match(player.kills, rank, false)
		Sfx.play("hurt", 4.0)
		hud.call("show_end", false, rank, player.kills)
	else:
		var kn := "ZONE"
		if f.last_hit_by != null and f.last_hit_by is Fighter:
			kn = (f.last_hit_by as Fighter).fname
		elif f.last_hit_by != null:
			kn = "BOOM"
		killfeed(kn, f.fname)
		if left == 1 and player != null and player.alive:
			state = "end"
			Settings.record_match(player.kills, 1, true)
			_slowmo_win()
			hud.call("show_end", true, 1, player.kills)


func _killer_of(_f: Fighter) -> String:
	return "???"

func _slowmo_win() -> void:
	Sfx.play_win()
	Engine.time_scale = 0.3
	await get_tree().create_timer(0.9, true, false, true).timeout
	Engine.time_scale = 1.0
