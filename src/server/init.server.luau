--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameService = require(script.Services.GameService)
local StatCalculator = require(ReplicatedStorage.Shared.Util.StatCalculator)

-- Initialize game service with 4-unit tiles
local gameService = GameService.new(4)

print("MazesAndMonsters Server initialized!")

-- Setup remote events for client-server communication
local playerClickEvent = Instance.new("RemoteEvent")
playerClickEvent.Name = "PlayerClick"
playerClickEvent.Parent = ReplicatedStorage

local playerAbilityEvent = Instance.new("RemoteEvent")
playerAbilityEvent.Name = "PlayerAbility"
playerAbilityEvent.Parent = ReplicatedStorage

local updateStatsEvent = Instance.new("RemoteEvent")
updateStatsEvent.Name = "UpdateStats"
updateStatsEvent.Parent = ReplicatedStorage

local showDamageEvent = Instance.new("RemoteEvent")
showDamageEvent.Name = "ShowDamage"
showDamageEvent.Parent = ReplicatedStorage

-- Inventory & Equipment events
local equipItemEvent = Instance.new("RemoteEvent")
equipItemEvent.Name = "EquipItem"
equipItemEvent.Parent = ReplicatedStorage

local unequipItemEvent = Instance.new("RemoteEvent")
unequipItemEvent.Name = "UnequipItem"
unequipItemEvent.Parent = ReplicatedStorage

local updateInventoryEvent = Instance.new("RemoteEvent")
updateInventoryEvent.Name = "UpdateInventory"
updateInventoryEvent.Parent = ReplicatedStorage

local updateEquipmentEvent = Instance.new("RemoteEvent")
updateEquipmentEvent.Name = "UpdateEquipment"
updateEquipmentEvent.Parent = ReplicatedStorage

local useBeltItemEvent = Instance.new("RemoteEvent")
useBeltItemEvent.Name = "UseBeltItem"
useBeltItemEvent.Parent = ReplicatedStorage

local updateBeltEvent = Instance.new("RemoteEvent")
updateBeltEvent.Name = "UpdateBelt"
updateBeltEvent.Parent = ReplicatedStorage

local setBeltSlotEvent = Instance.new("RemoteEvent")
setBeltSlotEvent.Name = "SetBeltSlot"
setBeltSlotEvent.Parent = ReplicatedStorage

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
	print(player.Name .. " joined the game")

	player.CharacterAdded:Connect(function(character)
		print(player.Name .. "'s character spawned")

		-- Wait for character to load
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
		if not humanoidRootPart then
			return
		end

		-- Register player at their spawn position
		local spawnPos = humanoidRootPart.Position
		local gridPos = gameService.GridSystem:WorldToGrid(spawnPos)

		local playerActor = gameService:RegisterPlayer(player, gridPos)
		playerActor.Model = character

		print(string.format(
			"%s registered at grid position (%d, %d) - HP: %d, Mana: %d",
			player.Name,
			gridPos.X,
			gridPos.Z,
			playerActor.Stats.RuntimeStats.CurrentHealth,
			playerActor.Stats.RuntimeStats.CurrentMana
		))

		-- Send initial stats to client
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

		-- Add some test items to server inventory for testing
		local ItemTypes = require(ReplicatedStorage.Shared.Types.Item)
		local testPotion: ItemTypes.Item = {
			Id = "potion_health_minor",
			Name = "Minor Health Potion",
			Description = "Restores 50 HP",
			Type = "Potion",
			Rarity = "Common",
			Level = 1,
			MaxStack = 10,
		}
		local testSword: ItemTypes.Item = {
			Id = "sword_iron",
			Name = "Iron Sword",
			Description = "A basic iron sword",
			Type = "Weapon",
			Rarity = "Common",
			Level = 1,
			MaxStack = 1,
			EquipmentSlot = "Weapon",
			WeaponMinDamage = 4,
			WeaponMaxDamage = 7,
		}
		playerActor.Inventory:AddItem(testPotion, 5)
		playerActor.Inventory:AddItem(testSword, 1)

		-- Send initial belt state (empty)
		updateBeltEvent:FireClient(player, playerActor.BeltSlots)

		-- Send initial equipment state (empty)
		updateEquipmentEvent:FireClient(player, playerActor.Equipment)

		-- Send initial inventory state with test items
		updateInventoryEvent:FireClient(player, playerActor.Inventory.Slots)

		-- Spawn some test monsters nearby
		local testMonsterPositions = {
			{ X = gridPos.X + 5, Z = gridPos.Z },
			{ X = gridPos.X + 3, Z = gridPos.Z + 3 },
			{ X = gridPos.X - 4, Z = gridPos.Z + 2 },
		}

		for i, monsterPos in testMonsterPositions do
			local monster = gameService:SpawnMonster("Skeleton", 1, monsterPos, false, false)
			if monster then
				print(string.format(
					"Spawned %s at grid position (%d, %d)",
					monster.Name,
					monsterPos.X,
					monsterPos.Z
				))

				-- Create a simple visual representation
				local monsterModel = Instance.new("Model")
				monsterModel.Name = monster.Name

				-- Create HumanoidRootPart (required for Humanoid:MoveTo to work)
				local rootPart = Instance.new("Part")
				rootPart.Name = "HumanoidRootPart"
				rootPart.Size = Vector3.new(2, 2, 1)
				rootPart.Color = Color3.fromRGB(150, 150, 150)
				rootPart.Anchored = false
				rootPart.CanCollide = true
				rootPart.Position = gameService.GridSystem:GridToWorld(monsterPos)
				rootPart.Parent = monsterModel

				-- Create visible body part
				local bodyPart = Instance.new("Part")
				bodyPart.Name = "Torso"
				bodyPart.Size = Vector3.new(2, 2, 1)
				bodyPart.Color = Color3.fromRGB(150, 150, 150)
				bodyPart.Anchored = false
				bodyPart.CanCollide = false
				bodyPart.Position = rootPart.Position + Vector3.new(0, 2, 0)
				bodyPart.Parent = monsterModel

				-- Weld body to root
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = rootPart
				weld.Part1 = bodyPart
				weld.Parent = rootPart

				-- Create humanoid
				local humanoid = Instance.new("Humanoid")
				humanoid.Parent = monsterModel

				monsterModel.PrimaryPart = rootPart
				monsterModel.Parent = workspace

				monster.Model = monsterModel
			end
		end
	end)
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	print(player.Name .. " left the game")
	gameService:UnregisterPlayer(player)
end)

-- Handle player clicks (movement/attack/interact)
playerClickEvent.OnServerEvent:Connect(function(player, clickPosition: Vector3)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	local targetGridPos = gameService.GridSystem:WorldToGrid(clickPosition)
	local tile = gameService.GridSystem:GetTile(targetGridPos)

	-- Check if clicking on an enemy
	if tile.OccupiedBy and not tile.OccupiedBy.IsPlayer then
		-- Move to attack the enemy
		gameService:SetPlayerMoveToAttack(player, tile.OccupiedBy)
	else
		-- Try to move
		gameService:MovePlayer(player, clickPosition)
		-- Cancel any existing action
		gameService.PlayerActions[player] = nil
	end
end)

-- Handle ability usage
playerAbilityEvent.OnServerEvent:Connect(function(player, targetPosition: Vector3)
	print(player.Name .. " used ability at", targetPosition)
	-- TODO: Implement ability system
end)

-- Handle equipment changes
equipItemEvent.OnServerEvent:Connect(function(player, inventorySlot: number, equipSlot: string)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	-- Get item from inventory
	local stack = playerActor.Inventory:GetItem(inventorySlot)
	if not stack then
		warn(player.Name, "tried to equip from empty slot", inventorySlot)
		return
	end

	local item = stack.Item

	-- Validate equipment slot
	if not item.EquipmentSlot then
		warn(player.Name, "tried to equip non-equipment item", item.Name)
		return
	end

	-- Use Actor's EquipItem method
	if playerActor:EquipItem(item) then
		-- Remove from inventory
		playerActor.Inventory:RemoveItem(inventorySlot, 1)

		print(string.format("%s equipped %s to %s", player.Name, item.Name, equipSlot))

		-- Broadcast updated stats
		gameService:BroadcastStatsUpdate(player, playerActor)

		-- Send updated equipment to client
		updateEquipmentEvent:FireClient(player, playerActor.Equipment)
	end
end)

unequipItemEvent.OnServerEvent:Connect(function(player, equipSlot: string)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	-- Use Actor's UnequipItem method
	if playerActor:UnequipItem(equipSlot) then
		print(string.format("%s unequipped %s", player.Name, equipSlot))

		-- Broadcast updated stats
		gameService:BroadcastStatsUpdate(player, playerActor)

		-- Send updated equipment to client
		updateEquipmentEvent:FireClient(player, playerActor.Equipment)
	else
		warn(player.Name, "failed to unequip from", equipSlot, "- inventory may be full")
	end
end)

-- Handle belt item usage
useBeltItemEvent.OnServerEvent:Connect(function(player, slotIndex: number)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	-- Use the belt slot
	if playerActor:UseBeltSlot(slotIndex) then
		print(string.format("%s used belt slot %d", player.Name, slotIndex))

		-- Broadcast updated stats (health/mana may have changed)
		gameService:BroadcastStatsUpdate(player, playerActor)

		-- Send updated belt to client
		updateBeltEvent:FireClient(player, playerActor.BeltSlots)
	else
		warn(player.Name, "failed to use belt slot", slotIndex)
	end
end)

-- Handle setting belt slots
setBeltSlotEvent.OnServerEvent:Connect(function(player, slotIndex: number, inventorySlot: number?)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	if inventorySlot then
		-- Moving item from inventory to belt
		local stack = playerActor.Inventory:GetItem(inventorySlot)
		if not stack then
			warn(player.Name, "tried to move from empty inventory slot", inventorySlot)
			return
		end

		local item = stack.Item

		-- Validate item type
		if item.Type ~= "Potion" and item.Type ~= "Scroll" then
			warn(player.Name, "tried to put non-consumable in belt:", item.Name)
			return
		end

		-- Set belt slot (this will handle swapping if needed)
		if playerActor:SetBeltSlot(slotIndex, item, 1) then
			-- Remove from inventory
			playerActor.Inventory:RemoveItem(inventorySlot, 1)

			print(string.format("%s moved %s to belt slot %d", player.Name, item.Name, slotIndex))

			-- Send updated belt AND inventory to client
			updateBeltEvent:FireClient(player, playerActor.BeltSlots)
			updateInventoryEvent:FireClient(player, playerActor.Inventory.Slots)
		end
	else
		-- Clearing belt slot (moving to inventory would be handled separately)
		playerActor:SetBeltSlot(slotIndex, nil, nil)

		-- Send updated belt to client
		updateBeltEvent:FireClient(player, playerActor.BeltSlots)
	end
end)

print("Server setup complete!")
