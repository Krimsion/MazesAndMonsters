--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigurationManager = {}

-- Get or create the Configuration folder in ReplicatedStorage
function ConfigurationManager.GetOrCreateConfig(): Configuration
	local config = ReplicatedStorage:FindFirstChild("GameConfig") :: Configuration?

	if not config then
		config = Instance.new("Configuration")
		config.Name = "GameConfig"
		config.Parent = ReplicatedStorage

		-- === COMBAT SETTINGS ===
		ConfigurationManager.SetAttribute(config, "PlayerAttackCooldown", 1.0, "Player attack cooldown in seconds")
		ConfigurationManager.SetAttribute(config, "MonsterAttackCooldown", 1.5, "Monster attack cooldown in seconds")

		-- === MONSTER AI SETTINGS ===
		ConfigurationManager.SetAttribute(config, "MonsterAlertRange", 8, "How far monsters can detect players (tiles)")
		ConfigurationManager.SetAttribute(config, "MonsterChaseRange", 12, "Max distance monsters will chase players (tiles)")
		ConfigurationManager.SetAttribute(config, "MonsterAlertDuration", 0.5, "Time in Alert state before chasing (seconds)")
		ConfigurationManager.SetAttribute(config, "MonsterChaseDuration", 10.0, "Max time to chase before giving up (seconds)")
		ConfigurationManager.SetAttribute(config, "MonsterAttackRange", 1, "Monster melee attack range (tiles)")
		ConfigurationManager.SetAttribute(config, "MonsterAttackRangeBuffer", 1, "Buffer to prevent jitter (tiles)")

		-- === RESPAWN SETTINGS ===
		ConfigurationManager.SetAttribute(config, "MonsterRespawnTime", 20.0, "Time before monsters respawn (seconds)")

		-- === PLAYER SETTINGS ===
		ConfigurationManager.SetAttribute(config, "PlayerStartingHealth", 100, "Player starting health")
		ConfigurationManager.SetAttribute(config, "PlayerStartingMana", 50, "Player starting mana")
		ConfigurationManager.SetAttribute(config, "PlayerMovementSpeed", 0.65, "Time per tile movement (seconds)")

		-- === GRID SETTINGS ===
		ConfigurationManager.SetAttribute(config, "GridTileSize", 4, "Size of each grid tile (studs)")

		-- === LOOT SETTINGS ===
		ConfigurationManager.SetAttribute(config, "LootPickupRange", 2, "Range to pick up loot (tiles)")

		print("Created GameConfig with default attributes")
	end

	return config
end

-- Helper to set attribute with description comment
function ConfigurationManager.SetAttribute(config: Instance, name: string, value: any, description: string?)
	config:SetAttribute(name, value)
	if description then
		-- Store description in a StringValue for reference
		local desc = Instance.new("StringValue")
		desc.Name = name .. "_Description"
		desc.Value = description
		desc.Parent = config
	end
end

-- Get a config value with fallback
function ConfigurationManager.GetNumber(attributeName: string, fallback: number): number
	local config = ConfigurationManager.GetOrCreateConfig()
	local value = config:GetAttribute(attributeName)
	if type(value) == "number" then
		return value
	end
	return fallback
end

function ConfigurationManager.GetString(attributeName: string, fallback: string): string
	local config = ConfigurationManager.GetOrCreateConfig()
	local value = config:GetAttribute(attributeName)
	if type(value) == "string" then
		return value
	end
	return fallback
end

function ConfigurationManager.GetBoolean(attributeName: string, fallback: boolean): boolean
	local config = ConfigurationManager.GetOrCreateConfig()
	local value = config:GetAttribute(attributeName)
	if type(value) == "boolean" then
		return value
	end
	return fallback
end

return ConfigurationManager
