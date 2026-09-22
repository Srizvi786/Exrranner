extends Area3D
## Goli: tez projectile, takrane par damage.

var dir := Vector3.FORWARD
var speed := 60.0
var damage := 12.0
var shooter = null
var life := 2.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.15
	col.shape = sph
	add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.08, 0.5)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.8, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.6, 0.1)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)
	body_entered.connect(_on_body_entered)


func setup(d: Vector3, dmg: float, s) -> void:
	dir = d.normalized()
	damage = dmg
	shooter = s
	if dir.length() > 0.01:
		basis = Basis.looking_at(dir)


func _physics_process(delta: float) -> void:
	global_position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body != null and body.has_method("take_damage"):
		body.take_damage(damage, shooter)
	queue_free()
