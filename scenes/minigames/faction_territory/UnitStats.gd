class_name UnitStats
extends Resource

@export var display_name := ""
@export var model_scene: PackedScene

@export_group("Combat")
@export var max_health := 50.0
@export var damage := 10.0
@export var attack_range := 1.5
@export var attack_interval := 1.0

@export_group("Movement")
@export var move_speed := 3.0

@export_group("Spawn")
@export var cooldown := 5.0
## Number of spawned units required before the button appears (0 = available from start).
@export var unlock_after_spawns := 0
