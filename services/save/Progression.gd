extends Node
class_name Progression


var coins: int = 0
var total_candy: int = 0
var completed_worlds: Array[StringName] = []
var finale_seen: bool = false


func _init(
	initial_coins: int = 0,
	initial_total_candy: int = 0,
	initial_completed_worlds: Array[StringName] = [],
	initial_finale_seen: bool = false
) -> void:
	self.coins = initial_coins
	self.total_candy = initial_total_candy
	self.completed_worlds = initial_completed_worlds.duplicate()
	self.finale_seen = initial_finale_seen
