extends Node
## Global settings + stats (phone me save hota hai).

const PATH := "user://battlearena.cfg"

var difficulty := 1  # 0 easy, 1 normal, 2 hard
var graphics := 0  # 0 low, 1 medium, 2 high
var sensitivity := 1.0
var stats := {"kills": 0, "wins": 0, "matches": 0, "best_rank": 99}


func _ready() -> void:
	load_all()


func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	difficulty = int(cfg.get_value("game", "difficulty", 1))
	graphics = int(cfg.get_value("game", "graphics", 0))
	sensitivity = float(cfg.get_value("game", "sensitivity", 1.0))
	stats["kills"] = int(cfg.get_value("stats", "kills", 0))
	stats["wins"] = int(cfg.get_value("stats", "wins", 0))
	stats["matches"] = int(cfg.get_value("stats", "matches", 0))
	stats["best_rank"] = int(cfg.get_value("stats", "best_rank", 99))


func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "graphics", graphics)
	cfg.set_value("game", "sensitivity", sensitivity)
	cfg.set_value("stats", "kills", stats["kills"])
	cfg.set_value("stats", "wins", stats["wins"])
	cfg.set_value("stats", "matches", stats["matches"])
	cfg.set_value("stats", "best_rank", stats["best_rank"])
	cfg.save(PATH)


func record_match(kills: int, rank: int, won: bool) -> void:
	stats["matches"] = int(stats["matches"]) + 1
	stats["kills"] = int(stats["kills"]) + kills
	if won:
		stats["wins"] = int(stats["wins"]) + 1
	stats["best_rank"] = mini(int(stats["best_rank"]), rank)
	save_all()


func bot_mult() -> Dictionary:
	match difficulty:
		0:
			return {"dmg": 0.6, "err": 2.0, "spd": 0.9, "burst": 1.5}
		2:
			return {"dmg": 1.35, "err": 0.55, "spd": 1.05, "burst": 0.7}
	return {"dmg": 1.0, "err": 1.0, "spd": 1.0, "burst": 1.0}


func diff_name() -> String:
	return ["EASY", "NORMAL", "HARD"][clampi(difficulty, 0, 2)]


func gfx_name() -> String:
	return ["LOW", "MEDIUM", "HIGH"][clampi(graphics, 0, 2)]
