extends Control
## HUD V2: buttons, minimap, killfeed, hitmarker, cast bars, compass.

var player: Fighter
var arena: Node3D

var alive_label: Label
var zone_label: Label
var kill_label: Label
var compass_label: Label
var hp_bar: ProgressBar
var ammo_label: Label
var gun_label: Label
var reload_bar: ProgressBar
var cast_bar: ProgressBar
var cast_label: Label
var msg_label: Label
var toast_label: Label
var toast_t := 0.0
var feed_box: VBoxContainer
var hitmark: Label
var hit_t := 0.0
var cross: Label
var stick_base: Panel
var stick_knob: Panel
var fire_btn: Button
var jump_btn: Button
var aim_btn: Button
var reload_btn: Button
var crouch_btn: Button
var nade_btn: Button
var drive_btn: Button
var horn_btn: Button
var plane_btn: Button
var med_btn: Button
var band_btn: Button
var drink_btn: Button
var end_panel: Panel
var end_title: Label
var end_stats: Label
var mmap: Minimap
var mmap_t := 0.0

var move_touch := -1
var move_origin := Vector2.ZERO
var look_touch := -1
var look_last := Vector2.ZERO
const STICK_RADIUS := 90.0


class Minimap extends Control:
	var arena_ref: Node3D
	var player_ref: Fighter
	func _draw() -> void:
		var s := size.x
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.08, 0.05, 0.85))
		if arena_ref == null:
			return
		var w2m := func(p: Vector2) -> Vector2:
			return Vector2((p.x + 65.0) / 130.0 * s, (p.y + 65.0) / 130.0 * s)
		# Roads
		draw_rect(Rect2(Vector2(0, s * 0.48), Vector2(s, s * 0.04)), Color(0.25, 0.25, 0.27))
		draw_rect(Rect2(Vector2(s * 0.48, 0), Vector2(s * 0.04, s)), Color(0.25, 0.25, 0.27))
		# Houses
		for h in arena_ref.houses:
			var hp: Vector2 = h["pos"]
			var hs: Vector2 = h["size"]
			var c: Vector2 = w2m.call(hp)
			var sc: Vector2 = hs / 130.0 * s
			draw_rect(Rect2(c - sc * 0.5, sc), Color(0.7, 0.6, 0.45))
		# Red zone
		if bool(arena_ref.redzone["active"]):
			var rc: Vector2 = arena_ref.redzone["center"]
			draw_circle(w2m.call(rc), float(arena_ref.redzone["r"]) / 130.0 * s, Color(1, 0.15, 0.1, 0.4))
		# Zone
		var zc: Vector2 = arena_ref.zone_center
		draw_arc(w2m.call(zc), arena_ref.zone_radius / 130.0 * s, 0, TAU, 48, Color(0.35, 0.75, 1), 3.0)
		# Air-drop
		if arena_ref.airdrop_active:
			var ap := arena_ref.airdrop_pos
			draw_circle(w2m.call(Vector2(ap.x, ap.z)), 5.0, Color(1, 0.9, 0.2))
		# Landing target flag
		if bool(arena_ref.get("has_target")):
			var tp2: Vector2 = arena_ref.get("land_target")
			draw_circle(w2m.call(tp2), 6.0, Color(1, 0.85, 0.2))
		# Jeeps
		for j in arena_ref.jeeps:
			if not (j as Jeep).dead:
				var jp: Vector3 = (j as Jeep).global_position
				draw_circle(w2m.call(Vector2(jp.x, jp.z)), 3.0, Color(0.7, 0.7, 0.75))
		# Plane path
		if arena_ref.state == "plane":
			var a: Vector3 = arena_ref.plane_from
			var b: Vector3 = arena_ref.plane_to
			draw_line(w2m.call(Vector2(a.x, a.z)), w2m.call(Vector2(b.x, b.z)), Color(1, 1, 1, 0.7), 2.0)
		# Player arrow
		if player_ref != null and player_ref.alive:
			var pp: Vector3 = player_ref.global_position
			var c2: Vector2 = w2m.call(Vector2(pp.x, pp.z))
			var yaw: float = player_ref.aim_yaw
			var fwd := Vector2(-sin(yaw), -cos(yaw)) * 8.0
			var rgt := Vector2(-fwd.y, fwd.x) * 0.6
			draw_colored_polygon([c2 + fwd, c2 - fwd * 0.6 + rgt * 4.0, c2 - fwd * 0.6 - rgt * 4.0], Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(s / 2 - 6, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_minimap()
	_build_feed()
	_build_bottom()
	_build_buttons()
	_build_end_panel()
	_build_crosshair()


func bind(p: Fighter, a: Node3D) -> void:
	player = p
	arena = a
	mmap.arena_ref = a
	mmap.player_ref = p
	refresh(12, "Zone", 100.0, 0)
	_update_plane_ui()


func _mk_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_top() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_top = 8
	top.offset_right = -260
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 36)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	alive_label = _mk_label("ALIVE 12", 28)
	zone_label = _mk_label("Zone", 28)
	kill_label = _mk_label("KILLS 0", 28)
	top.add_child(alive_label)
	top.add_child(zone_label)
	top.add_child(kill_label)
	compass_label = _mk_label("N 0°", 24)
	compass_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass_label.position = Vector2(-60, 48)
	compass_label.size = Vector2(120, 32)
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(compass_label)
	msg_label = _mk_label("", 30)
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.position = Vector2(-300, 86)
	msg_label.size = Vector2(600, 44)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(msg_label)
	toast_label = _mk_label("", 24)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-300, 130)
	toast_label.size = Vector2(600, 36)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(toast_label)


func _build_minimap() -> void:
	mmap = Minimap.new()
	mmap.custom_minimum_size = Vector2(230, 230)
	mmap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mmap.position = Vector2(-242, 10)
	mmap.mouse_filter = Control.MOUSE_FILTER_STOP
	mmap.gui_input.connect(_on_mmap_tap)
	add_child(mmap)


func _build_feed() -> void:
	feed_box = VBoxContainer.new()
	feed_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	feed_box.position = Vector2(16, 50)
	feed_box.add_theme_constant_override("separation", 2)
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feed_box)


func _circle_panel(d: float, color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(d, d)
	p.size = Vector2(d, d)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = int(d / 2)
	sb.corner_radius_top_right = int(d / 2)
	sb.corner_radius_bottom_left = int(d / 2)
	sb.corner_radius_bottom_right = int(d / 2)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _small_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(110, 76)
	return b


func _build_bottom() -> void:
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(380, 24)
	hp_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hp_bar.position = Vector2(-190, -64)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bar)
	ammo_label = _mk_label("30/120", 30)
	ammo_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ammo_label.position = Vector2(-190, -110)
	ammo_label.size = Vector2(380, 40)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ammo_label)
	gun_label = _mk_label("RIFLE", 22)
	gun_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	gun_label.position = Vector2(-190, -140)
	gun_label.size = Vector2(380, 30)
	gun_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(gun_label)
	reload_bar = ProgressBar.new()
	reload_bar.min_value = 0
	reload_bar.max_value = 1
	reload_bar.show_percentage = false
	reload_bar.custom_minimum_size = Vector2(200, 10)
	reload_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	reload_bar.position = Vector2(-100, -38)
	reload_bar.visible = false
	reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reload_bar)
	cast_bar = ProgressBar.new()
	cast_bar.min_value = 0
	cast_bar.max_value = 1
	cast_bar.show_percentage = false
	cast_bar.custom_minimum_size = Vector2(260, 12)
	cast_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cast_bar.position = Vector2(-130, -24)
	cast_bar.visible = false
	cast_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cast_bar)
	cast_label = _mk_label("", 20)
	cast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cast_label.position = Vector2(-130, -48)
	cast_label.size = Vector2(260, 26)
	cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(cast_label)
	stick_base = _circle_panel(220, Color(1, 1, 1, 0.15))
	stick_base.visible = false
	add_child(stick_base)
	stick_knob = _circle_panel(100, Color(1, 1, 1, 0.4))
	stick_knob.visible = false
	add_child(stick_knob)


func _build_buttons() -> void:
	fire_btn = Button.new()
	fire_btn.text = "FIRE"
	fire_btn.add_theme_font_size_override("font_size", 32)
	fire_btn.custom_minimum_size = Vector2(165, 165)
	fire_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_btn.position = Vector2(-205, -225)
	_style_round(fire_btn, 82, Color(0.85, 0.25, 0.2, 0.78), Color(1, 0.4, 0.3, 0.95))
	fire_btn.button_down.connect(_on_fire_down)
	fire_btn.button_up.connect(_on_fire_up)
	add_child(fire_btn)
	# Right column small buttons
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	col.position = Vector2(-350, -520)
	col.custom_minimum_size = Vector2(120, 400)
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	aim_btn = _small_btn("AIM x1")
	aim_btn.pressed.connect(_on_aim)
	col.add_child(aim_btn)
	reload_btn = _small_btn("RLD")
	reload_btn.pressed.connect(func() -> void:
		if player != null:
			player.start_reload())
	col.add_child(reload_btn)
	jump_btn = _small_btn("JUMP")
	jump_btn.pressed.connect(_on_jump)
	col.add_child(jump_btn)
	crouch_btn = _small_btn("CRCH")
	crouch_btn.pressed.connect(_on_crouch)
	col.add_child(crouch_btn)
	nade_btn = _small_btn("BOMB")
	nade_btn.pressed.connect(_on_nade)
	col.add_child(nade_btn)
	# Heal row (bottom center, above hp)
	var heal := HBoxContainer.new()
	heal.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	heal.position = Vector2(-190, -180)
	heal.add_theme_constant_override("separation", 10)
	add_child(heal)
	med_btn = _small_btn("MED")
	med_btn.pressed.connect(func() -> void: _try_heal("medkit"))
	heal.add_child(med_btn)
	band_btn = _small_btn("BND")
	band_btn.pressed.connect(func() -> void: _try_heal("bandage"))
	heal.add_child(band_btn)
	drink_btn = _small_btn("DRK")
	drink_btn.pressed.connect(func() -> void: _try_heal("drink"))
	heal.add_child(drink_btn)
	# Drive / plane contextual
	drive_btn = Button.new()
	drive_btn.text = "DRIVE"
	drive_btn.add_theme_font_size_override("font_size", 30)
	drive_btn.custom_minimum_size = Vector2(220, 90)
	drive_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	drive_btn.position = Vector2(-110, -260)
	drive_btn.visible = false
	drive_btn.pressed.connect(_on_drive)
	add_child(drive_btn)
	horn_btn = _small_btn("HORN")
	horn_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	horn_btn.position = Vector2(120, -260)
	horn_btn.visible = false
	horn_btn.pressed.connect(func() -> void:
		if player != null and player.driving != null:
			player.driving.honk())
	add_child(horn_btn)
	plane_btn = Button.new()
	plane_btn.text = "🪂 TAP TO JUMP!"
	plane_btn.add_theme_font_size_override("font_size", 40)
	plane_btn.custom_minimum_size = Vector2(420, 110)
	plane_btn.set_anchors_preset(Control.PRESET_CENTER)
	plane_btn.position = Vector2(-210, -55)
	plane_btn.visible = false
	plane_btn.pressed.connect(func() -> void:
		if arena != null:
			arena.player_jump())
	add_child(plane_btn)


func _style_round(b: Button, r: int, c: Color, cp: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	b.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate() as StyleBoxFlat
	sb2.bg_color = cp
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_color_override("font_color", Color.WHITE)


func _build_end_panel() -> void:
	end_panel = Panel.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.custom_minimum_size = Vector2(560, 460)
	end_panel.position = Vector2(-280, -230)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.95)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.3, 0.8, 0.4)
	end_panel.add_theme_stylebox_override("panel", sb)
	end_panel.visible = false
	add_child(end_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 30
	vb.offset_top = 30
	vb.offset_right = -30
	vb.offset_bottom = -30
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	end_panel.add_child(vb)
	end_title = _mk_label("", 54)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_title)
	end_stats = _mk_label("", 28)
	end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_stats)
	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.add_theme_font_size_override("font_size", 32)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	vb.add_child(again)
	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.add_theme_font_size_override("font_size", 28)
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vb.add_child(menu)


func _build_crosshair() -> void:
	cross = _mk_label("+", 34)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-17, -25)
	cross.size = Vector2(34, 34)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(cross)
	hitmark = _mk_label("✕", 44)
	hitmark.set_anchors_preset(Control.PRESET_CENTER)
	hitmark.position = Vector2(-22, -32)
	hitmark.size = Vector2(44, 44)
	hitmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmark.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	hitmark.visible = false
	add_child(hitmark)


# ---------- updates ----------

func refresh(alive: int, zone_text: String, hp: float, kills: int) -> void:
	alive_label.text = "ALIVE %d" % alive
	zone_label.text = zone_text
	kill_label.text = "KILLS %d" % kills
	hp_bar.value = hp
	var style := hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		hp_bar.add_theme_stylebox_override("fill", style)
	style.bg_color = Color(0.3, 0.8, 0.35) if hp > 35.0 else Color(0.9, 0.25, 0.2)


func _process(delta: float) -> void:
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			toast_label.text = ""
	if hit_t > 0.0:
		hit_t -= delta
		if hit_t <= 0.0:
			hitmark.visible = false
	if player == null:
		return
	# Compass
	var deg := posmod(int(round(-rad_to_deg(player.aim_yaw))), 360)
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	compass_label.text = "%s %d°" % [dirs[int(fposmod(deg + 22.5, 360.0) / 45.0) % 8], deg]
	if arena != null and str(arena.get("state")) == "chute" and player != null:
		if bool(arena.get("has_target")):
			var tp: Vector2 = arena.get("land_target")
			var dd := Vector2(player.global_position.x, player.global_position.z).distance_to(tp)
			msg_label.text = "🎯 %dm" % int(dd)
		else:
			msg_label.text = "Minimap par tap = landing!"
	ammo_label.text = "%d/%d" % [player.ammo_mag, player.ammo_reserve]
	gun_label.text = "%s%s" % [player.gun.to_upper(), " +MAG" if player.ext_mag else ""]
	nade_btn.text = "BMB %d" % player.grenades
	med_btn.text = "MED %d" % player.medkits
	band_btn.text = "BND %d" % player.bandages
	drink_btn.text = "DRK %d" % player.drinks
	aim_btn.text = "AIM x%d" % [1, 2, 4][clampi(player.zoom_idx, 0, 2)]
	crouch_btn.text = "DOWN" if player.crouching else "CRCH"
	reload_bar.visible = player.reloading > 0.0
	if player.reloading > 0.0:
		reload_bar.value = 1.0 - player.reloading / 2.2
	cast_bar.visible = player.heal_t > 0.0
	if player.heal_t > 0.0:
		cast_bar.value = 1.0 - player.heal_t / player.heal_total
		cast_label.text = "HEALING - MAT HILO!"
	else:
		cast_label.text = ""
	# Drive button
	if arena != null and player.driving == null and player.alive:
		drive_btn.visible = arena.call("nearby_jeep", player) != null
		if drive_btn.visible:
			drive_btn.text = "DRIVE"
	elif player != null and player.driving != null:
		drive_btn.visible = true
		drive_btn.text = "EXIT"
		horn_btn.visible = true
	else:
		drive_btn.visible = false
		horn_btn.visible = false
	# Minimap throttle
	mmap_t -= delta
	if mmap_t <= 0.0:
		mmap_t = 0.25
		mmap.queue_redraw()


func _update_plane_ui() -> void:
	if arena != null and arena.state == "plane":
		plane_btn.visible = true
	else:
		plane_btn.visible = false


func toast(msg: String) -> void:
	toast_label.text = msg
	toast_t = 2.5


func flash_msg(msg: String) -> void:
	msg_label.text = msg
	await get_tree().create_timer(3.0).timeout
	if msg_label.text == msg:
		msg_label.text = ""


func feed(killer: String, victim: String) -> void:
	var l := _mk_label(killer + "  ☠  " + victim, 22)
	feed_box.add_child(l)
	while feed_box.get_child_count() > 4:
		(feed_box.get_child(0) as Node).queue_free()
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)
	if player != null and (killer == "YOU" or killer == player.fname):
		hitmark.visible = true
		hit_t = 0.4


func show_end(won: bool, rank: int, kills: int) -> void:
	end_panel.visible = true
	if won:
		end_title.text = "WINNER!"
		end_title.add_theme_color_override("font_color", Color(0.4, 1, 0.45))
	else:
		end_title.text = "GAME OVER #%d" % rank
		end_title.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
	var st: Dictionary = Settings.stats
	end_stats.text = "Kills: %d   Wins: %d/%d   Best: #%d" % [kills, st["wins"], st["matches"], st["best_rank"]]
	if won and player != null and player.alive:
		player.start_dance()


# ---------- buttons ----------

func _on_fire_down() -> void:
	if player != null and player.alive:
		player.fire_held = true


func _on_fire_up() -> void:
	if player != null:
		player.release_trigger()


func _on_aim() -> void:
	if player != null and player.alive:
		player.zoom_idx = (player.zoom_idx + 1) % 3
		Sfx.play("ui")


func _on_jump() -> void:
	if arena != null and arena.state == "plane":
		arena.player_jump()
		_update_plane_ui()
		return
	if player != null and player.alive and player.driving == null:
		player.try_jump()


func _on_crouch() -> void:
	if player != null and player.alive and player.driving == null:
		player.set_crouch(not player.crouching)
		Sfx.play("ui")


func _on_nade() -> void:
	if player != null and player.alive and player.driving == null:
		if player.grenades > 0:
			player.throw_grenade(player._aim_point())
		else:
			toast("Grenade khatam!")


func _try_heal(kind: String) -> void:
	if player != null and player.alive:
		if not player.start_heal(kind):
			toast("Heal nahi ho paya!")


func _on_drive() -> void:
	if player == null or not player.alive:
		return
	if player.driving != null:
		player.driving.exit_driver(0.0)
	else:
		var j = arena.call("nearby_jeep", player)
		if j != null:
			j.enter(player)


func _mmap_rect() -> Rect2:
	return Rect2(mmap.global_position, mmap.size)


func _on_mmap_tap(event: InputEvent) -> void:
	if arena == null:
		return
	var st: String = str(arena.get("state"))
	if st != "plane" and st != "chute":
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var lp: Vector2 = (event as InputEventScreenTouch).position
		var wx := lp.x / mmap.size.x * 130.0 - 65.0
		var wz := lp.y / mmap.size.y * 130.0 - 65.0
		arena.set_land_target(Vector2(wx, wz))


func _fire_rect() -> Rect2:
	return Rect2(fire_btn.global_position, fire_btn.size)


func _input(event: InputEvent) -> void:
	if player == null or not player.alive or end_panel.visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var vp := get_viewport_rect().size
		if t.pressed:
			if t.position.x < vp.x * 0.45 and move_touch == -1:
				move_touch = t.index
				move_origin = t.position
				stick_base.visible = true
				stick_knob.visible = true
				stick_base.position = t.position - Vector2(110, 110)
				stick_knob.position = t.position - Vector2(50, 50)
			elif t.position.x >= vp.x * 0.45 and look_touch == -1 and not _fire_rect().has_point(t.position) and not _mmap_rect().has_point(t.position):
				look_touch = t.index
				look_last = t.position
		else:
			if t.index == move_touch:
				move_touch = -1
				player.move_input = Vector2.ZERO
				stick_base.visible = false
				stick_knob.visible = false
			elif t.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == move_touch:
			var off := d.position - move_origin
			if off.length() > STICK_RADIUS:
				off = off.normalized() * STICK_RADIUS
			stick_knob.position = move_origin + off - Vector2(50, 50)
			player.move_input = off / STICK_RADIUS
		elif d.index == look_touch:
			var rel := d.position - look_last
			look_last = d.position
			var s := Settings.sensitivity
			player.aim_yaw -= rel.x * 0.006 * s
			player.aim_pitch = clamp(player.aim_pitch - rel.y * 0.004 * s, -0.9, 0.5)
