extends Control
## Main menu: play + difficulty + graphics + sensitivity + stats.

var diff_label: Label
var gfx_label: Label
var sens_label: Label
var stats_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1)
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.custom_minimum_size = Vector2(700, 620)
	vb.position = Vector2(-350, -310)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)

	vb.add_child(_title("BATTLEARENA", 76, Color(0.35, 0.9, 0.45)))
	vb.add_child(_title("12 drop in. 1 survives. That is you.", 24, Color(0.8, 0.85, 0.9)))

	var play := Button.new()
	play.text = "▶  PLAY"
	play.add_theme_font_size_override("font_size", 42)
	play.custom_minimum_size = Vector2(380, 90)
	play.pressed.connect(_on_play)
	var pc := CenterContainer.new()
	pc.add_child(play)
	vb.add_child(pc)

	# Difficulty
	var dh := HBoxContainer.new()
	dh.alignment = BoxContainer.ALIGNMENT_CENTER
	dh.add_theme_constant_override("separation", 10)
	vb.add_child(dh)
	diff_label = _title("BOTS: ", 24, Color.WHITE)
	dh.add_child(diff_label)
	for i in 3:
		var b := Button.new()
		b.text = ["EASY", "NORMAL", "HARD"][i]
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func() -> void:
			Settings.difficulty = i
			Settings.save_all()
			_refresh()
			Sfx.play("ui"))
		dh.add_child(b)

	# Graphics
	var gh := HBoxContainer.new()
	gh.alignment = BoxContainer.ALIGNMENT_CENTER
	gh.add_theme_constant_override("separation", 10)
	vb.add_child(gh)
	gfx_label = _title("GFX: ", 24, Color.WHITE)
	gh.add_child(gfx_label)
	for i in 3:
		var b2 := Button.new()
		b2.text = ["LOW", "MED", "HIGH"][i]
		b2.add_theme_font_size_override("font_size", 22)
		b2.pressed.connect(func() -> void:
			Settings.graphics = i
			Settings.save_all()
			_refresh()
			Sfx.play("ui"))
		gh.add_child(b2)

	# Sensitivity
	var sh := HBoxContainer.new()
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_theme_constant_override("separation", 10)
	vb.add_child(sh)
	sens_label = _title("AIM: ", 24, Color.WHITE)
	sh.add_child(sens_label)
	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 2.0
	slider.step = 0.1
	slider.value = Settings.sensitivity
	slider.custom_minimum_size = Vector2(300, 40)
	slider.value_changed.connect(func(v: float) -> void:
		Settings.sensitivity = v
		Settings.save_all()
		_refresh())
	sh.add_child(slider)

	stats_label = _title("", 22, Color(0.7, 0.75, 0.85))
	vb.add_child(stats_label)
	vb.add_child(_title("Left: move | Right: aim | FIRE / JUMP / AIM / RLD / BOMB", 20, Color(0.6, 0.65, 0.72)))
	_refresh()


func _title(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _refresh() -> void:
	diff_label.text = "BOTS: " + Settings.diff_name()
	gfx_label.text = "GFX: " + Settings.gfx_name()
	sens_label.text = "AIM: %.1f" % Settings.sensitivity
	var st: Dictionary = Settings.stats
	var best := str(st["best_rank"]) if int(st["best_rank"]) < 99 else "-"
	stats_label.text = "Wins %d/%d | Kills %d | Best #%s" % [st["wins"], st["matches"], st["kills"], best]


func _on_play() -> void:
	Sfx.play("ui")
	get_tree().change_scene_to_file("res://scenes/arena.tscn")
