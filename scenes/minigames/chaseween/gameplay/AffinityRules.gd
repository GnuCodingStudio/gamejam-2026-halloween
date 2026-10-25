class_name FactionFightAffinityRules
extends RefCounted

enum Reaction { EFFECTIVE, WEAK, INVERSE }

const MATRIX: Dictionary = {
	&"sugar_spray": {
		&"goblin": Reaction.EFFECTIVE,
		&"paladin": Reaction.WEAK,
		&"conqueror": Reaction.INVERSE,
	},
	&"candy_cane": {
		&"goblin": Reaction.EFFECTIVE,
		&"paladin": Reaction.WEAK,
		&"conqueror": Reaction.EFFECTIVE,
	},
	&"caramel_shield": {
		&"goblin": Reaction.EFFECTIVE,
		&"paladin": Reaction.EFFECTIVE,
		&"conqueror": Reaction.INVERSE,
	},
	&"ghost_lamp": {
		&"goblin": Reaction.EFFECTIVE,
		&"paladin": Reaction.EFFECTIVE,
		&"conqueror": Reaction.WEAK,
	},
}

const LABELS: Dictionary = {
	Reaction.EFFECTIVE: "CHASE_HUD_REACTION_EFFECTIVE",
	Reaction.WEAK: "CHASE_HUD_REACTION_WEAK",
	Reaction.INVERSE: "CHASE_HUD_REACTION_DANGEROUS",
}

const COLORS: Dictionary = {
	Reaction.EFFECTIVE: Color(0.2, 1.0, 0.72),
	Reaction.WEAK: Color(1.0, 0.78, 0.18),
	Reaction.INVERSE: Color(1.0, 0.2, 0.08),
}


static func reaction(item_id: StringName, monster_type: StringName) -> int:
	var item_rules: Dictionary = MATRIX.get(item_id, {})
	return int(item_rules.get(monster_type, Reaction.WEAK))


static func label(reaction_id: int) -> String:
	return TranslationServer.translate(LABELS.get(reaction_id, "CHASE_HUD_REACTION_WEAK"))


static func color(reaction_id: int) -> Color:
	return COLORS.get(reaction_id, Color.WHITE) as Color
