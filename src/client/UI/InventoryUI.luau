--!strict

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Data.Inventory)
local ItemTypes = require(ReplicatedStorage.Shared.Types.Item)

local InventoryUI = {}
InventoryUI.__index = InventoryUI

export type InventoryUI = typeof(setmetatable(
	{} :: {
		Player: Player,
		Inventory: Inventory.Inventory,
		ScreenGui: ScreenGui,
		InventoryFrame: Frame,
		SlotButtons: { [number]: TextButton },
		EquipmentSlots: { [string]: TextButton },
		BeltSlots: { [number]: TextButton },
		IsOpen: boolean,
		DraggedItem: { SlotType: string, SlotIndex: number | string }?,
		Equipment: { [string]: ItemTypes.Item? }, -- Mirror of Actor.Equipment
		Belt: { [number]: ItemTypes.ItemStack? }, -- Mirror of Actor.BeltSlots
	},
	InventoryUI
))

function InventoryUI.new(player: Player, inventory: Inventory.Inventory): InventoryUI
	local self = setmetatable({
		Player = player,
		Inventory = inventory,
		SlotButtons = {},
		EquipmentSlots = {},
		BeltSlots = {},
		IsOpen = false,
		DraggedItem = nil,
		Equipment = {
			Weapon = nil,
			Helmet = nil,
			Chest = nil,
			Gloves = nil,
			Boots = nil,
			Ring1 = nil,
			Ring2 = nil,
			Amulet = nil,
			Belt = nil,
		},
		Belt = {}, -- Initialize empty belt
	} :: any, InventoryUI)

	self:CreateUI()
	self:SetupInputHandling()

	return self
end

function InventoryUI:CreateUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InventoryUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false -- Start hidden
	screenGui.Parent = self.Player.PlayerGui

	self.ScreenGui = screenGui

	-- Create main inventory frame (wider to accommodate paper doll)
	local inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "InventoryFrame"
	inventoryFrame.Size = UDim2.new(0, 700, 0, 500)
	inventoryFrame.Position = UDim2.new(0.5, -350, 0.5, -250)
	inventoryFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	inventoryFrame.BorderSizePixel = 2
	inventoryFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inventoryFrame.Parent = screenGui

	self.InventoryFrame = inventoryFrame

	-- Create title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	title.BorderSizePixel = 0
	title.Text = "Inventory & Equipment"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = inventoryFrame

	-- Create close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 18
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = inventoryFrame

	closeButton.MouseButton1Click:Connect(function()
		self:Toggle()
	end)

	-- Create paper doll section (left side)
	self:CreatePaperDoll(inventoryFrame)

	-- Create belt slots (top of right side)
	self:CreateBeltSlots(inventoryFrame)

	-- Create x5 inventory grid (right side)
	self:CreateInventoryGrid(inventoryFrame)
end

function InventoryUI:CreatePaperDoll(parent: Frame)
	local startX = 20
	local startY = 60
	local slotSize = 60

	-- Equipment slot positions (paper doll layout)
	local equipmentLayout = {
		Helmet = { x = startX + 70, y = startY },
		Amulet = { x = startX + 70, y = startY + 70 },
		Chest = { x = startX + 70, y = startY + 140 },
		Weapon = { x = startX, y = startY + 140 },
		Gloves = { x = startX + 140, y = startY + 140 },
		Ring1 = { x = startX, y = startY + 210 },
		Belt = { x = startX + 70, y = startY + 210 },
		Ring2 = { x = startX + 140, y = startY + 210 },
		Boots = { x = startX + 70, y = startY + 280 },
	}

	-- Create equipment slots
	for slotName, pos in equipmentLayout do
		local slot = self:CreateEquipmentSlot(slotName, pos.x, pos.y, slotSize)
		slot.Parent = parent
		self.EquipmentSlots[slotName] = slot
	end

	-- Add label
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 200, 0, 20)
	label.Position = UDim2.new(0, startX, 0, startY + 360)
	label.BackgroundTransparency = 1
	label.Text = "Equipment"
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.Parent = parent
end

function InventoryUI:CreateBeltSlots(parent: Frame)
	local slotSize = 50
	local padding = 10
	local startX = 280
	local startY = 60

	-- Create 5 belt slots horizontally
	for i = 1, 5 do
		local slot = self:CreateSlot("Belt", i, startX + (i - 1) * (slotSize + padding), startY, slotSize)
		slot.Parent = parent
		self.BeltSlots[i] = slot

		-- Add keybind indicator to belt slots
		local keybind = Instance.new("TextLabel")
		keybind.Name = "Keybind"
		keybind.Size = UDim2.new(0, 20, 0, 20)
		keybind.Position = UDim2.new(0, 2, 0, 2)
		keybind.BackgroundTransparency = 1
		keybind.Text = tostring(i)
		keybind.TextColor3 = Color3.fromRGB(255, 255, 0)
		keybind.TextSize = 12
		keybind.Font = Enum.Font.GothamBold
		keybind.TextStrokeTransparency = 0.5
		keybind.Parent = slot
	end

	-- Add label
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 200, 0, 20)
	label.Position = UDim2.new(0, startX, 0, startY - 25)
	label.BackgroundTransparency = 1
	label.Text = "Belt (Quick Slots)"
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Parent = parent
end

function InventoryUI:CreateInventoryGrid(parent: Frame)
	local slotSize = 60
	local padding = 8
	local startX = 250
	local startY = 130

	-- Create 5x5 grid
	for row = 0, 4 do
		for col = 0, 4 do
			local slotIndex = row * 5 + col + 1
			local slot = self:CreateSlot("Inventory", slotIndex, startX + col * (slotSize + padding), startY + row * (slotSize + padding), slotSize)
			slot.Parent = parent
			self.SlotButtons[slotIndex] = slot
		end
	end

	-- Add label
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 200, 0, 20)
	label.Position = UDim2.new(0, startX, 0, startY + 360)
	label.BackgroundTransparency = 1
	label.Text = "Inventory (5x5)"
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.Parent = parent
end

function InventoryUI:CreateEquipmentSlot(slotName: string, x: number, y: number, size: number): TextButton
	local slot = Instance.new("TextButton")
	slot.Name = "Equipment_" .. slotName
	slot.Size = UDim2.new(0, size, 0, size)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	slot.BorderSizePixel = 2
	slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
	slot.Text = ""
	slot.AutoButtonColor = false

	-- Slot type indicator
	local indicator = Instance.new("TextLabel")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(1, 0, 0, 15)
	indicator.Position = UDim2.new(0, 0, 0, 0)
	indicator.BackgroundTransparency = 1
	indicator.Text = slotName
	indicator.TextColor3 = Color3.fromRGB(150, 150, 150)
	indicator.TextSize = 10
	indicator.Font = Enum.Font.Gotham
	indicator.Parent = slot

	-- Item icon
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, -10, 1, -20)
	icon.Position = UDim2.new(0, 5, 0, 15)
	icon.BackgroundTransparency = 1
	icon.Text = ""
	icon.TextColor3 = Color3.fromRGB(255, 255, 255)
	icon.TextSize = 12
	icon.Font = Enum.Font.GothamBold
	icon.TextWrapped = true
	icon.Parent = slot

	-- Drag/drop handlers
	slot.MouseButton1Down:Connect(function()
		self:OnSlotMouseDown("Equipment", slotName)
	end)

	slot.MouseButton1Up:Connect(function()
		self:OnSlotMouseUp("Equipment", slotName)
	end)

	return slot
end

function InventoryUI:CreateSlot(slotType: string, index: number | string, x: number, y: number, size: number): TextButton
	local slot = Instance.new("TextButton")
	slot.Name = slotType .. "_" .. tostring(index)
	slot.Size = UDim2.new(0, size, 0, size)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	slot.BorderSizePixel = 2
	slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
	slot.Text = ""
	slot.AutoButtonColor = false

	-- Item icon
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, -10, 1, -10)
	icon.Position = UDim2.new(0, 5, 0, 5)
	icon.BackgroundTransparency = 1
	icon.Text = ""
	icon.TextColor3 = Color3.fromRGB(255, 255, 255)
	icon.TextSize = 12
	icon.Font = Enum.Font.GothamBold
	icon.TextWrapped = true
	icon.Parent = slot

	-- Stack count
	local count = Instance.new("TextLabel")
	count.Name = "Count"
	count.Size = UDim2.new(0, 30, 0, 20)
	count.Position = UDim2.new(1, -32, 1, -22)
	count.BackgroundTransparency = 1
	count.Text = ""
	count.TextColor3 = Color3.fromRGB(255, 255, 255)
	count.TextSize = 14
	count.Font = Enum.Font.GothamBold
	count.TextStrokeTransparency = 0.5
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Parent = slot

	-- Drag/drop handlers
	slot.MouseButton1Down:Connect(function()
		self:OnSlotMouseDown(slotType, index)
	end)

	slot.MouseButton1Up:Connect(function()
		self:OnSlotMouseUp(slotType, index)
	end)

	return slot
end

function InventoryUI:OnSlotMouseDown(slotType: string, slotIndex: number | string)
	self.DraggedItem = {
		SlotType = slotType,
		SlotIndex = slotIndex,
	}
	print("Started dragging from", slotType, slotIndex)
end

function InventoryUI:OnSlotMouseUp(slotType: string, slotIndex: number | string)
	if not self.DraggedItem then
		return
	end

	local fromType = self.DraggedItem.SlotType
	local fromIndex = self.DraggedItem.SlotIndex

	-- Don't process if dropping on same slot
	if fromType == slotType and fromIndex == slotIndex then
		self.DraggedItem = nil
		return
	end

	-- Get the item being dragged
	local draggedItem: ItemTypes.Item? = nil
	if fromType == "Inventory" then
		local stack = self.Inventory:GetItem(fromIndex :: number)
		if stack then
			draggedItem = stack.Item
		end
	elseif fromType == "Equipment" then
		draggedItem = self.Equipment[fromIndex :: string]
	elseif fromType == "Belt" then
		local stack = self.Belt[fromIndex :: number]
		if stack then
			draggedItem = stack.Item
		end
	end

	if not draggedItem then
		self.DraggedItem = nil
		return
	end

	-- Handle different drop targets
	if slotType == "Belt" then
		-- Only potions and scrolls can go in belt
		if draggedItem.Type ~= "Potion" and draggedItem.Type ~= "Scroll" then
			warn(string.format("Cannot put %s in belt - only potions and scrolls allowed", draggedItem.Name))
			self.DraggedItem = nil
			return
		end

		if fromType == "Inventory" then
			self:MoveToBelt(fromIndex :: number, slotIndex :: number)
		elseif fromType == "Belt" then
			self:SwapBelt(fromIndex :: number, slotIndex :: number)
		end
	elseif slotType == "Equipment" then
		-- Validate item can go in this equipment slot
		if not self:CanEquipItem(draggedItem, slotIndex :: string) then
			warn(string.format("Cannot equip %s in %s slot", draggedItem.Name, slotIndex))
			self.DraggedItem = nil
			return
		end

		-- Move from inventory to equipment
		if fromType == "Inventory" then
			self:EquipFromInventory(fromIndex :: number, slotIndex :: string)
		elseif fromType == "Equipment" then
			-- Swap equipment slots
			self:SwapEquipment(fromIndex :: string, slotIndex :: string)
		end
	elseif slotType == "Inventory" then
		-- Move from equipment or belt to inventory
		if fromType == "Equipment" then
			self:UnequipToInventory(fromIndex :: string, slotIndex :: number)
		elseif fromType == "Belt" then
			self:MoveFromBeltToInventory(fromIndex :: number, slotIndex :: number)
		elseif fromType == "Inventory" then
			-- Move within inventory
			self.Inventory:MoveItem(fromIndex :: number, slotIndex :: number)
		end
	end

	self:RefreshUI()
	self.DraggedItem = nil
end

-- Check if an item can be equipped in a specific slot
function InventoryUI:CanEquipItem(item: ItemTypes.Item, slotName: string): boolean
	-- Must be equipment type
	if not item.EquipmentSlot then
		return false
	end

	-- Check if item's slot matches target slot
	if item.EquipmentSlot == slotName then
		return true
	end

	-- Special case for rings - Ring1 and Ring2 are interchangeable
	if (item.EquipmentSlot == "Ring1" or item.EquipmentSlot == "Ring2") and (slotName == "Ring1" or slotName == "Ring2") then
		return true
	end

	return false
end

-- Equip item from inventory slot
function InventoryUI:EquipFromInventory(inventorySlot: number, equipSlot: string)
	local stack = self.Inventory:GetItem(inventorySlot)
	if not stack then
		return
	end

	local item = stack.Item

	-- If there's already an item equipped, swap it
	local currentEquipped = self.Equipment[equipSlot]
	if currentEquipped then
		-- Put current equipped item back in inventory
		if not self.Inventory:AddItem(currentEquipped, 1) then
			warn("Cannot equip - inventory full")
			return
		end
	end

	-- Remove from inventory and equip (client-side)
	self.Inventory:RemoveItem(inventorySlot, 1)
	self.Equipment[equipSlot] = item

	-- Notify server
	local equipItemEvent = ReplicatedStorage:FindFirstChild("EquipItem")
	if equipItemEvent then
		equipItemEvent:FireServer(inventorySlot, equipSlot)
	end

	print(string.format("Equipped %s to %s", item.Name, equipSlot))
end

-- Unequip item to specific inventory slot
function InventoryUI:UnequipToInventory(equipSlot: string, inventorySlot: number)
	local item = self.Equipment[equipSlot]
	if not item then
		return
	end

	-- Check if target slot is empty or has same item (for stacking)
	local targetStack = self.Inventory:GetItem(inventorySlot)

	if targetStack then
		-- If same item and can stack, try to add
		if targetStack.Item.Id == item.Id and item.MaxStack > 1 then
			local spaceAvailable = item.MaxStack - targetStack.Count
			if spaceAvailable > 0 then
				targetStack.Count += 1
				self.Equipment[equipSlot] = nil

				-- Notify server
				local unequipItemEvent = ReplicatedStorage:FindFirstChild("UnequipItem")
				if unequipItemEvent then
					unequipItemEvent:FireServer(equipSlot)
				end

				print(string.format("Unequipped %s from %s", item.Name, equipSlot))
				return
			end
		end

		-- Otherwise, we need to swap
		-- Put target item in a temp location
		if not self.Inventory:AddItem(item, 1) then
			warn("Cannot unequip - inventory full")
			return
		end
		self.Equipment[equipSlot] = nil
	else
		-- Slot is empty, just move there
		self.Inventory.Slots[inventorySlot] = {
			Item = item,
			Count = 1,
		}
		self.Equipment[equipSlot] = nil
	end

	-- Notify server
	local unequipItemEvent = ReplicatedStorage:FindFirstChild("UnequipItem")
	if unequipItemEvent then
		unequipItemEvent:FireServer(equipSlot)
	end

	print(string.format("Unequipped %s from %s", item.Name, equipSlot))
end

-- Swap two equipment slots
function InventoryUI:SwapEquipment(fromSlot: string, toSlot: string)
	local fromItem = self.Equipment[fromSlot]
	local toItem = self.Equipment[toSlot]

	-- Validate target slot can hold the item
	if fromItem and not self:CanEquipItem(fromItem, toSlot) then
		warn(string.format("Cannot equip %s in %s slot", fromItem.Name, toSlot))
		return
	end

	if toItem and not self:CanEquipItem(toItem, fromSlot) then
		warn(string.format("Cannot equip %s in %s slot", toItem.Name, fromSlot))
		return
	end

	-- Swap
	self.Equipment[fromSlot] = toItem
	self.Equipment[toSlot] = fromItem

	print(string.format("Swapped equipment slots %s and %s", fromSlot, toSlot))
end

function InventoryUI:SetupInputHandling()
	-- Toggle inventory with I key
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.I then
			self:Toggle()
		end
	end)
end

function InventoryUI:Toggle()
	self.IsOpen = not self.IsOpen
	self.ScreenGui.Enabled = self.IsOpen

	if self.IsOpen then
		self:RefreshUI()
	end
end

function InventoryUI:Open()
	self.IsOpen = true
	self.ScreenGui.Enabled = true
	self:RefreshUI()
end

function InventoryUI:Close()
	self.IsOpen = false
	self.ScreenGui.Enabled = false
end

function InventoryUI:RefreshUI()
	-- Update inventory slots
	for i = 1, self.Inventory.Size do
		local slotButton = self.SlotButtons[i]
		if not slotButton then
			continue
		end

		local itemStack = self.Inventory:GetItem(i)
		local icon = slotButton:FindFirstChild("Icon") :: TextLabel
		local countLabel = slotButton:FindFirstChild("Count") :: TextLabel

		if itemStack then
			icon.Text = itemStack.Item.Name
			icon.TextColor3 = self:GetRarityColor(itemStack.Item.Rarity)

			if itemStack.Count > 1 then
				countLabel.Text = tostring(itemStack.Count)
			else
				countLabel.Text = ""
			end

			slotButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		else
			icon.Text = ""
			countLabel.Text = ""
			slotButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		end
	end

	-- Update equipment slots
	for slotName, slotButton in self.EquipmentSlots do
		local icon = slotButton:FindFirstChild("Icon") :: TextLabel
		local equippedItem = self.Equipment[slotName]

		if equippedItem then
			icon.Text = equippedItem.Name
			icon.TextColor3 = self:GetRarityColor(equippedItem.Rarity)
			slotButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		else
			icon.Text = ""
			slotButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		end
	end

	-- Update belt slots
	for i = 1, 5 do
		local slotButton = self.BeltSlots[i]
		if not slotButton then
			continue
		end

		local itemStack = self.Belt[i]
		local icon = slotButton:FindFirstChild("Icon") :: TextLabel
		local countLabel = slotButton:FindFirstChild("Count") :: TextLabel

		if itemStack then
			icon.Text = itemStack.Item.Name
			icon.TextColor3 = self:GetRarityColor(itemStack.Item.Rarity)

			if itemStack.Count > 1 then
				countLabel.Text = tostring(itemStack.Count)
			else
				countLabel.Text = ""
			end

			slotButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		else
			icon.Text = ""
			countLabel.Text = ""
			slotButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		end
	end
end

function InventoryUI:GetRarityColor(rarity: string): Color3
	if rarity == "Common" then
		return Color3.fromRGB(200, 200, 200) -- Gray
	elseif rarity == "Magic" then
		return Color3.fromRGB(100, 150, 255) -- Blue
	elseif rarity == "Rare" then
		return Color3.fromRGB(255, 215, 0) -- Gold
	elseif rarity == "Unique" then
		return Color3.fromRGB(255, 150, 50) -- Orange
	else
		return Color3.fromRGB(255, 255, 255) -- White
	end
end

-- Move item from inventory to belt
function InventoryUI:MoveToBelt(inventorySlot: number, beltSlot: number)
	local stack = self.Inventory:GetItem(inventorySlot)
	if not stack then
		return
	end

	-- Don't modify client-side yet - let server handle it and broadcast back
	-- This prevents desync issues where we remove from inventory before server validates

	-- Notify server to sync
	local setBeltSlotEvent = ReplicatedStorage:FindFirstChild("SetBeltSlot")
	if setBeltSlotEvent then
		setBeltSlotEvent:FireServer(beltSlot, inventorySlot)
	end

	print(string.format("Requesting to move %s to belt slot %d", stack.Item.Name, beltSlot))
end

-- Move item from belt to inventory
function InventoryUI:MoveFromBeltToInventory(beltSlot: number, inventorySlot: number)
	local stack = self.Belt[beltSlot]
	if not stack then
		return
	end

	-- Try to add to inventory slot
	local targetStack = self.Inventory:GetItem(inventorySlot)
	if not targetStack then
		-- Empty slot - move there
		self.Inventory.Slots[inventorySlot] = {
			Item = stack.Item,
			Count = 1,
		}
	else
		-- Slot occupied - try to add to inventory generally
		if not self.Inventory:AddItem(stack.Item, 1) then
			warn("Cannot move from belt - inventory full")
			return
		end
	end

	-- Remove from belt
	stack.Count -= 1
	if stack.Count <= 0 then
		self.Belt[beltSlot] = nil
	end

	print(string.format("Moved item from belt slot %d to inventory", beltSlot))
end

-- Swap two belt slots
function InventoryUI:SwapBelt(fromSlot: number, toSlot: number)
	local fromStack = self.Belt[fromSlot]
	local toStack = self.Belt[toSlot]

	self.Belt[fromSlot] = toStack
	self.Belt[toSlot] = fromStack

	print(string.format("Swapped belt slots %d and %d", fromSlot, toSlot))
end

function InventoryUI:Destroy()
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

return InventoryUI
