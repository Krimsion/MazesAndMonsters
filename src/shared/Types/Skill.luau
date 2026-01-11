--!strict

-- Skill/Ability types for the game

-- Skill rarity
export type SkillRarity = "Common" | "Rare" | "Epic" | "Legendary"

-- Skill type
export type SkillType = "Spell" | "Ability"

-- Damage type for skills
export type DamageType = "Fire" | "Ice" | "Lightning" | "Physical" | "Heal"

-- Projectile behavior
export type ProjectileBehavior = "Straight" | "Erratic" | "Homing"

-- Skill definition
export type Skill = {
	Id: string, -- Unique identifier
	Name: string,
	Description: string,
	Type: SkillType,
	Rarity: SkillRarity,
	Icon: string?, -- Icon asset ID (optional)

	-- Cost and requirements
	ManaCost: number,
	RequiredLevel: number,
	RequiredInt: number?, -- For spells

	-- Damage/healing
	DamageType: DamageType,
	BaseDamageMin: number?,
	BaseDamageMax: number?,
	IntScaling: number?, -- Percentage of INT that adds to damage (e.g., 0.5 = 50% of INT)

	-- Projectile properties (if applicable)
	ProjectileCount: number?, -- Number of projectiles
	ProjectileCountPerLevel: number?, -- Additional projectiles per skill level
	ProjectileSpeed: number?,
	ProjectileBehavior: ProjectileBehavior?,
	ProjectileSpreadAngle: number?, -- Spread angle in degrees (e.g., 90 for charged bolt)
	ProjectileRange: number?, -- Max distance before despawn

	-- AOE properties (if applicable)
	AOERadius: number?,

	-- Cooldown
	Cooldown: number, -- In seconds
}

-- Learned skill (player's instance of a skill)
export type LearnedSkill = {
	SkillId: string,
	Level: number, -- Skill level (1-20)
	LastUsedTime: number?, -- For cooldown tracking
}

return {}
