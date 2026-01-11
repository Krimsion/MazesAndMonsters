--!strict

local ItemTypes = require(script.Parent.Parent.Types.Item)

local LootSystem = {}

export type LootDrop = {
	Item: ItemTypes.Item,
	Quantity: number,
}

-- Simple loot table for monsters based on level
-- In a full implementation, this would be more sophisticated with monster-specific drops
function LootSystem.GenerateLoot(monsterLevel: number, monsterName: string): { LootDrop }
	local drops: { LootDrop } = {}

	-- Always have a chance to drop health potions
	local potionChance = 0.3 + (monsterLevel * 0.02) -- 30% base, +2% per level
	if math.random() < potionChance then
		local healthPotion: ItemTypes.Item = {
			Id = "potion_health_minor",
			Name = "Minor Health Potion",
			Description = "Restores 50 HP",
			Type = "Potion",
			Rarity = "Common",
			Level = 1,
			MaxStack = 10,
		}
		table.insert(drops, { Item = healthPotion, Quantity = 1 })
	end

	-- Chance to drop weapons based on level
	local weaponChance = 0.15 + (monsterLevel * 0.03) -- 15% base, +3% per level
	if math.random() < weaponChance then
		local weaponRarity = LootSystem.RollRarity(monsterLevel)
		local weapon = LootSystem.GenerateWeapon(monsterLevel, weaponRarity)
		table.insert(drops, { Item = weapon, Quantity = 1 })
	end

	-- Chance to drop armor based on level
	local armorChance = 0.12 + (monsterLevel * 0.02) -- 12% base, +2% per level
	if math.random() < armorChance then
		local armorRarity = LootSystem.RollRarity(monsterLevel)
		local armor = LootSystem.GenerateArmor(monsterLevel, armorRarity)
		table.insert(drops, { Item = armor, Quantity = 1 })
	end

	return drops
end

-- Roll item rarity based on monster level
function LootSystem.RollRarity(monsterLevel: number): ItemTypes.ItemRarity
	local roll = math.random()

	-- Higher level monsters have better drop rates
	local magicThreshold = 0.6 - (monsterLevel * 0.03) -- Easier to get magic at higher levels
	local rareThreshold = 0.85 - (monsterLevel * 0.02)
	local uniqueThreshold = 0.97 - (monsterLevel * 0.01)

	if roll > uniqueThreshold then
		return "Unique"
	elseif roll > rareThreshold then
		return "Rare"
	elseif roll > magicThreshold then
		return "Magic"
	else
		return "Common"
	end
end

-- Generate a random weapon
function LootSystem.GenerateWeapon(itemLevel: number, rarity: ItemTypes.ItemRarity): ItemTypes.Item
	local weaponTypes = {
		{ Name = "Sword", MinDmg = 4, MaxDmg = 7, StatReq = "STR" },
		{ Name = "Axe", MinDmg = 5, MaxDmg = 9, StatReq = "STR" },
		{ Name = "Dagger", MinDmg = 3, MaxDmg = 5, StatReq = "DEX" },
		{ Name = "Mace", MinDmg = 4, MaxDmg = 8, StatReq = "STR" },
		{ Name = "Bow", MinDmg = 3, MaxDmg = 6, StatReq = "DEX" },
		{ Name = "Staff", MinDmg = 3, MaxDmg = 7, StatReq = "INT" },
	}

	local weaponType = weaponTypes[math.random(#weaponTypes)]

	-- Scale damage with item level (stronger scaling)
	local levelMultiplier = 1 + (itemLevel - 1) * 0.2 -- 20% per level
	local minDamage = math.floor(weaponType.MinDmg * levelMultiplier)
	local maxDamage = math.floor(weaponType.MaxDmg * levelMultiplier)

	-- Apply rarity multiplier
	local rarityMultiplier = LootSystem.GetRarityMultiplier(rarity)
	minDamage = math.floor(minDamage * rarityMultiplier)
	maxDamage = math.floor(maxDamage * rarityMultiplier)

	-- Add random variance (±10%)
	local variance = 0.9 + math.random() * 0.2
	minDamage = math.max(1, math.floor(minDamage * variance))
	maxDamage = math.max(minDamage + 1, math.floor(maxDamage * variance))

	local prefix = LootSystem.GetRarityPrefix(rarity)
	local suffix = LootSystem.GetRandomSuffix(rarity)
	local itemName = prefix .. weaponType.Name .. suffix

	-- Calculate stat requirement (scales with item level)
	local statReqValue = math.max(10, itemLevel * 3)

	local weapon: ItemTypes.Item = {
		Id = "weapon_" .. string.lower(weaponType.Name) .. "_" .. tostring(itemLevel) .. "_" .. tostring(math.random(1000, 9999)),
		Name = itemName,
		Description = string.format("%d-%d Damage", minDamage, maxDamage),
		Type = "Weapon",
		Rarity = rarity,
		Level = itemLevel,
		MaxStack = 1,
		EquipmentSlot = "Weapon",
		WeaponMinDamage = minDamage,
		WeaponMaxDamage = maxDamage,
		StatRequirements = {
			{ Stat = weaponType.StatReq, Value = statReqValue }
		},
	}

	-- Add stat modifiers for higher rarity items
	if rarity ~= "Common" then
		weapon.StatModifiers = LootSystem.GenerateWeaponModifiers(rarity, itemLevel)
	end

	return weapon
end

-- Generate a random armor piece
function LootSystem.GenerateArmor(itemLevel: number, rarity: ItemTypes.ItemRarity): ItemTypes.Item
	local armorSlots = {
		{ Slot = "Helmet", BaseArmor = 3, StatReq = "VIT" },
		{ Slot = "Chest", BaseArmor = 5, StatReq = "VIT" },
		{ Slot = "Gloves", BaseArmor = 2, StatReq = "DEX" },
		{ Slot = "Boots", BaseArmor = 2, StatReq = "DEX" },
		{ Slot = "Ring1", BaseArmor = 0, StatReq = "INT" },
		{ Slot = "Ring2", BaseArmor = 0, StatReq = "INT" },
		{ Slot = "Amulet", BaseArmor = 0, StatReq = "INT" },
	}

	local armorType = armorSlots[math.random(#armorSlots)]

	-- Scale armor with item level
	local levelMultiplier = 1 + (itemLevel - 1) * 0.25 -- 25% per level
	local armorValue = math.floor(armorType.BaseArmor * levelMultiplier)

	-- Apply rarity multiplier
	local rarityMultiplier = LootSystem.GetRarityMultiplier(rarity)
	armorValue = math.floor(armorValue * rarityMultiplier)

	-- Add random variance (±10%)
	local variance = 0.9 + math.random() * 0.2
	armorValue = math.max(0, math.floor(armorValue * variance))

	local prefix = LootSystem.GetRarityPrefix(rarity)
	local suffix = LootSystem.GetRandomSuffix(rarity)
	local itemName = prefix .. armorType.Slot .. suffix

	-- Calculate stat requirement
	local statReqValue = math.max(10, itemLevel * 3)

	local armor: ItemTypes.Item = {
		Id = "armor_" .. string.lower(armorType.Slot) .. "_" .. tostring(itemLevel) .. "_" .. tostring(math.random(1000, 9999)),
		Name = itemName,
		Description = armorValue > 0 and string.format("%d Armor", armorValue) or "Accessory",
		Type = "Armor",
		Rarity = rarity,
		Level = itemLevel,
		MaxStack = 1,
		EquipmentSlot = armorType.Slot :: ItemTypes.EquipmentSlot,
		ArmorValue = armorValue,
		StatRequirements = {
			{ Stat = armorType.StatReq, Value = statReqValue }
		},
	}

	-- Add stat modifiers for higher rarity items
	if rarity ~= "Common" then
		armor.StatModifiers = LootSystem.GenerateArmorModifiers(rarity, itemLevel)
	end

	return armor
end

-- Get rarity multiplier for item power
function LootSystem.GetRarityMultiplier(rarity: ItemTypes.ItemRarity): number
	if rarity == "Common" then
		return 1.0
	elseif rarity == "Magic" then
		return 1.2
	elseif rarity == "Rare" then
		return 1.5
	elseif rarity == "Unique" then
		return 2.0
	end
	return 1.0
end

-- Get rarity prefix for item names
function LootSystem.GetRarityPrefix(rarity: ItemTypes.ItemRarity): string
	if rarity == "Common" then
		return "Iron "
	elseif rarity == "Magic" then
		return "Steel "
	elseif rarity == "Rare" then
		return "Masterwork "
	elseif rarity == "Unique" then
		return "Legendary "
	end
	return ""
end

-- Get random suffix for item names
function LootSystem.GetRandomSuffix(rarity: ItemTypes.ItemRarity): string
	if rarity == "Common" then
		return ""
	elseif rarity == "Magic" then
		local suffixes = { " of Power", " of Precision", " of Vigor", " of the Bear", " of the Wolf" }
		return suffixes[math.random(#suffixes)]
	elseif rarity == "Rare" then
		local suffixes = { " of the Titan", " of the Phoenix", " of the Dragon", " of Destruction", " of Excellence" }
		return suffixes[math.random(#suffixes)]
	elseif rarity == "Unique" then
		local suffixes = { " of the Gods", " of Eternity", " of the Ancients", " of Supremacy", " of Infinity" }
		return suffixes[math.random(#suffixes)]
	end
	return ""
end

-- Generate stat modifiers for weapons
function LootSystem.GenerateWeaponModifiers(rarity: ItemTypes.ItemRarity, itemLevel: number): { ItemTypes.StatModifier }
	local modifiers: { ItemTypes.StatModifier } = {}

	-- Number of modifiers based on rarity
	local modCount = 0
	if rarity == "Magic" then
		modCount = 1
	elseif rarity == "Rare" then
		modCount = 2
	elseif rarity == "Unique" then
		modCount = 3
	end

	-- Scale modifier values with item level
	local levelScale = 1 + (itemLevel - 1) * 0.1

	local possibleMods = {
		{ Type = "CritChance", Value = math.floor((math.random(3, 8) * levelScale)) / 100, IsPercent = true },
		{ Type = "CritDamage", Value = math.floor((math.random(15, 35) * levelScale)) / 100, IsPercent = true },
		{ Type = "Strength", Value = math.floor(math.random(2, 5) * levelScale) },
		{ Type = "Dexterity", Value = math.floor(math.random(2, 5) * levelScale) },
		{ Type = "Intelligence", Value = math.floor(math.random(2, 5) * levelScale) },
	}

	-- Add random modifiers
	for i = 1, modCount do
		if #possibleMods > 0 then
			local index = math.random(#possibleMods)
			table.insert(modifiers, possibleMods[index])
			table.remove(possibleMods, index)
		end
	end

	return modifiers
end

-- Generate stat modifiers for armor
function LootSystem.GenerateArmorModifiers(rarity: ItemTypes.ItemRarity, itemLevel: number): { ItemTypes.StatModifier }
	local modifiers: { ItemTypes.StatModifier } = {}

	-- Number of modifiers based on rarity
	local modCount = 0
	if rarity == "Magic" then
		modCount = 1
	elseif rarity == "Rare" then
		modCount = 2
	elseif rarity == "Unique" then
		modCount = 3
	end

	-- Scale modifier values with item level
	local levelScale = 1 + (itemLevel - 1) * 0.1

	local possibleMods = {
		{ Type = "Vitality", Value = math.floor(math.random(3, 8) * levelScale) },
		{ Type = "Strength", Value = math.floor(math.random(2, 5) * levelScale) },
		{ Type = "Dexterity", Value = math.floor(math.random(2, 5) * levelScale) },
		{ Type = "Intelligence", Value = math.floor(math.random(2, 5) * levelScale) },
		{ Type = "CritChance", Value = math.floor((math.random(2, 5) * levelScale)) / 100, IsPercent = true },
	}

	-- Add random modifiers
	for i = 1, modCount do
		if #possibleMods > 0 then
			local index = math.random(#possibleMods)
			table.insert(modifiers, possibleMods[index])
			table.remove(possibleMods, index)
		end
	end

	return modifiers
end

return LootSystem
