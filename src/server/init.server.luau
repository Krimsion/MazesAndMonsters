--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameService = require(script.Services.GameService)
local PlayerDataService = require(script.Services.PlayerDataService)
local ConfigurationManager = require(script.Services.ConfigurationManager)
local QuestManager = require(script.Services.QuestManager)
local StatCalculator = require(ReplicatedStorage.Shared.Util.StatCalculator)
local CombatSystem = require(ReplicatedStorage.Shared.Combat.CombatSystem)
local SkillBook = require(ReplicatedStorage.Shared.Data.SkillBook)
local MonsterAI = require(ReplicatedStorage.Shared.Systems.MonsterAI)
local MonsterHealthBar = require(script.UI.MonsterHealthBar)
local ItemTypes = require(ReplicatedStorage.Shared.Types.Item)
local Actor = require(ReplicatedStorage.Shared.Data.Actor)

-- Initialize configuration first
ConfigurationManager.GetOrCreateConfig()

-- Initialize game service
local gameService = GameService.new()

-- Initialize quest manager
local questManager = QuestManager.new()

print("MazesAndMonsters Server initialized with tile size:", tileSize)

-- Set up collision groups to prevent player-monster pushing
local PhysicsService = game:GetService("PhysicsService")

-- Create collision groups if they don't exist
pcall(function()
	PhysicsService:CreateCollisionGroup("Players")
end)
pcall(function()
	PhysicsService:CreateCollisionGroup("Monsters")
end)

-- Make players and monsters not collide with each other (body blocking only, no pushing)
PhysicsService:CollisionGroupSetCollidable("Players", "Monsters", false)

-- Helper function to create a visual model for a monster
local function CreateMonsterModel(monster, position)
	-- Create a simple visual representation
	local monsterModel = Instance.new("Model")
	monsterModel.Name = monster.Name

	-- Create HumanoidRootPart (anchored to prevent physics issues)
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Color = Color3.fromRGB(150, 150, 150)
	rootPart.Anchored = true
	rootPart.CanCollide = false
	rootPart.CanQuery = false
	rootPart.Position = position
	rootPart.Parent = monsterModel

	-- Assign to Monsters collision group
	PhysicsService:SetPartCollisionGroup(rootPart, "Monsters")

	-- Create visible body part
	local bodyPart = Instance.new("Part")
	bodyPart.Name = "Torso"
	bodyPart.Size = Vector3.new(2, 2, 1)
	bodyPart.Color = Color3.fromRGB(150, 150, 150)
	bodyPart.Anchored = true -- Anchor since root is anchored
	bodyPart.CanCollide = false
	bodyPart.CanQuery = false -- Don't block raycasts - let ClickArea handle clicks
	bodyPart.Position = rootPart.Position + Vector3.new(0, 2, 0)
	bodyPart.Parent = monsterModel

	-- Create larger invisible clickable area for easier targeting
	local clickArea = Instance.new("Part")
	clickArea.Name = "ClickArea"
	clickArea.Size = Vector3.new(6, 8, 6) -- Even larger for easier clicking
	clickArea.Color = Color3.fromRGB(255, 0, 0)
	clickArea.Transparency = 0.95 -- Nearly invisible (but not fully, as mouse can't detect 1.0)
	clickArea.Anchored = true -- Anchor since root is anchored
	clickArea.CanCollide = false
	clickArea.CanTouch = false -- Don't trigger touch events
	clickArea.Position = rootPart.Position + Vector3.new(0, 2, 0) -- Centered higher to cover full height
	clickArea.Parent = monsterModel

	-- Don't create Humanoid - we handle monster movement manually
	-- and Humanoids cause physics interactions that knock over players

	monsterModel.PrimaryPart = rootPart
	monsterModel.Parent = workspace

	monster.Model = monsterModel

	-- Create health bar UI
	MonsterHealthBar.Create(monster, monsterModel)
end

-- Helper function to create Cane NPC model
local function CreateCaneNPC(position)
	local npcModel = Instance.new("Model")
	npcModel.Name = "Cane"

	-- Create HumanoidRootPart
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Color = Color3.fromRGB(100, 180, 100) -- Green color for friendly NPC
	rootPart.Anchored = true
	rootPart.CanCollide = false
	rootPart.CanQuery = false
	rootPart.Position = position
	rootPart.Parent = npcModel

	-- Create visible body part
	local bodyPart = Instance.new("Part")
	bodyPart.Name = "Torso"
	bodyPart.Size = Vector3.new(2, 2, 1)
	bodyPart.Color = Color3.fromRGB(100, 180, 100)
	bodyPart.Anchored = true
	bodyPart.CanCollide = false
	bodyPart.CanQuery = false
	bodyPart.Position = rootPart.Position + Vector3.new(0, 2, 0)
	bodyPart.Parent = npcModel

	-- Create clickable area for NPC interaction
	local clickArea = Instance.new("Part")
	clickArea.Name = "ClickArea"
	clickArea.Size = Vector3.new(6, 8, 6)
	clickArea.Color = Color3.fromRGB(0, 255, 0)
	clickArea.Transparency = 0.95
	clickArea.Anchored = true
	clickArea.CanCollide = false
	clickArea.CanTouch = false
	clickArea.Position = rootPart.Position + Vector3.new(0, 2, 0)
	clickArea.Parent = npcModel

	-- Add a name tag above the NPC
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "NameTag"
	billboardGui.Size = UDim2.new(0, 100, 0, 40)
	billboardGui.StudsOffset = Vector3.new(0, 5, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.Parent = rootPart

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Cane"
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- Yellow for quest giver
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.Parent = billboardGui

	npcModel.PrimaryPart = rootPart
	npcModel.Parent = workspace

	return npcModel
end

-- Set up callback for when monsters spawn (including respawns)
gameService.OnMonsterSpawned = function(monster, position)
	CreateMonsterModel(monster, position)
end

-- Set up callback for when monsters are killed by players
gameService.OnMonsterKilled = function(player, monster)
	-- Update quest progress for killing this monster type
	local updatedQuests = questManager:UpdateQuestProgress(player, "Kill", monster.Name, 1)

	-- If any quests were updated, send the new quest state to client
	if #updatedQuests > 0 then
		local activeQuests = questManager:GetActiveQuests(player)
		updateQuestsEvent:FireClient(player, activeQuests)

		-- Check if any objectives were completed
		for _, questId in updatedQuests do
			local quest = questManager:GetQuest(player, questId)
			if quest and quest.Status == "Completed" then
				showNotificationEvent:FireClient(
					player,
					"Quest objective completed! Return to Cane to turn in your quest."
				)
			end
		end
	end
end

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

local updateFullStatsEvent = Instance.new("RemoteEvent")
updateFullStatsEvent.Name = "UpdateFullStats"
updateFullStatsEvent.Parent = ReplicatedStorage

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

local pickupLootEvent = Instance.new("RemoteEvent")
pickupLootEvent.Name = "PickupLoot"
pickupLootEvent.Parent = ReplicatedStorage

local showNotificationEvent = Instance.new("RemoteEvent")
showNotificationEvent.Name = "ShowNotification"
showNotificationEvent.Parent = ReplicatedStorage

local useSkillBookEvent = Instance.new("RemoteEvent")
useSkillBookEvent.Name = "UseSkillBook"
useSkillBookEvent.Parent = ReplicatedStorage

local updateLearnedSkillsEvent = Instance.new("RemoteEvent")
updateLearnedSkillsEvent.Name = "UpdateLearnedSkills"
updateLearnedSkillsEvent.Parent = ReplicatedStorage

local setSkillSlotEvent = Instance.new("RemoteEvent")
setSkillSlotEvent.Name = "SetSkillSlot"
setSkillSlotEvent.Parent = ReplicatedStorage

local updateSkillSlotsEvent = Instance.new("RemoteEvent")
updateSkillSlotsEvent.Name = "UpdateSkillSlots"
updateSkillSlotsEvent.Parent = ReplicatedStorage

local castSkillEvent = Instance.new("RemoteEvent")
castSkillEvent.Name = "CastSkill"
castSkillEvent.Parent = ReplicatedStorage

local spendAttributePointEvent = Instance.new("RemoteEvent")
spendAttributePointEvent.Name = "SpendAttributePoint"
spendAttributePointEvent.Parent = ReplicatedStorage

-- Character selection events
local requestCharacterListEvent = Instance.new("RemoteEvent")
requestCharacterListEvent.Name = "RequestCharacterList"
requestCharacterListEvent.Parent = ReplicatedStorage

local updateCharacterListEvent = Instance.new("RemoteEvent")
updateCharacterListEvent.Name = "UpdateCharacterList"
updateCharacterListEvent.Parent = ReplicatedStorage

local selectCharacterEvent = Instance.new("RemoteEvent")
selectCharacterEvent.Name = "SelectCharacter"
selectCharacterEvent.Parent = ReplicatedStorage

local promptCharacterNameEvent = Instance.new("RemoteEvent")
promptCharacterNameEvent.Name = "PromptCharacterName"

-- Quest events
local npcClickEvent = Instance.new("RemoteEvent")
npcClickEvent.Name = "NPCClick"
npcClickEvent.Parent = ReplicatedStorage

local openDialogueEvent = Instance.new("RemoteEvent")
openDialogueEvent.Name = "OpenDialogue"
openDialogueEvent.Parent = ReplicatedStorage

local acceptQuestEvent = Instance.new("RemoteEvent")
acceptQuestEvent.Name = "AcceptQuest"
acceptQuestEvent.Parent = ReplicatedStorage

local turnInQuestEvent = Instance.new("RemoteEvent")
turnInQuestEvent.Name = "TurnInQuest"
turnInQuestEvent.Parent = ReplicatedStorage

local updateQuestsEvent = Instance.new("RemoteEvent")
updateQuestsEvent.Name = "UpdateQuests"
updateQuestsEvent.Parent = ReplicatedStorage
promptCharacterNameEvent.Parent = ReplicatedStorage

local createCharacterEvent = Instance.new("RemoteEvent")
createCharacterEvent.Name = "CreateCharacter"
createCharacterEvent.Parent = ReplicatedStorage

local deleteCharacterEvent = Instance.new("RemoteEvent")
deleteCharacterEvent.Name = "DeleteCharacter"
deleteCharacterEvent.Parent = ReplicatedStorage

-- Track which character slot each player is using
local playerCharacterSlots: { [Player]: number } = {}

-- Track pending character creation (slot index)
local pendingCharacterCreation: { [Player]: number } = {}

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

		-- Wait for humanoid to fully load
		local humanoid = character:WaitForChild("Humanoid", 5)
		if not humanoid then
			return
		end

		-- Assign all character parts to Players collision group
		-- This prevents physics interactions with monsters (they won't collide)
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				PhysicsService:SetPartCollisionGroup(part, "Players")
			end
		end

		-- Enforce upright orientation every frame to prevent tipping
		local uprightEnforcer = game:GetService("RunService").Heartbeat:Connect(function()
			if not humanoidRootPart or not humanoidRootPart.Parent then
				uprightEnforcer:Disconnect()
				return
			end

			local currentUpVector = humanoidRootPart.CFrame.UpVector
			local tiltAmount = math.acos(currentUpVector.Y) -- Angle from vertical in radians
			local tiltDegrees = math.deg(tiltAmount)

			-- If tilted more than 1 degree, correct orientation
			if tiltDegrees > 1 then
				-- Extract current Y rotation (facing direction) and position
				local _, currentYRotation, _ = humanoidRootPart.CFrame:ToOrientation()
				local currentPos = humanoidRootPart.Position

				-- Create perfectly upright CFrame with same position and Y rotation
				humanoidRootPart.CFrame = CFrame.new(currentPos) * CFrame.Angles(0, currentYRotation, 0)

				-- Log correction for debugging
				warn(string.format("Corrected %s tilt: %.1f degrees -> upright", player.Name, tiltDegrees))
			end
		end)

		-- Clean up upright enforcer when character dies or leaves
		humanoid.Died:Connect(function()
			if uprightEnforcer then
				uprightEnforcer:Disconnect()
			end
		end)

		-- Check if player has selected a character
		local selectedSlot = playerCharacterSlots[player]
		if not selectedSlot then
			-- No character selected yet, don't create actor
			print(player.Name, "has not selected a character yet")
			return
		end

		-- Load character data from selected slot
		local characterData = PlayerDataService.LoadCharacter(player.UserId, selectedSlot)
		if not characterData then
			warn("Failed to load character data for", player.Name, "from slot", selectedSlot)
			return
		end

		-- Set fixed spawn position in world space
		local spawnPosition = Vector3.new(0, 3, 0) -- Spawn at origin, 3 studs above ground

		-- Anchor character temporarily to prevent falling during teleport
		humanoidRootPart.Anchored = true

		-- Wait a tiny bit for physics to settle
		task.wait(0.1)

		-- Teleport character to spawn position
		humanoidRootPart.CFrame = CFrame.new(spawnPosition)

		-- Unanchor after teleport
		humanoidRootPart.Anchored = false

		-- Create player actor at spawn position
		local playerActor = Actor.new(player.Name, true, 1, nil, spawnPosition)
		gameService:RegisterPlayer(player, playerActor)
		playerActor.Model = character

		-- Apply loaded character data
		playerActor.Stats.Level = characterData.Level
		playerActor.Stats.RuntimeStats.CurrentXP = characterData.Experience

		-- Map full attribute names to abbreviated names expected by Actor
		playerActor.Stats.Attributes.STR = characterData.Attributes.Strength
		playerActor.Stats.Attributes.DEX = characterData.Attributes.Dexterity
		playerActor.Stats.Attributes.VIT = characterData.Attributes.Vitality
		playerActor.Stats.Attributes.INT = characterData.Attributes.Intelligence
		playerActor.BaseAttributes.STR = characterData.Attributes.Strength
		playerActor.BaseAttributes.DEX = characterData.Attributes.Dexterity
		playerActor.BaseAttributes.VIT = characterData.Attributes.Vitality
		playerActor.BaseAttributes.INT = characterData.Attributes.Intelligence
		playerActor.AvailableAttributePoints = characterData.AvailableAttributePoints

		-- Recalculate derived stats based on loaded attributes
		playerActor.Stats.DerivedStats = StatCalculator.CalculateDerivedStats(
			playerActor.Stats.Level,
			playerActor.Stats.Attributes,
			playerActor.ArmorFromGear,
			playerActor.CritFromGear,
			playerActor.CritDmgFromGear,
			playerActor.AttackSpeed
		)

		-- Set current health/mana from saved data
		playerActor.Stats.RuntimeStats.CurrentHealth = characterData.CurrentHealth
		playerActor.Stats.RuntimeStats.CurrentMana = characterData.CurrentMana

		-- Load learned skills
		playerActor.LearnedSkills = characterData.LearnedSkills

		-- Load skill slots
		playerActor.SkillSlots = characterData.SkillSlots

		-- Load inventory
		for _, itemStack in characterData.Inventory do
			playerActor.Inventory:AddItem(itemStack.Item, itemStack.Count)
		end

		-- Load belt slots
		playerActor.BeltSlots = characterData.BeltSlots

		-- Load equipment (convert ItemStacks to Items)
		for slotName, itemStack in characterData.Equipment do
			if itemStack then
				playerActor.Equipment[slotName] = itemStack.Item
			else
				playerActor.Equipment[slotName] = nil
			end
		end

		print(string.format(
			"%s registered at position %s - HP: %d, Mana: %d",
			player.Name,
			tostring(spawnPosition),
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

		-- Send loaded belt state
		updateBeltEvent:FireClient(player, playerActor.BeltSlots)

		-- Send loaded equipment state
		updateEquipmentEvent:FireClient(player, playerActor.Equipment)

		-- Send loaded inventory state
		updateInventoryEvent:FireClient(player, playerActor.Inventory.Slots)

		-- Send full stats for character sheet (include AvailableAttributePoints)
		local fullStats = playerActor.Stats
		fullStats.AvailableAttributePoints = playerActor.AvailableAttributePoints
		updateFullStatsEvent:FireClient(player, fullStats)

		-- Send learned skills
		updateLearnedSkillsEvent:FireClient(player, playerActor.LearnedSkills)

		-- Send skill slots (convert to dictionary format for RemoteEvent)
		local skillSlotsDict = {}
		for i = 1, 5 do
			local skillId = playerActor.SkillSlots[i]
			if skillId then
				skillSlotsDict[tostring(i)] = skillId
			end
		end
		updateSkillSlotsEvent:FireClient(player, skillSlotsDict)

		-- Spawn some test monsters (outside aggro range of 8 tiles = 32 studs)
		local testMonsterPositions = {
			Vector3.new(40, 3, 0),   -- East
			Vector3.new(32, 3, 32),  -- Northeast
			Vector3.new(-40, 3, 24), -- Northwest
		}

		for i, monsterPos in testMonsterPositions do
			local monster = gameService:SpawnMonster("Skeleton", 1, monsterPos, false, false)
			if monster then
				print(string.format(
					"Spawned %s at position %s",
					monster.Name,
					tostring(monsterPos)
				))
			end
		end

		-- Spawn Cane NPC (quest giver) - place him close to spawn
		local canePosition = Vector3.new(-12, 3, -12)
		local caneNPC = CreateCaneNPC(canePosition)
		print(string.format("Spawned Cane NPC at position %s", tostring(canePosition)))

		-- Initialize player quests
		questManager:InitializePlayer(player, {})

		-- Send initial quest state to client
		local activeQuests = questManager:GetActiveQuests(player)
		updateQuestsEvent:FireClient(player, activeQuests)
	end)
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	print(player.Name .. " left the game")

	-- Save character data before they leave
	local selectedSlot = playerCharacterSlots[player]
	if selectedSlot then
		local playerActor = gameService.Players[player]
		if playerActor then
			local success = PlayerDataService.SaveCharacter(player.UserId, selectedSlot, playerActor)
			if success then
				print("Saved character data for", player.Name, "in slot", selectedSlot)
			else
				warn("Failed to save character data for", player.Name)
			end
		end
	end

	-- Clean up
	playerCharacterSlots[player] = nil
	gameService:UnregisterPlayer(player)
end)

-- Handle player clicks (movement/attack/interact)
playerClickEvent.OnServerEvent:Connect(function(player, clickPosition: Vector3, clickedMonster: boolean?)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	-- Only handle monster clicks - no click-to-move
	if clickedMonster then
		-- Find closest monster near click position
		local closestMonster = nil
		local closestDistance = math.huge

		for _, monsterData in gameService.Monsters do
			local monster = monsterData.monster
			if monster:IsAlive() then
				local distance = (monster.Position - clickPosition).Magnitude
				if distance < 10 and distance < closestDistance then -- Within 10 studs of click
					closestMonster = monster
					closestDistance = distance
				end
			end
		end

		if closestMonster then
			gameService:SetPlayerMoveToAttack(player, closestMonster)
		end
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
		showNotificationEvent:FireClient(player, "Cannot equip this item")
		return
	end

	-- Validate stat requirements
	if item.StatRequirements then
		for _, req in item.StatRequirements do
			local playerStatValue = 0
			if req.Stat == "STR" then
				playerStatValue = playerActor.Stats.Attributes.STR
			elseif req.Stat == "DEX" then
				playerStatValue = playerActor.Stats.Attributes.DEX
			elseif req.Stat == "VIT" then
				playerStatValue = playerActor.Stats.Attributes.VIT
			elseif req.Stat == "INT" then
				playerStatValue = playerActor.Stats.Attributes.INT
			end

			if playerStatValue < req.Value then
				warn(player.Name, "does not meet stat requirements for", item.Name, "-", req.Stat, playerStatValue, "/", req.Value)
				showNotificationEvent:FireClient(player, "I can't equip that, yet.")
				return
			end
		end
	end

	-- Validate level requirement
	if item.Level > playerActor.Stats.Level then
		warn(player.Name, "does not meet level requirement for", item.Name, "- Level", playerActor.Stats.Level, "/", item.Level)
		showNotificationEvent:FireClient(player, "I can't equip that, yet.")
		return
	end

	-- Use Actor's EquipItem method
	if playerActor:EquipItem(item) then
		-- Remove from inventory
		playerActor.Inventory:RemoveItem(inventorySlot, 1)

		print(string.format("%s equipped %s to %s", player.Name, item.Name, equipSlot))

		-- Broadcast updated stats
		gameService:BroadcastStatsUpdate(player, playerActor)

		-- Send updated equipment AND inventory to client
		updateEquipmentEvent:FireClient(player, playerActor.Equipment)
		updateInventoryEvent:FireClient(player, playerActor.Inventory.Slots)
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

		-- Send updated equipment AND inventory to client
		updateEquipmentEvent:FireClient(player, playerActor.Equipment)
		updateInventoryEvent:FireClient(player, playerActor.Inventory.Slots)
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

		-- Check if there's already an item in this belt slot
		local existingBeltStack = playerActor.BeltSlots[slotIndex]

		if existingBeltStack and existingBeltStack.Item.Id == item.Id then
			-- Same item - stack them
			existingBeltStack.Count += 1

			-- Remove from inventory
			playerActor.Inventory:RemoveItem(inventorySlot, 1)

			-- Clear skill in this slot (shouldn't exist, but just in case)
			playerActor.SkillSlots[slotIndex] = nil

			print(string.format("%s stacked %s in belt slot %d (now %d)", player.Name, item.Name, slotIndex, existingBeltStack.Count))
		else
			-- Different item or empty slot - replace
			-- If there was an existing item, we need to return it to inventory first
			if existingBeltStack then
				-- Try to add old belt item back to inventory
				if not playerActor.Inventory:AddItem(existingBeltStack.Item, existingBeltStack.Count) then
					warn(player.Name, "inventory full, can't swap belt item")
					return
				end
			end

			-- Set belt slot with new item
			if playerActor:SetBeltSlot(slotIndex, item, 1) then
				-- Remove from inventory
				playerActor.Inventory:RemoveItem(inventorySlot, 1)

				-- Clear skill in this slot
				playerActor.SkillSlots[slotIndex] = nil

				print(string.format("%s moved %s to belt slot %d", player.Name, item.Name, slotIndex))
			end
		end

		-- Send updated belt, skills, AND inventory to client
		updateBeltEvent:FireClient(player, playerActor.BeltSlots)
		updateSkillSlotsEvent:FireClient(player, playerActor.SkillSlots)
		updateInventoryEvent:FireClient(player, playerActor.Inventory.Slots)
	else
		-- Clearing belt slot (moving to inventory would be handled separately)
		playerActor:SetBeltSlot(slotIndex, nil, nil)

		-- Send updated belt to client
		updateBeltEvent:FireClient(player, playerActor.BeltSlots)
	end
end)

-- Handle loot pickup
pickupLootEvent.OnServerEvent:Connect(function(player, lootId: string)
	-- Use the GameService method to handle loot pickup
	gameService:PickupLoot(player, lootId)
end)

-- Handle using skill books
useSkillBookEvent.OnServerEvent:Connect(function(player, inventorySlot: number)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	local stack = playerActor.Inventory:GetItem(inventorySlot)
	if not stack then
		warn(player.Name, "tried to use item from empty slot", inventorySlot)
		return
	end

	local item = stack.Item

	-- Verify it's a skill book
	if item.Type ~= "SkillBook" or not item.TeachesSkillId then
		warn(player.Name, "tried to use non-skill-book as skill book")
		return
	end

	-- Try to learn the skill
	if playerActor:LearnSkill(item.TeachesSkillId) then
		-- Remove book from inventory
		playerActor.Inventory:RemoveItem(inventorySlot, 1)

		-- Send success notification
		showNotificationEvent:FireClient(player, string.format("Learned %s!", item.Name:gsub("Book of ", "")))

		print(string.format("%s learned skill: %s", player.Name, item.TeachesSkillId))

		-- Send updated learned skills to client
		updateLearnedSkillsEvent:FireClient(player, playerActor.LearnedSkills)

		-- Send updated inventory
		updateInventoryEvent:FireClient(player, playerActor.Inventory.Slots)
	else
		-- Already learned
		showNotificationEvent:FireClient(player, "You already know this skill.")
	end
end)

-- Handle setting skill to hotbar slot
setSkillSlotEvent.OnServerEvent:Connect(function(player, slotIndex: number, skillId: string?)
	print(string.format("Server received SetSkillSlot: player=%s, slot=%s, skillId=%s", player.Name, tostring(slotIndex), tostring(skillId)))

	local playerActor = gameService.Players[player]
	if not playerActor then
		warn(player.Name, "playerActor not found in gameService")
		return
	end

	-- Validate slot index
	if slotIndex < 1 or slotIndex > 5 then
		warn(player.Name, "tried to set invalid skill slot", slotIndex)
		return
	end

	-- If setting a skill, verify player has learned it
	if skillId then
		if not playerActor:HasLearnedSkill(skillId) then
			warn(player.Name, "tried to set unlearned skill to hotbar:", skillId)
			return
		end
	end

	-- Set the skill slot
	if playerActor:SetSkillSlot(slotIndex, skillId) then
		print(string.format("%s set skill slot %d to %s", player.Name, slotIndex, skillId or "empty"))

		-- Debug: Print what's in SkillSlots before sending
		print("SkillSlots array:", playerActor.SkillSlots)
		for i = 1, 5 do
			print(string.format("  Slot %d: %s", i, tostring(playerActor.SkillSlots[i])))
		end

		-- Clear belt item in this slot if setting a skill
		if skillId then
			local existingBeltStack = playerActor.BeltSlots[slotIndex]
			if existingBeltStack then
				-- Return belt item to inventory
				if not playerActor.Inventory:AddItem(existingBeltStack.Item, existingBeltStack.Count) then
					warn(player.Name, "inventory full, couldn't return belt item when setting skill")
				end
			end
			playerActor.BeltSlots[slotIndex] = nil
			-- Send updated belt and inventory to client
			updateBeltEvent:FireClient(player, playerActor.BeltSlots)
			updateInventoryEvent:FireClient(player, playerActor.Inventory.Slots)
		end

		-- Send updated skill slots to client
		-- Convert to dictionary to avoid sparse array issues with RemoteEvents
		-- Roblox doesn't transmit tables with nil values properly
		local skillSlotsDict = {}
		for i = 1, 5 do
			local skillId = playerActor.SkillSlots[i]
			if skillId then
				skillSlotsDict[tostring(i)] = skillId
			end
		end
		print("Sending SkillSlots to client as dict:", skillSlotsDict)
		updateSkillSlotsEvent:FireClient(player, skillSlotsDict)
	end
end)

-- Handle casting spells
castSkillEvent.OnServerEvent:Connect(function(player, skillId: string, mousePosition: Vector3?)
	local playerActor = gameService.Players[player]
	if not playerActor or not playerActor:IsAlive() then
		return
	end

	-- Verify player has learned this skill
	local learnedSkill = playerActor.LearnedSkills and playerActor.LearnedSkills[skillId]
	if not learnedSkill then
		warn(player.Name, "tried to cast unlearned skill:", skillId)
		return
	end

	-- Get skill definition
	local skill = SkillBook.GetSkill(skillId)
	if not skill then
		warn("Skill not found:", skillId)
		return
	end

	-- Check cooldown
	local currentTime = tick()
	if learnedSkill.LastUsedTime then
		local timeSinceLastUse = currentTime - learnedSkill.LastUsedTime
		if timeSinceLastUse < skill.Cooldown then
			-- Still on cooldown
			local remainingCooldown = skill.Cooldown - timeSinceLastUse
			showNotificationEvent:FireClient(
				player,
				string.format("%s on cooldown (%.1fs)", skill.Name, remainingCooldown)
			)
			return
		end
	end

	-- Check mana cost
	if playerActor.Stats.RuntimeStats.CurrentMana < skill.ManaCost then
		showNotificationEvent:FireClient(player, "Not enough mana!")
		return
	end

	-- Deduct mana
	playerActor.Stats.RuntimeStats.CurrentMana -= skill.ManaCost

	-- Update cooldown
	learnedSkill.LastUsedTime = currentTime

	-- Cast the skill
	print(string.format("%s cast %s", player.Name, skill.Name))

	-- Handle different skill types
	if skillId == "fireball" then
		-- Fireball spell - single straight projectile
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
			if humanoidRootPart then
				-- Calculate damage
				local minDamage, maxDamage =
					SkillBook.CalculateSkillDamage(skill, learnedSkill.Level, playerActor.Stats.Attributes.INT)
				local damage = math.random(minDamage, maxDamage)

				-- Get cast direction (towards mouse or where player is facing)
				local direction
				if mousePosition then
					-- Calculate direction from player to mouse position
					direction = (mousePosition - humanoidRootPart.Position).Unit
				else
					-- Fallback to where player is facing
					direction = humanoidRootPart.CFrame.LookVector
				end
				local startPosition = humanoidRootPart.Position + Vector3.new(0, 1, 0) + direction * 3

				-- Create projectile with hit callback
				local projectile = gameService.ProjectileManager:CreateProjectile(
					player.Name,
					skill,
					learnedSkill.Level,
					startPosition,
					direction,
					damage,
					function(proj, hitPart)
						-- Handle hit
						if hitPart and hitPart.Parent then
							local hitModel = hitPart.Parent
							-- Check if hit a monster
							for _, monsterData in gameService.Monsters do
								if monsterData.monster.Model == hitModel and monsterData.monster:IsAlive() then
									-- Apply spell damage directly
									local spellDamage = proj.Damage
									monsterData.monster.Stats.RuntimeStats.CurrentHealth -= spellDamage

									print(
										string.format(
											"%s's fireball hit %s for %d fire damage",
											player.Name,
											monsterData.monster.Name,
											spellDamage
										)
									)

									-- Update health bar
									if hitModel.PrimaryPart then
										local healthBar = hitModel.PrimaryPart:FindFirstChild("HealthBar")
										if healthBar then
											MonsterHealthBar.Update(healthBar, monsterData.monster)
										end
									end

									-- Make monster aggro on player
									MonsterAI.ForceAggro(monsterData.ai, playerActor, tick())

									-- Send damage number to all clients
									if hitModel.PrimaryPart then
										showDamageEvent:FireAllClients(
											hitModel.PrimaryPart.Position + Vector3.new(0, 3, 0),
											spellDamage,
											"Fire",
											false, -- spells don't crit (for now)
											false -- not a miss
										)
									end

									-- Check if monster died
									if monsterData.monster:IsDead() then
										print(string.format("%s killed %s", player.Name, monsterData.monster.Name))
										gameService:OnMonsterDeath(monsterData, playerActor)
									end
									break
								end
							end
						end
					end
				)

				-- Create visual for projectile
				projectile:CreateModel(Color3.fromRGB(255, 100, 0), Vector3.new(1, 1, 1))

				print(string.format("%s cast Fireball", player.Name))
			end
		end
	elseif skillId == "healing" then
		-- Healing spell
		local minHeal, maxHeal = SkillBook.CalculateSkillDamage(skill, learnedSkill.Level, playerActor.Stats.Attributes.INT)
		local healAmount = math.random(minHeal, maxHeal)

		-- Heal the player
		playerActor.Stats.RuntimeStats.CurrentHealth = math.min(
			playerActor.Stats.RuntimeStats.CurrentHealth + healAmount,
			playerActor.Stats.DerivedStats.MaxHealth
		)

		print(string.format("%s healed for %d HP", player.Name, healAmount))
		showNotificationEvent:FireClient(player, string.format("Healed for %d HP", healAmount))
	elseif skillId == "charged_bolt" then
		-- Charged Bolt spell - multiple erratic projectiles
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
			if humanoidRootPart then
				-- Calculate damage
				local minDamage, maxDamage =
					SkillBook.CalculateSkillDamage(skill, learnedSkill.Level, playerActor.Stats.Attributes.INT)
				local damage = math.random(minDamage, maxDamage)

				-- Get cast direction (towards mouse or where player is facing)
				local direction
				if mousePosition then
					-- Calculate direction from player to mouse position
					direction = (mousePosition - humanoidRootPart.Position).Unit
				else
					-- Fallback to where player is facing
					direction = humanoidRootPart.CFrame.LookVector
				end
				local startPosition = humanoidRootPart.Position + Vector3.new(0, 1, 0) + direction * 3

				-- Calculate projectile count (increases with skill level)
				local projectileCount = SkillBook.GetProjectileCount(skill, learnedSkill.Level)

				-- Create multiple projectiles in spread
				local projectiles = gameService.ProjectileManager:CreateProjectileSpread(
					player.Name,
					skill,
					learnedSkill.Level,
					startPosition,
					direction,
					damage,
					projectileCount,
					skill.ProjectileSpreadAngle or 90,
					"Erratic",
					function(proj, hitPart)
						-- Handle hit
						if hitPart and hitPart.Parent then
							local hitModel = hitPart.Parent
							-- Check if hit a monster
							for _, monsterData in gameService.Monsters do
								if monsterData.monster.Model == hitModel and monsterData.monster:IsAlive() then
									-- Apply spell damage directly
									local spellDamage = proj.Damage
									monsterData.monster.Stats.RuntimeStats.CurrentHealth -= spellDamage

									print(
										string.format(
											"%s's charged bolt hit %s for %d lightning damage",
											player.Name,
											monsterData.monster.Name,
											spellDamage
										)
									)

									-- Update health bar
									if hitModel.PrimaryPart then
										local healthBar = hitModel.PrimaryPart:FindFirstChild("HealthBar")
										if healthBar then
											MonsterHealthBar.Update(healthBar, monsterData.monster)
										end
									end

									-- Make monster aggro on player
									MonsterAI.ForceAggro(monsterData.ai, playerActor, tick())

									-- Send damage number to all clients
									if hitModel.PrimaryPart then
										showDamageEvent:FireAllClients(
											hitModel.PrimaryPart.Position + Vector3.new(0, 3, 0),
											spellDamage,
											"Lightning",
											false, -- spells don't crit (for now)
											false -- not a miss
										)
									end

									-- Check if monster died
									if monsterData.monster:IsDead() then
										print(string.format("%s killed %s", player.Name, monsterData.monster.Name))
										gameService:OnMonsterDeath(monsterData, playerActor)
									end
									break
								end
							end
						end
					end
				)

				-- Create visuals for all projectiles
				for _, projectile in projectiles do
					projectile:CreateModel(Color3.fromRGB(100, 150, 255), Vector3.new(0.5, 0.5, 1.5))
				end

				print(string.format("%s cast Charged Bolt (%d bolts)", player.Name, projectileCount))
			end
		end
	end

	-- Send updated stats to client
	updateStatsEvent:FireClient(player, {
		CurrentHealth = playerActor.Stats.RuntimeStats.CurrentHealth,
		MaxHealth = playerActor.Stats.DerivedStats.MaxHealth,
		CurrentMana = playerActor.Stats.RuntimeStats.CurrentMana,
		MaxMana = playerActor.Stats.DerivedStats.MaxMana,
		CurrentXP = playerActor.Stats.RuntimeStats.CurrentXP,
		RequiredXP = StatCalculator.CalculateXPForNextLevel(playerActor.Stats.Level),
		Level = playerActor.Stats.Level,
	})
end)

-- Handle attribute point spending
spendAttributePointEvent.OnServerEvent:Connect(function(player, attribute: string)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	-- Try to spend the attribute point
	if playerActor:AddAttributePoint(attribute, 1) then
		print(string.format("%s spent 1 point on %s", player.Name, attribute))

		-- Send updated stats to client (include AvailableAttributePoints)
		local fullStats = playerActor.Stats
		fullStats.AvailableAttributePoints = playerActor.AvailableAttributePoints
		updateFullStatsEvent:FireClient(player, fullStats)

		-- Also update HUD stats
		updateStatsEvent:FireClient(player, {
			CurrentHealth = playerActor.Stats.RuntimeStats.CurrentHealth,
			MaxHealth = playerActor.Stats.DerivedStats.MaxHealth,
			CurrentMana = playerActor.Stats.RuntimeStats.CurrentMana,
			MaxMana = playerActor.Stats.DerivedStats.MaxMana,
			CurrentXP = playerActor.Stats.RuntimeStats.CurrentXP,
			RequiredXP = StatCalculator.CalculateXPForNextLevel(playerActor.Stats.Level),
			Level = playerActor.Stats.Level,
		})
	else
		warn(string.format("%s failed to spend attribute point on %s", player.Name, attribute))
	end
end)

-- Handle character selection events
requestCharacterListEvent.OnServerEvent:Connect(function(player)
	print(player.Name, "requested character list")
	local characters = PlayerDataService.GetCharacterList(player.UserId)

	-- Convert to simplified format for UI
	local characterSlots = {}
	for i = 1, 3 do
		if characters[i] then
			characterSlots[i] = {
				Name = characters[i].Name,
				Level = characters[i].Level,
				LastSaved = characters[i].LastSaved,
			}
		end
	end

	updateCharacterListEvent:FireClient(player, characterSlots)
end)

promptCharacterNameEvent.OnServerEvent:Connect(function(player, slotIndex: number)
	print(player.Name, "wants to create character in slot", slotIndex)
	pendingCharacterCreation[player] = slotIndex

	-- Use TextChatService or prompt for name in chat
	-- For now, we'll use a simple default name and the player can rename later
	-- In a full implementation, you'd want a proper name input dialog
	local characterName = player.Name .. "'s Character"

	local success, err = PlayerDataService.CreateCharacter(player.UserId, slotIndex, characterName)
	if success then
		print("Created character", characterName, "in slot", slotIndex)
		-- Refresh character list
		local characters = PlayerDataService.GetCharacterList(player.UserId)
		local characterSlots = {}
		for i = 1, 3 do
			if characters[i] then
				characterSlots[i] = {
					Name = characters[i].Name,
					Level = characters[i].Level,
					LastSaved = characters[i].LastSaved,
				}
			end
		end
		updateCharacterListEvent:FireClient(player, characterSlots)
	else
		warn("Failed to create character:", err)
		showNotificationEvent:FireClient(player, "Failed to create character: " .. tostring(err))
	end

	pendingCharacterCreation[player] = nil
end)

deleteCharacterEvent.OnServerEvent:Connect(function(player, slotIndex: number)
	print(player.Name, "wants to delete character in slot", slotIndex)

	local success, err = PlayerDataService.DeleteCharacter(player.UserId, slotIndex)
	if success then
		print("Deleted character in slot", slotIndex)
		-- Refresh character list
		local characters = PlayerDataService.GetCharacterList(player.UserId)
		local characterSlots = {}
		for i = 1, 3 do
			if characters[i] then
				characterSlots[i] = {
					Name = characters[i].Name,
					Level = characters[i].Level,
					LastSaved = characters[i].LastSaved,
				}
			end
		end
		updateCharacterListEvent:FireClient(player, characterSlots)
	else
		warn("Failed to delete character:", err)
		showNotificationEvent:FireClient(player, "Failed to delete character: " .. tostring(err))
	end
end)

selectCharacterEvent.OnServerEvent:Connect(function(player, slotIndex: number)
	print(player.Name, "selected character in slot", slotIndex)
	playerCharacterSlots[player] = slotIndex

	-- Load character data
	local characterData = PlayerDataService.LoadCharacter(player.UserId, slotIndex)
	if not characterData then
		warn("Failed to load character from slot", slotIndex)
		showNotificationEvent:FireClient(player, "Failed to load character")
		return
	end

	-- Respawn player to actually create their character in the game
	if player.Character then
		player:LoadCharacter()
	end
end)

-- Auto-save all characters every 5 minutes
task.spawn(function()
	while true do
		task.wait(300) -- 5 minutes
		print("Auto-saving all player data...")

		for player, slotIndex in pairs(playerCharacterSlots) do
			local playerActor = gameService.Players[player]
			if playerActor then
				local success = PlayerDataService.SaveCharacter(player.UserId, slotIndex, playerActor)
				if success then
					print("Auto-saved", player.Name, "slot", slotIndex)
				else
					warn("Failed to auto-save", player.Name)
				end
			end
		end

		print("Auto-save complete!")
	end
end)

-- Handle NPC click (quest giver interaction)
npcClickEvent.OnServerEvent:Connect(function(player, npcName: string)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	-- Check if NPC is "Cane"
	if npcName ~= "Cane" then
		return
	end

	-- Find Cane NPC in workspace
	local caneNPC = workspace:FindFirstChild("Cane")
	if not caneNPC then
		return
	end

	-- Check distance (close range = 2 tiles)
	local character = player.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	local npcRootPart = caneNPC.PrimaryPart
	if not npcRootPart then
		return
	end

	-- Calculate distance (2 tiles = 8 studs)
	local distance = (humanoidRootPart.Position - npcRootPart.Position).Magnitude

	if distance > 8 then
		showNotificationEvent:FireClient(player, "You are too far from Cane")
		return
	end

	-- Check if player already has quest or has completed it
	local hasQuest = questManager:HasQuest(player, "defeat_skeletons")
	local activeQuest = questManager:GetQuest(player, "defeat_skeletons")

	if activeQuest and activeQuest.Status == "Completed" then
		-- Quest completed, show turn-in dialogue
		openDialogueEvent:FireClient(player, {
			NPCName = "Cane",
			Dialogue = "You've defeated those skeletons! Thank you, brave adventurer. Here's your reward.",
			QuestId = "defeat_skeletons",
			ShowAccept = false,
			ShowTurnIn = true,
		})
	elseif hasQuest then
		-- Quest in progress
		openDialogueEvent:FireClient(player, {
			NPCName = "Cane",
			Dialogue = "Those skeletons are still out there. Please defeat them!",
			QuestId = "defeat_skeletons",
			ShowAccept = false,
			ShowTurnIn = false,
		})
	else
		-- Offer quest
		openDialogueEvent:FireClient(player, {
			NPCName = "Cane",
			Dialogue = "Those cursed skeletons have been threatening this area. Can you defeat three of them for me? I'll reward you with 50 XP and 3 health potions.",
			QuestId = "defeat_skeletons",
			ShowAccept = true,
			ShowTurnIn = false,
		})
	end
end)

-- Handle quest acceptance
acceptQuestEvent.OnServerEvent:Connect(function(player, questId: string)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	local success = questManager:AcceptQuest(player, questId)
	if success then
		print(player.Name, "accepted quest:", questId)
		showNotificationEvent:FireClient(player, "Quest accepted: Skeletal Threat")

		-- Send updated quest state
		local activeQuests = questManager:GetActiveQuests(player)
		updateQuestsEvent:FireClient(player, activeQuests)
	else
		warn(player.Name, "failed to accept quest:", questId)
	end
end)

-- Handle quest turn-in
turnInQuestEvent.OnServerEvent:Connect(function(player, questId: string)
	local playerActor = gameService.Players[player]
	if not playerActor then
		return
	end

	local success = questManager:TurnInQuest(player, questId, playerActor)
	if success then
		print(player.Name, "turned in quest:", questId)
		showNotificationEvent:FireClient(player, "Quest complete! Received 50 XP and 3 health potions")

		-- Update client inventory and stats
		updateInventoryEvent:FireClient(player, playerActor.Inventory.Slots)

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

		-- Send updated quest state
		local activeQuests = questManager:GetActiveQuests(player)
		updateQuestsEvent:FireClient(player, activeQuests)
	else
		warn(player.Name, "failed to turn in quest:", questId)
	end
end)

print("Server setup complete!")
