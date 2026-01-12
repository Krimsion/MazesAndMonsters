-- Run this in Studio Command Bar to create GameConfig
-- Copy and paste into Command Bar, then press Enter

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function SetAttribute(config, name, value, description)
	config:SetAttribute(name, value)
	if description then
		local desc = Instance.new("StringValue")
		desc.Name = name .. "_Description"
		desc.Value = description
		desc.Parent = config
	end
end

-- Remove existing config if it exists
local existing = ReplicatedStorage:FindFirstChild("GameConfig")
if existing then
	existing:Destroy()
end

-- Create new config
local config = Instance.new("Configuration")
config.Name = "GameConfig"
config.Parent = ReplicatedStorage

-- === COMBAT SETTINGS ===
SetAttribute(config, "PlayerAttackCooldown", 1.0, "Player attack cooldown in seconds")
SetAttribute(config, "MonsterAttackCooldown", 1.5, "Monster attack cooldown in seconds")

-- === MONSTER AI SETTINGS ===
SetAttribute(config, "MonsterAlertRange", 8, "How far monsters can detect players (tiles)")
SetAttribute(config, "MonsterChaseRange", 12, "Max distance monsters will chase players (tiles)")
SetAttribute(config, "MonsterAlertDuration", 0.5, "Time in Alert state before chasing (seconds)")
SetAttribute(config, "MonsterChaseDuration", 10.0, "Max time to chase before giving up (seconds)")
SetAttribute(config, "MonsterAttackRange", 1, "Monster melee attack range (tiles)")
SetAttribute(config, "MonsterAttackRangeBuffer", 1, "Buffer to prevent jitter (tiles)")

-- === RESPAWN SETTINGS ===
SetAttribute(config, "MonsterRespawnTime", 20.0, "Time before monsters respawn (seconds)")

-- === PLAYER SETTINGS ===
SetAttribute(config, "PlayerStartingHealth", 100, "Player starting health")
SetAttribute(config, "PlayerStartingMana", 50, "Player starting mana")
SetAttribute(config, "PlayerMovementSpeed", 0.65, "Time per tile movement (seconds)")

-- === GRID SETTINGS ===
SetAttribute(config, "GridTileSize", 4, "Size of each grid tile (studs)")

-- === LOOT SETTINGS ===
SetAttribute(config, "LootPickupRange", 2, "Range to pick up loot (tiles)")

print("✓ GameConfig created successfully in ReplicatedStorage!")
print("✓ You can now edit attributes in the Properties panel")
