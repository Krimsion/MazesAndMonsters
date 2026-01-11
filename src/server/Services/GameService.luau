--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Actor = require(Shared.Data.Actor)
local GridSystem = require(Shared.Systems.GridSystem)
local MonsterAI = require(Shared.Systems.MonsterAI)
local MonsterTemplates = require(Shared.Data.MonsterTemplates)
local CombatSystem = require(Shared.Combat.CombatSystem)
local StatCalculator = require(Shared.Util.StatCalculator)
local GridTypes = require(Shared.Types.Grid)
local LootSystem = require(Shared.Systems.LootSystem)
local ItemTypes = require(Shared.Types.Item)
local ProjectileManager = require(script.Parent.Parent.Combat.ProjectileManager)
local MonsterHealthBar = require(script.Parent.Parent.UI.MonsterHealthBar)

local GameService = {}
GameService.__index = GameService

export type PlayerAction = {
	Type: "Move" | "Attack",
	Path: { GridTypes.GridPosition }?,
	Target: Actor.Actor?,
	PathIndex: number,
}

export type LootContainer = {
	Id: string,
	Items: { LootSystem.LootDrop },
	GridPosition: GridTypes.GridPosition,
	Model: Model?,
}

export type RespawnInfo = {
	TemplateName: string,
	Level: number,
	SpawnPosition: GridTypes.GridPosition,
	RespawnTime: number,
}

export type MonsterData = {
	monster: Actor.Actor,
	ai: MonsterAI.MonsterAI,
	templateName: string,
	spawnPosition: GridTypes.GridPosition,
}

export type GameService = typeof(setmetatable(
	{} :: {
		GridSystem: GridSystem.GridSystem,
		Players: { [Player]: Actor.Actor },
		PlayerActions: { [Player]: PlayerAction? },
		Monsters: { MonsterData },
		LootContainers: { [string]: LootContainer },
		ProjectileManager: ProjectileManager.ProjectileManager,
		RespawnQueue: { RespawnInfo },
		LastUpdateTime: number,
		NextLootId: number,
		OnMonsterSpawned: ((Actor.Actor, GridTypes.GridPosition) -> ())?,
	},
	GameService
))

function GameService.new(tileSize: number): GameService
	local self = setmetatable({
		GridSystem = GridSystem.new(tileSize),
		Players = {},
		PlayerActions = {},
		Monsters = {},
		LootContainers = {},
		ProjectileManager = ProjectileManager.new(),
		RespawnQueue = {},
		LastUpdateTime = tick(),
		NextLootId = 1,
		OnMonsterSpawned = nil,
	}, GameService)

	-- Start update loop
	RunService.Heartbeat:Connect(function()
		self:Update()
	end)

	return self
end

-- Get player from actor
function GameService:GetPlayerFromActor(actor: Actor.Actor): Player?
	for player, playerActor in self.Players do
		if playerActor == actor then
			return player
		end
	end
	return nil
end

-- Broadcast stat update to a player's client
function GameService:BroadcastStatsUpdate(player: Player, playerActor: Actor.Actor)
	local updateStatsEvent = ReplicatedStorage:FindFirstChild("UpdateStats")
	if updateStatsEvent then
		local requiredXP = StatCalculator.CalculateXPForNextLevel(playerActor.Stats.Level)
		updateStatsEvent:FireClient(player, {
			CurrentHealth = playerActor.Stats.RuntimeStats.CurrentHealth,
			MaxHealth = playerActor.Stats.DerivedStats.MaxHealth,
			CurrentMana = playerActor.Stats.RuntimeStats.CurrentMana,
			MaxMana = playerActor.Stats.DerivedStats.MaxMana,
			CurrentXP = playerActor.Stats.RuntimeStats.CurrentXP,
			RequiredXP = requiredXP,
			Level = playerActor.Stats.Level,
		})
	end

	-- Also send full stats for character sheet (include AvailableAttributePoints)
	local updateFullStatsEvent = ReplicatedStorage:FindFirstChild("UpdateFullStats")
	if updateFullStatsEvent then
		local fullStats = playerActor.Stats
		fullStats.AvailableAttributePoints = playerActor.AvailableAttributePoints
		updateFullStatsEvent:FireClient(player, fullStats)
	end
end

-- Broadcast damage number to all nearby players
function GameService:BroadcastDamage(
	targetActor: Actor.Actor,
	amount: number,
	damageType: string,
	isCrit: boolean,
	isMiss: boolean
)
	local showDamageEvent = ReplicatedStorage:FindFirstChild("ShowDamage")
	if not showDamageEvent then
		return
	end

	-- Get world position of target
	local worldPosition = Vector3.zero
	if targetActor.Model then
		local humanoidRootPart = targetActor.Model:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			worldPosition = humanoidRootPart.Position
		end
	end

	-- Send to all players (they'll see damage numbers on all entities)
	for player, _ in self.Players do
		showDamageEvent:FireClient(player, worldPosition, amount, damageType, isCrit, isMiss)
	end
end

-- Main update loop
function GameService:Update()
	local currentTime = tick()
	local deltaTime = currentTime - self.LastUpdateTime
	self.LastUpdateTime = currentTime

	-- Update all player status effects and actions
	for player, playerActor in self.Players do
		-- Update player grid position based on actual world position
		if playerActor.Model then
			local humanoidRootPart = playerActor.Model:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				local currentWorldPos = humanoidRootPart.Position
				local currentGridPos = self.GridSystem:WorldToGrid(currentWorldPos)

				-- If player moved to a different tile, update grid
				if currentGridPos.X ~= playerActor.GridPosition.X or currentGridPos.Z ~= playerActor.GridPosition.Z then
					-- Clear old position
					self.GridSystem:ClearTile(playerActor.GridPosition)
					-- Update to new position (if available)
					if self.GridSystem:IsTileAvailable(currentGridPos) then
						self.GridSystem:OccupyTile(currentGridPos, playerActor)
						playerActor.GridPosition = currentGridPos
					else
						-- Tile occupied, re-occupy old position
						self.GridSystem:OccupyTile(playerActor.GridPosition, playerActor)
					end
				end
			end
		end

		playerActor:UpdateStatusEffects(deltaTime, currentTime)

		-- Apply regeneration
		if playerActor:IsAlive() then
			CombatSystem.Heal(playerActor.Stats, playerActor.Stats.DerivedStats.HealthRegen * deltaTime)
			CombatSystem.RestoreMana(playerActor.Stats, playerActor.Stats.DerivedStats.ManaRegen * deltaTime)
		end

		-- Process player actions (movement/attack)
		self:ProcessPlayerAction(player, playerActor)
	end

	-- Update all monsters
	for i = #self.Monsters, 1, -1 do
		local monsterData = self.Monsters[i]
		local monster = monsterData.monster
		local ai = monsterData.ai

		if not monster:IsAlive() then
			-- Check if this is a skeleton that should respawn
			if monsterData.templateName == "Skeleton" then
				-- Queue for respawn in 20 seconds
				table.insert(self.RespawnQueue, {
					TemplateName = monsterData.templateName,
					Level = monster.Stats.Level,
					SpawnPosition = monsterData.spawnPosition,
					RespawnTime = currentTime + 20, -- 20 second respawn timer
				})
			end

			-- Remove dead monster
			self.GridSystem:ClearTile(monster.GridPosition)
			table.remove(self.Monsters, i)
			if monster.Model then
				monster.Model:Destroy()
			end
			continue
		end

		-- Update monster grid position based on actual world position
		if monster.Model then
			local humanoidRootPart = monster.Model:FindFirstChild("HumanoidRootPart")
			if not humanoidRootPart then
				humanoidRootPart = monster.Model.PrimaryPart
			end

			if humanoidRootPart then
				local currentWorldPos = humanoidRootPart.Position
				local currentGridPos = self.GridSystem:WorldToGrid(currentWorldPos)

				-- If monster moved to a different tile, update grid
				if currentGridPos.X ~= monster.GridPosition.X or currentGridPos.Z ~= monster.GridPosition.Z then
					-- Clear old position
					self.GridSystem:ClearTile(monster.GridPosition)
					-- Update to new position (if available)
					if self.GridSystem:IsTileAvailable(currentGridPos) then
						self.GridSystem:OccupyTile(currentGridPos, monster)
						monster.GridPosition = currentGridPos
					else
						-- Tile occupied, re-occupy old position
						self.GridSystem:OccupyTile(monster.GridPosition, monster)
					end
				end
			end
		end

		-- Update status effects
		monster:UpdateStatusEffects(deltaTime, currentTime)

		-- Get all alive players as potential targets
		local potentialTargets = {}
		for _, playerActor in self.Players do
			if playerActor:IsAlive() then
				table.insert(potentialTargets, playerActor)
			end
		end

		-- Update AI
		local previousState = ai.CurrentState
		MonsterAI.Update(ai, monster, self.GridSystem, potentialTargets, currentTime, deltaTime)

		-- Debug state changes
		if ai.CurrentState ~= previousState then
			print(string.format("%s: %s -> %s", monster.Name, previousState, ai.CurrentState))
			if ai.Target then
				print(string.format("  Target: %s", ai.Target.Name))
			end
		end

		-- Handle AI behaviors
		if ai.CurrentState == "Chase" then
			-- Check if monster has reached their current grid position (world pos matches grid pos)
			if monster.Model then
				local humanoidRootPart = monster.Model.PrimaryPart or monster.Model:FindFirstChild("HumanoidRootPart")
				if humanoidRootPart then
					local currentWorldPos = humanoidRootPart.Position
					local currentGridPos = self.GridSystem:WorldToGrid(currentWorldPos)
					local targetWorldPos = self.GridSystem:GridToWorld(monster.GridPosition)
					local distance = (currentWorldPos - targetWorldPos).Magnitude

					-- Only request new movement if close to current grid position
					if distance < 2 then
						-- Try to move toward target
						local nextPos = MonsterAI.GetNextMovePosition(ai, monster, self.GridSystem)
						if nextPos then
							local moved = self:MoveMonster(monster, nextPos)
							if not moved then
								print(string.format("%s failed to move to (%d, %d)", monster.Name, nextPos.X, nextPos.Z))
							end
						end
					end
				end
			end
		elseif ai.CurrentState == "Attack" then
			-- Try to attack target
			if MonsterAI.CanAttack(ai, monster, currentTime) and ai.Target then
				self:MonsterAttack(monster, ai.Target)
				MonsterAI.MarkAttack(ai, currentTime)
			end
		end
	end

	-- Process respawn queue
	for i = #self.RespawnQueue, 1, -1 do
		local respawnInfo = self.RespawnQueue[i]
		if currentTime >= respawnInfo.RespawnTime then
			-- Check if spawn position is now available
			if self.GridSystem:IsTileAvailable(respawnInfo.SpawnPosition) then
				-- Respawn the monster
				self:SpawnMonster(
					respawnInfo.TemplateName,
					respawnInfo.Level,
					respawnInfo.SpawnPosition
				)
				print(
					string.format(
						"Respawned %s at (%d, %d)",
						respawnInfo.TemplateName,
						respawnInfo.SpawnPosition.X,
						respawnInfo.SpawnPosition.Z
					)
				)
				-- Remove from queue
				table.remove(self.RespawnQueue, i)
			else
				-- Position still occupied, delay respawn by 5 seconds
				respawnInfo.RespawnTime = currentTime + 5
			end
		end
	end
end

-- Register a player actor
function GameService:RegisterPlayer(player: Player, startPosition: GridTypes.GridPosition): Actor.Actor
	-- Create player actor at level 1 with default attributes
	local playerActor = Actor.new(player.Name, true, 1, nil, startPosition)

	-- Occupy starting tile
	self.GridSystem:OccupyTile(startPosition, playerActor)

	self.Players[player] = playerActor

	return playerActor
end

-- Unregister player
function GameService:UnregisterPlayer(player: Player)
	local playerActor = self.Players[player]
	if playerActor then
		self.GridSystem:ClearTile(playerActor.GridPosition)
		self.Players[player] = nil
	end
end

-- Spawn a monster
function GameService:SpawnMonster(
	templateName: string,
	level: number,
	position: GridTypes.GridPosition,
	isElite: boolean?,
	isBoss: boolean?
): Actor.Actor?
	local template = MonsterTemplates.GetTemplate(templateName)
	if not template then
		warn("Monster template not found:", templateName)
		return nil
	end

	-- Check if position is available
	if not self.GridSystem:IsTileAvailable(position) then
		warn("Cannot spawn monster: position occupied")
		return nil
	end

	-- Calculate monster stats
	local stats = MonsterTemplates.CalculateMonsterStats(template, level)

	-- Apply elite/boss modifiers
	if isBoss then
		stats = MonsterTemplates.ApplyBossModifiers(stats)
	elseif isElite then
		stats = MonsterTemplates.ApplyEliteModifiers(stats)
	end

	-- Create monster actor
	local monster = Actor.new(template.Name, false, level, stats.Attributes, position)
	monster.Stats = stats

	-- Create AI
	local ai = MonsterAI.new(template.AggroRange, template.AttackRange, position)

	-- Occupy tile
	self.GridSystem:OccupyTile(position, monster)

	-- Add to monsters list with spawn info for respawning
	table.insert(self.Monsters, {
		monster = monster,
		ai = ai,
		templateName = templateName,
		spawnPosition = position,
	})

	-- Call spawn callback if set
	if self.OnMonsterSpawned then
		self.OnMonsterSpawned(monster, position)
	end

	return monster
end

-- Process player action (movement along path, attacking target)
function GameService:ProcessPlayerAction(player: Player, playerActor: Actor.Actor)
	local action = self.PlayerActions[player]
	if not action then
		return
	end

	-- Check if we're moving along a path
	if action.Type == "Move" and action.Path then
		-- Check if humanoid has reached current waypoint
		local humanoid = playerActor.Model and playerActor.Model:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			self.PlayerActions[player] = nil
			return
		end

		-- Check if we've reached the current waypoint
		local targetWorldPos = self.GridSystem:GridToWorld(action.Path[action.PathIndex])
		local currentPos = humanoid.RootPart and humanoid.RootPart.Position or Vector3.zero
		local distance = (currentPos - targetWorldPos).Magnitude

		-- If close enough to current waypoint, move to next
		if distance < 2 then
			action.PathIndex += 1

			-- Check if we've completed the path
			if action.PathIndex > #action.Path then
				-- Path complete!
				if action.Target and action.Target:IsAlive() then
					-- We were moving to attack, now attack
					self:PlayerAttack(player, action.Target)
				end
				self.PlayerActions[player] = nil
				return
			end

			-- Move to next waypoint
			local nextPos = action.Path[action.PathIndex]
			if self.GridSystem:IsTileAvailable(nextPos) then
				self.GridSystem:MoveOccupant(playerActor.GridPosition, nextPos)
				playerActor.GridPosition = nextPos

				local worldPos = self.GridSystem:GridToWorld(nextPos)
				humanoid:MoveTo(worldPos)
			else
				-- Path blocked, cancel action
				self.PlayerActions[player] = nil
			end
		end
	end
end

-- Set player to move to target and optionally attack
function GameService:SetPlayerMoveToAttack(player: Player, targetActor: Actor.Actor)
	local playerActor = self.Players[player]
	if not playerActor then
		return
	end

	-- Check if already adjacent
	local distance = GridSystem.GetDistance(playerActor.GridPosition, targetActor.GridPosition)
	if distance <= 1 then
		-- Already in range, attack immediately
		self:PlayerAttack(player, targetActor)
		return
	end

	-- Find path to get adjacent to target
	-- Pathfind to target's position (A* will handle getting us adjacent)
	local path = self.GridSystem:FindPath(playerActor.GridPosition, targetActor.GridPosition, 100)

	if not path then
		print(string.format(
			"%s cannot find path to target at (%d, %d) from (%d, %d)",
			player.Name,
			targetActor.GridPosition.X,
			targetActor.GridPosition.Z,
			playerActor.GridPosition.X,
			playerActor.GridPosition.Z
		))
		return
	end

	print(string.format("%s found path with %d tiles", player.Name, #path))

	-- The path includes the target's occupied tile at the end
	-- Remove it so we stop adjacent to the target
	if #path > 1 then
		-- Check if last tile is the target's position
		local lastTile = path[#path]
		if lastTile.X == targetActor.GridPosition.X and lastTile.Z == targetActor.GridPosition.Z then
			table.remove(path, #path)
			print("Removed target tile from path, new length:", #path)
		end
	end

	-- If path is too short after removal, we might already be adjacent
	if #path < 2 then
		print(player.Name .. " is already next to target, attacking directly")
		self:PlayerAttack(player, targetActor)
		return
	end

	-- Set up movement action
	self.PlayerActions[player] = {
		Type = "Move",
		Path = path,
		Target = targetActor,
		PathIndex = 2, -- Start at index 2 (1 is current position)
	}

	print(string.format("Starting movement, path has %d tiles", #path))

	-- Start moving immediately
	if playerActor.Model then
		local humanoid = playerActor.Model:FindFirstChildOfClass("Humanoid")
		if humanoid and path[2] then
			local nextPos = path[2]
			if self.GridSystem:MoveOccupant(playerActor.GridPosition, nextPos) then
				playerActor.GridPosition = nextPos
				local worldPos = self.GridSystem:GridToWorld(nextPos)
				humanoid:MoveTo(worldPos)
				print(string.format("Moving to (%d, %d)", nextPos.X, nextPos.Z))
			else
				print("Failed to move to first tile - occupied")
			end
		end
	end
end

-- Move player to target position
function GameService:MovePlayer(player: Player, targetWorldPos: Vector3): boolean
	local playerActor = self.Players[player]
	if not playerActor or not playerActor:IsAlive() then
		return false
	end

	local targetGridPos = self.GridSystem:WorldToGrid(targetWorldPos)

	-- Check if target is available
	if not self.GridSystem:IsTileAvailable(targetGridPos) then
		return false
	end

	-- Don't move if already at target
	if playerActor.GridPosition.X == targetGridPos.X and playerActor.GridPosition.Z == targetGridPos.Z then
		return false
	end

	-- Move on grid
	if self.GridSystem:MoveOccupant(playerActor.GridPosition, targetGridPos) then
		playerActor.GridPosition = targetGridPos

		-- Animate character movement using Humanoid
		if playerActor.Model then
			local humanoid = playerActor.Model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local worldPos = self.GridSystem:GridToWorld(targetGridPos)
				-- Use Humanoid:MoveTo for smooth walking animation
				humanoid:MoveTo(worldPos)
			end
		end

		return true
	end

	return false
end

-- Move monster to target position
function GameService:MoveMonster(monster: Actor.Actor, targetGridPos: GridTypes.GridPosition): boolean
	if not monster:IsAlive() then
		return false
	end

	-- Check if target is available
	if not self.GridSystem:IsTileAvailable(targetGridPos) then
		return false
	end

	-- Don't move if already at target
	if monster.GridPosition.X == targetGridPos.X and monster.GridPosition.Z == targetGridPos.Z then
		return false
	end

	-- Move on grid
	if self.GridSystem:MoveOccupant(monster.GridPosition, targetGridPos) then
		monster.GridPosition = targetGridPos

		-- Smoothly move monster model using TweenService
		if monster.Model then
			local rootPart = monster.Model.PrimaryPart or monster.Model:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local worldPos = self.GridSystem:GridToWorld(targetGridPos)
				local startPos = rootPart.Position
				local offset = worldPos - startPos

				-- Calculate movement duration based on distance (roughly 0.3s per tile)
				local distance = offset.Magnitude
				local moveDuration = math.max(0.2, distance / 4 * 0.3)

				-- Use TweenService for smooth movement
				local TweenService = game:GetService("TweenService")
				local tweenInfo = TweenInfo.new(
					moveDuration,
					Enum.EasingStyle.Linear,
					Enum.EasingDirection.InOut
				)

				-- Tween all parts together
				for _, part in monster.Model:GetDescendants() do
					if part:IsA("BasePart") then
						local targetPos = part.Position + offset
						local tween = TweenService:Create(part, tweenInfo, { Position = targetPos })
						tween:Play()
					end
				end
			end
		end

		return true
	end

	return false
end

-- Player attacks a target
function GameService:PlayerAttack(player: Player, targetActor: Actor.Actor)
	local playerActor = self.Players[player]
	if not playerActor or not playerActor:IsAlive() then
		return
	end

	if not targetActor:IsAlive() then
		return
	end

	-- Play attack animation
	if playerActor.Model then
		local humanoid = playerActor.Model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- Load and play slash animation (Roblox built-in)
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				-- Use Roblox's built-in slash animation
				local slashAnim = Instance.new("Animation")
				slashAnim.AnimationId = "rbxassetid://522635514" -- Roblox slash animation
				local slashTrack = animator:LoadAnimation(slashAnim)
				slashTrack:Play()
			end
		end

		-- Face the target
		local humanoidRootPart = playerActor.Model:FindFirstChild("HumanoidRootPart")
		local targetPart = targetActor.Model and targetActor.Model:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and targetPart then
			humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, targetPart.Position)
		end
	end

	-- TODO: Get weapon stats from equipped weapon
	-- For now, use basic starter weapon stats
	local weaponMin = 4
	local weaponMax = 7

	-- Process attack (delay slightly for animation)
	task.wait(0.2)

	local damageInfo = CombatSystem.ProcessAttack(playerActor.Stats, targetActor.Stats, weaponMin, weaponMax, "Physical")

	if damageInfo then
		local died = CombatSystem.ApplyDamage(targetActor.Stats, damageInfo)

		-- Update monster health bar if target is a monster
		if not targetActor.IsPlayer and targetActor.Model and targetActor.Model.PrimaryPart then
			local healthBar = targetActor.Model.PrimaryPart:FindFirstChild("HealthBar")
			if healthBar then
				MonsterHealthBar.Update(healthBar, targetActor)
			end
		end

		-- Show damage numbers
		self:BroadcastDamage(targetActor, damageInfo.Amount, damageInfo.Type, damageInfo.IsCrit, false)

		print(
			string.format(
				"%s hit %s for %d %s damage%s",
				playerActor.Name,
				targetActor.Name,
				damageInfo.Amount,
				damageInfo.Type,
				damageInfo.IsCrit and " (CRIT!)" or ""
			)
		)

		if died then
			print(targetActor.Name .. " died!")

			-- Grant XP to player
			local xpReward = 5 + targetActor.Stats.Level * 2
			local leveledUp = playerActor:GrantXP(xpReward)

			if leveledUp then
				print(playerActor.Name .. " leveled up to " .. playerActor.Stats.Level .. "!")

				-- Send level-up notification
				local showNotificationEvent = game:GetService("ReplicatedStorage"):FindFirstChild("ShowNotification")
				if showNotificationEvent then
					showNotificationEvent:FireClient(
						player,
						string.format(
							"LEVEL UP! You are now level %d! You have %d attribute points to spend. Press C to open your character sheet.",
							playerActor.Stats.Level,
							playerActor.AvailableAttributePoints or 0
						)
					)
				end
			end

			-- Update stats after XP gain
			self:BroadcastStatsUpdate(player, playerActor)

			-- Generate and drop loot
			local loot = LootSystem.GenerateLoot(targetActor.Stats.Level, targetActor.Name)
			if #loot > 0 then
				self:CreateLootContainer(targetActor.GridPosition, loot)
			end
		end
	else
		-- Show miss
		self:BroadcastDamage(targetActor, 0, "Physical", false, true)
		print(playerActor.Name .. " missed!")
	end
end

-- Monster attacks a target
function GameService:MonsterAttack(monster: Actor.Actor, targetActor: Actor.Actor)
	if not monster:IsAlive() or not targetActor:IsAlive() then
		return
	end

	-- Get monster's damage from derived stats
	local avgDamage = monster.Stats.DerivedStats.MeleePower
	local weaponMin = math.floor(avgDamage * 0.8)
	local weaponMax = math.ceil(avgDamage * 1.2)

	-- Process attack
	local damageInfo = CombatSystem.ProcessAttack(monster.Stats, targetActor.Stats, weaponMin, weaponMax, "Physical")

	if damageInfo then
		local died = CombatSystem.ApplyDamage(targetActor.Stats, damageInfo)

		-- Update monster health bar if target is a monster
		if not targetActor.IsPlayer and targetActor.Model and targetActor.Model.PrimaryPart then
			local healthBar = targetActor.Model.PrimaryPart:FindFirstChild("HealthBar")
			if healthBar then
				MonsterHealthBar.Update(healthBar, targetActor)
			end
		end

		-- Show damage numbers
		self:BroadcastDamage(targetActor, damageInfo.Amount, damageInfo.Type, damageInfo.IsCrit, false)

		print(
			string.format(
				"%s hit %s for %d damage%s",
				monster.Name,
				targetActor.Name,
				damageInfo.Amount,
				damageInfo.IsCrit and " (CRIT!)" or ""
			)
		)

		-- If target is a player, update their stats
		if targetActor.IsPlayer then
			local player = self:GetPlayerFromActor(targetActor)
			if player then
				self:BroadcastStatsUpdate(player, targetActor)
			end
		end

		if died then
			print(targetActor.Name .. " died!")
		end
	else
		-- Show miss
		self:BroadcastDamage(targetActor, 0, "Physical", false, true)
		print(monster.Name .. " missed!")
	end
end

-- Create a loot container at a grid position
function GameService:CreateLootContainer(gridPos: GridTypes.GridPosition, loot: { LootSystem.LootDrop })
	if #loot == 0 then
		return nil
	end

	local lootId = "loot_" .. tostring(self.NextLootId)
	self.NextLootId += 1

	-- Create visual loot bag model
	local lootModel = Instance.new("Model")
	lootModel.Name = "LootBag_" .. lootId

	local lootPart = Instance.new("Part")
	lootPart.Name = "LootPart"
	lootPart.Size = Vector3.new(1.5, 1.5, 1.5)
	lootPart.Color = Color3.fromRGB(180, 140, 60) -- Golden/brown color
	lootPart.Material = Enum.Material.SmoothPlastic
	lootPart.Anchored = true
	lootPart.CanCollide = false
	lootPart.Position = self.GridSystem:GridToWorld(gridPos) + Vector3.new(0, 0.75, 0)
	lootPart.Parent = lootModel

	-- Add click detector for interaction
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 10
	clickDetector.Parent = lootPart

	-- Add visual sparkles to make it noticeable
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 215, 0)
	sparkles.Parent = lootPart

	lootModel.Parent = workspace

	-- Store loot container
	local container: LootContainer = {
		Id = lootId,
		Items = loot,
		GridPosition = gridPos,
		Model = lootModel,
	}

	self.LootContainers[lootId] = container

	print(string.format("Created loot container %s at (%d, %d) with %d items", lootId, gridPos.X, gridPos.Z, #loot))

	return container
end

-- Remove a loot container
function GameService:RemoveLootContainer(lootId: string)
	local container = self.LootContainers[lootId]
	if not container then
		return
	end

	-- Destroy visual model
	if container.Model then
		container.Model:Destroy()
	end

	-- Remove from table
	self.LootContainers[lootId] = nil

	print("Removed loot container " .. lootId)
end

return GameService
