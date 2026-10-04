extends Node
## Game-wide state: the chosen difficulty, whether sound is on, scene changes
## between the title screen and the survival game, and the best waves reached
## (saved to disk).

## A short message for the HUD (e.g. what was just picked up).
signal message(text: String)

enum Difficulty { FUGITIVE, HARD_BOILED, DEAD_ON_ARRIVAL }

const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const SURVIVAL_SCENE := "res://scenes/game/survival.tscn"
const SAVE_PATH := "user://save.cfg"

## Tuning per difficulty, named after Max Payne's difficulty levels.
const SETTINGS := {
	Difficulty.FUGITIVE: {
		"name": "Fugitive",
		"description": "Sloppy aim, generous drops.",
		"first_wave": 2,
		"max_alive": 4,
		"enemy_health": 70.0,
		"enemy_damage": 6.0,
		"enemy_spread_degrees": 6.0,
		"enemy_reaction_time": 1.1,
		"enemy_burst_interval": 1.9,
		"drop_adrenaline_chance": 0.55,
		"drop_painkiller_chance": 0.35,
		"start_painkillers": 3,
	},
	Difficulty.HARD_BOILED: {
		"name": "Hard-Boiled",
		"description": "The way it was meant to be played.",
		"first_wave": 3,
		"max_alive": 6,
		"enemy_health": 100.0,
		"enemy_damage": 10.0,
		"enemy_spread_degrees": 4.0,
		"enemy_reaction_time": 0.75,
		"enemy_burst_interval": 1.4,
		"drop_adrenaline_chance": 0.4,
		"drop_painkiller_chance": 0.22,
		"start_painkillers": 2,
	},
	Difficulty.DEAD_ON_ARRIVAL: {
		"name": "Dead on Arrival",
		"description": "They don't miss. Neither should you.",
		"first_wave": 4,
		"max_alive": 8,
		"enemy_health": 120.0,
		"enemy_damage": 15.0,
		"enemy_spread_degrees": 2.6,
		"enemy_reaction_time": 0.5,
		"enemy_burst_interval": 1.0,
		"drop_adrenaline_chance": 0.3,
		"drop_painkiller_chance": 0.12,
		"start_painkillers": 1,
	},
}

var difficulty := Difficulty.HARD_BOILED
## All sound (effects and music) off.
var muted := false

var _best_waves := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		difficulty = config.get_value("game", "difficulty", difficulty)
		_best_waves = config.get_value("game", "best_waves", {})
		muted = config.get_value("game", "muted", false)
	AudioServer.set_bus_mute(0, muted)


## A tuning value for the current difficulty.
func setting(key: String) -> Variant:
	return SETTINGS[difficulty][key]


func difficulty_name(level := difficulty) -> String:
	return SETTINGS[level]["name"]


func best_wave(level := difficulty) -> int:
	return _best_waves.get(level, 0)


## Remembers [param wave] if it beats the record for the current difficulty.
## Returns true for a new record.
func record_wave(wave: int) -> bool:
	if wave <= best_wave():
		return false
	_best_waves[difficulty] = wave
	_save()
	return true


## Turns all sound off or back on, and remembers it.
func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(0, muted)
	_save()


func set_difficulty(level: Difficulty) -> void:
	difficulty = level
	_save()


func start_survival() -> void:
	_change_scene(SURVIVAL_SCENE)


func go_to_title() -> void:
	_change_scene(TITLE_SCENE)


func _change_scene(path: String) -> void:
	get_tree().paused = false
	BulletTime.reset()
	get_tree().change_scene_to_file(path)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "difficulty", difficulty)
	config.set_value("game", "best_waves", _best_waves)
	config.set_value("game", "muted", muted)
	config.save(SAVE_PATH)
