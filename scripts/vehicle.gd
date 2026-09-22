class_name Jeep
extends CharacterBody3D
## Chalane layak jeep: betho, joystick se chalao, bots ko udao.

const MAX_SPEED := 16.0
const ACCEL := 12.0
const TURN := 1.6

var hp := 200.0
var dead := false
var driver = null
var speed := 0.0
var steer_vis: Array = []
var smoke_t := 0.0
var last_hit := {}
var body_mat: StandardMaterial3D


static func make(pos: Vector3, yaw: float) -> Jeep:
	var j := Jeep.new()
	j.position = pos
	j.rotation.y = yaw
	return j


func _ready() -> void:
	add_to_group("jeeps")
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.35, 0.4, 0.2)
	body_mat.roughness = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.12, 0.14)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.15, 0.25, 0.35)
	glass.metallic = 0.6
	glass.roughness = 0.2
	_box(Vector3(2.0, 0.7, 4.2), Vector3(0, 0.9, 0), body_mat)
	_box(Vector3(1.8, 0.7, 2.0), Vector3(0, 1.6, 0.3), glass)
	_box(Vector3(2.0, 0.15, 4.2), Vector3(0, 2.0, 0), body_mat)
	# Headlights
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1, 0.95, 0.8)
	lamp.emission_enabled = true
	lamp.emission = Color(1, 0.95, 0.8)
	lamp.emission_energy_multiplier = 3.0
	_box(Vector3(0.3, 0.2, 0.1), Vector3(-0.6, 0.9, -2.12), lamp)
	_box(Vector3(0.3, 0.2, 0.1), Vector3(0.6, 0.9, -2.12), lamp)
	# Wheels
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.08, 0.08, 0.09)
	for x in [-1.0, 1.0]:
		for z in [-1.4, 1.4]:
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.45
			cyl.bottom_radius = 0.45
			cyl.height = 0.3
			w.mesh = cyl
			w.material_override = wm
			w.rotation.z = PI / 2.0
			w.position = Vector3(1.05 * x, 0.45, z)
			add_child(w)
			if z < 0.0:
				steer_vis.append(w)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.8, 4.2)
	col.shape = shape
	col.position = Vector3(0, 1.1, 0)
	add_child(col)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func seat_pos() -> Vector3:
	return global_transform * Vector3(0, 1.45, 0.6)


func enter(p) -> void:
	if dead or driver != null:
		return
	driver = p
	p.set_drive_mode(self)
	p.global_position = seat_pos()
	Sfx.engine_start()


func exit_driver(hurt: float) -> void:
	if driver == null:
		return
	var p = driver
	driver = null
	Sfx.engine_stop()
	var side: Vector3 = global_transform.basis.x.normalized() * 2.4
	p.set_drive_mode(null)
	p.global_position = global_position + side + Vector3(0, 1.0, 0)
	if hurt > 0.0:
		p.take_damage(hurt, null)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	if driver != null:
		var throt := -driver.move_input.y
		var steer := driver.move_input.x
		speed = move_toward(speed, throt * MAX_SPEED, ACCEL * delta * (1.0 if abs(throt) > 0.05 else 3.0))
		if abs(speed) > 0.5:
			rotation.y -= steer * TURN * delta * sign(speed)
		driver.global_position = seat_pos()
		driver.rotation.y = rotation.y
		Sfx.engine_update(abs(speed) / MAX_SPEED)
	else:
		speed = move_toward(speed, 0.0, ACCEL * delta)
	velocity = -global_transform.basis.z * speed
	velocity.y = minf(velocity.y, 0.0) if is_on_floor() else velocity.y
	move_and_slide()
	for w in steer_vis:
		(w as MeshInstance3D).rotation.y = -driver.move_input.x * 0.4 if driver != null else 0.0
	_run_over()
	_smoke(delta)


func _run_over() -> void:
	if abs(speed) < 6.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for n in get_tree().get_nodes_in_group("fighters"):
		if n == driver:
			continue
		var f := n as Fighter
		if f == null or not f.alive:
			continue
		var d: Vector3 = f.global_position - global_position
		d.y = 0.0
		if d.length() < 2.8:
			var last: float = float(last_hit.get(f.get_instance_id(), -10.0))
			if now - last > 1.0:
				last_hit[f.get_instance_id()] = now
				f.take_damage(60.0, driver)


func _smoke(delta: float) -> void:
	if hp > 80.0:
		return
	smoke_t -= delta
	if smoke_t > 0.0:
		return
	smoke_t = 0.4
	var arena := get_tree().current_scene
	if arena != null and arena.has_method("puff"):
		arena.puff(global_position + Vector3(0, 2.2, -1.0))


func take_damage(amount: float, _from = null) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		dead = true
		body_mat.albedo_color = Color(0.1, 0.1, 0.1)
		var arena := get_tree().current_scene
		if arena != null and arena.has_method("explode"):
			arena.explode(global_position + Vector3(0, 1, 0), 40.0, 4.0, null)
		exit_driver(30.0)


func honk() -> void:
	if not dead:
		Sfx.play("horn")
