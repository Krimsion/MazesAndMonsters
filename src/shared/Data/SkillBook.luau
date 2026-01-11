--!strict

local SkillTypes = require(script.Parent.Parent.Types.Skill)

local SkillBook = {}

-- All available skills in the game
local Skills: { [string]: SkillTypes.Skill } = {
	fireball = {
		Id = "fireball",
		Name = "Fireball",
		Description = "Launches a fiery projectile that explodes on impact, dealing fire damage.",
		Type = "Spell",
		Rarity = "Common",
		ManaCost = 15,
		RequiredLevel = 1,
		RequiredInt = 10,
		DamageType = "Fire",
		BaseDamageMin = 10,
		BaseDamageMax = 18,
		IntScaling = 0.5, -- 50% of INT adds to damage
		ProjectileCount = 1,
		ProjectileSpeed = 40,
		ProjectileBehavior = "Straight",
		ProjectileRange = 100,
		Cooldown = 1.0,
	},

	healing = {
		Id = "healing",
		Name = "Healing",
		Description = "Restores health to the caster based on intelligence.",
		Type = "Spell",
		Rarity = "Common",
		ManaCost = 20,
		RequiredLevel = 1,
		RequiredInt = 5,
		DamageType = "Heal",
		BaseDamageMin = 15,
		BaseDamageMax = 25,
		IntScaling = 0.4, -- 40% of INT adds to healing
		Cooldown = 2.0,
	},

	charged_bolt = {
		Id = "charged_bolt",
		Name = "Charged Bolt",
		Description = "Releases multiple lightning bolts that travel erratically forward. Higher levels increase bolt count.",
		Type = "Spell",
		Rarity = "Rare",
		ManaCost = 12,
		RequiredLevel = 1,
		RequiredInt = 8,
		DamageType = "Lightning",
		BaseDamageMin = 6,
		BaseDamageMax = 12,
		IntScaling = 0.4, -- 40% of INT adds to damage
		ProjectileCount = 4,
		ProjectileCountPerLevel = 1, -- +1 bolt per skill level
		ProjectileSpeed = 30,
		ProjectileBehavior = "Erratic",
		ProjectileSpreadAngle = 90, -- 90-degree arc
		ProjectileRange = 80,
		Cooldown = 1.5,
	},
}

-- Get a skill by ID
function SkillBook.GetSkill(skillId: string): SkillTypes.Skill?
	return Skills[skillId]
end

-- Get all skills
function SkillBook.GetAllSkills(): { [string]: SkillTypes.Skill }
	return Skills
end

-- Calculate skill damage based on caster's INT
function SkillBook.CalculateSkillDamage(
	skill: SkillTypes.Skill,
	skillLevel: number,
	casterInt: number
): (number, number)
	local minDamage = skill.BaseDamageMin or 0
	local maxDamage = skill.BaseDamageMax or 0

	-- Add INT scaling
	if skill.IntScaling then
		local intBonus = math.floor(casterInt * skill.IntScaling)
		minDamage += intBonus
		maxDamage += intBonus
	end

	return minDamage, maxDamage
end

-- Calculate projectile count based on skill level
function SkillBook.GetProjectileCount(skill: SkillTypes.Skill, skillLevel: number): number
	local baseCount = skill.ProjectileCount or 1
	local perLevel = skill.ProjectileCountPerLevel or 0
	return baseCount + (skillLevel - 1) * perLevel
end

return SkillBook
