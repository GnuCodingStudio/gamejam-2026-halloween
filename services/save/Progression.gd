extends Node
class_name Progression


var coins: int = 0
var total_candy: int = 0
var completed_worlds: Array[StringName] = []


func _init(
	initial_coins: int = 0,
	initial_total_candy: int = 0,
	initial_completed_worlds: Array[StringName] = []
) -> void:
	self.coins = initial_coins
	self.total_candy = initial_total_candy
	self.completed_worlds = initial_completed_worlds.duplicate()
