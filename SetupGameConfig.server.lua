--[[
	GAME CONFIG SETUP SCRIPT

	This script creates the GameConfig object in ReplicatedStorage with all attributes.

	TO USE:
	1. In Roblox Studio, go to ServerScriptService
	2. Create a new Script
	3. Copy this entire file and paste it into the script
	4. Name the script "SetupGameConfig"
	5. Run the game (or use the command bar method below)
	6. The script will create GameConfig and then disable itself
	7. You can now edit GameConfig attributes in Properties panel
	8. Delete this script when done

	ALTERNATIVE (Command Bar):
	1. Open View → Command Bar
	2. Copy lines 25-64 (just the code part)
	3. Paste into Command Bar
	4. Press Enter
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remove existing config if it exists
local existing = ReplicatedStorage:FindFirstChild("GameConfig")
if existing then
	existing:Destroy()
	print("Removed existing GameConfig")
end

-- Create new config
local config = Instance.new("Configuration")
config.Name = "GameConfig"

-- Set all attributes
config:SetAttribute("PlayerAttackCooldown", 1.0)
config:SetAttribute("MonsterAttackCooldown", 1.5)
config:SetAttribute("MonsterAlertRange", 8)
config:SetAttribute("MonsterChaseRange", 12)
config:SetAttribute("MonsterAlertDuration", 0.5)
config:SetAttribute("MonsterChaseDuration", 10.0)
config:SetAttribute("MonsterAttackRange", 1)
config:SetAttribute("MonsterAttackRangeBuffer", 1)
config:SetAttribute("MonsterRespawnTime", 20.0)
config:SetAttribute("PlayerStartingHealth", 100)
config:SetAttribute("PlayerStartingMana", 50)
config:SetAttribute("PlayerMovementSpeed", 0.65)
config:SetAttribute("GridTileSize", 4)
config:SetAttribute("LootPickupRange", 2)

-- Add description children
local descriptions = {
	{"PlayerAttackCooldown", "Player attack cooldown in seconds"},
	{"MonsterAttackCooldown", "Monster attack cooldown in seconds"},
	{"MonsterAlertRange", "How far monsters can detect players (tiles)"},
	{"MonsterChaseRange", "Max distance monsters will chase players (tiles)"},
	{"MonsterAlertDuration", "Time in Alert state before chasing (seconds)"},
	{"MonsterChaseDuration", "Max time to chase before giving up (seconds)"},
	{"MonsterAttackRange", "Monster melee attack range (tiles)"},
	{"MonsterAttackRangeBuffer", "Buffer to prevent jitter (tiles)"},
	{"MonsterRespawnTime", "Time before monsters respawn (seconds)"},
	{"PlayerStartingHealth", "Player starting health"},
	{"PlayerStartingMana", "Player starting mana"},
	{"PlayerMovementSpeed", "Time per tile movement (seconds)"},
	{"GridTileSize", "Size of each grid tile (studs)"},
	{"LootPickupRange", "Range to pick up loot (tiles)"},
}

for _, desc in descriptions do
	local stringValue = Instance.new("StringValue")
	stringValue.Name = desc[1] .. "_Description"
	stringValue.Value = desc[2]
	stringValue.Parent = config
end

-- Parent to ReplicatedStorage
config.Parent = ReplicatedStorage

print("✓ GameConfig created successfully!")
print("✓ You can now edit attributes in Properties panel")
print("✓ Save your place file to persist changes")

-- Disable this script so it doesn't run again
if script then
	script.Disabled = true
end
