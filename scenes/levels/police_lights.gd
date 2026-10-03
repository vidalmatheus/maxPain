class_name PoliceLights
extends Node3D
## The flashing red and blue light bar of a police car. Flashes in game time,
## so it slows down in bullet time like everything else.

const RED := Color(1.0, 0.12, 0.1)
const BLUE := Color(0.15, 0.3, 1.0)
## Flashes per second for each color.
const RATE := 2.5

var _time := randf() * 10.0
var _red: OmniLight3D
var _blue: OmniLight3D


func _ready() -> void:
	_red = _make_light(RED, Vector3(0.4, 0, 0))
	_blue = _make_light(BLUE, Vector3(-0.4, 0, 0))


func _process(delta: float) -> void:
	_time += delta
	# Each color double-flashes, alternating with the other.
	var phase := fmod(_time * RATE, 1.0)
	var red_on := phase < 0.12 or (phase > 0.2 and phase < 0.32)
	var blue_on := (phase > 0.5 and phase < 0.62) or (phase > 0.7 and phase < 0.82)
	_red.light_energy = 3.0 if red_on else 0.0
	_blue.light_energy = 3.5 if blue_on else 0.0


func _make_light(color: Color, offset: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 9.0
	light.omni_attenuation = 1.2
	light.position = offset
	add_child(light)
	return light
