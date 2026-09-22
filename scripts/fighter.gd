class_name Fighter
extends CharacterBody3D
## Human-type commando: sir, jacket, haath-pair, rifle, walk animation.
## Camera-center aim - jahan camera dekhega, goli wahin lagegi.

signal died(fighter: Fighter)

const SPEED := 7.0
const BOT_SPEED := 5.8
const GRAVITY := 24.0
const MAX_HP := 100.0
const BULLET_SCENE := preload("res://scenes/bullet.tscn")

const GUNS := {
	"rifle": {"dmg": 12.0, "interval": 0.16, "mag": 30, "auto": true, "spread": 0.02, "sound": "rifle"},
	"smg": {"dmg": 8.0, "interval": 0.09, "mag": 40, "auto": true, "spread": 0.05, "sound": "smg"},
	"sniper": {"dmg": 45.0, "interval": 1.1, "mag": 5, "auto": false, "spread": 0.0, "sound": "sniper"},
}

var is_player := false
var fname := "Bot"
var personality := 0  # 0 rusher, 1 camper, 2 looter
var hp := MAX_HP
var alive := true
var kills := 0
var move_input := Vector2.ZERO
var aim_yaw := 0.0
var aim_pitch := -0.08
var fire_held := false
var fire_cd := 0.0
var body_color := Color(0.2, 0.6, 1.0)
var skin_color := Color(0.85, 0.65, 0.5)

# Loadout
var gun := "rifle"
var ammo_mag := 30
var ammo_reserve := 120
var ext_mag := false
var grenades := 2
var medkits := 1
var bandages := 2
var drinks := 1
var helmet := false
var helmet_hp := 50.0
var vest := false
var vest_hp := 50.0

var reloading := 0.0
var heal_t := 0.0
var heal_total := 1.0
var heal_kind := ""
var crouching := false
var zoom_idx := 0  # 0,1,2 -> 1x,2x,4x
var driving = null  # Jeep ya null
var last_hit_by = null

# Visual refs
var visual: Node3D
var torso: MeshInstance3D
var head_m: MeshInstance3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var gun_m: MeshInstance3D
var muzzle: Marker3D
var flash_m: MeshInstance3D
var flash_t := 0.0
var helmet_m: MeshInstance3D
var vest_m: MeshInstance3D
var body_mat: StandardMaterial3D
var walk_phase := 0.0
var col: CollisionShape3D
var cam_pivot: Node3D
var cam: Camera3D

# Bot brain
var think_cd := 0.0
var wander_cd := 0.0
var burst_cd := 0.0
var strafe_sign := 1.0
var nade_cd := 8.0


func mag_size() -> int:
	return int(GUNS[gun]["mag"]) + (10 if ext_mag else 0)


func _ready() -> void:
	add_to_group("fighters")
	_build_humanoid()
	if is_player:
		_setup_camera()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_humanoid() -> void:
	visual = Node3D.new()
	add_child(visual)
	var jacket := _mat(body_color)
	body_mat = jacket
	var pants := _mat(body_color.darkened(0.35))
	var skin := _mat(skin_color)
	var dark := _mat(Color(0.08, 0.08, 0.1))
	var bootm := _mat(Color(0.15, 0.12, 0.1))

	# Torso (jacket)
	torso = _box(visual, Vector3(0.55, 0.7, 0.32), Vector3(0, 1.2, 0), jacket)
	# Vest overlay
	vest_m = _box(visual, Vector3(0.6, 0.5, 0.37), Vector3(0, 1.22, 0), _mat(Color(0.2, 0.22, 0.18)))
	vest_m.visible = false
	# Head + eyes
	head_m = MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.24
	hs.height = 0.48
	head_m.mesh = hs
	head_m.material_override = skin
	head_m.position = Vector3(0, 1.78, 0)
	visual.add_child(head_m)
	var eye_m := _mat(Color(0.05, 0.05, 0.06))
	_box(visual, Vector3(0.06, 0.06, 0.03), Vector3(-0.09, 1.8, -0.22), eye_m)
	_box(visual, Vector3(0.06, 0.06, 0.03), Vector3(0.09, 1.8, -0.22), eye_m)
	# Helmet (chhupa, loot par dikhega)
	helmet_m = MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.29
	hm.height = 0.4
	helmet_m.mesh = hm
	helmet_m.material_override = _mat(Color(0.25, 0.3, 0.22))
	helmet_m.position = Vector3(0, 1.86, 0)
	helmet_m.visible = false
	visual.add_child(helmet_m)

	# Arms (shoulder pivot se hilenge)
	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0.36 * side, 1.48, 0)
		visual.add_child(sh)
		_box(sh, Vector3(0.16, 0.52, 0.16), Vector3(0, -0.26, 0), jacket)
		_box(sh, Vector3(0.14, 0.14, 0.14), Vector3(0, -0.55, -0.05), skin)
		if side < 0.0:
			arm_l = sh
		else:
			arm_r = sh
	# Legs (hip pivot se hilengi)
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.15 * side, 0.9, 0)
		visual.add_child(hip)
		_box(hip, Vector3(0.2, 0.48, 0.2), Vector3(0, -0.24, 0), pants)
		_box(hip, Vector3(0.22, 0.16, 0.3), Vector3(0, -0.55, -0.04), bootm)
		if side < 0.0:
			leg_l = hip
		else:
			leg_r = hip
	# Rifle haathon me
	gun_m = _box(visual, Vector3(0.1, 0.14, 0.95), Vector3(0.22, 1.28, -0.35), dark)
	_box(visual, Vector3(0.08, 0.22, 0.12), Vector3(0.22, 1.12, -0.25), dark)
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0.22, 1.3, -0.85)
	visual.add_child(muzzle)
	# Muzzle flash (fire par 0.06 sec chamkega)
	flash_m = MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.22
	fs.height = 0.44
	flash_m.mesh = fs
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1, 0.8, 0.3)
	fm.emission_enabled = true
	fm.emission = Color(1, 0.7, 0.2)
	fm.emission_energy_multiplier = 4.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_m.material_override = fm
	flash_m.position = muzzle.position
	flash_m.visible = false
	visual.add_child(flash_m)

	col = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.7
	col.shape = shape
	col.position = Vector3(0, 0.95, 0)
	add_child(col)


func _setup_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.position = Vector3(0, 1.7, 0)
	add_child(cam_pivot)
	var spring := SpringArm3D.new()
	spring.spring_length = 5.0
	spring.margin = 0.3
	cam_pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 150.0
	cam.current = true
	spring.add_child(cam)
	_apply_aim()


func _apply_aim() -> void:
	rotation.y = aim_yaw
	if cam_pivot != null:
		cam_pivot.rotation.x = aim_pitch
		var zooms := [70.0, 45.0, 28.0]
		cam.fov = zooms[clampi(zoom_idx, 0, 2)]


func set_crouch(v: bool) -> void:
	if crouching == v:
		return
	crouching = v
	if crouching:
		visual.scale.y = 0.78
		(col.shape as CapsuleShape3D).height = 1.25
		col.position.y = 0.72
	else:
		visual.scale.y = 1.0
		(col.shape as CapsuleShape3D).height = 1.7
		col.position.y = 0.95


func set_drive_mode(jeep) -> void:
	driving = jeep
	set_physics_process(jeep == null)
	col.set_deferred("disabled", jeep != null)
	if jeep == null:
		visible = true


func _physics_process(delta: float) -> void:
	if not alive or driving != null:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if is_player:
		_keyboard_input(delta)
	else:
		_bot_think(delta)

	var spd := SPEED * (0.55 if crouching else 1.0)
	if not is_player:
		spd = BOT_SPEED
	var local := Vector3(move_input.x, 0.0, move_input.y)
	var world_dir: Vector3 = Basis(Vector3.UP, aim_yaw) * local
	if world_dir.length() > 1.0:
		world_dir = world_dir.normalized()
	velocity.x = world_dir.x * spd
	velocity.z = world_dir.z * spd
	_apply_aim()
	move_and_slide()

	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			_finish_reload()
	_update_heal(delta)

	fire_cd -= delta
	if fire_held and fire_cd <= 0.0 and reloading <= 0.0 and heal_t <= 0.0:
		if ammo_mag > 0:
			shoot()
		else:
			start_reload()

	_animate(delta, world_dir.length())


func _animate(delta: float, speed01: float) -> void:
	var aiming := fire_held or zoom_idx > 0
	if speed01 > 0.3 and is_on_floor():
		walk_phase += delta * (6.0 + speed01 * 7.0)
		var s := sin(walk_phase) * (0.55 if not aiming else 0.25)
		arm_l.rotation.x = s
		arm_r.rotation.x = -s
		leg_l.rotation.x = -s
		leg_r.rotation.x = s
		visual.position.y = abs(sin(walk_phase)) * 0.05
	elif aiming:
		arm_l.rotation.x = -1.15
		arm_r.rotation.x = -1.15
		leg_l.rotation.x = 0.0
		leg_r.rotation.x = 0.0
	else:
		arm_l.rotation.x = lerpf(arm_l.rotation.x, 0.0, delta * 8.0)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, 0.0, delta * 8.0)
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, delta * 8.0)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, delta * 8.0)
	if crouching:
		leg_l.rotation.x = 0.9
		leg_r.rotation.x = -0.7
		torso.rotation.x = 0.25
	else:
		torso.rotation.x = 0.0
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			flash_m.visible = false


func _keyboard_input(delta: float) -> void:
	var ix := Input.get_axis("move_left", "move_right")
	var iy := Input.get_axis("move_forward", "move_back")
	if Vector2(ix, iy).length() > 0.01:
		move_input = Vector2(ix, iy)
	if Input.is_key_pressed(KEY_Q):
		aim_yaw += 2.2 * delta
	if Input.is_key_pressed(KEY_E):
		aim_yaw -= 2.2 * delta
	if Input.is_action_pressed("fire"):
		fire_held = true
	elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Touch FIRE button hi fire ka zariya hai; keyboard chhuta to ruko
		pass


func release_trigger() -> void:
	# Touch FIRE chhutne par HUD bulayega
	fire_held = false
	if Input.is_action_pressed("fire") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		fire_held = true


func try_jump() -> void:
	if alive and is_on_floor() and driving == null:
		velocity.y = 8.5


func _aim_point() -> Vector3:
	# Camera center se 120m tak ray - jahan dekhoge wahin nishana
	if is_player and cam != null:
		var vp := get_viewport()
		if vp != null:
			var center := vp.get_visible_rect().size * 0.5
			var from := cam.project_ray_origin(center)
			var to: Vector3 = from + cam.project_ray_normal(center) * 120.0
			var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				return hit["position"]
			return to
	var fwd := -global_transform.basis.z
	return muzzle.global_position + fwd * 60.0


func shoot() -> void:
	if not alive or reloading > 0.0:
		return
	if ammo_mag <= 0:
		start_reload()
		return
	ammo_mag -= 1
	fire_cd = float(GUNS[gun]["interval"])
	var arena := get_tree().current_scene
	if arena == null or not arena.has_method("get_bullet"):
		return
	var b = arena.get_bullet()
	if b == null:
		return
	b.global_position = muzzle.global_position
	var target := _aim_point()
	var dir: Vector3 = (target - muzzle.global_position).normalized()
	var spread: float = float(GUNS[gun]["spread"]) * (0.6 if crouching else 1.0)
	if zoom_idx == 2:
		spread *= 0.4
	if not is_player:
		var bm: Dictionary = Settings.bot_mult()
		spread = 0.05 * float(bm["err"])
		if crouching:
			spread *= 0.7
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	dir.y += randf_range(-spread * 0.5, spread * 0.5)
	b.setup(dir.normalized(), _gun_damage(), self)
	flash_m.visible = true
	flash_t = 0.06
	Sfx.play(str(GUNS[gun]["sound"]))


func _gun_damage() -> float:
	var d := float(GUNS[gun]["dmg"])
	if not is_player:
		d *= float(Settings.bot_mult()["dmg"])
	return d


func start_reload() -> void:
	if reloading > 0.0 or ammo_reserve <= 0 or ammo_mag >= mag_size():
		return
	reloading = 2.2
	Sfx.play("reload")


func _finish_reload() -> void:
	var need := mag_size() - ammo_mag
	var take := mini(need, ammo_reserve)
	ammo_mag += take
	ammo_reserve -= take


func start_heal(kind: String) -> bool:
	if heal_t > 0.0 or not alive:
		return false
	if kind == "medkit" and medkits > 0:
		heal_t = 5.0
	elif kind == "bandage" and bandages > 0:
		heal_t = 1.2
	elif kind == "drink" and drinks > 0:
		heal_t = 3.0
	else:
		return false
	heal_total = heal_t
	heal_kind = kind
	return true


func _update_heal(delta: float) -> void:
	if heal_t <= 0.0:
		return
	# Medkit/drink: hile ya goli lagi to cancel
	if heal_kind != "bandage" and move_input.length() > 0.1:
		heal_t = 0.0
		heal_kind = ""
		return
	heal_t -= delta
	if heal_t <= 0.0:
		if heal_kind == "medkit":
			medkits -= 1
			hp = MAX_HP
		elif heal_kind == "bandage":
			bandages -= 1
			hp = minf(MAX_HP, hp + 15.0)
		elif heal_kind == "drink":
			drinks -= 1
			hp = minf(MAX_HP, hp + 40.0)
		heal_kind = ""


func cancel_heal_on_damage() -> void:
	if heal_kind == "medkit" or heal_kind == "drink":
		heal_t = 0.0
		heal_kind = ""


func throw_grenade(target: Vector3) -> void:
	if grenades <= 0 or not alive:
		return
	grenades -= 1
	var arena := get_tree().current_scene
	if arena != null and arena.has_method("spawn_grenade"):
		arena.spawn_grenade(muzzle.global_position, target, self)


func take_damage(amount: float, from = null) -> void:
	if not alive:
		return
	last_hit_by = from
	var a := amount
	if helmet and helmet_hp > 0.0:
		a *= 0.8
		helmet_hp -= amount
		if helmet_hp <= 0.0:
			helmet = false
			helmet_m.visible = false
	if vest and vest_hp > 0.0:
		a *= 0.75
		vest_hp -= amount
		if vest_hp <= 0.0:
			vest = false
			vest_m.visible = false
	hp -= a
	_flash_hit()
	cancel_heal_on_damage()
	if is_player:
		Sfx.play("hurt")
		Sfx.buzz(40)
	if hp <= 0.0:
		hp = 0.0
		alive = false
		if from != null and from != self and from is Fighter and (from as Fighter).is_player:
			(from as Fighter).kills += 1
			Sfx.buzz(60)
		died.emit(self)
		_die_fall()


func _die_fall() -> void:
	set_physics_process(false)
	col.set_deferred("disabled", true)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(visual, "rotation:x", -1.5, 0.5)
	tw.tween_property(visual, "position:y", 0.3, 0.5)
	tw.chain().tween_interval(0.8)
	tw.tween_callback(queue_free)


func _flash_hit() -> void:
	if body_mat == null:
		return
	body_mat.emission_enabled = true
	body_mat.emission = Color(1, 0.2, 0.2)
	body_mat.emission_energy_multiplier = 2.0
	var tw := create_tween()
	tw.tween_property(body_mat, "emission_energy_multiplier", 0.0, 0.25)


# ---------------- BOT BRAIN ----------------

func _nearest_enemy(max_dist: float) -> Fighter:
	var best: Fighter = null
	var best_d := max_dist
	for n in get_tree().get_nodes_in_group("fighters"):
		if n == self:
			continue
		var f := n as Fighter
		if f == null or not f.alive:
			continue
		var d := global_position.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best


func _has_los(target: Fighter) -> bool:
	var from: Vector3 = global_position + Vector3(0, 1.5, 0)
	var to: Vector3 = target.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	return hit.get("collider") == target


func _bot_think(delta: float) -> void:
	think_cd -= delta
	wander_cd -= delta
	burst_cd -= delta
	nade_cd -= delta
	if think_cd > 0.0:
		return
	think_cd = 0.25
	var arena := get_tree().current_scene
	var live := true
	if arena != null and arena.has_method("is_live"):
		live = arena.is_live()
	var target := _nearest_enemy(42.0)

	if personality == 2 and arena != null and arena.has_method("get_loot_point"):
		# Lootera: air-drop/loot ki taraf
		var lp: Vector3 = arena.get_loot_point()
		if target == null or global_position.distance_to(target.global_position) > 18.0:
			_go_to(Vector2(lp.x, lp.z))
			fire_held = false
			if target != null and global_position.distance_to(target.global_position) < 16.0:
				_engage(target, delta)
			return

	if target != null and live:
		var to: Vector3 = target.global_position - global_position
		var dist := to.length()
		var engage_r := 40.0
		if personality == 1:
			engage_r = 30.0
		if (target as Fighter).crouching:
			engage_r *= 0.65
		if dist < engage_r and _has_los(target):
			_engage(target, delta)
			return
		elif personality == 0 and dist < 60.0:
			# Rusher: door se bhi daudke aayega
			_go_to(Vector2(target.global_position.x, target.global_position.z))
			fire_held = false
			return
	# Wander / zone ki taraf
	if arena != null and arena.has_method("get_zone_info"):
		var zi: Dictionary = arena.get_zone_info()
		var c: Vector2 = zi["center"]
		var r: float = zi["radius"]
		var me := Vector2(global_position.x, global_position.z)
		if me.distance_to(c) > r * 0.9:
			_go_to(c)
			fire_held = false
			return
	if personality == 1:
		move_input = Vector2.ZERO
		fire_held = false
		return
	if wander_cd <= 0.0:
		wander_cd = randf_range(2.0, 4.0)
		var a := randf() * TAU
		aim_yaw = a
	move_input = Vector2(0, -1)
	fire_held = false


func _go_to(p: Vector2) -> void:
	var d := p - Vector2(global_position.x, global_position.z)
	if d.length() < 2.0:
		move_input = Vector2.ZERO
		return
	aim_yaw = atan2(-d.x, -d.y)
	move_input = Vector2(0, -1)


func _engage(target: Fighter, _delta: float) -> void:
	var to: Vector3 = target.global_position - global_position
	var dist := to.length()
	var want_yaw := atan2(-to.x, -to.z)
	aim_yaw = want_yaw
	aim_pitch = clamp(-(to.y - 0.4) / maxf(dist, 1.0), -0.5, 0.3)
	var bm: Dictionary = Settings.bot_mult()
	var fwd_amount := 0.0
	if personality == 0:
		fwd_amount = -0.8 if dist > 12.0 else 0.4
	else:
		if dist > 20.0:
			fwd_amount = -1.0
		elif dist < 10.0:
			fwd_amount = 1.0
	var side := sin(Time.get_ticks_msec() / 700.0 + float(get_instance_id() % 10)) * strafe_sign
	move_input = Vector2(side, fwd_amount)
	fire_held = dist < 36.0 and burst_cd <= 0.0
	if randf() < 0.05:
		burst_cd = randf_range(0.5, 1.2) * float(bm["burst"])
		if randf() < 0.3:
			strafe_sign = -strafe_sign
	# Hard bot: cover me chhupe dushman par grenade
	if Settings.difficulty == 2 and nade_cd <= 0.0 and grenades > 0 and dist < 26.0 and dist > 8.0:
		if not _has_los(target) or randf() < 0.3:
			nade_cd = 10.0
			throw_grenade(target.global_position)
