--!strict

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hotbar = {}
Hotbar.__index = Hotbar

export type Hotbar = typeof(setmetatable(
	{} :: {
		Player: Player,
		ScreenGui: ScreenGui,
		HotbarFrame: Frame,
		BeltSlots: { [number]: TextButton },
		BeltItems: { [number]: any? }, -- Holds references to items in belt slots
		SkillIds: { [number]: string? }, -- Holds skill IDs in slots
	},
	Hotbar
))

function Hotbar.new(player: Player): Hotbar
	local self = setmetatable({
		Player = player,
		BeltSlots = {},
		BeltItems = {},
		SkillIds = {},
	} :: any, Hotbar)

	self:CreateUI()
	self:SetupInputHandling()

	return self
end

function Hotbar:CreateUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HotbarUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = self.Player.PlayerGui

	self.ScreenGui = screenGui

	-- Create hotbar frame at bottom center
	local hotbarFrame = Instance.new("Frame")
	hotbarFrame.Name = "HotbarFrame"
	hotbarFrame.Size = UDim2.new(0, 400, 0, 70)
	hotbarFrame.Position = UDim2.new(0.5, -200, 1, -90)
	hotbarFrame.BackgroundTransparency = 1
	hotbarFrame.Parent = screenGui

	self.HotbarFrame = hotbarFrame

	-- Create 5 belt/quick slots
	local slotSize = 60
	local padding = 20
	local totalWidth = (slotSize * 5) + (padding * 4)
	local startX = (400 - totalWidth) / 2

	for i = 1, 5 do
		local slot = self:CreateBeltSlot(i, startX + (i - 1) * (slotSize + padding), 5, slotSize)
		slot.Parent = hotbarFrame
		self.BeltSlots[i] = slot
		self.BeltItems[i] = nil
	end
end

function Hotbar:CreateBeltSlot(index: number, x: number, y: number, size: number): TextButton
	local slot = Instance.new("TextButton")
	slot.Name = "BeltSlot" .. index
	slot.Size = UDim2.new(0, size, 0, size)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	slot.BorderSizePixel = 2
	slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
	slot.Text = ""
	slot.AutoButtonColor = false

	-- Keybind indicator
	local keybind = Instance.new("TextLabel")
	keybind.Name = "Keybind"
	keybind.Size = UDim2.new(0, 20, 0, 20)
	keybind.Position = UDim2.new(0, 2, 0, 2)
	keybind.BackgroundTransparency = 1
	keybind.Text = tostring(index)
	keybind.TextColor3 = Color3.fromRGB(255, 255, 0)
	keybind.TextSize = 14
	keybind.Font = Enum.Font.GothamBold
	keybind.TextStrokeTransparency = 0.5
	keybind.Parent = slot

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
	count.TextSize = 16
	count.Font = Enum.Font.GothamBold
	count.TextStrokeTransparency = 0.5
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Parent = slot

	-- Click handler
	slot.MouseButton1Click:Connect(function()
		self:UseSlot(index)
	end)

	return slot
end

function Hotbar:SetupInputHandling()
	-- Number keys 1-5 to use belt slots
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		-- Handle number keys 1-5
		if input.KeyCode == Enum.KeyCode.One then
			self:UseSlot(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			self:UseSlot(2)
		elseif input.KeyCode == Enum.KeyCode.Three then
			self:UseSlot(3)
		elseif input.KeyCode == Enum.KeyCode.Four then
			self:UseSlot(4)
		elseif input.KeyCode == Enum.KeyCode.Five then
			self:UseSlot(5)
		end
	end)
end

function Hotbar:UseSlot(slotIndex: number)
	-- Check if it's a skill first
	local skillId = self.SkillIds[slotIndex]
	if skillId then
		print(string.format("Used skill slot %d - %s", slotIndex, skillId))

		-- Get mouse position for skill direction
		local mouse = self.Player:GetMouse()
		local mousePosition = mouse.Hit.Position

		-- Send request to server to cast the skill with mouse position
		local castSkillEvent = ReplicatedStorage:FindFirstChild("CastSkill")
		if castSkillEvent then
			castSkillEvent:FireServer(skillId, mousePosition)
		end
		return
	end

	-- Otherwise check if it's an item
	local item = self.BeltItems[slotIndex]
	if item then
		print(string.format("Used belt slot %d - %s", slotIndex, item.Name or "Unknown"))

		-- Send request to server to use the item
		local useBeltItemEvent = ReplicatedStorage:FindFirstChild("UseBeltItem")
		if useBeltItemEvent then
			useBeltItemEvent:FireServer(slotIndex)
		end
	else
		print(string.format("Hotbar slot %d is empty", slotIndex))
	end
end

function Hotbar:SetBeltSlot(slotIndex: number, item: any?)
	self.BeltItems[slotIndex] = item
	-- Clear skill if setting a belt item
	if item then
		self.SkillIds[slotIndex] = nil
	end
	self:RefreshSlot(slotIndex)
end

function Hotbar:RefreshSlot(slotIndex: number)
	local slot = self.BeltSlots[slotIndex]
	if not slot then
		warn(string.format("RefreshSlot: BeltSlot %d not found", slotIndex))
		return
	end

	local icon = slot:FindFirstChild("Icon") :: TextLabel
	local countLabel = slot:FindFirstChild("Count") :: TextLabel

	-- Check if it's a skill first
	local skillId = self.SkillIds[slotIndex]
	if skillId then
		-- Display skill name
		local SkillBook = require(ReplicatedStorage.Shared.Data.SkillBook)
		local skill = SkillBook.GetSkill(skillId)
		if skill then
			print(string.format("RefreshSlot %d: Setting skill %s (%s)", slotIndex, skillId, skill.Name))
			icon.Text = skill.Name
			icon.TextColor3 = Color3.fromRGB(100, 200, 255) -- Blue tint for skills
			countLabel.Text = "" -- No count for skills
			slot.BackgroundColor3 = Color3.fromRGB(30, 50, 70) -- Bluish background
		else
			warn(string.format("RefreshSlot %d: Skill %s not found in SkillBook", slotIndex, skillId))
			-- Clear the slot since the skill doesn't exist
			icon.Text = ""
			countLabel.Text = ""
			slot.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		end
	else
		-- Check for belt item
		local item = self.BeltItems[slotIndex]
		if item then
			icon.Text = item.Name or "Item"
			icon.TextColor3 = Color3.fromRGB(255, 255, 255) -- White for items
			countLabel.Text = item.Count and tostring(item.Count) or ""
			slot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		else
			icon.Text = ""
			icon.TextColor3 = Color3.fromRGB(255, 255, 255)
			countLabel.Text = ""
			slot.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		end
	end
end

function Hotbar:RefreshAll()
	for i = 1, 5 do
		self:RefreshSlot(i)
	end
end

function Hotbar:SetSkillSlot(slotIndex: number, skillId: string?)
	print(string.format("Hotbar:SetSkillSlot(%d, %s)", slotIndex, tostring(skillId)))
	self.SkillIds[slotIndex] = skillId
	-- Clear belt item if setting a skill
	if skillId then
		self.BeltItems[slotIndex] = nil
	end
	self:RefreshSlot(slotIndex)
end

function Hotbar:Destroy()
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

return Hotbar
