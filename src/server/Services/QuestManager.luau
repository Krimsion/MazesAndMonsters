--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestTypes = require(ReplicatedStorage.Shared.Types.Quest)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Actor = require(ReplicatedStorage.Shared.Data.Actor)

local QuestManager = {}
QuestManager.__index = QuestManager

export type QuestManager = typeof(setmetatable(
	{} :: {
		PlayerQuests: { [Player]: { [string]: QuestTypes.ActiveQuest } },
	},
	QuestManager
))

function QuestManager.new(): QuestManager
	local self = setmetatable({
		PlayerQuests = {},
	}, QuestManager)

	return self
end

-- Initialize player quests
function QuestManager:InitializePlayer(player: Player, activeQuests: { [string]: QuestTypes.ActiveQuest }?)
	self.PlayerQuests[player] = activeQuests or {}
end

-- Check if player has quest
function QuestManager:HasQuest(player: Player, questId: string): boolean
	local playerQuests = self.PlayerQuests[player]
	if not playerQuests then
		return false
	end
	return playerQuests[questId] ~= nil
end

-- Accept a quest
function QuestManager:AcceptQuest(player: Player, questId: string): boolean
	local playerQuests = self.PlayerQuests[player]
	if not playerQuests then
		return false
	end

	-- Check if already has quest
	if playerQuests[questId] then
		return false
	end

	-- Get quest definition
	local questDef = Quests[questId]
	if not questDef then
		warn("Quest not found:", questId)
		return false
	end

	-- Create active quest with a copy of objectives
	local objectives = {}
	for _, obj in questDef.Objectives do
		table.insert(objectives, {
			Type = obj.Type,
			Description = obj.Description,
			Target = obj.Target,
			Current = 0,
			Required = obj.Required,
			Completed = false,
		})
	end

	playerQuests[questId] = {
		QuestId = questId,
		Objectives = objectives,
		Status = "Active",
		AcceptedTime = tick(),
	}

	return true
end

-- Update quest progress (e.g., killed a monster)
function QuestManager:UpdateQuestProgress(
	player: Player,
	objectiveType: QuestTypes.QuestObjectiveType,
	target: string,
	amount: number?
): { string }
	amount = amount or 1
	local updatedQuests = {}

	local playerQuests = self.PlayerQuests[player]
	if not playerQuests then
		return updatedQuests
	end

	for questId, activeQuest in playerQuests do
		if activeQuest.Status == "Active" then
			for _, objective in activeQuest.Objectives do
				if
					objective.Type == objectiveType
					and objective.Target == target
					and not objective.Completed
				then
					objective.Current = math.min(objective.Current + amount, objective.Required)

					if objective.Current >= objective.Required then
						objective.Completed = true
					end

					table.insert(updatedQuests, questId)
				end
			end

			-- Check if all objectives completed
			local allCompleted = true
			for _, objective in activeQuest.Objectives do
				if not objective.Completed then
					allCompleted = false
					break
				end
			end

			if allCompleted and activeQuest.Status ~= "Completed" then
				activeQuest.Status = "Completed"
			end
		end
	end

	return updatedQuests
end

-- Turn in a completed quest
function QuestManager:TurnInQuest(player: Player, questId: string, playerActor: Actor.Actor): boolean
	local playerQuests = self.PlayerQuests[player]
	if not playerQuests then
		return false
	end

	local activeQuest = playerQuests[questId]
	if not activeQuest or activeQuest.Status ~= "Completed" then
		return false
	end

	-- Get quest definition for rewards
	local questDef = Quests[questId]
	if not questDef then
		return false
	end

	-- Give XP reward
	if questDef.Rewards.XP then
		playerActor.Stats.RuntimeStats.CurrentXP += questDef.Rewards.XP
	end

	-- Give item rewards
	if questDef.Rewards.Items then
		for _, itemReward in questDef.Rewards.Items do
			playerActor.Inventory:AddItem(itemReward.Item, itemReward.Count)
		end
	end

	-- Mark as turned in
	activeQuest.Status = "TurnedIn"

	return true
end

-- Get all active quests for a player
function QuestManager:GetActiveQuests(player: Player): { QuestTypes.ActiveQuest }
	local playerQuests = self.PlayerQuests[player]
	if not playerQuests then
		return {}
	end

	local active = {}
	for _, quest in playerQuests do
		if quest.Status == "Active" or quest.Status == "Completed" then
			table.insert(active, quest)
		end
	end

	return active
end

-- Get quest by ID
function QuestManager:GetQuest(player: Player, questId: string): QuestTypes.ActiveQuest?
	local playerQuests = self.PlayerQuests[player]
	if not playerQuests then
		return nil
	end

	return playerQuests[questId]
end

-- Remove player data on leave
function QuestManager:CleanupPlayer(player: Player)
	self.PlayerQuests[player] = nil
end

return QuestManager
