class_name Grenade
extends RigidBody3D
## Pheka hua bomb: 3 sec fuse, phir area damage + dhamaaka.

var fuse := 3.0
var damage := 70.0
var radius := 7.0
var shooter = null
var blink := 0.0
var ball: MeshInstance3D
var ball_mat: StandardMaterial3D


static func make(from_pos: Vector3, target: Vector3, s) -> Grenade:
	var g := Grenade.new()
	g.shooter = s
	g.position = from_pos
	var to: Vector3 = target - from_pos
	var flat := Vector3(to.x, 0, to.z)
	var dist := flat.length()
	var dir := flat.normalized() if dist > 0.5 else Vector3.FORWARD
	var speed := clampf(dist * 1.1, 8.0, 22.0)
	g.linear_velocity = dir * speed + Vector3.UP * (5.0 + dist * 0.15)
	return g


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	mass = 0.5
	linear_damp = 0.4
	angular_damp = 0.5
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.8
	physics_material_override = pm
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.18
	col.shape = sph
	add_child(col)
	ball = MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.18
	bs.height = 0.36
	ball.mesh = bs
	ball_mat = StandardMaterial3D.new()
	ball_mat.albedo_color = Color(0.2, 0.5, 0.2)
	ball_mat.emission_enabled = true
	ball_mat.emission = Color(1, 0.2, 0.1)
	ball_mat.emission_energy_multiplier = 0.0
	ball.material_override = ball_mat
	add_child(ball)


func _physics_process(delta: float) -> void:
	fuse -= delta
	if fuse < 1.0:
		blink += delta * 12.0
		ball_mat.emission_energy_multiplier = 2.0 + sin(blink) * 2.0
	if fuse <= 0.0:
		var arena := get_tree().current_scene
		if arena != null and arena.has_method("explode"):
			arena.explode(global_position, damage, radius, shooter)
		queue_free()
