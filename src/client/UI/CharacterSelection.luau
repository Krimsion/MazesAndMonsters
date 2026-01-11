--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CharacterSelection = {}
CharacterSelection.__index = CharacterSelection

export type CharacterSlotData = {
	Name: string,
	Level: number,
	LastSaved: number,
}

export type CharacterSelection = typeof(setmetatable(
	{} :: {
		Player: Player,
		ScreenGui: ScreenGui,
		SelectionFrame: Frame,
		SlotButtons: { TextButton },
		OnCharacterSelected: ((number) -> ())?,
		CharacterSlots: { CharacterSlotData? },
	},
	CharacterSelection
))

function CharacterSelection.new(player: Player): CharacterSelection
	local self = setmetatable({
		Player = player,
		SlotButtons = {},
		CharacterSlots = {},
	} :: any, CharacterSelection)

	self:CreateUI()
	self:RequestCharacterList()

	return self
end

function CharacterSelection:CreateUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CharacterSelectionUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = self.Player.PlayerGui

	self.ScreenGui = screenGui

	-- Background overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	-- Main selection frame
	local selectionFrame = Instance.new("Frame")
	selectionFrame.Name = "SelectionFrame"
	selectionFrame.Size = UDim2.new(0, 600, 0, 500)
	selectionFrame.Position = UDim2.new(0.5, -300, 0.5, -250)
	selectionFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	selectionFrame.BorderSizePixel = 2
	selectionFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	selectionFrame.Parent = screenGui

	self.SelectionFrame = selectionFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	title.BorderSizePixel = 0
	title.Text = "SELECT CHARACTER"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextSize = 28
	title.Font = Enum.Font.GothamBold
	title.Parent = selectionFrame

	-- Create 3 character slots
	for i = 1, 3 do
		local slotButton = self:CreateCharacterSlot(i)
		slotButton.Parent = selectionFrame
		table.insert(self.SlotButtons, slotButton)
	end
end

function CharacterSelection:CreateCharacterSlot(slotIndex: number): TextButton
	local yPos = 80 + (slotIndex - 1) * 130

	local slotButton = Instance.new("TextButton")
	slotButton.Name = "CharacterSlot" .. slotIndex
	slotButton.Size = UDim2.new(0, 560, 0, 110)
	slotButton.Position = UDim2.new(0, 20, 0, yPos)
	slotButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	slotButton.BorderSizePixel = 2
	slotButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
	slotButton.Text = ""
	slotButton.AutoButtonColor = false

	-- Character name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0, 300, 0, 30)
	nameLabel.Position = UDim2.new(0, 15, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Empty Slot"
	nameLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	nameLabel.TextSize = 20
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = slotButton

	-- Level label
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0, 200, 0, 25)
	levelLabel.Position = UDim2.new(0, 15, 0, 45)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = ""
	levelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	levelLabel.TextSize = 16
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = slotButton

	-- Last saved label
	local savedLabel = Instance.new("TextLabel")
	savedLabel.Name = "SavedLabel"
	savedLabel.Size = UDim2.new(0, 200, 0, 20)
	savedLabel.Position = UDim2.new(0, 15, 0, 75)
	savedLabel.BackgroundTransparency = 1
	savedLabel.Text = ""
	savedLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	savedLabel.TextSize = 12
	savedLabel.Font = Enum.Font.Gotham
	savedLabel.TextXAlignment = Enum.TextXAlignment.Left
	savedLabel.Parent = slotButton

	-- Play button (only visible if character exists)
	local playButton = Instance.new("TextButton")
	playButton.Name = "PlayButton"
	playButton.Size = UDim2.new(0, 120, 0, 40)
	playButton.Position = UDim2.new(1, -260, 0, 35)
	playButton.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
	playButton.Text = "PLAY"
	playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	playButton.TextSize = 18
	playButton.Font = Enum.Font.GothamBold
	playButton.Visible = false
	playButton.Parent = slotButton

	playButton.MouseButton1Click:Connect(function()
		self:PlayCharacter(slotIndex)
	end)

	-- Delete button (only visible if character exists)
	local deleteButton = Instance.new("TextButton")
	deleteButton.Name = "DeleteButton"
	deleteButton.Size = UDim2.new(0, 120, 0, 40)
	deleteButton.Position = UDim2.new(1, -130, 0, 35)
	deleteButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	deleteButton.Text = "DELETE"
	deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	deleteButton.TextSize = 18
	deleteButton.Font = Enum.Font.GothamBold
	deleteButton.Visible = false
	deleteButton.Parent = slotButton

	deleteButton.MouseButton1Click:Connect(function()
		self:DeleteCharacter(slotIndex)
	end)

	-- Create button (only visible if slot is empty)
	local createButton = Instance.new("TextButton")
	createButton.Name = "CreateButton"
	createButton.Size = UDim2.new(0, 200, 0, 50)
	createButton.Position = UDim2.new(0.5, -100, 0.5, -25)
	createButton.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
	createButton.Text = "CREATE NEW CHARACTER"
	createButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	createButton.TextSize = 16
	createButton.Font = Enum.Font.GothamBold
	createButton.Visible = true
	createButton.Parent = slotButton

	createButton.MouseButton1Click:Connect(function()
		self:CreateNewCharacter(slotIndex)
	end)

	return slotButton
end

function CharacterSelection:RequestCharacterList()
	local requestCharactersEvent = ReplicatedStorage:FindFirstChild("RequestCharacterList")
	if requestCharactersEvent then
		requestCharactersEvent:FireServer()
	end
end

function CharacterSelection:UpdateCharacterSlots(characterSlots: { CharacterSlotData? })
	self.CharacterSlots = characterSlots

	for i, slotButton in self.SlotButtons do
		local characterData = characterSlots[i]

		local nameLabel = slotButton:FindFirstChild("NameLabel") :: TextLabel
		local levelLabel = slotButton:FindFirstChild("LevelLabel") :: TextLabel
		local savedLabel = slotButton:FindFirstChild("SavedLabel") :: TextLabel
		local playButton = slotButton:FindFirstChild("PlayButton") :: TextButton
		local deleteButton = slotButton:FindFirstChild("DeleteButton") :: TextButton
		local createButton = slotButton:FindFirstChild("CreateButton") :: TextButton

		if characterData then
			-- Slot has character
			nameLabel.Text = characterData.Name
			nameLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			levelLabel.Text = string.format("Level %d", characterData.Level)
			levelLabel.Visible = true

			-- Format last saved time
			local timeDiff = os.time() - characterData.LastSaved
			local timeStr = ""
			if timeDiff < 60 then
				timeStr = "Just now"
			elseif timeDiff < 3600 then
				timeStr = string.format("%d minutes ago", math.floor(timeDiff / 60))
			elseif timeDiff < 86400 then
				timeStr = string.format("%d hours ago", math.floor(timeDiff / 3600))
			else
				timeStr = string.format("%d days ago", math.floor(timeDiff / 86400))
			end
			savedLabel.Text = "Last played: " .. timeStr
			savedLabel.Visible = true

			playButton.Visible = true
			deleteButton.Visible = true
			createButton.Visible = false
			slotButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		else
			-- Empty slot
			nameLabel.Text = "Empty Slot"
			nameLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
			levelLabel.Visible = false
			savedLabel.Visible = false
			playButton.Visible = false
			deleteButton.Visible = false
			createButton.Visible = true
			slotButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		end
	end
end

function CharacterSelection:CreateNewCharacter(slotIndex: number)
	print("Creating new character in slot", slotIndex)

	-- Prompt for character name
	local namePromptEvent = ReplicatedStorage:FindFirstChild("PromptCharacterName")
	if namePromptEvent then
		namePromptEvent:FireServer(slotIndex)
	end
end

function CharacterSelection:PlayCharacter(slotIndex: number)
	print("Playing character in slot", slotIndex)

	local selectCharacterEvent = ReplicatedStorage:FindFirstChild("SelectCharacter")
	if selectCharacterEvent then
		selectCharacterEvent:FireServer(slotIndex)
	end

	-- Hide selection screen
	self.ScreenGui.Enabled = false
end

function CharacterSelection:DeleteCharacter(slotIndex: number)
	print("Requesting delete for character in slot", slotIndex)

	local deleteCharacterEvent = ReplicatedStorage:FindFirstChild("DeleteCharacter")
	if deleteCharacterEvent then
		deleteCharacterEvent:FireServer(slotIndex)
	end
end

function CharacterSelection:Show()
	self.ScreenGui.Enabled = true
	self:RequestCharacterList()
end

function CharacterSelection:Hide()
	self.ScreenGui.Enabled = false
end

function CharacterSelection:Destroy()
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

return CharacterSelection
