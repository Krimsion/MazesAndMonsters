--!strict

local Stats = require(script.Parent.Parent.Types.Stats)

export type MonsterTemplate = {
	Name: string,
	Type: "Melee" | "Ranged" | "Caster",
	DamageMin: number,
	DamageMax: number,
	BaseHealth: number, -- Will be scaled by level
	BaseArmor: number, -- Will be scaled by level
	AttackSpeed: number,
	MoveSpeed: number,
	AttackRange: number, -- In tiles
	AggroRange: number, -- In tiles
	Resistances: {
		Fire: number,
		Ice: number,
		Poison: number,
		Arcane: number,
	},
	XPReward: number, -- Base XP, scaled by level
}

local MonsterTemplates = {}

-- Monster Stat Formulas from GDD:
-- Health: H = 45 + 15 * monsterLevel
-- Damage: Melee grunt: [5..8] + 1.2 * monsterLevel
-- Damage: Ranged: [3..6] + 1.0 * monsterLevel
-- Armor: A = 5 + 1.5 * monsterLevel

-- Calculate monster stats based on template and level
function MonsterTemplates.CalculateMonsterStats(template: MonsterTemplate, level: number): Stats.ActorStats
	-- Health: 45 + 15 * level
	local maxHealth = 45 + 15 * level

	-- Armor: 5 + 1.5 * level (from template base)
	local armor = template.BaseArmor + 1.5 * level

	-- Calculate attributes to match expected stats
	-- For monsters, we work backwards from expected stats
	-- STR for armor: Armor = 0.5 * STR + ArmorFromGear
	-- We'll set STR based on expected armor
	local str = 10 + level -- Base STR scaling
	local dex = 8 + math.floor(level * 0.5) -- Some DEX for hit chance
	local int = 5 -- Most monsters don't use INT
	local vit = 5 -- VIT is less important since we set health directly

	-- Adjust damage based on level
	local damageMin = template.DamageMin + (template.Type == "Melee" and (1.2 * level) or (1.0 * level))
	local damageMax = template.DamageMax + (template.Type == "Melee" and (1.2 * level) or (1.0 * level))

	return {
		Level = level,
		Attributes = {
			STR = str,
			DEX = dex,
			INT = int,
			VIT = vit,
		},
		DerivedStats = {
			MaxHealth = maxHealth,
			MaxMana = 0, -- Most monsters don't use mana
			Armor = armor,
			PhysicalDR = armor / (armor + 100 + 10 * level),
			HitChance = 0.85 + 0.005 * level,
			Evasion = 0.005 * dex,
			CritChance = 0.05,
			CritDamage = 1.25,
			MeleePower = (damageMin + damageMax) / 2,
			SpellPower = 0,
			HealthRegen = 0.5,
			ManaRegen = 0,
			AttackSpeed = template.AttackSpeed,
		},
		Resistances = template.Resistances,
		RuntimeStats = {
			CurrentHealth = maxHealth,
			CurrentMana = 0,
			CurrentXP = 0,
		},
	}
end

-- Calculate XP reward based on monster level
function MonsterTemplates.CalculateXPReward(baseXP: number, monsterLevel: number, isElite: boolean, isBoss: boolean): number
	local xp = baseXP + monsterLevel * 2

	if isBoss then
		xp *= 10
	elseif isElite then
		xp *= 3
	end

	return xp
end

-- Predefined monster templates
MonsterTemplates.Templates = {
	-- Basic melee enemies
	Skeleton = {
		Name = "Skeleton Warrior",
		Type = "Melee",
		DamageMin = 5,
		DamageMax = 8,
		BaseHealth = 45,
		BaseArmor = 5,
		AttackSpeed = 1.2,
		MoveSpeed = 3.5,
		AttackRange = 1, -- Adjacent tile only
		AggroRange = 6,
		Resistances = {
			Fire = 0,
			Ice = 0.2, -- Resistant to ice
			Poison = 0.5, -- Very resistant to poison (undead)
			Arcane = 0,
		},
		XPReward = 5,
	} :: MonsterTemplate,

	Zombie = {
		Name = "Zombie",
		Type = "Melee",
		DamageMin = 6,
		DamageMax = 10,
		BaseHealth = 45,
		BaseArmor = 5,
		AttackSpeed = 0.9,
		MoveSpeed = 2.8, -- Slower
		AttackRange = 1,
		AggroRange = 5,
		Resistances = {
			Fire = -0.2, -- Weak to fire
			Ice = 0.3,
			Poison = 0.8, -- Very resistant (undead)
			Arcane = 0,
		},
		XPReward = 5,
	} :: MonsterTemplate,

	Goblin = {
		Name = "Goblin",
		Type = "Melee",
		DamageMin = 4,
		DamageMax = 7,
		BaseHealth = 45,
		BaseArmor = 5,
		AttackSpeed = 1.6, -- Fast attacks
		MoveSpeed = 4.2, -- Quick movement
		AttackRange = 1,
		AggroRange = 7,
		Resistances = {
			Fire = 0,
			Ice = 0,
			Poison = 0.1,
			Arcane = 0,
		},
		XPReward = 5,
	} :: MonsterTemplate,

	-- Ranged enemies
	SkeletonArcher = {
		Name = "Skeleton Archer",
		Type = "Ranged",
		DamageMin = 3,
		DamageMax = 6,
		BaseHealth = 45,
		BaseArmor = 5,
		AttackSpeed = 1.5,
		MoveSpeed = 3.5,
		AttackRange = 6, -- Can shoot from distance
		AggroRange = 8,
		Resistances = {
			Fire = 0,
			Ice = 0.2,
			Poison = 0.5,
			Arcane = 0,
		},
		XPReward = 5,
	} :: MonsterTemplate,

	DarkMage = {
		Name = "Dark Mage",
		Type = "Caster",
		DamageMin = 4,
		DamageMax = 7,
		BaseHealth = 45,
		BaseArmor = 5,
		AttackSpeed = 1.3,
		MoveSpeed = 3.2,
		AttackRange = 7,
		AggroRange = 9,
		Resistances = {
			Fire = 0.2,
			Ice = 0.2,
			Poison = 0.1,
			Arcane = 0.4, -- Resistant to arcane
		},
		XPReward = 6,
	} :: MonsterTemplate,

	-- Elite variants (handled with modifiers in spawn logic)
	-- Elites: +50% HP, +20% dmg, +1-2 affixes
	-- Bosses: +200% HP, +30% dmg, unique mechanics
}

-- Get a monster template by name
function MonsterTemplates.GetTemplate(templateName: string): MonsterTemplate?
	return MonsterTemplates.Templates[templateName]
end

-- Apply elite modifiers to stats
function MonsterTemplates.ApplyEliteModifiers(stats: Stats.ActorStats): Stats.ActorStats
	stats.DerivedStats.MaxHealth = math.floor(stats.DerivedStats.MaxHealth * 1.5)
	stats.RuntimeStats.CurrentHealth = stats.DerivedStats.MaxHealth

	stats.DerivedStats.MeleePower = stats.DerivedStats.MeleePower * 1.2
	stats.DerivedStats.SpellPower = stats.DerivedStats.SpellPower * 1.2

	return stats
end

-- Apply boss modifiers to stats
function MonsterTemplates.ApplyBossModifiers(stats: Stats.ActorStats): Stats.ActorStats
	stats.DerivedStats.MaxHealth = math.floor(stats.DerivedStats.MaxHealth * 3.0)
	stats.RuntimeStats.CurrentHealth = stats.DerivedStats.MaxHealth

	stats.DerivedStats.MeleePower = stats.DerivedStats.MeleePower * 1.3
	stats.DerivedStats.SpellPower = stats.DerivedStats.SpellPower * 1.3

	return stats
end

return MonsterTemplates
