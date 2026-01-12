--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueUI = {}
DialogueUI.__index = DialogueUI

export type DialogueData = {
	NPCName: string,
	Dialogue: string,
	QuestId: string,
	ShowAccept: boolean,
	ShowTurnIn: boolean,
}

export type DialogueUI = typeof(setmetatable(
	{} :: {
		Player: Player,
		ScreenGui: ScreenGui,
		DialogueFrame: Frame,
		NPCNameLabel: TextLabel,
		DialogueLabel: TextLabel,
		AcceptButton: TextButton,
		DeclineButton: TextButton,
		TurnInButton: TextButton,
		CloseButton: TextButton,
		CurrentQuestId: string?,
	},
	DialogueUI
))

function DialogueUI.new(player: Player): DialogueUI
	local self = setmetatable({
		Player = player,
		CurrentQuestId = nil,
	} :: any, DialogueUI)

	self:CreateUI()

	-- Listen for dialogue open events from server
	local openDialogueEvent = ReplicatedStorage:WaitForChild("OpenDialogue") :: RemoteEvent
	openDialogueEvent.OnClientEvent:Connect(function(dialogueData: DialogueData)
		self:Show(dialogueData)
	end)

	return self
end

function DialogueUI:CreateUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DialogueUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = self.Player.PlayerGui

	self.ScreenGui = screenGui

	-- Create main dialogue frame
	local dialogueFrame = Instance.new("Frame")
	dialogueFrame.Name = "DialogueFrame"
	dialogueFrame.Size = UDim2.new(0, 500, 0, 300)
	dialogueFrame.Position = UDim2.new(0.5, -250, 0.5, -150)
	dialogueFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	dialogueFrame.BorderSizePixel = 2
	dialogueFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	dialogueFrame.Parent = screenGui

	self.DialogueFrame = dialogueFrame

	-- NPC Name label
	local npcNameLabel = Instance.new("TextLabel")
	npcNameLabel.Name = "NPCName"
	npcNameLabel.Size = UDim2.new(1, 0, 0, 40)
	npcNameLabel.Position = UDim2.new(0, 0, 0, 0)
	npcNameLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	npcNameLabel.BorderSizePixel = 0
	npcNameLabel.Text = "Cane"
	npcNameLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	npcNameLabel.TextSize = 24
	npcNameLabel.Font = Enum.Font.GothamBold
	npcNameLabel.Parent = dialogueFrame

	self.NPCNameLabel = npcNameLabel

	-- Dialogue text label (with text wrapping)
	local dialogueLabel = Instance.new("TextLabel")
	dialogueLabel.Name = "DialogueText"
	dialogueLabel.Size = UDim2.new(1, -40, 0, 170)
	dialogueLabel.Position = UDim2.new(0, 20, 0, 50)
	dialogueLabel.BackgroundTransparency = 1
	dialogueLabel.Text = "Hello adventurer!"
	dialogueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	dialogueLabel.TextSize = 18
	dialogueLabel.Font = Enum.Font.Gotham
	dialogueLabel.TextWrapped = true
	dialogueLabel.TextXAlignment = Enum.TextXAlignment.Left
	dialogueLabel.TextYAlignment = Enum.TextYAlignment.Top
	dialogueLabel.Parent = dialogueFrame

	self.DialogueLabel = dialogueLabel

	-- Accept button
	local acceptButton = Instance.new("TextButton")
	acceptButton.Name = "AcceptButton"
	acceptButton.Size = UDim2.new(0, 140, 0, 40)
	acceptButton.Position = UDim2.new(0, 20, 1, -60)
	acceptButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	acceptButton.BorderSizePixel = 1
	acceptButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
	acceptButton.Text = "Accept Quest"
	acceptButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	acceptButton.TextSize = 16
	acceptButton.Font = Enum.Font.GothamBold
	acceptButton.Visible = false
	acceptButton.Parent = dialogueFrame

	self.AcceptButton = acceptButton

	-- Turn In button
	local turnInButton = Instance.new("TextButton")
	turnInButton.Name = "TurnInButton"
	turnInButton.Size = UDim2.new(0, 140, 0, 40)
	turnInButton.Position = UDim2.new(0, 20, 1, -60)
	turnInButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
	turnInButton.BorderSizePixel = 1
	turnInButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
	turnInButton.Text = "Turn In Quest"
	turnInButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	turnInButton.TextSize = 16
	turnInButton.Font = Enum.Font.GothamBold
	turnInButton.Visible = false
	turnInButton.Parent = dialogueFrame

	self.TurnInButton = turnInButton

	-- Decline/Close button
	local declineButton = Instance.new("TextButton")
	declineButton.Name = "DeclineButton"
	declineButton.Size = UDim2.new(0, 120, 0, 40)
	declineButton.Position = UDim2.new(1, -140, 1, -60)
	declineButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	declineButton.BorderSizePixel = 1
	declineButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
	declineButton.Text = "Close"
	declineButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	declineButton.TextSize = 16
	declineButton.Font = Enum.Font.GothamBold
	declineButton.Parent = dialogueFrame

	self.DeclineButton = declineButton

	-- Close button (X)
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 5)
	closeButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 18
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = dialogueFrame

	self.CloseButton = closeButton

	-- Button event handlers
	acceptButton.MouseButton1Click:Connect(function()
		self:OnAcceptQuest()
	end)

	turnInButton.MouseButton1Click:Connect(function()
		self:OnTurnInQuest()
	end)

	declineButton.MouseButton1Click:Connect(function()
		self:Hide()
	end)

	closeButton.MouseButton1Click:Connect(function()
		self:Hide()
	end)
end

function DialogueUI:Show(dialogueData: DialogueData)
	-- Update UI with dialogue data
	self.NPCNameLabel.Text = dialogueData.NPCName
	self.DialogueLabel.Text = dialogueData.Dialogue
	self.CurrentQuestId = dialogueData.QuestId

	-- Show/hide buttons based on dialogue type
	self.AcceptButton.Visible = dialogueData.ShowAccept
	self.TurnInButton.Visible = dialogueData.ShowTurnIn
	self.DeclineButton.Text = if dialogueData.ShowAccept then "Decline" else "Close"

	-- Show the UI
	self.ScreenGui.Enabled = true
end

function DialogueUI:Hide()
	self.ScreenGui.Enabled = false
	self.CurrentQuestId = nil
end

function DialogueUI:OnAcceptQuest()
	if self.CurrentQuestId then
		local acceptQuestEvent = ReplicatedStorage:WaitForChild("AcceptQuest") :: RemoteEvent
		acceptQuestEvent:FireServer(self.CurrentQuestId)
	end
	self:Hide()
end

function DialogueUI:OnTurnInQuest()
	if self.CurrentQuestId then
		local turnInQuestEvent = ReplicatedStorage:WaitForChild("TurnInQuest") :: RemoteEvent
		turnInQuestEvent:FireServer(self.CurrentQuestId)
	end
	self:Hide()
end

return DialogueUI
