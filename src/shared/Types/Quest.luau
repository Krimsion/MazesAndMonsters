--!strict

local ItemTypes = require(script.Parent.Item)

-- Quest objective types
export type QuestObjectiveType = "Kill" | "Collect" | "Talk" | "Explore"

-- Quest objective
export type QuestObjective = {
	Type: QuestObjectiveType,
	Description: string,
	Target: string?, -- Monster name, item ID, NPC name, or location
	Current: number,
	Required: number,
	Completed: boolean,
}

-- Quest reward
export type QuestReward = {
	XP: number?,
	Items: { { Item: ItemTypes.Item, Count: number } }?,
	Gold: number?,
}

-- Quest status
export type QuestStatus = "Available" | "Active" | "Completed" | "TurnedIn"

-- Quest definition
export type Quest = {
	Id: string,
	Name: string,
	Description: string,
	QuestGiver: string, -- NPC name
	Objectives: { QuestObjective },
	Rewards: QuestReward,
	Status: QuestStatus,
	Level: number, -- Recommended level
}

-- Active quest (player's copy)
export type ActiveQuest = {
	QuestId: string,
	Objectives: { QuestObjective },
	Status: QuestStatus,
	AcceptedTime: number,
}

return {}
