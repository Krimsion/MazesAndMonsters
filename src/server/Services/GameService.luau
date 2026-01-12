--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ConfigurationManager = require(script.Parent.ConfigurationManager)
local Shared = ReplicatedStorage.Shared
local Actor = require(Shared.Data.Actor)
local MonsterAI = require(Shared.Systems.MonsterAI)
local MonsterTemplates = require(Shared.Data.MonsterTemplates)
local CombatSystem = require(Shared.Combat.CombatSystem)
local StatCalculator = require(Shared.Util.StatCalculator)
local LootSystem = require(Shared.Systems.LootSystem)
local ItemTypes = require(Shared.Types.Item)
local ProjectileManager = require(script.Parent.Parent.Combat.ProjectileManager)
local MonsterHealthBar = require(script.Parent.Parent.UI.MonsterHealthBar)
local PathfindingHelper = require(Shared.Systems.PathfindingService)

local GameService = {}
GameService.__index = GameService

export type PlayerAction = {
	Type: "Move" | "Attack",
	Path: { Vector3 }?,
	Target: Actor.Actor?,
	PathIndex: number,
	MovingToWaypoint: boolean?,
}

export type LootContainer = {
	Id: string,
	Items: { LootSystem.LootDrop },
	Position: Vector3,
	Model: Model?,
}

export type RespawnInfo = {
	TemplateName: string,
	Level: number,
	SpawnPosition: Vector3,
	RespawnTime: number,
}

export type MonsterData = {
	monster: Actor.Actor,
	ai: MonsterAI.MonsterAI,
	templateName: string,
	spawnPosition: Vector3,
}

export type GameService = typeof(setmetatable(
	{} :: {
		PathfindingHelper: PathfindingHelper.PathfindingHelper,
		Players: { [Player]: Actor.Actor },
		PlayerActions: { [Player]: PlayerAction? },
		PlayerLastAttackTime: { [Player]: number },
		Monsters: { MonsterData },
		LootContainers: { [string]: LootContainer },
		ProjectileManager: ProjectileManager.ProjectileManager,
		RespawnQueue: { RespawnInfo },
		LastUpdateTime: number,
		NextLootId: number,
		OnMonsterSpawned: ((Actor.Actor, Vector3) -> ())?,
		OnMonsterKilled: ((Player, Actor.Actor) -> ())?,
	},
	GameService
))

function GameService.new(): GameService
	local self = setmetatable({
		PathfindingHelper = PathfindingHelper.new(),
		Players = {},
		PlayerActions = {},
		PlayerLastAttackTime = {},
		Monsters = {},
		LootContainers = {},
		ProjectileManager = ProjectileManager.new(),
		RespawnQueue = {},
		LastUpdateTime = tick(),
		NextLootId = 1,
		OnMonsterSpawned = nil,
		OnMonsterKilled = nil,
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

	-- Also send full stats for character sheet
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
	local worldPosition = targetActor.Position

	-- Send to all players
	for player, _ in self.Players do
		showDamageEvent:FireClient(player, worldPosition, amount, damageType, isCrit, isMiss)
	end
end

-- Main update loop
function GameService:Update()
	local currentTime = tick()
	local deltaTime = currentTime - self.LastUpdateTime
	self.LastUpdateTime = currentTime

	-- Update all players
	for player, playerActor in self.Players do
		if playerActor:IsAlive() then
			-- Sync player position from character model
			if playerActor.Model then
				local humanoidRootPart = playerActor.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if humanoidRootPart then
					local oldPosition = playerActor.Position
					playerActor.Position = humanoidRootPart.Position

					-- Check if player manually moved (not following our path)
					local action = self.PlayerActions[player]
					if action and action.Type == "Move" and action.Path and #action.Path > 0 then
						local movedDistance = (playerActor.Position - oldPosition).Magnitude
						if movedDistance > 0.5 then
							-- Player moved significantly
							local targetWaypoint = action.Path[action.PathIndex]
							if targetWaypoint then
								local directionToWaypoint = (targetWaypoint - oldPosition).Unit
								local actualDirection = (playerActor.Position - oldPosition).Unit
								local dot = directionToWaypoint:Dot(actualDirection)

								-- If moving away from waypoint (dot < 0.5), player is manually controlling
								if dot < 0.5 then
									-- Player is manually moving, cancel automatic movement
									self.PlayerActions[player] = nil
								end
							end
						end
					end
				end
			end

			-- Handle player actions (movement, attacks)
			local action = self.PlayerActions[player]
			if action then
				if action.Type == "Move" and action.Path and #action.Path > 0 then
					-- Check if we're attacking a target and within weapon range
					if action.Target and action.Target:IsAlive() then
						local weapon = playerActor.Equipment.Weapon
						local attackRange = weapon and weapon.AttackRange or 1
						local attackRangeStuds = attackRange * 4
						local distance = (playerActor.Position - action.Target.Position).Magnitude

						if distance <= attackRangeStuds then
							-- Within attack range, transition to attacking
							action.Type = "Attack"
							action.Path = nil
							action.PathIndex = 1

							-- Stop the humanoid from moving
							if playerActor.Model then
								local humanoid = playerActor.Model:FindFirstChildOfClass("Humanoid")
								if humanoid then
									humanoid:Move(Vector3.new(0, 0, 0))
								end
							end
						else
							-- Check if target has moved significantly (more than 8 studs from path end)
							-- If so, recalculate path to avoid chasing old positions
							local pathEnd = action.Path[#action.Path]
							if pathEnd then
								local targetMovement = (action.Target.Position - pathEnd).Magnitude
								if targetMovement > 8 then
									-- Target moved significantly, recalculate path
									local newPath = self.PathfindingHelper:FindPath(playerActor.Position, action.Target.Position)
									if newPath then
										action.Path = newPath
										action.PathIndex = 1
										action.MovingToWaypoint = false
									end
								end
							end
						end
					end

					-- Only move if still in Move mode
					if action.Type == "Move" then
						-- Move along path
						self:MoveActorAlongPath(playerActor, action, deltaTime)

						-- Check if reached end of path
						if action.PathIndex > #action.Path then
							-- Path complete, check if we should attack target
							if action.Target and action.Target:IsAlive() then
								action.Type = "Attack"
								action.Path = nil
							else
								self.PlayerActions[player] = nil
							end
						end
					end
				elseif action.Type == "Attack" and action.Target then
					-- Attack once then clear action (one attack per click)
					if action.Target:IsAlive() then
						local weapon = playerActor.Equipment.Weapon
						local attackRange = weapon and weapon.AttackRange or 1
						local attackRangeStuds = attackRange * 4
						local distance = (playerActor.Position - action.Target.Position).Magnitude

						if distance <= attackRangeStuds then
							-- In range, attack once
							self:PlayerAttack(player, action.Target)
							-- Clear action after single attack
							self.PlayerActions[player] = nil
						elseif distance > attackRangeStuds + 8 then
							-- Significantly out of range (2+ tiles beyond weapon range), move closer
							-- Add buffer to prevent jittery movement when target is near range boundary
							action.Type = "Move"
							local path = self.PathfindingHelper:FindPath(playerActor.Position, action.Target.Position)
							if path then
								action.Path = path
								action.PathIndex = 1
								action.MovingToWaypoint = false
							else
								self.PlayerActions[player] = nil
							end
						else
							-- Within buffer zone, just clear action (too far to attack but not far enough to chase)
							self.PlayerActions[player] = nil
						end
					else
						-- Target is dead, clear action
						self.PlayerActions[player] = nil
					end
				end
			end
		end
	end

	-- Update all monsters
	for i = #self.Monsters, 1, -1 do
		local monsterData = self.Monsters[i]
		local monster = monsterData.monster
		local ai = monsterData.ai

		if not monster:IsAlive() then
			-- Queue for respawn if it's a respawnable monster
			if monsterData.templateName == "Skeleton" then
				local respawnDelay = ConfigurationManager.GetNumber("MonsterRespawnTime", 20)
				table.insert(self.RespawnQueue, {
					TemplateName = monsterData.templateName,
					Level = monster.Stats.Level,
					SpawnPosition = monsterData.spawnPosition,
					RespawnTime = currentTime + respawnDelay,
				})
			end

			-- Remove dead monster
			table.remove(self.Monsters, i)
			if monster.Model then
				monster.Model:Destroy()
			end
			continue
		end

		-- Update monster AI
		MonsterAI.Update(ai, deltaTime, monster, self.Players, self.Monsters, self)
	end

	-- Check respawn queue
	for i = #self.RespawnQueue, 1, -1 do
		local respawnInfo = self.RespawnQueue[i]
		if currentTime >= respawnInfo.RespawnTime then
			-- Respawn the monster
			self:SpawnMonster(
				respawnInfo.TemplateName,
				respawnInfo.Level,
				respawnInfo.SpawnPosition,
				false,
				false
			)
			table.remove(self.RespawnQueue, i)
		end
	end

	-- Update projectiles
	self.ProjectileManager:Update(deltaTime)
end

-- Move actor smoothly along path
function GameService:MoveActorAlongPath(actor: Actor.Actor, action: PlayerAction, deltaTime: number)
	if not action.Path or #action.Path == 0 then
		return
	end

	local targetPos = action.Path[action.PathIndex]
	if not targetPos then
		return
	end

	-- For players, use Humanoid:MoveTo for smooth movement
	if actor.IsPlayer and actor.Model then
		local humanoid = actor.Model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- Check if reached waypoint (within 2 studs)
			-- Position already synced in main update loop
			local distance = (targetPos - actor.Position).Magnitude
			if distance < 2 then
				-- Reached waypoint, move to next
				action.PathIndex += 1
				action.MovingToWaypoint = false
			elseif not action.MovingToWaypoint then
				-- Only call MoveTo once per waypoint
				action.MovingToWaypoint = true
				humanoid:MoveTo(targetPos)
			end
		end
	else
		-- For monsters, move directly
		local direction = (targetPos - actor.Position).Unit
		local distance = (targetPos - actor.Position).Magnitude
		local moveSpeed = 0.8
		local studsPerSecond = (1 / moveSpeed) * 4
		local moveAmount = studsPerSecond * deltaTime

		if moveAmount >= distance then
			actor.Position = targetPos
			action.PathIndex += 1
		else
			actor.Position = actor.Position + (direction * moveAmount)
		end

		-- Update model position - use PivotTo to move entire model
		if actor.Model and actor.Model.PrimaryPart then
			actor.Model:PivotTo(CFrame.new(actor.Position))
		end
	end
end

-- Register a player
function GameService:RegisterPlayer(player: Player, actor: Actor.Actor)
	self.Players[player] = actor
	print(string.format("Registered player %s at position %s", player.Name, tostring(actor.Position)))
end

-- Unregister a player
function GameService:UnregisterPlayer(player: Player)
	self.Players[player] = nil
	self.PlayerActions[player] = nil
end

-- Spawn a monster
function GameService:SpawnMonster(
	templateName: string,
	level: number,
	spawnPosition: Vector3,
	debug: boolean?,
	isElite: boolean?
): Actor.Actor?
	local template = MonsterTemplates.GetTemplate(templateName)
	if not template then
		warn("Monster template not found:", templateName)
		return nil
	end

	-- Calculate monster stats based on template and level
	local monsterStats = MonsterTemplates.CalculateMonsterStats(template, level)

	-- Create monster actor
	local monster = Actor.new(template.Name, false, level, monsterStats.Attributes, spawnPosition)
	monster.Stats = monsterStats

	-- Create AI
	local ai = MonsterAI.new()

	-- Store monster data
	table.insert(self.Monsters, {
		monster = monster,
		ai = ai,
		templateName = templateName,
		spawnPosition = spawnPosition,
	})

	-- Call spawn callback
	if self.OnMonsterSpawned then
		self.OnMonsterSpawned(monster, spawnPosition)
	end

	return monster
end

-- Set player to move to attack a target
function GameService:SetPlayerMoveToAttack(player: Player, targetActor: Actor.Actor)
	print(string.format("CLICK: %s clicked on %s", player.Name, targetActor.Name))

	local playerActor = self.Players[player]
	if not playerActor then
		return
	end

	-- Sync player position from character model before pathfinding
	if playerActor.Model then
		local humanoidRootPart = playerActor.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoidRootPart then
			playerActor.Position = humanoidRootPart.Position
		end
	end

	-- Check for duplicate action - if already moving to or attacking this target, ignore
	local existingAction = self.PlayerActions[player]
	if existingAction and existingAction.Target == targetActor then
		-- Already targeting this enemy, don't create duplicate action
		print(string.format("DUPLICATE: %s already has action for %s (type: %s)", player.Name, targetActor.Name, existingAction.Type))
		return
	end

	-- Get weapon range
	local weapon = playerActor.Equipment.Weapon
	local attackRange = weapon and weapon.AttackRange or 1
	local attackRangeStuds = attackRange * 4 -- Convert to studs

	-- Check if already in range
	local distance = (playerActor.Position - targetActor.Position).Magnitude
	if distance <= attackRangeStuds then
		-- In range, attack immediately
		print(string.format("IMMEDIATE: %s in range (%.1f <= %.1f), attacking now", player.Name, distance, attackRangeStuds))
		self:PlayerAttack(player, targetActor)
		return
	end

	-- Find path to target
	local path = self.PathfindingHelper:FindPath(playerActor.Position, targetActor.Position)
	if not path then
		print(player.Name, "could not find path to target")
		return
	end

	-- Set player action
	self.PlayerActions[player] = {
		Type = "Move",
		Path = path,
		Target = targetActor,
		PathIndex = 2, -- Start at index 2 (skip current position)
	}

	print(player.Name, "moving to attack", targetActor.Name, "with", #path, "waypoints")
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

	-- Attack cooldown check
	local currentTime = tick()
	local lastAttackTime = self.PlayerLastAttackTime[player] or 0
	local attackCooldown = ConfigurationManager.GetNumber("PlayerAttackCooldown", 1.0)

	if currentTime - lastAttackTime < attackCooldown then
		print(string.format("COOLDOWN: %s attack blocked (%.2fs remaining)", player.Name, attackCooldown - (currentTime - lastAttackTime)))
		return
	end

	print(string.format("ATTACK: %s attacking %s from position %s (target at %s)", player.Name, targetActor.Name, tostring(playerActor.Position), tostring(targetActor.Position)))
	self.PlayerLastAttackTime[player] = currentTime

	-- Get weapon stats
	local weapon = playerActor.Equipment.Weapon
	local weaponMin = weapon and weapon.WeaponMinDamage or 4
	local weaponMax = weapon and weapon.WeaponMaxDamage or 7
	local isRanged = weapon and weapon.IsRanged or false
	local attackRange = weapon and weapon.AttackRange or 1
	local attackRangeStuds = attackRange * 4

	-- Check if target is within weapon range
	local distance = (playerActor.Position - targetActor.Position).Magnitude
	if distance > attackRangeStuds then
		warn(string.format("%s tried to attack but target is out of range (%.1f > %.1f)", player.Name, distance, attackRangeStuds))
		return
	end

	-- Face the target
	if playerActor.Model and playerActor.Model.PrimaryPart and targetActor.Model and targetActor.Model.PrimaryPart then
		playerActor.Model.PrimaryPart.CFrame = CFrame.lookAt(playerActor.Position, targetActor.Position)
	end

	-- Create projectile for ranged weapons
	if isRanged and playerActor.Model and targetActor.Model then
		local attackerPart = playerActor.Model:FindFirstChild("HumanoidRootPart")
		local targetPart = targetActor.Model:FindFirstChild("HumanoidRootPart")

		if attackerPart and targetPart then
			-- Create arrow projectile
			local arrow = Instance.new("Part")
			arrow.Name = "Arrow"
			arrow.Size = Vector3.new(0.2, 0.2, 1)
			arrow.Color = Color3.fromRGB(101, 67, 33)
			arrow.Material = Enum.Material.Wood
			arrow.Anchored = true
			arrow.CanCollide = false
			arrow.Parent = workspace

			local startPos = attackerPart.Position + Vector3.new(0, 2, 0)
			local endPos = targetPart.Position + Vector3.new(0, 1.5, 0)

			arrow.CFrame = CFrame.lookAt(startPos, endPos)

			-- Tween arrow to target
			local TweenService = game:GetService("TweenService")
			local flightTime = 0.3
			local tweenInfo = TweenInfo.new(flightTime, Enum.EasingStyle.Linear)
			local tween = TweenService:Create(arrow, tweenInfo, {
				CFrame = CFrame.lookAt(endPos, startPos),
			})
			tween:Play()

			task.delay(flightTime, function()
				arrow:Destroy()
			end)
		end
	end

	-- Process attack (delay for animation/projectile)
	task.wait(isRanged and 0.3 or 0.2)

	local damageInfo = CombatSystem.ProcessAttack(playerActor.Stats, targetActor.Stats, weaponMin, weaponMax, "Physical")

	if damageInfo then
		local died = CombatSystem.ApplyDamage(targetActor.Stats, damageInfo)

		-- Update monster health bar
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

			-- Notify quest system
			if self.OnMonsterKilled then
				self.OnMonsterKilled(player, targetActor)
			end

			-- Grant XP
			local xpReward = 5 + targetActor.Stats.Level * 2
			local leveledUp = playerActor:GrantXP(xpReward)

			if leveledUp then
				print(playerActor.Name .. " leveled up to " .. playerActor.Stats.Level .. "!")

				local showNotificationEvent = ReplicatedStorage:FindFirstChild("ShowNotification")
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
				self:CreateLootContainer(targetActor.Position, loot)
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

	-- Check range
	local attackRange = ConfigurationManager.GetNumber("MonsterAttackRange", 1) * 4
	local distance = (monster.Position - targetActor.Position).Magnitude
	if distance > attackRange then
		return
	end

	-- Face the target
	if monster.Model and monster.Model.PrimaryPart and targetActor.Model and targetActor.Model.PrimaryPart then
		monster.Model.PrimaryPart.CFrame = CFrame.lookAt(monster.Position, targetActor.Position)
	end

	-- Simple monster attack (always melee)
	task.wait(0.3)

	local damageInfo = CombatSystem.ProcessAttack(monster.Stats, targetActor.Stats, 5, 10, "Physical")

	if damageInfo then
		local died = CombatSystem.ApplyDamage(targetActor.Stats, damageInfo)

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

		if died then
			print(targetActor.Name .. " died from monster attack!")

			-- Update player stats
			local player = self:GetPlayerFromActor(targetActor)
			if player then
				self:BroadcastStatsUpdate(player, targetActor)
			end
		else
			-- Update player stats for health change
			local player = self:GetPlayerFromActor(targetActor)
			if player then
				self:BroadcastStatsUpdate(player, targetActor)
			end
		end
	else
		-- Show miss
		self:BroadcastDamage(targetActor, 0, "Physical", false, true)
		print(monster.Name .. " missed!")
	end
end

-- Create loot container at position
function GameService:CreateLootContainer(position: Vector3, items: { LootSystem.LootDrop })
	local lootId = tostring(self.NextLootId)
	self.NextLootId += 1

	-- Create loot bag model (client expects a Model, not a Part)
	local lootBagModel = Instance.new("Model")
	lootBagModel.Name = "LootBag_" .. lootId

	-- Create the visual part (client looks for "LootPart")
	local lootPart = Instance.new("Part")
	lootPart.Name = "LootPart"
	lootPart.Size = Vector3.new(2, 1, 2)
	lootPart.Position = position + Vector3.new(0, 0.5, 0)
	lootPart.Color = Color3.fromRGB(139, 69, 19)
	lootPart.Material = Enum.Material.Fabric
	lootPart.Anchored = true
	lootPart.CanCollide = false
	lootPart.Parent = lootBagModel

	-- Add click detector to the part
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 10
	clickDetector.Parent = lootPart

	lootBagModel.PrimaryPart = lootPart
	lootBagModel.Parent = workspace

	self.LootContainers[lootId] = {
		Id = lootId,
		Items = items,
		Position = position,
		Model = lootBagModel,
	}

	print(string.format("Created loot container at %s with %d items", tostring(position), #items))
end

-- Pick up loot from container
function GameService:PickupLoot(player: Player, lootId: string)
	print(string.format("PickupLoot called: player=%s, lootId=%s", player.Name, lootId))

	local container = self.LootContainers[lootId]
	if not container then
		warn(string.format("Loot container %s not found", lootId))
		return
	end

	local playerActor = self.Players[player]
	if not playerActor then
		warn(string.format("Player actor not found for %s", player.Name))
		return
	end

	-- Check range
	local distance = (playerActor.Position - container.Position).Magnitude
	local pickupRange = ConfigurationManager.GetNumber("LootPickupRange", 2) * 4
	print(string.format("Pickup distance check: %.2f studs (max: %.2f)", distance, pickupRange))
	if distance > pickupRange then
		warn(string.format("%s is too far from loot (%.2f > %.2f)", player.Name, distance, pickupRange))
		return
	end

	-- Add items to inventory
	print(string.format("Adding %d items to inventory", #container.Items))
	for _, lootDrop in container.Items do
		local success = playerActor.Inventory:AddItem(lootDrop.Item, lootDrop.Quantity)
		print(string.format("Added %s x%d: %s", lootDrop.Item.Name, lootDrop.Quantity, tostring(success)))
	end

	-- Update client inventory
	local updateInventoryEvent = ReplicatedStorage:FindFirstChild("UpdateInventory")
	if updateInventoryEvent then
		updateInventoryEvent:FireClient(player, playerActor.Inventory.Slots)
		print("Sent inventory update to client")
	end

	-- Remove loot container
	if container.Model then
		container.Model:Destroy()
		print("Destroyed loot model")
	end
	self.LootContainers[lootId] = nil

	print(player.Name, "successfully picked up loot", lootId)
end

return GameService
