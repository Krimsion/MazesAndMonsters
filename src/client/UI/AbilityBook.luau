--!strict

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SkillTypes = require(ReplicatedStorage.Shared.Types.Skill)
local SkillBook = require(ReplicatedStorage.Shared.Data.SkillBook)

local AbilityBook = {}
AbilityBook.__index = AbilityBook

export type AbilityBook = typeof(setmetatable(
	{} :: {
		Player: Player,
		ScreenGui: ScreenGui,
		BookFrame: Frame,
		IsOpen: boolean,
		LearnedSkills: { [string]: SkillTypes.LearnedSkill },
		SkillSlots: { TextButton },
		DragFrame: Frame?,
		IsDragging: boolean,
		DraggedSkillId: string?,
	},
	AbilityBook
))

function AbilityBook.new(player: Player): AbilityBook
	local self = setmetatable({
		Player = player,
		IsOpen = false,
		LearnedSkills = {},
		SkillSlots = {},
		DragFrame = nil,
		IsDragging = false,
		DraggedSkillId = nil,
	} :: any, AbilityBook)

	self:CreateUI()
	self:SetupInputHandling()
	self:SetupDragAndDrop()

	return self
end

function AbilityBook:CreateUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AbilityBookUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = self.Player.PlayerGui

	self.ScreenGui = screenGui

	-- Create main ability book frame
	local bookFrame = Instance.new("Frame")
	bookFrame.Name = "AbilityBook"
	bookFrame.Size = UDim2.new(0, 350, 0, 450)
	bookFrame.Position = UDim2.new(0.5, -175, 0.5, -225)
	bookFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bookFrame.BorderSizePixel = 2
	bookFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	bookFrame.Parent = screenGui

	self.BookFrame = bookFrame

	-- Create title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	title.BorderSizePixel = 0
	title.Text = "Ability Book"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = bookFrame

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 18
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = bookFrame

	closeButton.MouseButton1Click:Connect(function()
		self:Toggle()
	end)

	-- Instructions
	local instructions = Instance.new("TextLabel")
	instructions.Size = UDim2.new(1, -20, 0, 30)
	instructions.Position = UDim2.new(0, 10, 0, 45)
	instructions.BackgroundTransparency = 1
	instructions.Text = "Left-click and drag skills to your hotbar"
	instructions.TextColor3 = Color3.fromRGB(200, 200, 200)
	instructions.TextSize = 12
	instructions.Font = Enum.Font.Gotham
	instructions.TextXAlignment = Enum.TextXAlignment.Left
	instructions.Parent = bookFrame

	-- Create skill slots grid
	self:CreateSkillGrid(bookFrame)
end

function AbilityBook:CreateSkillGrid(parent: Frame)
	local startY = 85
	local slotSize = 80
	local spacing = 10
	local slotsPerRow = 3

	-- Create up to 15 skill slots (3x5 grid)
	for i = 1, 15 do
		local row = math.floor((i - 1) / slotsPerRow)
		local col = (i - 1) % slotsPerRow
		local x = 20 + col * (slotSize + spacing)
		local y = startY + row * (slotSize + spacing)

		local slot = self:CreateSkillSlot(i, x, y, slotSize)
		slot.Parent = parent
		table.insert(self.SkillSlots, slot)
	end
end

function AbilityBook:CreateSkillSlot(index: number, x: number, y: number, size: number): TextButton
	local slot = Instance.new("TextButton")
	slot.Name = "SkillSlot_" .. tostring(index)
	slot.Size = UDim2.new(0, size, 0, size)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	slot.BorderSizePixel = 2
	slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
	slot.Text = ""
	slot.AutoButtonColor = false

	-- Skill name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -4, 0, 20)
	nameLabel.Position = UDim2.new(0, 2, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextWrapped = true
	nameLabel.Parent = slot

	-- Skill level label
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, -4, 0, 16)
	levelLabel.Position = UDim2.new(0, 2, 1, -18)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = ""
	levelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	levelLabel.TextSize = 10
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.Parent = slot

	return slot
end

function AbilityBook:SetupInputHandling()
	-- Toggle ability book with 'K' key
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.K then
			self:Toggle()
		end
	end)
end

function AbilityBook:Toggle()
	self.IsOpen = not self.IsOpen
	self.ScreenGui.Enabled = self.IsOpen

	if self.IsOpen then
		self:RefreshUI()
	end
end

function AbilityBook:Open()
	self.IsOpen = true
	self.ScreenGui.Enabled = true
	self:RefreshUI()
end

function AbilityBook:Close()
	self.IsOpen = false
	self.ScreenGui.Enabled = false
end

function AbilityBook:UpdateLearnedSkills(learnedSkills: { [string]: SkillTypes.LearnedSkill })
	self.LearnedSkills = learnedSkills
	if self.IsOpen then
		self:RefreshUI()
	end
end

function AbilityBook:RefreshUI()
	-- Convert learned skills map to array for display
	local skillsArray = {}
	for skillId, learnedSkill in self.LearnedSkills do
		local skill = SkillBook.GetSkill(skillId)
		if skill then
			table.insert(skillsArray, {
				Skill = skill,
				LearnedSkill = learnedSkill,
			})
		end
	end

	-- Sort by skill name
	table.sort(skillsArray, function(a, b)
		return a.Skill.Name < b.Skill.Name
	end)

	-- Update skill slots
	for i, slot in self.SkillSlots do
		local nameLabel = slot:FindFirstChild("NameLabel") :: TextLabel
		local levelLabel = slot:FindFirstChild("LevelLabel") :: TextLabel

		if skillsArray[i] then
			local skillData = skillsArray[i]
			local skill = skillData.Skill
			local learnedSkill = skillData.LearnedSkill

			-- Set skill name with rarity color
			local rarityColor = self:GetRarityColor(skill.Rarity)
			nameLabel.TextColor3 = rarityColor
			nameLabel.Text = skill.Name

			-- Set skill level
			levelLabel.Text = string.format("Level %d", learnedSkill.Level)

			-- Make visible
			slot.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			slot.Visible = true

			-- Store skill ID for drag-drop
			slot:SetAttribute("SkillId", skill.Id)
		else
			-- Empty slot
			nameLabel.Text = ""
			levelLabel.Text = ""
			slot.Visible = false
			slot:SetAttribute("SkillId", nil)
		end
	end
end

function AbilityBook:GetRarityColor(rarity: SkillTypes.SkillRarity): Color3
	if rarity == "Common" then
		return Color3.fromRGB(200, 200, 200)
	elseif rarity == "Rare" then
		return Color3.fromRGB(100, 150, 255)
	elseif rarity == "Epic" then
		return Color3.fromRGB(200, 100, 255)
	elseif rarity == "Legendary" then
		return Color3.fromRGB(255, 165, 0)
	end
	return Color3.fromRGB(255, 255, 255)
end

function AbilityBook:SetupDragAndDrop()
	-- Setup mouse input for dragging
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Check if mouse is over a skill slot
			local mouse = self.Player:GetMouse()
			for _, slot in self.SkillSlots do
				if not slot.Visible then
					continue
				end

				local skillId = slot:GetAttribute("SkillId")
				if not skillId then
					continue
				end

				-- Check if mouse is over this slot
				local absPos = slot.AbsolutePosition
				local absSize = slot.AbsoluteSize
				if
					mouse.X >= absPos.X
					and mouse.X <= absPos.X + absSize.X
					and mouse.Y >= absPos.Y
					and mouse.Y <= absPos.Y + absSize.Y
				then
					-- Start dragging
					self:StartDrag(skillId, slot)
					break
				end
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and self.IsDragging and self.DragFrame then
			-- Update drag frame position
			local mouse = self.Player:GetMouse()
			self.DragFrame.Position = UDim2.new(0, mouse.X - 40, 0, mouse.Y - 40)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self.IsDragging then
			self:EndDrag()
		end
	end)
end

function AbilityBook:StartDrag(skillId: string, sourceSlot: TextButton)
	self.IsDragging = true
	self.DraggedSkillId = skillId

	-- Create drag frame
	local dragFrame = Instance.new("Frame")
	dragFrame.Name = "DragFrame"
	dragFrame.Size = UDim2.new(0, 80, 0, 80)
	dragFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	dragFrame.BorderSizePixel = 2
	dragFrame.BorderColor3 = Color3.fromRGB(200, 200, 200)
	dragFrame.ZIndex = 1000
	dragFrame.Parent = self.ScreenGui

	-- Add skill name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -4, 1, -4)
	nameLabel.Position = UDim2.new(0, 2, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = sourceSlot:FindFirstChild("NameLabel").TextColor3
	nameLabel.Text = sourceSlot:FindFirstChild("NameLabel").Text
	nameLabel.TextSize = 11
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextWrapped = true
	nameLabel.Parent = dragFrame

	self.DragFrame = dragFrame

	-- Update position
	local mouse = self.Player:GetMouse()
	dragFrame.Position = UDim2.new(0, mouse.X - 40, 0, mouse.Y - 40)
end

function AbilityBook:EndDrag()
	if not self.IsDragging or not self.DraggedSkillId then
		return
	end

	local mouse = self.Player:GetMouse()
	local mouseX, mouseY = mouse.X, mouse.Y

	-- Check if dropped on hotbar
	local hotbarUI = self.Player.PlayerGui:FindFirstChild("HotbarUI")
	if hotbarUI then
		local hotbarFrame = hotbarUI:FindFirstChild("HotbarFrame")
		if hotbarFrame then
			-- Check each hotbar slot with expanded hit detection
			local margin = 10 -- Add 10 pixel margin for easier dropping
			for i = 1, 5 do
				local slot = hotbarFrame:FindFirstChild("BeltSlot" .. i)
				if slot then
					local absPos = slot.AbsolutePosition
					local absSize = slot.AbsoluteSize
					if
						mouseX >= absPos.X - margin
						and mouseX <= absPos.X + absSize.X + margin
						and mouseY >= absPos.Y - margin
						and mouseY <= absPos.Y + absSize.Y + margin
					then
						-- Dropped on this hotbar slot
						print(string.format("Assigning skill %s to hotbar slot %d", self.DraggedSkillId, i))

						-- Send to server
						local setSkillSlotEvent = ReplicatedStorage:FindFirstChild("SetSkillSlot")
						if setSkillSlotEvent then
							setSkillSlotEvent:FireServer(i, self.DraggedSkillId)
							print("Sent SetSkillSlot event to server")
						else
							warn("SetSkillSlot event not found!")
						end
						break
					end
				else
					warn(string.format("BeltSlot%d not found in hotbar", i))
				end
			end
		else
			warn("HotbarFrame not found in HotbarUI")
		end
	else
		warn("HotbarUI not found in PlayerGui")
	end

	-- Clean up
	if self.DragFrame then
		self.DragFrame:Destroy()
		self.DragFrame = nil
	end
	self.IsDragging = false
	self.DraggedSkillId = nil
end

function AbilityBook:Destroy()
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

return AbilityBook
