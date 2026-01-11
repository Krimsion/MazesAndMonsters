--!strict

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage.Shared.Types.Stats)

local CharacterSheet = {}
CharacterSheet.__index = CharacterSheet

export type CharacterSheet = typeof(setmetatable(
	{} :: {
		Player: Player,
		ScreenGui: ScreenGui,
		SheetFrame: Frame,
		IsOpen: boolean,
		Stats: Stats.ActorStats?,
	},
	CharacterSheet
))

function CharacterSheet.new(player: Player): CharacterSheet
	local self = setmetatable({
		Player = player,
		IsOpen = false,
		Stats = nil,
	} :: any, CharacterSheet)

	self:CreateUI()
	self:SetupInputHandling()

	return self
end

function CharacterSheet:CreateUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CharacterSheetUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = self.Player.PlayerGui

	self.ScreenGui = screenGui

	-- Create main character sheet frame
	local sheetFrame = Instance.new("Frame")
	sheetFrame.Name = "CharacterSheet"
	sheetFrame.Size = UDim2.new(0, 400, 0, 550)
	sheetFrame.Position = UDim2.new(0.5, -200, 0.5, -275)
	sheetFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	sheetFrame.BorderSizePixel = 2
	sheetFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	sheetFrame.Parent = screenGui

	self.SheetFrame = sheetFrame

	-- Create title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	title.BorderSizePixel = 0
	title.Text = "Character Sheet"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = sheetFrame

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
	closeButton.Parent = sheetFrame

	closeButton.MouseButton1Click:Connect(function()
		self:Toggle()
	end)

	-- Create content sections
	self:CreateStatsSection(sheetFrame, 50)
	self:CreateAttributesSection(sheetFrame, 200)
	self:CreateResistancesSection(sheetFrame, 350)
end

function CharacterSheet:CreateStatsSection(parent: Frame, yPos: number)
	-- Stats section (Level, HP, Mana, XP)
	local section = Instance.new("Frame")
	section.Name = "StatsSection"
	section.Size = UDim2.new(1, -20, 0, 140)
	section.Position = UDim2.new(0, 10, 0, yPos)
	section.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	section.BorderSizePixel = 1
	section.BorderColor3 = Color3.fromRGB(100, 100, 100)
	section.Parent = parent

	local sectionTitle = Instance.new("TextLabel")
	sectionTitle.Size = UDim2.new(1, 0, 0, 25)
	sectionTitle.BackgroundTransparency = 1
	sectionTitle.Text = "Character Stats"
	sectionTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
	sectionTitle.TextSize = 16
	sectionTitle.Font = Enum.Font.GothamBold
	sectionTitle.Parent = section

	local yOffset = 30
	local stats = {
		{ Name = "Level", Field = "Level" },
		{ Name = "Health", Field = "Health" },
		{ Name = "Mana", Field = "Mana" },
		{ Name = "Experience", Field = "XP" },
	}

	for i, stat in stats do
		local label = Instance.new("TextLabel")
		label.Name = stat.Field .. "Label"
		label.Size = UDim2.new(1, -10, 0, 20)
		label.Position = UDim2.new(0, 5, 0, yOffset + (i - 1) * 25)
		label.BackgroundTransparency = 1
		label.Text = stat.Name .. ": 0"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 14
		label.Font = Enum.Font.Gotham
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = section
	end
end

function CharacterSheet:CreateAttributesSection(parent: Frame, yPos: number)
	-- Attributes section (STR, DEX, VIT, INT)
	local section = Instance.new("Frame")
	section.Name = "AttributesSection"
	section.Size = UDim2.new(1, -20, 0, 170)
	section.Position = UDim2.new(0, 10, 0, yPos)
	section.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	section.BorderSizePixel = 1
	section.BorderColor3 = Color3.fromRGB(100, 100, 100)
	section.Parent = parent

	local sectionTitle = Instance.new("TextLabel")
	sectionTitle.Size = UDim2.new(1, 0, 0, 25)
	sectionTitle.BackgroundTransparency = 1
	sectionTitle.Text = "Attributes"
	sectionTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
	sectionTitle.TextSize = 16
	sectionTitle.Font = Enum.Font.GothamBold
	sectionTitle.Parent = section

	-- Available points display
	local pointsLabel = Instance.new("TextLabel")
	pointsLabel.Name = "AvailablePointsLabel"
	pointsLabel.Size = UDim2.new(1, -10, 0, 20)
	pointsLabel.Position = UDim2.new(0, 5, 0, 28)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Text = "Available Points: 0"
	pointsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	pointsLabel.TextSize = 14
	pointsLabel.Font = Enum.Font.GothamBold
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
	pointsLabel.Parent = section

	local yOffset = 55
	local attributes = {
		{ Name = "Strength (STR)", Field = "STR" },
		{ Name = "Dexterity (DEX)", Field = "DEX" },
		{ Name = "Vitality (VIT)", Field = "VIT" },
		{ Name = "Intelligence (INT)", Field = "INT" },
	}

	for i, attr in attributes do
		local label = Instance.new("TextLabel")
		label.Name = attr.Field .. "Label"
		label.Size = UDim2.new(1, -45, 0, 20)
		label.Position = UDim2.new(0, 5, 0, yOffset + (i - 1) * 25)
		label.BackgroundTransparency = 1
		label.Text = attr.Name .. ": 0"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 14
		label.Font = Enum.Font.Gotham
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = section

		-- Add + button
		local plusButton = Instance.new("TextButton")
		plusButton.Name = attr.Field .. "PlusButton"
		plusButton.Size = UDim2.new(0, 25, 0, 20)
		plusButton.Position = UDim2.new(1, -30, 0, yOffset + (i - 1) * 25)
		plusButton.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
		plusButton.Text = "+"
		plusButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		plusButton.TextSize = 18
		plusButton.Font = Enum.Font.GothamBold
		plusButton.Parent = section

		plusButton.MouseButton1Click:Connect(function()
			self:SpendAttributePoint(attr.Field)
		end)
	end
end

function CharacterSheet:CreateResistancesSection(parent: Frame, yPos: number)
	-- Resistances section
	local section = Instance.new("Frame")
	section.Name = "ResistancesSection"
	section.Size = UDim2.new(1, -20, 0, 140)
	section.Position = UDim2.new(0, 10, 0, yPos)
	section.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	section.BorderSizePixel = 1
	section.BorderColor3 = Color3.fromRGB(100, 100, 100)
	section.Parent = parent

	local sectionTitle = Instance.new("TextLabel")
	sectionTitle.Size = UDim2.new(1, 0, 0, 25)
	sectionTitle.BackgroundTransparency = 1
	sectionTitle.Text = "Resistances"
	sectionTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
	sectionTitle.TextSize = 16
	sectionTitle.Font = Enum.Font.GothamBold
	sectionTitle.Parent = section

	local yOffset = 30
	local resistances = {
		{ Name = "Fire Resistance", Field = "Fire" },
		{ Name = "Ice Resistance", Field = "Ice" },
		{ Name = "Poison Resistance", Field = "Poison" },
		{ Name = "Arcane Resistance", Field = "Arcane" },
	}

	for i, res in resistances do
		local label = Instance.new("TextLabel")
		label.Name = res.Field .. "Label"
		label.Size = UDim2.new(1, -10, 0, 20)
		label.Position = UDim2.new(0, 5, 0, yOffset + (i - 1) * 25)
		label.BackgroundTransparency = 1
		label.Text = res.Name .. ": 0%"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 14
		label.Font = Enum.Font.Gotham
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = section
	end
end

function CharacterSheet:SetupInputHandling()
	-- Toggle character sheet with C key
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.C then
			self:Toggle()
		end
	end)
end

function CharacterSheet:Toggle()
	self.IsOpen = not self.IsOpen
	self.ScreenGui.Enabled = self.IsOpen

	if self.IsOpen then
		self:RefreshUI()
	end
end

function CharacterSheet:Open()
	self.IsOpen = true
	self.ScreenGui.Enabled = true
	self:RefreshUI()
end

function CharacterSheet:Close()
	self.IsOpen = false
	self.ScreenGui.Enabled = false
end

function CharacterSheet:UpdateStats(stats: Stats.ActorStats)
	self.Stats = stats
	if self.IsOpen then
		self:RefreshUI()
	end
end

function CharacterSheet:RefreshUI()
	if not self.Stats then
		return
	end

	local statsSection = self.SheetFrame:FindFirstChild("StatsSection") :: Frame
	if statsSection then
		local levelLabel = statsSection:FindFirstChild("LevelLabel") :: TextLabel
		local healthLabel = statsSection:FindFirstChild("HealthLabel") :: TextLabel
		local manaLabel = statsSection:FindFirstChild("ManaLabel") :: TextLabel
		local xpLabel = statsSection:FindFirstChild("XPLabel") :: TextLabel

		if levelLabel then
			levelLabel.Text = string.format("Level: %d", self.Stats.Level)
		end
		if healthLabel then
			healthLabel.Text = string.format(
				"Health: %d / %d",
				self.Stats.RuntimeStats.CurrentHealth,
				self.Stats.DerivedStats.MaxHealth
			)
		end
		if manaLabel then
			manaLabel.Text = string.format(
				"Mana: %d / %d",
				self.Stats.RuntimeStats.CurrentMana,
				self.Stats.DerivedStats.MaxMana
			)
		end
		if xpLabel then
			xpLabel.Text = string.format("Experience: %d", self.Stats.RuntimeStats.CurrentXP)
		end
	end

	local attributesSection = self.SheetFrame:FindFirstChild("AttributesSection") :: Frame
	if attributesSection then
		-- Update available points
		local availablePoints = (self.Stats :: any).AvailableAttributePoints or 0
		local pointsLabel = attributesSection:FindFirstChild("AvailablePointsLabel") :: TextLabel
		if pointsLabel then
			pointsLabel.Text = string.format("Available Points: %d", availablePoints)
		end

		local strLabel = attributesSection:FindFirstChild("STRLabel") :: TextLabel
		local dexLabel = attributesSection:FindFirstChild("DEXLabel") :: TextLabel
		local vitLabel = attributesSection:FindFirstChild("VITLabel") :: TextLabel
		local intLabel = attributesSection:FindFirstChild("INTLabel") :: TextLabel

		if strLabel then
			strLabel.Text = string.format("Strength (STR): %d", self.Stats.Attributes.STR)
		end
		if dexLabel then
			dexLabel.Text = string.format("Dexterity (DEX): %d", self.Stats.Attributes.DEX)
		end
		if vitLabel then
			vitLabel.Text = string.format("Vitality (VIT): %d", self.Stats.Attributes.VIT)
		end
		if intLabel then
			intLabel.Text = string.format("Intelligence (INT): %d", self.Stats.Attributes.INT)
		end
	end

	local resistancesSection = self.SheetFrame:FindFirstChild("ResistancesSection") :: Frame
	if resistancesSection then
		local fireLabel = resistancesSection:FindFirstChild("FireLabel") :: TextLabel
		local iceLabel = resistancesSection:FindFirstChild("IceLabel") :: TextLabel
		local poisonLabel = resistancesSection:FindFirstChild("PoisonLabel") :: TextLabel
		local arcaneLabel = resistancesSection:FindFirstChild("ArcaneLabel") :: TextLabel

		if fireLabel then
			fireLabel.Text = string.format("Fire Resistance: %.1f%%", self.Stats.Resistances.Fire * 100)
		end
		if iceLabel then
			iceLabel.Text = string.format("Ice Resistance: %.1f%%", self.Stats.Resistances.Ice * 100)
		end
		if poisonLabel then
			poisonLabel.Text = string.format("Poison Resistance: %.1f%%", self.Stats.Resistances.Poison * 100)
		end
		if arcaneLabel then
			arcaneLabel.Text = string.format("Arcane Resistance: %.1f%%", self.Stats.Resistances.Arcane * 100)
		end
	end
end

function CharacterSheet:SpendAttributePoint(attribute: string)
	-- Send request to server to spend attribute point
	local spendAttributePointEvent = ReplicatedStorage:FindFirstChild("SpendAttributePoint")
	if spendAttributePointEvent then
		spendAttributePointEvent:FireServer(attribute)
		print(string.format("Spending attribute point on %s", attribute))
	end
end

function CharacterSheet:Destroy()
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

return CharacterSheet
