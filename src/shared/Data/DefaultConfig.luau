--!strict

-- Default configuration values
-- These are used as fallbacks if GameConfig attributes aren't set

return {
	-- === COMBAT SETTINGS ===
	PlayerAttackCooldown = 1.0, -- Player attack cooldown in seconds
	MonsterAttackCooldown = 1.5, -- Monster attack cooldown in seconds

	-- === MONSTER AI SETTINGS ===
	MonsterAlertRange = 8, -- How far monsters can detect players (tiles)
	MonsterChaseRange = 12, -- Max distance monsters will chase players (tiles)
	MonsterAlertDuration = 0.5, -- Time in Alert state before chasing (seconds)
	MonsterChaseDuration = 10.0, -- Max time to chase before giving up (seconds)
	MonsterAttackRange = 1, -- Monster melee attack range (tiles)
	MonsterAttackRangeBuffer = 1, -- Buffer to prevent jitter (tiles)

	-- === RESPAWN SETTINGS ===
	MonsterRespawnTime = 20.0, -- Time before monsters respawn (seconds)

	-- === PLAYER SETTINGS ===
	PlayerStartingHealth = 100, -- Player starting health
	PlayerStartingMana = 50, -- Player starting mana
	PlayerMovementSpeed = 0.65, -- Time per tile movement (seconds)

	-- === GRID SETTINGS ===
	GridTileSize = 4, -- Size of each grid tile (studs)

	-- === LOOT SETTINGS ===
	LootPickupRange = 2, -- Range to pick up loot (tiles)
}
