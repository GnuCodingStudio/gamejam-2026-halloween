class_name Faction
extends RefCounted

enum Side { PLAYER, ENEMY }

const PLAYER_COLOR := Color(0.25, 0.55, 1.0)
const ENEMY_COLOR := Color(0.9, 0.25, 0.25)


static func color_of(side: Faction.Side) -> Color:
	return PLAYER_COLOR if side == Side.PLAYER else ENEMY_COLOR


static func opponent_of(side: Faction.Side) -> Faction.Side:
	if side == Side.PLAYER:
		return Side.ENEMY
	return Side.PLAYER
