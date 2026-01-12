--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerController = require(script.Controllers.PlayerController)
local HUD = require(script.UI.HUD)
local DamageNumbers = require(script.UI.DamageNumbers)
local InventoryUI = require(script.UI.InventoryUI)
local Hotbar = require(script.UI.Hotbar)
local CharacterSheet = require(script.UI.CharacterSheet)
local AbilityBook = require(script.UI.AbilityBook)
local Notifications = require(script.UI.Notifications)
local CharacterSelection = require(script.UI.CharacterSelection)
local DialogueUI = require(script.UI.DialogueUI)
local QuestTrackerUI = require(script.UI.QuestTrackerUI)
local Inventory = require(ReplicatedStorage.Shared.Data.Inventory)

local player = Players.LocalPlayer

print("MazesAndMonsters Client initialized for", player.Name)

-- Show character selection screen
local characterSelection = CharacterSelection.new(player)

-- Listen for character list updates
local updateCharacterListEvent = ReplicatedStorage:WaitForChild("UpdateCharacterList", 10)
if updateCharacterListEvent then
	updateCharacterListEvent.OnClientEvent:Connect(function(characterSlots)
		characterSelection:UpdateCharacterSlots(characterSlots)
	end)
end

-- Store connections to clean up on character respawn
local currentConnections: { RBXScriptConnection } = {}
local controller: any = nil -- Store controller to prevent duplicates

-- Wait for character to spawn
player.CharacterAdded:Connect(function(character)
	-- Disconnect all previous character connections
	for _, connection in currentConnections do
		connection:Disconnect()
	end
	table.clear(currentConnections)
	print("Character spawned:", character.Name)

	-- Wait for HumanoidRootPart
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoidRootPart then
		warn("Failed to find HumanoidRootPart")
		return
	end

	print("DEBUG: HumanoidRootPart found at position:", humanoidRootPart.Position)

	-- Wait a frame to ensure character is fully loaded
	task.wait()

	-- Initialize player controller only once
	if not controller then
		controller = PlayerController.new(player)
		print("DEBUG: PlayerController created")
	else
		print("DEBUG: PlayerController already exists, skipping creation")
	end

	-- Set initial camera position
	controller:UpdateCamera(humanoidRootPart.Position)

	-- Initialize HUD
	local hud = HUD.new(player)

	-- Initialize Hotbar
	local hotbar = Hotbar.new(player)

	-- Initialize Inventory (empty - will be synced from server)
	local playerInventory = Inventory.new(25)
	local inventoryUI = InventoryUI.new(player, playerInventory)

	-- Initialize Character Sheet
	local characterSheet = CharacterSheet.new(player)

	-- Initialize Ability Book
	local abilityBook = AbilityBook.new(player)

	-- Initialize Notifications
	Notifications.Initialize(player)

	-- Initialize Quest UIs
	local dialogueUI = DialogueUI.new(player)
	local questTracker = QuestTrackerUI.new(player)

	-- Don't add test items to hotbar - let server sync properly
	-- hotbar:SetBeltSlot(1, { Name = "Health Potion", Count = 3 })

	-- Client-side stat tracking for smooth regeneration display
	local clientStats = {
		CurrentHealth = 100,
		MaxHealth = 100,
		CurrentMana = 40,
		MaxMana = 40,
		HealthRegen = 0.5,
		ManaRegen = 0.3,
		CurrentXP = 0,
		RequiredXP = 50,
		Level = 1,
	}

	-- Listen for stat updates from server
	local updateStatsEvent = ReplicatedStorage:WaitForChild("UpdateStats", 10)
	if not updateStatsEvent then
		warn("UpdateStats event not found")
		return
	end
	updateStatsEvent.OnClientEvent:Connect(function(stats)
		-- Update client-side tracking with server authority
		clientStats.CurrentHealth = stats.CurrentHealth
		clientStats.MaxHealth = stats.MaxHealth
		clientStats.CurrentMana = stats.CurrentMana
		clientStats.MaxMana = stats.MaxMana
		clientStats.CurrentXP = stats.CurrentXP
		clientStats.RequiredXP = stats.RequiredXP
		clientStats.Level = stats.Level

		-- Update HUD immediately
		hud:UpdateHealth(stats.CurrentHealth, stats.MaxHealth)
		hud:UpdateMana(stats.CurrentMana, stats.MaxMana)
		hud:UpdateXP(stats.CurrentXP, stats.RequiredXP)
		hud:UpdateLevel(stats.Level)
	end)

	-- Listen for full stats updates for character sheet
	local updateFullStatsEvent = ReplicatedStorage:WaitForChild("UpdateFullStats", 10)
	updateFullStatsEvent.OnClientEvent:Connect(function(stats)
		-- Update character sheet
		characterSheet:UpdateStats(stats)

		-- Update regen rates for client-side prediction
		clientStats.HealthRegen = stats.DerivedStats.HealthRegen
		clientStats.ManaRegen = stats.DerivedStats.ManaRegen
	end)

	-- Listen for notifications
	local showNotificationEvent = ReplicatedStorage:WaitForChild("ShowNotification", 10)
	showNotificationEvent.OnClientEvent:Connect(function(message)
		Notifications.Show(message)
	end)

	-- Listen for learned skills updates
	local updateLearnedSkillsEvent = ReplicatedStorage:WaitForChild("UpdateLearnedSkills", 10)
	updateLearnedSkillsEvent.OnClientEvent:Connect(function(learnedSkills)
		abilityBook:UpdateLearnedSkills(learnedSkills)
	end)

	-- Listen for damage number events from server
	local showDamageEvent = ReplicatedStorage:WaitForChild("ShowDamage", 10)
	showDamageEvent.OnClientEvent:Connect(function(worldPosition, amount, damageType, isCrit, isMiss)
		DamageNumbers.Show(worldPosition, amount, damageType, isCrit, isMiss)
	end)

	-- Listen for belt updates from server
	local updateBeltEvent = ReplicatedStorage:WaitForChild("UpdateBelt", 10)
	updateBeltEvent.OnClientEvent:Connect(function(beltSlots)
		-- Update both hotbar and inventory UI with new belt contents
		for i = 1, 5 do
			local stack = beltSlots[i]
			if stack then
				hotbar:SetBeltSlot(i, { Name = stack.Item.Name, Count = stack.Count })
				inventoryUI.Belt[i] = stack
			else
				hotbar:SetBeltSlot(i, nil)
				inventoryUI.Belt[i] = nil
			end
		end
		-- Refresh inventory UI if it's open
		if inventoryUI.IsOpen then
			inventoryUI:RefreshUI()
		end
	end)

	-- Listen for equipment updates from server
	local updateEquipmentEvent = ReplicatedStorage:WaitForChild("UpdateEquipment", 10)
	updateEquipmentEvent.OnClientEvent:Connect(function(equipment)
		-- Sync InventoryUI equipment with server
		inventoryUI.Equipment = equipment
		inventoryUI:RefreshUI()
	end)

	-- Listen for inventory updates from server
	local updateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory", 10)
	updateInventoryEvent.OnClientEvent:Connect(function(inventorySlots)
		-- Sync inventory with server
		playerInventory.Slots = inventorySlots
		if inventoryUI.IsOpen then
			inventoryUI:RefreshUI()
		end
	end)

	-- Listen for skill slot updates from server
	local updateSkillSlotsEvent = ReplicatedStorage:WaitForChild("UpdateSkillSlots", 10)
	updateSkillSlotsEvent.OnClientEvent:Connect(function(skillSlotsDict)
		print("Client received UpdateSkillSlots event:", skillSlotsDict)
		-- Clear all slots first
		for i = 1, 5 do
			hotbar:SetSkillSlot(i, nil)
		end
		-- Update hotbar with skill slots from dictionary
		for slotIndexStr, skillId in pairs(skillSlotsDict) do
			local slotIndex = tonumber(slotIndexStr)
			if slotIndex then
				print(string.format("Setting hotbar slot %d to skill %s", slotIndex, skillId))
				hotbar:SetSkillSlot(slotIndex, skillId)
			end
		end
		print("Hotbar update complete")
	end)

	-- Update camera to follow player
	local RunService = game:GetService("RunService")
	local lastRegenTime = tick()

	local cameraUpdateCount = 0
	local cameraConnection = RunService.RenderStepped:Connect(function()
		if humanoidRootPart and humanoidRootPart.Parent then
			controller:UpdateCamera(humanoidRootPart.Position)
			cameraUpdateCount = cameraUpdateCount + 1
			if cameraUpdateCount == 1 or cameraUpdateCount % 60 == 0 then
				print("DEBUG: Camera updating at position:", humanoidRootPart.Position)
			end
		else
			if cameraUpdateCount > 0 then
				warn("DEBUG: HumanoidRootPart is nil or has no parent!")
			end
		end
	end)
	table.insert(currentConnections, cameraConnection)

	-- Client-side regeneration simulation (updates HUD smoothly)
	local regenConnection = RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		local deltaTime = currentTime - lastRegenTime
		lastRegenTime = currentTime

		-- Apply regeneration to client stats (server is still authoritative)
		if clientStats.CurrentHealth < clientStats.MaxHealth then
			clientStats.CurrentHealth = math.min(
				clientStats.CurrentHealth + clientStats.HealthRegen * deltaTime,
				clientStats.MaxHealth
			)
			hud:UpdateHealth(clientStats.CurrentHealth, clientStats.MaxHealth)
		end

		if clientStats.CurrentMana < clientStats.MaxMana then
			clientStats.CurrentMana = math.min(
				clientStats.CurrentMana + clientStats.ManaRegen * deltaTime,
				clientStats.MaxMana
			)
			hud:UpdateMana(clientStats.CurrentMana, clientStats.MaxMana)
		end
	end)
	table.insert(currentConnections, regenConnection)

	-- Listen for loot bag clicks
	local pickupLootEvent = ReplicatedStorage:WaitForChild("PickupLoot", 10)

	-- Monitor workspace for new loot bags
	workspace.ChildAdded:Connect(function(child)
		if child:IsA("Model") and string.match(child.Name, "^LootBag_") then
			local lootPart = child:WaitForChild("LootPart", 2)
			if lootPart then
				local clickDetector = lootPart:FindFirstChildOfClass("ClickDetector")
				if clickDetector then
					clickDetector.MouseClick:Connect(function()
						-- Extract loot ID from model name
						local lootId = string.gsub(child.Name, "^LootBag_", "")
						print("Clicked on loot container:", lootId)
						pickupLootEvent:FireServer(lootId)
					end)
				end
			end
		end
	end)

	-- Handle existing loot bags (in case they spawned before this script ran)
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and string.match(child.Name, "^LootBag_") then
			local lootPart = child:FindFirstChild("LootPart")
			if lootPart then
				local clickDetector = lootPart:FindFirstChildOfClass("ClickDetector")
				if clickDetector then
					clickDetector.MouseClick:Connect(function()
						local lootId = string.gsub(child.Name, "^LootBag_", "")
						print("Clicked on loot container:", lootId)
						pickupLootEvent:FireServer(lootId)
					end)
				end
			end
		end
	end

	print("Player controller and HUD initialized")
end)

print("Client setup complete!")
