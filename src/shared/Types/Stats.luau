--!strict

-- Core attribute types
export type Attributes = {
	STR: number, -- Strength
	DEX: number, -- Dexterity
	INT: number, -- Intelligence
	VIT: number, -- Vitality
}

-- Secondary/derived stats
export type DerivedStats = {
	MaxHealth: number,
	MaxMana: number,
	Armor: number,
	PhysicalDR: number, -- Damage reduction percentage
	HitChance: number,
	Evasion: number,
	CritChance: number,
	CritDamage: number,
	MeleePower: number,
	SpellPower: number,
	HealthRegen: number,
	ManaRegen: number,
	AttackSpeed: number,
}

-- Resistances
export type Resistances = {
	Fire: number,
	Ice: number,
	Poison: number,
	Arcane: number,
}

-- Current runtime stats (HP/Mana/XP)
export type RuntimeStats = {
	CurrentHealth: number,
	CurrentMana: number,
	CurrentXP: number,
}

-- Complete actor stats (player or monster)
export type ActorStats = {
	Level: number,
	Attributes: Attributes,
	DerivedStats: DerivedStats,
	Resistances: Resistances,
	RuntimeStats: RuntimeStats,
}

return {}
