--!strict

-- Item rarity
export type ItemRarity = "Common" | "Magic" | "Rare" | "Unique"

-- Item types
export type ItemType = "Weapon" | "Armor" | "Potion" | "Scroll" | "Material" | "Quest"

-- Item slot for equipment
export type EquipmentSlot = "Weapon" | "Helmet" | "Chest" | "Gloves" | "Boots" | "Ring1" | "Ring2" | "Amulet"

-- Stat modifier for items
export type StatModifier = {
	Type: string, -- "STR", "DEX", "MaxHealth", "PhysicalDamage", etc
	Value: number,
	IsPercent: boolean, -- true for percentage bonuses, false for flat
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

	-- Equipment specific
	EquipmentSlot: EquipmentSlot?,
	StatModifiers: { StatModifier }?,

	-- Weapon specific
	WeaponMinDamage: number?,
	WeaponMaxDamage: number?,

	-- Armor specific
	ArmorValue: number?,

	-- Visual
	IconId: string?, -- Asset ID for icon
}

-- Item instance in inventory (includes stack count)
export type ItemStack = {
	Item: Item,
	Count: number,
}

return {}
