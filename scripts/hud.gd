extends Control
## HUD: health, alive, zone, kills + touch joystick + FIRE button.

var player: Fighter
var arena: Node3D

var alive_label: Label
var zone_label: Label
var kill_label: Label
var hp_bar: ProgressBar
var msg_label: Label
var stick_base: Panel
var stick_knob: Panel
var fire_btn: Button
var end_panel: Panel
var end_title: Label
var end_stats: Label

var move_touch := -1
var move_origin := Vector2.ZERO
var look_touch := -1
var look_last := Vector2.ZERO
const STICK_RADIUS := 90.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_bottom()
	_build_end_panel()


func bind(p: Fighter, a: Node3D) -> void:
	player = p
	arena = a
	refresh(12, "Zone", 100.0, 0)


func _mk_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _build_top() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_top = 10
	top.offset_right = -16
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 40)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	alive_label = _mk_label("ALIVE 12", 30)
	zone_label = _mk_label("Zone", 30)
	kill_label = _mk_label("KILLS 0", 30)
	top.add_child(alive_label)
	top.add_child(zone_label)
	top.add_child(kill_label)

	msg_label = _mk_label("", 26)
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.position = Vector2(-200, 60)
	msg_label.size = Vector2(400, 40)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(msg_label)


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


func _build_bottom() -> void:
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(420, 26)
	hp_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hp_bar.position = Vector2(-210, -70)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bar)

	stick_base = _circle_panel(220, Color(1, 1, 1, 0.15))
	stick_base.visible = false
	add_child(stick_base)
	stick_knob = _circle_panel(100, Color(1, 1, 1, 0.4))
	stick_knob.visible = false
	add_child(stick_knob)

	fire_btn = Button.new()
	fire_btn.text = "FIRE"
	fire_btn.add_theme_font_size_override("font_size", 34)
	fire_btn.custom_minimum_size = Vector2(170, 170)
	fire_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_btn.position = Vector2(-210, -230)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.85, 0.25, 0.2, 0.75)
	fsb.corner_radius_top_left = 85
	fsb.corner_radius_top_right = 85
	fsb.corner_radius_bottom_left = 85
	fsb.corner_radius_bottom_right = 85
	fire_btn.add_theme_stylebox_override("normal", fsb)
	var fsb2 := fsb.duplicate() as StyleBoxFlat
	fsb2.bg_color = Color(1, 0.35, 0.25, 0.95)
	fire_btn.add_theme_stylebox_override("pressed", fsb2)
	fire_btn.add_theme_stylebox_override("hover", fsb)
	fire_btn.add_theme_color_override("font_color", Color.WHITE)
	fire_btn.button_down.connect(_on_fire_down)
	fire_btn.button_up.connect(_on_fire_up)
	add_child(fire_btn)


func _build_end_panel() -> void:
	end_panel = Panel.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.custom_minimum_size = Vector2(560, 420)
	end_panel.position = Vector2(-280, -210)
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
	vb.add_theme_constant_override("separation", 18)
	end_panel.add_child(vb)

	end_title = _mk_label("", 54)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_title)
	end_stats = _mk_label("", 30)
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


func show_end(won: bool, rank: int, kills: int) -> void:
	end_panel.visible = true
	if won:
		end_title.text = "WINNER!"
		end_title.add_theme_color_override("font_color", Color(0.4, 1, 0.45))
	else:
		end_title.text = "GAME OVER #%d" % rank
		end_title.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
	end_stats.text = "Kills: %d" % kills


func _on_fire_down() -> void:
	if player != null and player.alive:
		player.fire_held = true


func _on_fire_up() -> void:
	if player != null:
		player.fire_held = false


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
			elif t.position.x >= vp.x * 0.45 and look_touch == -1 and not _fire_rect().has_point(t.position):
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
			player.aim_yaw -= rel.x * 0.006
			player.aim_pitch = clamp(player.aim_pitch - rel.y * 0.004, -0.9, 0.5)
