extends Control
## Main menu: title + play + help.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1)
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.custom_minimum_size = Vector2(700, 500)
	vb.position = Vector2(-350, -250)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 22)
	add_child(vb)

	var title := Label.new()
	title.text = "BATTLEARENA"
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "12 fighters drop in. 1 survives. That is you."
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var play := Button.new()
	play.text = "▶  PLAY"
	play.add_theme_font_size_override("font_size", 44)
	play.custom_minimum_size = Vector2(380, 100)
	play.pressed.connect(_on_play)
	var pc := CenterContainer.new()
	pc.add_child(play)
	vb.add_child(pc)

	var help := Label.new()
	help.text = "Left thumb: move  |  Right thumb: aim  |  FIRE: shoot\nStay inside the blue zone. Last one standing wins!"
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(help)


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/arena.tscn")
