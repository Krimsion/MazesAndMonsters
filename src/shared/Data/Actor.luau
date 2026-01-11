--!strict

local Stats = require(script.Parent.Parent.Types.Stats)
local GridTypes = require(script.Parent.Parent.Types.Grid)
local CombatTypes = require(script.Parent.Parent.Types.Combat)
local StatCalculator = require(script.Parent.Parent.Util.StatCalculator)
local Inventory = require(script.Parent.Inventory)
local ItemTypes = require(script.Parent.Parent.Types.Item)
local SkillTypes = require(script.Parent.Parent.Types.Skill)

local Actor = {}
Actor.__index = Actor

export type Actor = typeof(setmetatable(
	{} :: {
		Name: string,
		IsPlayer: boolean,
		Stats: Stats.ActorStats,
		BaseAttributes: Stats.Attributes, -- Base attributes without equipment bonuses
		GridPosition: GridTypes.GridPosition,
		StatusEffects: { CombatTypes.StatusEffect },
		Model: Model?,
		Inventory: Inventory.Inventory,
		Equipment: { [string]: ItemTypes.Item? }, -- Weapon, Helmet, Chest, Gloves, Boots, Ring1, Ring2, Amulet, Belt
		BeltSlots: { [number]: ItemTypes.ItemStack? }, -- 5 quick slots for potions/scrolls
		SkillSlots: { [number]: string? }, -- 5 quick slots for skills (stores skillId)

		-- Gear modifiers (for stat calculation)
		ArmorFromGear: number,
		CritFromGear: number,
		CritDmgFromGear: number,
		AttackSpeed: number,

		-- Player-specific
		AvailableAttributePoints: number?,
		UnspentSkillPoints: number?,
		LearnedSkills: { [string]: SkillTypes.LearnedSkill }?, -- Map of skillId -> LearnedSkill
	},
	Actor
))

-- Create a new actor (player or monster)
function Actor.new(
	name: string,
	isPlayer: boolean,
	level: number,
	startingAttributes: Stats.Attributes?,
	gridPosition: GridTypes.GridPosition
): Actor
	-- Default starting attributes (5 in each)
	startingAttributes = startingAttributes or {
		STR = 5,
		DEX = 5,
		INT = 5,
		VIT = 5,
	}

	local self = setmetatable({
		Name = name,
		IsPlayer = isPlayer,
		BaseAttributes = startingAttributes, -- Store base attributes separately
		GridPosition = gridPosition,
		StatusEffects = {},
		Model = nil,
		Inventory = Inventory.new(25), -- 5x5 grid
		Equipment = {
			Weapon = nil,
			Helmet = nil,
			Chest = nil,
			Gloves = nil,
			Boots = nil,
			Ring1 = nil,
			Ring2 = nil,
			Amulet = nil,
			Belt = nil,
		},
		BeltSlots = {}, -- 5 quick slots for potions/scrolls initialized empty
		SkillSlots = {}, -- 5 quick slots for skills initialized empty

		-- Gear modifiers
		ArmorFromGear = 0,
		CritFromGear = 0,
		CritDmgFromGear = 0,
		AttackSpeed = 1.0,

		Stats = {
			Level = level,
			Attributes = startingAttributes,
			DerivedStats = {} :: any, -- Will be calculated
			Resistances = {
				Fire = 0,
				Ice = 0,
				Poison = 0,
				Arcane = 0,
			},
			RuntimeStats = {
				CurrentHealth = 0,
				CurrentMana = 0,
				CurrentXP = 0,
			},
		},

		-- Player-specific
		AvailableAttributePoints = isPlayer and 0 or nil,
		UnspentSkillPoints = isPlayer and 0 or nil,
		LearnedSkills = isPlayer and {} or nil,
	}, Actor)

	-- Calculate derived stats
	self:RecalculateStats()

	-- Initialize at full health/mana
	self.Stats.RuntimeStats.CurrentHealth = self.Stats.DerivedStats.MaxHealth
	self.Stats.RuntimeStats.CurrentMana = self.Stats.DerivedStats.MaxMana

	return self
end

-- Recalculate all derived stats (call after attribute changes or gear changes)
function Actor:RecalculateStats()
	self.Stats.DerivedStats = StatCalculator.CalculateDerivedStats(
		self.Stats.Level,
		self.Stats.Attributes,
		self.ArmorFromGear,
		self.CritFromGear,
		self.CritDmgFromGear,
		self.AttackSpeed
	)
end

-- Add attribute points (player only)
function Actor:AddAttributePoint(attribute: string, amount: number): boolean
	if not self.IsPlayer or not self.AvailableAttributePoints then
		return false
	end

	if self.AvailableAttributePoints < amount then
		return false
	end

	if attribute == "STR" then
		self.BaseAttributes.STR += amount
	elseif attribute == "DEX" then
		self.BaseAttributes.DEX += amount
	elseif attribute == "INT" then
		self.BaseAttributes.INT += amount
	elseif attribute == "VIT" then
		self.BaseAttributes.VIT += amount
	else
		return false
	end

	self.AvailableAttributePoints -= amount
	self:RecalculateStatsFromEquipment()

	return true
end

-- Grant XP and check for level up (player only)
function Actor:GrantXP(amount: number): boolean
	if not self.IsPlayer then
		return false
	end

	self.Stats.RuntimeStats.CurrentXP += amount

	local xpNeeded = StatCalculator.CalculateXPForNextLevel(self.Stats.Level)

	-- Check for level up
	if self.Stats.RuntimeStats.CurrentXP >= xpNeeded then
		self:LevelUp()
		return true
	end

	return false
end

-- Level up the actor
function Actor:LevelUp()
	self.Stats.Level += 1
	self.Stats.RuntimeStats.CurrentXP = 0

	if self.IsPlayer and self.AvailableAttributePoints then
		-- Players get 5 attribute points per level
		self.AvailableAttributePoints += 5
	end

	-- Recalculate stats
	self:RecalculateStats()

	-- Refill health and mana
	self.Stats.RuntimeStats.CurrentHealth = self.Stats.DerivedStats.MaxHealth
	self.Stats.RuntimeStats.CurrentMana = self.Stats.DerivedStats.MaxMana
end

-- Check if actor is alive
function Actor:IsAlive(): boolean
	return self.Stats.RuntimeStats.CurrentHealth > 0
end

-- Check if actor is dead
function Actor:IsDead(): boolean
	return not self:IsAlive()
end

-- Get health percentage (0-1)
function Actor:GetHealthPercent(): number
	return self.Stats.RuntimeStats.CurrentHealth / self.Stats.DerivedStats.MaxHealth
end

-- Get mana percentage (0-1)
function Actor:GetManaPercent(): number
	return self.Stats.RuntimeStats.CurrentMana / self.Stats.DerivedStats.MaxMana
end

-- Add a status effect
function Actor:AddStatusEffect(effect: CombatTypes.StatusEffect)
	-- Check if this effect type already exists
	for i, existingEffect in self.StatusEffects do
		if existingEffect.Type == effect.Type then
			-- Refresh duration
			self.StatusEffects[i] = effect
			return
		end
	end

	table.insert(self.StatusEffects, effect)
end

-- Remove a status effect by type
function Actor:RemoveStatusEffect(effectType: CombatTypes.StatusEffectType)
	for i, effect in self.StatusEffects do
		if effect.Type == effectType then
			table.remove(self.StatusEffects, i)
			return
		end
	end
end

-- Update status effects (call each frame with deltaTime)
function Actor:UpdateStatusEffects(deltaTime: number, currentTime: number)
	for i = #self.StatusEffects, 1, -1 do
		local effect = self.StatusEffects[i]

		-- Check if effect expired
		if currentTime - effect.StartTime >= effect.Duration then
			table.remove(self.StatusEffects, i)
		else
			-- Apply tick damage if it's a DOT
			if effect.TickDamage then
				-- Apply damage per second
				self.Stats.RuntimeStats.CurrentHealth -= effect.TickDamage * deltaTime
				if self.Stats.RuntimeStats.CurrentHealth < 0 then
					self.Stats.RuntimeStats.CurrentHealth = 0
				end
			end
		end
	end
end

-- Check if actor has a specific status effect
function Actor:HasStatusEffect(effectType: CombatTypes.StatusEffectType): boolean
	for _, effect in self.StatusEffects do
		if effect.Type == effectType then
			return true
		end
	end
	return false
end

-- Get movement speed modifier from status effects (0-1, where 1 is normal speed)
function Actor:GetMovementSpeedModifier(): number
	local modifier = 1.0

	for _, effect in self.StatusEffects do
		if effect.MovementModifier then
			modifier = math.min(modifier, effect.MovementModifier)
		end
	end

	return modifier
end

-- Equip an item to equipment slot
function Actor:EquipItem(item: ItemTypes.Item): boolean
	if not item.EquipmentSlot then
		return false
	end

	-- Unequip current item in that slot if any
	local currentItem = self.Equipment[item.EquipmentSlot]
	if currentItem then
		-- Add current item back to inventory
		if not self.Inventory:AddItem(currentItem, 1) then
			return false -- Inventory full
		end
	end

	-- Equip new item
	self.Equipment[item.EquipmentSlot] = item
	self:RecalculateStatsFromEquipment()
	return true
end

-- Unequip an item from equipment slot
function Actor:UnequipItem(slotName: string): boolean
	local item = self.Equipment[slotName]
	if not item then
		return false
	end

	-- Add to inventory
	if not self.Inventory:AddItem(item, 1) then
		return false -- Inventory full
	end

	-- Remove from equipment
	self.Equipment[slotName] = nil
	self:RecalculateStatsFromEquipment()
	return true
end

-- Recalculate stats from equipped items
function Actor:RecalculateStatsFromEquipment()
	-- Store current health/mana percentages
	local healthPercent = self.Stats.RuntimeStats.CurrentHealth / math.max(1, self.Stats.DerivedStats.MaxHealth)
	local manaPercent = self.Stats.RuntimeStats.CurrentMana / math.max(1, self.Stats.DerivedStats.MaxMana)

	-- Reset gear modifiers
	self.ArmorFromGear = 0
	self.CritFromGear = 0
	self.CritDmgFromGear = 0

	-- Start with base attributes (without equipment bonuses)
	local totalAttributes = {
		STR = self.BaseAttributes.STR,
		DEX = self.BaseAttributes.DEX,
		VIT = self.BaseAttributes.VIT,
		INT = self.BaseAttributes.INT,
	}

	-- Sum up all equipment bonuses
	for slotName, item in self.Equipment do
		if item then
			-- Add armor
			if item.ArmorValue then
				self.ArmorFromGear += item.ArmorValue
			end

			-- Add stat modifiers
			if item.StatModifiers then
				for _, modifier in item.StatModifiers do
					if modifier.Type == "CritChance" then
						self.CritFromGear += modifier.Value
					elseif modifier.Type == "CritDamage" then
						self.CritDmgFromGear += modifier.Value
					elseif modifier.Type == "Strength" then
						totalAttributes.STR += modifier.Value
					elseif modifier.Type == "Dexterity" then
						totalAttributes.DEX += modifier.Value
					elseif modifier.Type == "Vitality" then
						totalAttributes.VIT += modifier.Value
					elseif modifier.Type == "Intelligence" then
						totalAttributes.INT += modifier.Value
					end
				end
			end
		end
	end

	-- Update current attributes with gear bonuses
	self.Stats.Attributes = totalAttributes

	-- Recalculate all stats
	self:RecalculateStats()

	-- Restore health/mana percentages (don't heal/damage on equipment change)
	self.Stats.RuntimeStats.CurrentHealth = math.floor(self.Stats.DerivedStats.MaxHealth * healthPercent)
	self.Stats.RuntimeStats.CurrentMana = math.floor(self.Stats.DerivedStats.MaxMana * manaPercent)
end

-- Use a consumable item (potion, scroll, etc.)
function Actor:UseItem(item: ItemTypes.Item): boolean
	if item.Type == "Potion" then
		-- Potions restore health/mana
		if item.Id == "potion_health_minor" then
			self.Stats.RuntimeStats.CurrentHealth = math.min(
				self.Stats.RuntimeStats.CurrentHealth + 50,
				self.Stats.DerivedStats.MaxHealth
			)
			print(string.format("%s used %s and restored 50 HP", self.Name, item.Name))
			return true
		elseif item.Id == "potion_mana_minor" then
			self.Stats.RuntimeStats.CurrentMana = math.min(
				self.Stats.RuntimeStats.CurrentMana + 30,
				self.Stats.DerivedStats.MaxMana
			)
			print(string.format("%s used %s and restored 30 Mana", self.Name, item.Name))
			return true
		end
	elseif item.Type == "Scroll" then
		-- Scrolls cast spells
		-- TODO: Implement scroll effects
		print(string.format("%s used scroll %s", self.Name, item.Name))
		return true
	end

	return false
end

-- Add item to belt slot
function Actor:SetBeltSlot(slotIndex: number, item: ItemTypes.Item?, count: number?): boolean
	if slotIndex < 1 or slotIndex > 5 then
		return false
	end

	if item then
		-- Only potions and scrolls can go in belt
		if item.Type ~= "Potion" and item.Type ~= "Scroll" then
			return false
		end

		self.BeltSlots[slotIndex] = {
			Item = item,
			Count = count or 1,
		}
	else
		self.BeltSlots[slotIndex] = nil
	end

	return true
end

-- Use item from belt slot
function Actor:UseBeltSlot(slotIndex: number): boolean
	local stack = self.BeltSlots[slotIndex]
	if not stack then
		return false
	end

	local item = stack.Item

	-- Try to use the item
	if self:UseItem(item) then
		-- Reduce count
		stack.Count -= 1

		-- Remove stack if empty
		if stack.Count <= 0 then
			self.BeltSlots[slotIndex] = nil
		end

		return true
	end

	return false
end

-- Learn a skill from a skill book
function Actor:LearnSkill(skillId: string): boolean
	if not self.IsPlayer or not self.LearnedSkills then
		return false
	end

	-- Check if already learned
	if self.LearnedSkills[skillId] then
		return false
	end

	-- Learn skill at level 1
	self.LearnedSkills[skillId] = {
		SkillId = skillId,
		Level = 1,
		LastUsedTime = nil,
	}

	return true
end

-- Check if player has learned a skill
function Actor:HasLearnedSkill(skillId: string): boolean
	if not self.LearnedSkills then
		return false
	end
	return self.LearnedSkills[skillId] ~= nil
end

-- Set skill to hotbar slot
function Actor:SetSkillSlot(slotIndex: number, skillId: string?): boolean
	if slotIndex < 1 or slotIndex > 5 then
		return false
	end

	-- If setting a skill, verify player has learned it
	if skillId and not self:HasLearnedSkill(skillId) then
		return false
	end

	self.SkillSlots[slotIndex] = skillId
	return true
end

return Actor
