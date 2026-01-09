--!strict

local CombatTypes = require(script.Parent.Parent.Types.Combat)
local Stats = require(script.Parent.Parent.Types.Stats)
local StatCalculator = require(script.Parent.Parent.Util.StatCalculator)

local CombatSystem = {}

-- Check if an attack hits based on attacker's hit chance and defender's evasion
function CombatSystem.TryHit(attackerDEX: number, defenderEvasion: number): boolean
	local hitChance = StatCalculator.CalculateHitChance(attackerDEX, defenderEvasion)
	return math.random() < hitChance
end

-- Check if an attack crits based on crit chance
function CombatSystem.TryCrit(critChance: number): boolean
	return math.random() < critChance
end

-- Calculate physical damage from melee attack
-- Raw = WeaponRoll * (1 + STR * 0.02 + %MeleeDmg) + FlatDamage
-- AfterArmor = Raw * (1 - DR_from_Armor)
-- Crit → AfterArmor * (CritDamage%)
function CombatSystem.CalculatePhysicalDamage(
	weaponMin: number,
	weaponMax: number,
	attackerSTR: number,
	attackerMeleeDmgPercent: number,
	attackerFlatDamage: number,
	defenderPhysicalDR: number,
	isCrit: boolean,
	critDamageMultiplier: number
): number
	-- Roll weapon damage
	local weaponRoll = math.random(weaponMin, weaponMax)

	-- Calculate raw damage
	local raw = weaponRoll * (1 + attackerSTR * 0.02 + attackerMeleeDmgPercent) + attackerFlatDamage

	-- Apply armor reduction
	local afterArmor = raw * (1 - defenderPhysicalDR)

	-- Apply crit multiplier if crit
	local final = isCrit and (afterArmor * critDamageMultiplier) or afterArmor

	-- Minimum 1 damage
	return math.max(1, math.round(final))
end

-- Calculate elemental/spell damage
-- Raw = SpellBase * (1 + INT * 0.02 + %SpellDmg) + FlatSpell
-- AfterResist = Raw * (1 - Resistance%)
function CombatSystem.CalculateElementalDamage(
	spellMin: number,
	spellMax: number,
	attackerINT: number,
	attackerSpellDmgPercent: number,
	attackerFlatSpell: number,
	defenderResistance: number,
	isCrit: boolean,
	critDamageMultiplier: number
): number
	-- Roll spell damage
	local spellRoll = math.random(spellMin, spellMax)

	-- Calculate raw damage
	local raw = spellRoll * (1 + attackerINT * 0.02 + attackerSpellDmgPercent) + attackerFlatSpell

	-- Apply resistance
	local afterResist = raw * (1 - defenderResistance)

	-- Apply crit if applicable
	local final = isCrit and (afterResist * critDamageMultiplier) or afterResist

	-- Minimum 1 damage
	return math.max(1, math.round(final))
end

-- Process a complete attack from attacker to defender
function CombatSystem.ProcessAttack(
	attackerStats: Stats.ActorStats,
	defenderStats: Stats.ActorStats,
	weaponMin: number,
	weaponMax: number,
	damageType: CombatTypes.DamageType,
	attackerBonusDmgPercent: number?,
	attackerFlatBonus: number?
): CombatTypes.DamageInfo?
	attackerBonusDmgPercent = attackerBonusDmgPercent or 0
	attackerFlatBonus = attackerFlatBonus or 0

	-- Check if attack hits
	if not CombatSystem.TryHit(attackerStats.Attributes.DEX, defenderStats.DerivedStats.Evasion) then
		return nil -- Miss
	end

	-- Check for crit
	local isCrit = CombatSystem.TryCrit(attackerStats.DerivedStats.CritChance)

	local damage: number
	local resistValue: number = 0

	if damageType == "Physical" then
		damage = CombatSystem.CalculatePhysicalDamage(
			weaponMin,
			weaponMax,
			attackerStats.Attributes.STR,
			attackerBonusDmgPercent,
			attackerFlatBonus,
			defenderStats.DerivedStats.PhysicalDR,
			isCrit,
			attackerStats.DerivedStats.CritDamage
		)
	else
		-- Elemental damage
		if damageType == "Fire" then
			resistValue = defenderStats.Resistances.Fire
		elseif damageType == "Ice" then
			resistValue = defenderStats.Resistances.Ice
		elseif damageType == "Poison" then
			resistValue = defenderStats.Resistances.Poison
		elseif damageType == "Arcane" then
			resistValue = defenderStats.Resistances.Arcane
		end

		damage = CombatSystem.CalculateElementalDamage(
			weaponMin,
			weaponMax,
			attackerStats.Attributes.INT,
			attackerBonusDmgPercent,
			attackerFlatBonus,
			resistValue,
			isCrit,
			attackerStats.DerivedStats.CritDamage
		)
	end

	return {
		Amount = damage,
		Type = damageType,
		IsCrit = isCrit,
		Source = nil, -- Will be set by caller
	}
end

-- Apply damage to an actor and return true if actor died
function CombatSystem.ApplyDamage(stats: Stats.ActorStats, damageInfo: CombatTypes.DamageInfo): boolean
	stats.RuntimeStats.CurrentHealth = math.max(0, stats.RuntimeStats.CurrentHealth - damageInfo.Amount)
	return stats.RuntimeStats.CurrentHealth <= 0
end

-- Heal an actor (clamped to max health)
function CombatSystem.Heal(stats: Stats.ActorStats, amount: number)
	stats.RuntimeStats.CurrentHealth = math.min(
		stats.DerivedStats.MaxHealth,
		stats.RuntimeStats.CurrentHealth + amount
	)
end

-- Restore mana (clamped to max mana)
function CombatSystem.RestoreMana(stats: Stats.ActorStats, amount: number)
	stats.RuntimeStats.CurrentMana = math.min(
		stats.DerivedStats.MaxMana,
		stats.RuntimeStats.CurrentMana + amount
	)
end

-- Check if actor has enough mana for ability
function CombatSystem.HasMana(stats: Stats.ActorStats, cost: number): boolean
	return stats.RuntimeStats.CurrentMana >= cost
end

-- Spend mana (returns true if successful)
function CombatSystem.SpendMana(stats: Stats.ActorStats, cost: number): boolean
	if not CombatSystem.HasMana(stats, cost) then
		return false
	end

	stats.RuntimeStats.CurrentMana -= cost
	return true
end

return CombatSystem
