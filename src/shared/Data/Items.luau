--!strict

local ItemTypes = require(script.Parent.Parent.Types.Item)

-- Item database - defines all items in the game
local Items = {}

-- WEAPONS

Items.WoodenBow = {
	Id = "wooden_bow",
	Name = "Wooden Bow",
	Description = "A simple wooden bow. Allows attacks from a distance.",
	Type = "Weapon",
	Rarity = "Common",
	Level = 1,
	MaxStack = 1,
	EquipmentSlot = "Weapon",
	WeaponMinDamage = 3,
	WeaponMaxDamage = 6,
	IsRanged = true,
	AttackRange = 6, -- 6 tiles range
	StatModifiers = {
		{ Type = "DEX", Value = 2, IsPercent = false },
	},
	StatRequirements = {},
} :: ItemTypes.Item

Items.IronSword = {
	Id = "iron_sword",
	Name = "Iron Sword",
	Description = "A sturdy iron sword for close combat.",
	Type = "Weapon",
	Rarity = "Common",
	Level = 1,
	MaxStack = 1,
	EquipmentSlot = "Weapon",
	WeaponMinDamage = 4,
	WeaponMaxDamage = 7,
	IsRanged = false,
	AttackRange = 1, -- Melee range
	StatModifiers = {
		{ Type = "STR", Value = 2, IsPercent = false },
	},
	StatRequirements = {},
} :: ItemTypes.Item

-- CONSUMABLES

Items.HealthPotion = {
	Id = "health_potion",
	Name = "Health Potion",
	Description = "Restores 50 health",
	Type = "Potion",
	Rarity = "Common",
	Level = 1,
	MaxStack = 10,
} :: ItemTypes.Item

return Items
