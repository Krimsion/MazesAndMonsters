--!strict

-- Item rarity
export type ItemRarity = "Common" | "Magic" | "Rare" | "Unique"

-- Item types
export type ItemType = "Weapon" | "Armor" | "Potion" | "Scroll" | "Material" | "Quest" | "SkillBook"

-- Item slot for equipment
export type EquipmentSlot = "Weapon" | "Helmet" | "Chest" | "Gloves" | "Boots" | "Ring1" | "Ring2" | "Amulet"

-- Stat modifier for items
export type StatModifier = {
	Type: string, -- "STR", "DEX", "VIT", "INT", "CritChance", "CritDamage", etc
	Value: number,
	IsPercent: boolean?, -- true for percentage bonuses (like CritChance), false/nil for flat
}

-- Stat requirements to equip item
export type StatRequirement = {
	Stat: string, -- "STR", "DEX", "VIT", "INT"
	Value: number,
}

-- Item definition
export type Item = {
	Id: string, -- Unique identifier
	Name: string,
	Description: string,
	Type: ItemType,
	Rarity: ItemRarity,
	Level: number, -- Required level to use
	MaxStack: number, -- How many can stack in one slot (1 for equipment, higher for consumables)

	-- Requirements
	StatRequirements: { StatRequirement }?, -- Stat requirements to equip

	-- Equipment specific
	EquipmentSlot: EquipmentSlot?,
	StatModifiers: { StatModifier }?,

	-- Weapon specific
	WeaponMinDamage: number?,
	WeaponMaxDamage: number?,

	-- Armor specific
	ArmorValue: number?,

	-- Skill book specific
	TeachesSkillId: string?, -- ID of skill this book teaches

	-- Visual
	IconId: string?, -- Asset ID for icon
}

-- Item instance in inventory (includes stack count)
export type ItemStack = {
	Item: Item,
	Count: number,
}

return {}
