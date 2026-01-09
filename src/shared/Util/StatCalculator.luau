--!strict

local Stats = require(script.Parent.Parent.Types.Stats)

local StatCalculator = {}

-- Constants
local BASE_HIT_CHANCE = 0.90
local BASE_CRIT_CHANCE = 0.05
local BASE_CRIT_DAMAGE = 1.50

-- XP curve: XPToNext(L) = 50 + round(25 * L ^ 1.6)
function StatCalculator.CalculateXPForNextLevel(currentLevel: number): number
	return 50 + math.round(25 * (currentLevel ^ 1.6))
end

-- BaseHealth(L) = 80 + 5 * (L - 1)
function StatCalculator.CalculateBaseHealth(level: number): number
	return 80 + 5 * (level - 1)
end

-- BaseMana(L) = 40 + 3 * (L - 1)
function StatCalculator.CalculateBaseMana(level: number): number
	return 40 + 3 * (level - 1)
end

-- Max Health = BaseHealth(L) + (6 * VIT)
function StatCalculator.CalculateMaxHealth(level: number, vitality: number): number
	return StatCalculator.CalculateBaseHealth(level) + (6 * vitality)
end

-- Max Mana = BaseMana(L) + (2 * INT)
function StatCalculator.CalculateMaxMana(level: number, intelligence: number): number
	return StatCalculator.CalculateBaseMana(level) + (2 * intelligence)
end

-- Armor = ArmorFromGear + 0.5 * STR
function StatCalculator.CalculateArmor(strength: number, armorFromGear: number): number
	return armorFromGear + (0.5 * strength)
end

-- Physical Damage Reduction = Armor / (Armor + 100 + 10*L) (clamped 75% max)
function StatCalculator.CalculatePhysicalDR(armor: number, level: number): number
	local dr = armor / (armor + 100 + 10 * level)
	return math.min(dr, 0.75)
end

-- Hit Chance = Base 90% + 1% * DEX - Target Evasion (clamped 10-98%)
function StatCalculator.CalculateHitChance(dexterity: number, targetEvasion: number): number
	local hitChance = BASE_HIT_CHANCE + (0.01 * dexterity) - targetEvasion
	return math.clamp(hitChance, 0.10, 0.98)
end

-- Evasion = 0.5% * DEX
function StatCalculator.CalculateEvasion(dexterity: number): number
	return 0.005 * dexterity
end

-- Crit Chance = 5% base + 0.4% * DEX + Gear
function StatCalculator.CalculateCritChance(dexterity: number, critFromGear: number): number
	return BASE_CRIT_CHANCE + (0.004 * dexterity) + critFromGear
end

-- Crit Damage = 150% base + Gear
function StatCalculator.CalculateCritDamage(critDmgFromGear: number): number
	return BASE_CRIT_DAMAGE + critDmgFromGear
end

-- Melee Power = WeaponBase + (2% * STR) * WeaponBase + FlatPowerFromGear
function StatCalculator.CalculateMeleePower(weaponBase: number, strength: number, flatPower: number): number
	return weaponBase + (0.02 * strength * weaponBase) + flatPower
end

-- Spell Power = SpellBase + (2% * INT) * SpellBase + FlatPowerFromGear
function StatCalculator.CalculateSpellPower(spellBase: number, intelligence: number, flatPower: number): number
	return spellBase + (0.02 * intelligence * spellBase) + flatPower
end

-- HP Regen (per sec): 0.5 + floor(VIT / 5) * 0.5
function StatCalculator.CalculateHealthRegen(vitality: number): number
	return 0.5 + math.floor(vitality / 5) * 0.5
end

-- MP Regen (per sec): 0.3 + floor(INT / 5) * 0.5
function StatCalculator.CalculateManaRegen(intelligence: number): number
	return 0.3 + math.floor(intelligence / 5) * 0.5
end

-- Soft cap scaling for attributes
-- Past 60: scaling × 0.75; past 90: × 0.6
function StatCalculator.ApplySoftCap(attributeValue: number, baseBonus: number): number
	if attributeValue > 90 then
		local normalPart = 60 * baseBonus
		local softPart1 = 30 * baseBonus * 0.75
		local softPart2 = (attributeValue - 90) * baseBonus * 0.6
		return normalPart + softPart1 + softPart2
	elseif attributeValue > 60 then
		local normalPart = 60 * baseBonus
		local softPart = (attributeValue - 60) * baseBonus * 0.75
		return normalPart + softPart
	else
		return attributeValue * baseBonus
	end
end

-- Calculate all derived stats for an actor
function StatCalculator.CalculateDerivedStats(
	level: number,
	attributes: Stats.Attributes,
	armorFromGear: number,
	critFromGear: number,
	critDmgFromGear: number,
	attackSpeed: number
): Stats.DerivedStats
	local armor = StatCalculator.CalculateArmor(attributes.STR, armorFromGear)

	return {
		MaxHealth = StatCalculator.CalculateMaxHealth(level, attributes.VIT),
		MaxMana = StatCalculator.CalculateMaxMana(level, attributes.INT),
		Armor = armor,
		PhysicalDR = StatCalculator.CalculatePhysicalDR(armor, level),
		HitChance = BASE_HIT_CHANCE + (0.01 * attributes.DEX),
		Evasion = StatCalculator.CalculateEvasion(attributes.DEX),
		CritChance = StatCalculator.CalculateCritChance(attributes.DEX, critFromGear),
		CritDamage = StatCalculator.CalculateCritDamage(critDmgFromGear),
		MeleePower = 0, -- Calculated per-weapon
		SpellPower = 0, -- Calculated per-spell
		HealthRegen = StatCalculator.CalculateHealthRegen(attributes.VIT),
		ManaRegen = StatCalculator.CalculateManaRegen(attributes.INT),
		AttackSpeed = attackSpeed,
	}
end

return StatCalculator
