extends SceneTree
## Headless smoke test: arena load, jump, landing, sab state print karo.

var arena: Node3D
var frame := 0
var errors := 0


func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/arena.tscn")
	if ps == null:
		print("SMOKE FAIL: arena.tscn load nahi hui")
		errors += 1
		return
	arena = ps.instantiate()
	root.add_child(arena)
	print("SMOKE f0: state=", arena.state, " fighters=", arena.fighters.size(), " player=", arena.player != null)


func _process(_delta: float) -> bool:
	frame += 1
	if arena == null:
		return frame > 30
	if frame == 30:
		print("SMOKE f30: state=", arena.state, " plane=", arena.plane != null)
		print("SMOKE f30: hud=", arena.hud != null, " player_alive=", arena.player.alive)
	if frame == 60:
		arena.player_jump()
		print("SMOKE f60: jumped state=", arena.state)
	if frame == 120:
		var p = arena.player
		print("SMOKE f120: y=", snapped(p.global_position.y, 0.1), " hud_plane_btn=", arena.hud.plane_btn.visible)
	if frame == 700:
		var p2 = arena.player
		print("SMOKE f700: state=", arena.state, " pos=", p2.global_position, " alive=", p2.alive)
		var inside: bool = abs(p2.global_position.x) <= 64.0 and abs(p2.global_position.z) <= 64.0
		print("SMOKE inside_map=", inside, " fighters_left=", arena.fighters.size())
		if arena.state != "play":
			print("SMOKE FAIL: land nahi hua, state=", arena.state)
			errors += 1
		if not inside:
			print("SMOKE FAIL: map se bahar landing!")
			errors += 1
		print("SMOKE DONE errors=", errors)
		return true
	return false
