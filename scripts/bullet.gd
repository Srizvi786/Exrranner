extends Area3D
## Moti chamakdar tracer goli. Pool me reuse hoti hai (low-end optimization).

var dir := Vector3.FORWARD
var speed := 70.0
var damage := 12.0
var shooter = null
var life := 0.0
var active := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	monitoring = false
	visible = false
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.2
	col.shape = sph
	add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.14, 1.4)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.65, 0.15)
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)
	body_entered.connect(_on_body_entered)


func setup(d: Vector3, dmg: float, s) -> void:
	dir = d.normalized()
	damage = dmg
	shooter = s
	life = 1.6
	active = true
	visible = true
	set_deferred("monitoring", true)
	if dir.length() > 0.01:
		basis = Basis.looking_at(dir)


func deactivate() -> void:
	active = false
	visible = false
	set_deferred("monitoring", false)
	global_position = Vector3(0, -100, 0)


func _physics_process(delta: float) -> void:
	if not active:
		return
	global_position += dir * speed * delta
	life -= delta
	if life <= 0.0 or global_position.y < -2.0:
		deactivate()


func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body == shooter:
		return
	if body != null and body.has_method("take_damage"):
		body.take_damage(damage, shooter)
		var arena := get_tree().current_scene
		if arena != null and arena.has_method("spark"):
			arena.spark(global_position)
	deactivate()
