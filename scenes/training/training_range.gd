class_name TrainingRange
extends Node3D
## The training range: mobsters at the far end shoot back, at the difficulty
## picked on the title screen. Each one comes back at its spot RESPAWN_TIME
## seconds after it dies, so there is always someone to practice on. If Max
## dies, the range starts over. How many mobsters (Game.training_mobsters)
## is picked on the title screen; with none, red practice targets stand
## there instead.
##
## Mobsters and targets stand at the Marker3D children of "Mobsters" (the
## mobsters in SPOT_ORDER); the targets at PATROLLING_SPOTS slide back and
## forth. The range bakes
## a navigation mesh from the arena so they can move around its walls and
## cover.

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const TARGET_SCENE := preload("res://scenes/targets/target_dummy.tscn")
const MAX_MOBSTERS := 7
## Spots for the mobsters, the first ones first: the middle, then outwards.
const SPOT_ORDER := [1, 0, 2, 3, 4, 5, 6]
## Spot index -> how far that practice target patrols.
const PATROLLING_SPOTS := {1: 3.0, 4: 2.0}
const RESPAWN_TIME := 5.0
const RESTART_TIME := 3.0

## Off in tests and tools that need a quiet range.
@export var spawn_mobsters := true

@onready var player: Player = $Player
@onready var arena: Node3D = $Arena
@onready var spawns: Node3D = $Mobsters


func _ready() -> void:
	player.painkillers = Game.setting("start_painkillers")
	player.painkillers_changed.emit(player.painkillers)
	player.died.connect(_on_player_died)
	_bake_navigation()
	if not spawn_mobsters:
		return
	if Game.training_mobsters > 0:
		for index in SPOT_ORDER.slice(0, mini(Game.training_mobsters, spawns.get_child_count())):
			_spawn(spawns.get_child(index) as Node3D)
		return
	for index in spawns.get_child_count():
		var spot := spawns.get_child(index) as Node3D
		var target: TargetDummy = TARGET_SCENE.instantiate()
		target.patrol_distance = PATROLLING_SPOTS.get(index, 0.0)
		target.position = spot.position
		spawns.add_child(target)


func _spawn(spot: Node3D) -> void:
	if not is_inside_tree() or player.state == Player.State.DEAD:
		return
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.target = player
	add_child(enemy)
	enemy.global_position = spot.global_position
	enemy.apply_difficulty()
	enemy.died.connect(func(_enemy: Enemy) -> void:
		get_tree().create_timer(RESPAWN_TIME, false).timeout.connect(_spawn.bind(spot)))


func _on_player_died() -> void:
	get_tree().create_timer(RESTART_TIME, false).timeout.connect(_restart)


func _restart() -> void:
	if is_inside_tree():
		get_tree().reload_current_scene()


func _bake_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	add_child(region)
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = &"training_navigation"
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	arena.add_to_group(&"training_navigation")
	region.navigation_mesh = mesh
	region.bake_navigation_mesh(false)
