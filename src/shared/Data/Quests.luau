--!strict

local QuestTypes = require(script.Parent.Parent.Types.Quest)
local Items = require(script.Parent.Items)

-- Quest database indexed by quest ID
local Quests: { [string]: QuestTypes.Quest } = {}

Quests["defeat_skeletons"] = {
	Id = "defeat_skeletons",
	Name = "Skeletal Threat",
	Description = "Cane has asked you to defeat three skeletons that have been threatening the area.",
	QuestGiver = "Cane",
	Objectives = {
		{
			Type = "Kill",
			Description = "Defeat Skeletons",
			Target = "Skeleton",
			Current = 0,
			Required = 3,
			Completed = false,
		},
	},
	Rewards = {
		XP = 50,
		Items = {
			{ Item = Items.HealthPotion, Count = 3 },
		},
	},
	Status = "Available",
	Level = 1,
}

return Quests
