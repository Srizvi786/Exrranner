extends Node
## Procedural sounds - koi audio file nahi, sab code se banta hai.

const RATE := 22050

var bank := {}
var players: Array = []
var engine_player: AudioStreamPlayer
var engine_on := false


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	engine_player = AudioStreamPlayer.new()
	engine_player.stream = _engine_loop()
	add_child(engine_player)
	bank["rifle"] = _shot(0.16, 0.9, 900.0)
	bank["smg"] = _shot(0.1, 0.7, 1400.0)
	bank["sniper"] = _shot(0.4, 1.0, 300.0)
	bank["boom"] = _explosion()
	bank["hit"] = _tone(1250.0, 0.07, 0.5)
	bank["hurt"] = _tone(180.0, 0.18, 0.7)
	bank["reload"] = _tone(700.0, 0.09, 0.5)
	bank["pickup"] = _tone(880.0, 0.12, 0.5)
	bank["ui"] = _tone(600.0, 0.06, 0.4)
	bank["warn"] = _tone(520.0, 0.25, 0.6)
	bank["chute"] = _noise(0.9, 0.35)


func _bytes(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size())
	for i in samples.size():
		data[i] = int(clampf(samples[i], -1.0, 1.0) * 100.0 + 128.0)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _tone(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var k := float(i) / float(n)
		s[i] = sin(TAU * freq * float(i) / RATE) * vol * (1.0 - k)
	return _bytes(s)


func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var k := float(i) / float(n)
		s[i] = randf_range(-1.0, 1.0) * vol * (1.0 - k)
	return _bytes(s)


func _shot(dur: float, vol: float, body_freq: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var k := float(i) / float(n)
		var env := (1.0 - k) * (1.0 - k)
		s[i] = (randf_range(-1.0, 1.0) * 0.7 + sin(TAU * body_freq * float(i) / RATE) * 0.5) * vol * env
	return _bytes(s)


func _explosion() -> AudioStreamWAV:
	var dur := 0.8
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var k := float(i) / float(n)
		var f := 120.0 * (1.0 - k) + 30.0
		s[i] = (sin(TAU * f * float(i) / RATE) * 0.8 + randf_range(-1.0, 1.0) * 0.5) * (1.0 - k)
	return _bytes(s)


func _engine_loop() -> AudioStreamWAV:
	var dur := 0.5
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var ph := fmod(TAU * 65.0 * float(i) / RATE, TAU)
		s[i] = (ph / PI - 1.0) * 0.35
	var w := _bytes(s)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func play(name: String, vol_db := 0.0) -> void:
	if not bank.has(name):
		return
	for p in players:
		if not (p as AudioStreamPlayer).playing:
			(p as AudioStreamPlayer).stream = bank[name]
			(p as AudioStreamPlayer).volume_db = vol_db
			(p as AudioStreamPlayer).play()
			return


func play_win() -> void:
	play("pickup")
	await get_tree().create_timer(0.12).timeout
	play("pickup", 2.0)
	await get_tree().create_timer(0.12).timeout
	play("hit", 2.0)


func engine_start() -> void:
	if not engine_on:
		engine_on = true
		engine_player.play()


func engine_stop() -> void:
	engine_on = false
	engine_player.stop()


func engine_update(speed01: float) -> void:
	if not engine_on:
		return
	engine_player.pitch_scale = 0.8 + speed01 * 0.9
	engine_player.volume_db = -8.0 + speed01 * 6.0


func buzz(ms: int) -> void:
	if OS.has_feature("android"):
		Input.vibrate_handheld(ms)
