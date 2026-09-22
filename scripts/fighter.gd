class_name Fighter
extends CharacterBody3D
## Ek ladaku: player ho ya bot. PUBG-style third-person shooter.

signal died(fighter: Fighter)

const SPEED := 7.0
const BOT_SPEED := 5.8
const GRAVITY := 24.0
const MAX_HP := 100.0
const FIRE_INTERVAL := 0.16
const BULLET_SCENE := preload("res://scenes/bullet.tscn")

var is_player := false
var hp := MAX_HP
var alive := true
var kills := 0
var move_input := Vector2.ZERO
var aim_yaw := 0.0
var aim_pitch := -0.3
var fire_held := false
var fire_cd := 0.0
var damage := 12.0
var body_color := Color(0.2, 0.6, 1.0)

var cam_pivot: Node3D
var body_mat: StandardMaterial3D
var muzzle: Marker3D
var flash_tween: Tween

# Bot brain
var think_cd := 0.0
var wander_dir := Vector3.ZERO
var wander_cd := 0.0
var strafe_sign := 1.0
var burst_cd := 0.0


func _ready() -> void:
	add_to_group("fighters")
	_build_visuals()
	if is_player:
		_setup_camera()


func _build_visuals() -> void:
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mat.roughness = 0.7

	var body_mesh := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.7
	body_mesh.mesh = cap
	body_mesh.material_override = body_mat
	body_mesh.position = Vector3(0, 0.95, 0)
	add_child(body_mesh)

	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.28
	sph.height = 0.56
	head.mesh = sph
	head.material_override = body_mat
	head.position = Vector3(0, 1.95, 0)
	add_child(head)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.1)
	var gun := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.9)
	gun.mesh = box
	gun.material_override = dark
	gun.position = Vector3(0.3, 1.3, -0.4)
	add_child(gun)

	muzzle = Marker3D.new()
	muzzle.position = Vector3(0.3, 1.3, -0.95)
	add_child(muzzle)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.7
	col.shape = shape
	col.position = Vector3(0, 0.95, 0)
	add_child(col)


func _setup_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.position = Vector3(0, 1.6, 0)
	add_child(cam_pivot)
	var spring := SpringArm3D.new()
	spring.spring_length = 5.0
	spring.margin = 0.3
	cam_pivot.add_child(spring)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.current = true
	spring.add_child(cam)
	_apply_aim()


func _apply_aim() -> void:
	rotation.y = aim_yaw
	if cam_pivot != null:
		cam_pivot.rotation.x = aim_pitch


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if is_player:
		_keyboard_input(delta)
	else:
		_bot_think(delta)

	var spd := SPEED if is_player else BOT_SPEED
	var local := Vector3(move_input.x, 0.0, move_input.y)
	var world_dir: Vector3 = Basis(Vector3.UP, aim_yaw) * local
	if world_dir.length() > 1.0:
		world_dir = world_dir.normalized()
	velocity.x = world_dir.x * spd
	velocity.z = world_dir.z * spd
	_apply_aim()
	move_and_slide()

	fire_cd -= delta
	if fire_held and fire_cd <= 0.0:
		shoot()


func _keyboard_input(delta: float) -> void:
	var ix := Input.get_axis("move_left", "move_right")
	var iy := Input.get_axis("move_forward", "move_back")
	if Vector2(ix, iy).length() > 0.01:
		move_input = Vector2(ix, iy)
	# Q/E se camera ghumao (testing ke liye)
	if Input.is_key_pressed(KEY_Q):
		aim_yaw += 2.2 * delta
	if Input.is_key_pressed(KEY_E):
		aim_yaw -= 2.2 * delta
	if Input.is_action_pressed("fire"):
		fire_held = true


func shoot() -> void:
	if not alive:
		return
	fire_cd = FIRE_INTERVAL
	var arena := get_tree().current_scene
	if arena == null:
		return
	var b = BULLET_SCENE.instantiate()
	arena.add_child(b)
	b.global_position = muzzle.global_position
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var dir: Vector3 = (fwd * cos(aim_pitch) + Vector3.UP * sin(aim_pitch)).normalized()
	if not is_player:
		# Bot thoda nishana chookta hai
		dir = dir.rotated(Vector3.UP, randf_range(-0.07, 0.07))
		dir.y += randf_range(-0.02, 0.02)
		dir = dir.normalized()
	b.setup(dir, damage if is_player else 8.0, self)


func take_damage(amount: float, from = null) -> void:
	if not alive:
		return
	hp -= amount
	_flash_hit()
	if hp <= 0.0:
		hp = 0.0
		alive = false
		if from != null and from != self and from is Fighter and (from as Fighter).is_player:
			(from as Fighter).kills += 1
		died.emit(self)
		queue_free()


func _flash_hit() -> void:
	if body_mat == null:
		return
	body_mat.emission_enabled = true
	body_mat.emission = Color(1, 0.2, 0.2)
	body_mat.emission_energy_multiplier = 2.0
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.tween_property(body_mat, "emission_energy_multiplier", 0.0, 0.25)


func _nearest_enemy() -> Fighter:
	var best: Fighter = null
	var best_d := 1e9
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
	var collider: Object = hit.get("collider")
	return collider == target


func _bot_think(delta: float) -> void:
	think_cd -= delta
	wander_cd -= delta
	burst_cd -= delta
	if think_cd > 0.0:
		return
	think_cd = 0.25
	var target := _nearest_enemy()
	if target != null:
		var to: Vector3 = target.global_position - global_position
		var dist := to.length()
		if dist < 42.0 and _has_los(target):
			var want_yaw := atan2(-to.x, -to.z)
			aim_yaw = want_yaw
			aim_pitch = clamp(-(to.y - 0.4) / max(dist, 1.0), -0.5, 0.3)
			# Doori banaye rakho + side me hilte raho
			var fwd_amount := 0.0
			if dist > 20.0:
				fwd_amount = -1.0
			elif dist < 10.0:
				fwd_amount = 1.0
			var side := sin(Time.get_ticks_msec() / 700.0 + float(get_instance_id() % 10)) * strafe_sign
			move_input = Vector2(side, fwd_amount)
			fire_held = dist < 36.0 and burst_cd <= 0.0
			if randf() < 0.05:
				burst_cd = randf_range(0.5, 1.2)
				if randf() < 0.3:
					strafe_sign = -strafe_sign
			return
	# Koi target nahi: zone ki taraf + wander
	var arena := get_tree().current_scene
	if arena != null and arena.has_method("get_zone_info"):
		var zi: Dictionary = arena.get_zone_info()
		var c: Vector2 = zi["center"]
		var r: float = zi["radius"]
		var me := Vector2(global_position.x, global_position.z)
		if me.distance_to(c) > r * 0.9:
			var want: Vector2 = (c - me).normalized()
			aim_yaw = atan2(-want.x, -want.y)
			move_input = Vector2(0, -1)
			fire_held = false
			return
	if wander_cd <= 0.0:
		wander_cd = randf_range(2.0, 4.0)
		var a := randf() * TAU
		wander_dir = Vector3(sin(a), 0, cos(a))
		aim_yaw = atan2(wander_dir.x, wander_dir.z) + PI
	move_input = Vector2(0, -1)
	fire_held = false
