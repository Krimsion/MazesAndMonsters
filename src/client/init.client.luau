--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerController = require(script.Controllers.PlayerController)
local HUD = require(script.UI.HUD)
local DamageNumbers = require(script.UI.DamageNumbers)
local InventoryUI = require(script.UI.InventoryUI)
local Hotbar = require(script.UI.Hotbar)
local Inventory = require(ReplicatedStorage.Shared.Data.Inventory)

local player = Players.LocalPlayer

print("MazesAndMonsters Client initialized for", player.Name)

-- Wait for character to spawn
player.CharacterAdded:Connect(function(character)
	print("Character spawned:", character.Name)

	-- Wait for HumanoidRootPart
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not humanoidRootPart then
		warn("Failed to find HumanoidRootPart")
		return
	end

	-- Initialize player controller
	local controller = PlayerController.new(player)

	-- Initialize HUD
	local hud = HUD.new(player)

	-- Initialize Hotbar
	local hotbar = Hotbar.new(player)

	-- Initialize Inventory (empty - will be synced from server)
	local playerInventory = Inventory.new(25)
	local inventoryUI = InventoryUI.new(player, playerInventory)

	-- Don't add test items to hotbar - let server sync properly
	-- hotbar:SetBeltSlot(1, { Name = "Health Potion", Count = 3 })

	-- Listen for stat updates from server
	local updateStatsEvent = ReplicatedStorage:WaitForChild("UpdateStats")
	updateStatsEvent.OnClientEvent:Connect(function(stats)
		hud:UpdateHealth(stats.CurrentHealth, stats.MaxHealth)
		hud:UpdateMana(stats.CurrentMana, stats.MaxMana)
		hud:UpdateXP(stats.CurrentXP, stats.RequiredXP)
		hud:UpdateLevel(stats.Level)
	end)

	-- Listen for damage number events from server
	local showDamageEvent = ReplicatedStorage:WaitForChild("ShowDamage")
	showDamageEvent.OnClientEvent:Connect(function(worldPosition, amount, damageType, isCrit, isMiss)
		DamageNumbers.Show(worldPosition, amount, damageType, isCrit, isMiss)
	end)

	-- Listen for belt updates from server
	local updateBeltEvent = ReplicatedStorage:WaitForChild("UpdateBelt")
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
	local updateEquipmentEvent = ReplicatedStorage:WaitForChild("UpdateEquipment")
	updateEquipmentEvent.OnClientEvent:Connect(function(equipment)
		-- Sync InventoryUI equipment with server
		inventoryUI.Equipment = equipment
		inventoryUI:RefreshUI()
	end)

	-- Listen for inventory updates from server
	local updateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory")
	updateInventoryEvent.OnClientEvent:Connect(function(inventorySlots)
		-- Sync inventory with server
		playerInventory.Slots = inventorySlots
		if inventoryUI.IsOpen then
			inventoryUI:RefreshUI()
		end
	end)

	-- Update camera to follow player
	local RunService = game:GetService("RunService")
	RunService.RenderStepped:Connect(function()
		if humanoidRootPart then
			controller:UpdateCamera(humanoidRootPart.Position)
		end
	end)

	print("Player controller and HUD initialized")
end)

print("Client setup complete!")
