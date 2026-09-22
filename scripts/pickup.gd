class_name Pickup
extends Area3D
## Zameen par pada loot: gun, goli, heal, armor. Chhune par milta hai.

const NAMES := {
	"smg": "SMG", "sniper": "SNIPER", "rifle": "RIFLE",
	"ammo": "AMMO", "medkit": "MEDKIT", "bandage": "BANDAGE",
	"drink": "DRINK", "helmet": "HELMET", "vest": "VEST",
	"grenade": "GRENADE", "extmag": "EXT-MAG",
}
const COLORS := {
	"smg": Color(0.9, 0.5, 0.1), "sniper": Color(0.6, 0.2, 0.8), "rifle": Color(0.2, 0.6, 1.0),
	"ammo": Color(0.9, 0.85, 0.3), "medkit": Color(1, 0.25, 0.25), "bandage": Color(1, 1, 1),
	"drink": Color(0.2, 1, 0.6), "helmet": Color(0.4, 0.45, 0.3), "vest": Color(0.3, 0.3, 0.25),
	"grenade": Color(0.25, 0.6, 0.25), "extmag": Color(0.5, 0.8, 1.0),
}

var kind := "ammo"
var amount := 0
var base_y := 0.0
var t := 0.0


static func make(k: String, pos: Vector3, amt := 0) -> Pickup:
	var p := Pickup.new()
	p.kind = k
	p.amount = amt
	p.position = pos + Vector3(0, 0.6, 0)
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # sirf player layer-4 se takrayega? player layer 1 hai...
	# Player CharacterBody layer 1 par hai, isliye mask 1:
	collision_mask = 1
	monitoring = true
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.1
	col.shape = sph
	add_child(col)
	_build_look()
	base_y = position.y
	body_entered.connect(_on_body)


func _build_look() -> void:
	var c: Color = COLORS.get(kind, Color.WHITE)
	var mi := MeshInstance3D.new()
	if kind == "medkit":
		var b := BoxMesh.new()
		b.size = Vector3(0.5, 0.35, 0.5)
		mi.mesh = b
		var cross := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(0.3, 0.1, 0.12)
		cross.mesh = cb
		cross.material_override = _em(Color.WHITE)
		cross.position = Vector3(0, 0.2, 0)
		add_child(cross)
	elif kind == "helmet":
		var s := SphereMesh.new()
		s.radius = 0.28
		s.height = 0.4
		mi.mesh = s
	elif kind == "bandage" or kind == "drink":
		var b := BoxMesh.new()
		b.size = Vector3(0.25, 0.4, 0.25)
		mi.mesh = b
	elif kind == "grenade":
		var s := SphereMesh.new()
		s.radius = 0.18
		s.height = 0.36
		mi.mesh = s
	else:
		var b := BoxMesh.new()
		if kind == "ammo" or kind == "extmag":
			b.size = Vector3(0.4, 0.25, 0.3)
		else:
			b.size = Vector3(0.18, 0.18, 1.0)
		mi.mesh = b
	mi.material_override = _em(c)
	add_child(mi)
	# Naam upar tairta hai
	var lab := Label3D.new()
	lab.text = str(NAMES.get(kind, kind))
	lab.font_size = 48
	lab.pixel_size = 0.008
	lab.modulate = Color(1, 1, 1)
	lab.outline_size = 8
	lab.position = Vector3(0, 0.7, 0)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(lab)


func _em(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.8
	return m


func _process(delta: float) -> void:
	t += delta
	rotation.y += delta * 1.5
	position.y = base_y + sin(t * 2.5) * 0.12


func _on_body(body: Node) -> void:
	if body is Fighter and (body as Fighter).is_player and (body as Fighter).alive:
		var arena := get_tree().current_scene
		if _apply(body as Fighter):
			if arena != null and arena.has_method("toast"):
				arena.toast("Picked: " + str(NAMES.get(kind, kind)))
			Sfx.play("pickup")
			queue_free()


func _apply(p: Fighter) -> bool:
	match kind:
		"smg", "sniper", "rifle":
			if p.gun == kind:
				p.ammo_reserve += 60
				return true
			# Purani gun zameen par girao
			var arena := get_tree().current_scene
			if arena != null and arena.has_method("spawn_pickup"):
				arena.spawn_pickup(p.gun, p.global_position, 0)
			p.gun = kind
			p.ammo_mag = int(Fighter.GUNS[kind]["mag"]) + (10 if p.ext_mag else 0)
			p.ammo_reserve = 90
			p.reloading = 0.0
			return true
		"ammo":
			p.ammo_reserve += 60
			return true
		"medkit":
			p.medkits += 1
			return true
		"bandage":
			p.bandages += 2
			return true
		"drink":
			p.drinks += 1
			return true
		"helmet":
			p.helmet = true
			p.helmet_hp = 50.0
			p.helmet_m.visible = true
			return true
		"vest":
			p.vest = true
			p.vest_hp = 50.0
			p.vest_m.visible = true
			return true
		"grenade":
			p.grenades += 1
			return true
		"extmag":
			p.ext_mag = true
			return true
	return false
