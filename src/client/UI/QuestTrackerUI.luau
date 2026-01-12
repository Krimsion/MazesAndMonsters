--!strict

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestTypes = require(ReplicatedStorage.Shared.Types.Quest)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)

local QuestTrackerUI = {}
QuestTrackerUI.__index = QuestTrackerUI

export type QuestTrackerUI = typeof(setmetatable(
	{} :: {
		Player: Player,
		ScreenGui: ScreenGui,
		TrackerFrame: Frame,
		QuestList: ScrollingFrame,
		IsOpen: boolean,
		ActiveQuests: { QuestTypes.ActiveQuest },
	},
	QuestTrackerUI
))

function QuestTrackerUI.new(player: Player): QuestTrackerUI
	local self = setmetatable({
		Player = player,
		IsOpen = false,
		ActiveQuests = {},
	} :: any, QuestTrackerUI)

	self:CreateUI()
	self:SetupInputHandling()

	-- Listen for quest updates from server
	local updateQuestsEvent = ReplicatedStorage:WaitForChild("UpdateQuests") :: RemoteEvent
	updateQuestsEvent.OnClientEvent:Connect(function(activeQuests: { QuestTypes.ActiveQuest })
		self:UpdateQuests(activeQuests)
	end)

	return self
end

function QuestTrackerUI:CreateUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "QuestTrackerUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = self.Player.PlayerGui

	self.ScreenGui = screenGui

	-- Create main tracker frame
	local trackerFrame = Instance.new("Frame")
	trackerFrame.Name = "QuestTracker"
	trackerFrame.Size = UDim2.new(0, 350, 0, 450)
	trackerFrame.Position = UDim2.new(0.5, -175, 0.5, -225)
	trackerFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	trackerFrame.BorderSizePixel = 2
	trackerFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	trackerFrame.Parent = screenGui

	self.TrackerFrame = trackerFrame

	-- Create title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	title.BorderSizePixel = 0
	title.Text = "Quest Log"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = trackerFrame

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
	closeButton.BorderSizePixel = 0
	closeButton.Parent = title

	closeButton.MouseButton1Click:Connect(function()
		self:Toggle()
	end)

	-- Create scrolling frame for quest list
	local questList = Instance.new("ScrollingFrame")
	questList.Name = "QuestList"
	questList.Size = UDim2.new(1, -20, 1, -60)
	questList.Position = UDim2.new(0, 10, 0, 50)
	questList.BackgroundTransparency = 1
	questList.BorderSizePixel = 0
	questList.ScrollBarThickness = 6
	questList.CanvasSize = UDim2.new(0, 0, 0, 0)
	questList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	questList.Parent = trackerFrame

	-- Add UIListLayout for automatic positioning
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 10)
	listLayout.Parent = questList

	self.QuestList = questList
end

function QuestTrackerUI:SetupInputHandling()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		-- Press Q to toggle quest tracker
		if input.KeyCode == Enum.KeyCode.Q then
			self:Toggle()
		end
	end)
end

function QuestTrackerUI:Toggle()
	self.IsOpen = not self.IsOpen
	self.ScreenGui.Enabled = self.IsOpen
end

function QuestTrackerUI:UpdateQuests(activeQuests: { QuestTypes.ActiveQuest })
	self.ActiveQuests = activeQuests

	-- Clear existing quest items
	for _, child in self.QuestList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Create UI for each active quest
	for _, activeQuest in activeQuests do
		-- Skip turned-in quests
		if activeQuest.Status == "TurnedIn" then
			continue
		end

		-- Get quest definition
		local questDef = Quests[activeQuest.QuestId]
		if not questDef then
			continue
		end

		self:CreateQuestItem(questDef, activeQuest)
	end
end

function QuestTrackerUI:CreateQuestItem(questDef: QuestTypes.Quest, activeQuest: QuestTypes.ActiveQuest)
	-- Create quest item frame
	local questFrame = Instance.new("Frame")
	questFrame.Name = questDef.Id
	questFrame.Size = UDim2.new(1, 0, 0, 100)
	questFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	questFrame.BorderSizePixel = 1
	questFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	questFrame.Parent = self.QuestList

	-- Quest name
	local questName = Instance.new("TextLabel")
	questName.Name = "QuestName"
	questName.Size = UDim2.new(1, -10, 0, 25)
	questName.Position = UDim2.new(0, 5, 0, 5)
	questName.BackgroundTransparency = 1
	questName.Text = questDef.Name
	questName.TextColor3 = if activeQuest.Status == "Completed"
		then Color3.fromRGB(255, 215, 0)
		else Color3.fromRGB(255, 255, 255)
	questName.TextSize = 16
	questName.Font = Enum.Font.GothamBold
	questName.TextXAlignment = Enum.TextXAlignment.Left
	questName.Parent = questFrame

	-- Quest level indicator
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.Size = UDim2.new(0, 50, 0, 20)
	levelLabel.Position = UDim2.new(1, -55, 0, 5)
	levelLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	levelLabel.BorderSizePixel = 1
	levelLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
	levelLabel.Text = "Lv " .. questDef.Level
	levelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	levelLabel.TextSize = 14
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.Parent = questFrame

	-- Objectives container
	local objectivesFrame = Instance.new("Frame")
	objectivesFrame.Name = "Objectives"
	objectivesFrame.Size = UDim2.new(1, -10, 0, 65)
	objectivesFrame.Position = UDim2.new(0, 5, 0, 30)
	objectivesFrame.BackgroundTransparency = 1
	objectivesFrame.Parent = questFrame

	-- Add UIListLayout for objectives
	local objectiveLayout = Instance.new("UIListLayout")
	objectiveLayout.SortOrder = Enum.SortOrder.LayoutOrder
	objectiveLayout.Padding = UDim.new(0, 3)
	objectiveLayout.Parent = objectivesFrame

	-- Create objective labels
	for i, objective in activeQuest.Objectives do
		local objLabel = Instance.new("TextLabel")
		objLabel.Name = "Objective" .. i
		objLabel.Size = UDim2.new(1, 0, 0, 18)
		objLabel.BackgroundTransparency = 1
		objLabel.Text = string.format(
			"%s %s: %d/%d",
			if objective.Completed then "✓" else "•",
			objective.Description,
			objective.Current,
			objective.Required
		)
		objLabel.TextColor3 = if objective.Completed
			then Color3.fromRGB(100, 255, 100)
			else Color3.fromRGB(200, 200, 200)
		objLabel.TextSize = 14
		objLabel.Font = Enum.Font.Gotham
		objLabel.TextXAlignment = Enum.TextXAlignment.Left
		objLabel.Parent = objectivesFrame
	end

	-- Auto-size the quest frame based on number of objectives
	local objectiveCount = #activeQuest.Objectives
	questFrame.Size = UDim2.new(1, 0, 0, 35 + (objectiveCount * 21))
end

return QuestTrackerUI
