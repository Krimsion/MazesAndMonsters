--!strict

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actor = require(ReplicatedStorage.Shared.Data.Actor)
local ItemTypes = require(ReplicatedStorage.Shared.Types.Item)
local SkillTypes = require(ReplicatedStorage.Shared.Types.Skill)

-- TEST MODE: Use in-memory storage if DataStore is not available (Studio without API access)
local USE_TEST_MODE = RunService:IsStudio()
local MockDataStore: { [string]: any } = {} -- In-memory storage for test mode

local PlayerDataStore
if not USE_TEST_MODE then
	local success = pcall(function()
		PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
	end)
	if not success then
		warn("DataStore not available, switching to TEST MODE")
		USE_TEST_MODE = true
	end
end

if USE_TEST_MODE then
	print("=== PLAYERDATA SERVICE IN TEST MODE ===")
	print("Data will NOT persist between sessions!")
	print("To enable persistence, enable Studio API access in Game Settings")
end

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

-- Maximum number of character slots per player
local MAX_CHARACTER_SLOTS = 3

export type CharacterData = {
	Name: string,
	Level: number,
	Experience: number,
	Attributes: {
		Strength: number,
		Dexterity: number,
		Vitality: number,
		Intelligence: number,
	},
	AvailableAttributePoints: number,
	CurrentHealth: number,
	CurrentMana: number,
	LearnedSkills: { [string]: SkillTypes.LearnedSkill },
	SkillSlots: { [number]: string? },
	Inventory: { ItemTypes.ItemStack },
	BeltSlots: { [number]: ItemTypes.ItemStack? },
	Equipment: {
		Weapon: ItemTypes.ItemStack?,
		Helmet: ItemTypes.ItemStack?,
		Chest: ItemTypes.ItemStack?,
		Gloves: ItemTypes.ItemStack?,
		Boots: ItemTypes.ItemStack?,
		Ring1: ItemTypes.ItemStack?,
		Ring2: ItemTypes.ItemStack?,
		Amulet: ItemTypes.ItemStack?,
		Belt: ItemTypes.ItemStack?,
	},
	LastSaved: number,
}

export type PlayerData = {
	Characters: { CharacterData? }, -- Up to MAX_CHARACTER_SLOTS characters
	LastPlayedSlot: number?,
}

-- Load player data from DataStore (or mock store in test mode)
function PlayerDataService.LoadPlayerData(userId: number): PlayerData?
	local key = "Player_" .. tostring(userId)

	if USE_TEST_MODE then
		-- Use mock data store
		local data = MockDataStore[key]
		if data then
			print("[TEST MODE] Loaded data for user", userId)
			return data :: PlayerData
		else
			print("[TEST MODE] No existing data for user", userId, "- creating new profile")
			return {
				Characters = {},
				LastPlayedSlot = nil,
			}
		end
	else
		-- Use real DataStore
		local success, data = pcall(function()
			return PlayerDataStore:GetAsync(key)
		end)

		if success and data then
			print("Loaded data for user", userId)
			return data :: PlayerData
		elseif success then
			-- No data exists, return default
			print("No existing data for user", userId, "- creating new profile")
			return {
				Characters = {},
				LastPlayedSlot = nil,
			}
		else
			warn("Failed to load data for user", userId, ":", data)
			return nil
		end
	end
end

-- Save player data to DataStore (or mock store in test mode)
function PlayerDataService.SavePlayerData(userId: number, data: PlayerData): boolean
	local key = "Player_" .. tostring(userId)

	if USE_TEST_MODE then
		-- Use mock data store
		MockDataStore[key] = data
		print("[TEST MODE] Saved data for user", userId)
		return true
	else
		-- Use real DataStore
		local success, err = pcall(function()
			PlayerDataStore:SetAsync(key, data)
		end)

		if success then
			print("Saved data for user", userId)
			return true
		else
			warn("Failed to save data for user", userId, ":", err)
			return false
		end
	end
end

-- Create a new character in a specific slot
function PlayerDataService.CreateCharacter(
	userId: number,
	slotIndex: number,
	characterName: string
): (boolean, string?)
	if slotIndex < 1 or slotIndex > MAX_CHARACTER_SLOTS then
		return false, "Invalid slot index"
	end

	local playerData = PlayerDataService.LoadPlayerData(userId)
	if not playerData then
		return false, "Failed to load player data"
	end

	if playerData.Characters[slotIndex] then
		return false, "Slot already occupied"
	end

	-- Create new character with default values
	local newCharacter: CharacterData = {
		Name = characterName,
		Level = 1,
		Experience = 0,
		Attributes = {
			Strength = 10,
			Dexterity = 10,
			Vitality = 10,
			Intelligence = 10,
		},
		AvailableAttributePoints = 0,
		CurrentHealth = 100,
		CurrentMana = 50,
		LearnedSkills = {},
		SkillSlots = {},
		Inventory = {},
		BeltSlots = {},
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
		LastSaved = os.time(),
	}

	playerData.Characters[slotIndex] = newCharacter
	playerData.LastPlayedSlot = slotIndex

	if PlayerDataService.SavePlayerData(userId, playerData) then
		return true, nil
	else
		return false, "Failed to save character"
	end
end

-- Delete a character from a specific slot
function PlayerDataService.DeleteCharacter(userId: number, slotIndex: number): (boolean, string?)
	if slotIndex < 1 or slotIndex > MAX_CHARACTER_SLOTS then
		return false, "Invalid slot index"
	end

	local playerData = PlayerDataService.LoadPlayerData(userId)
	if not playerData then
		return false, "Failed to load player data"
	end

	playerData.Characters[slotIndex] = nil

	-- Clear last played slot if it was this slot
	if playerData.LastPlayedSlot == slotIndex then
		playerData.LastPlayedSlot = nil
	end

	if PlayerDataService.SavePlayerData(userId, playerData) then
		return true, nil
	else
		return false, "Failed to delete character"
	end
end

-- Load a specific character
function PlayerDataService.LoadCharacter(userId: number, slotIndex: number): CharacterData?
	if slotIndex < 1 or slotIndex > MAX_CHARACTER_SLOTS then
		return nil
	end

	local playerData = PlayerDataService.LoadPlayerData(userId)
	if not playerData then
		return nil
	end

	return playerData.Characters[slotIndex]
end

-- Save a character's current state
function PlayerDataService.SaveCharacter(userId: number, slotIndex: number, actor: Actor.Actor): boolean
	if slotIndex < 1 or slotIndex > MAX_CHARACTER_SLOTS then
		return false
	end

	local playerData = PlayerDataService.LoadPlayerData(userId)
	if not playerData then
		return false
	end

	if not playerData.Characters[slotIndex] then
		warn("No character in slot", slotIndex, "for user", userId)
		return false
	end

	-- Convert Actor to CharacterData
	-- Map abbreviated attribute names to full names for storage
	local characterData: CharacterData = {
		Name = actor.Name,
		Level = actor.Stats.Level,
		Experience = actor.Stats.RuntimeStats.CurrentXP,
		Attributes = {
			Strength = actor.Stats.Attributes.STR,
			Dexterity = actor.Stats.Attributes.DEX,
			Vitality = actor.Stats.Attributes.VIT,
			Intelligence = actor.Stats.Attributes.INT,
		},
		AvailableAttributePoints = actor.AvailableAttributePoints or 0,
		CurrentHealth = actor.Stats.RuntimeStats.CurrentHealth,
		CurrentMana = actor.Stats.RuntimeStats.CurrentMana,
		LearnedSkills = actor.LearnedSkills,
		SkillSlots = actor.SkillSlots,
		Inventory = actor.Inventory.Slots,
		BeltSlots = actor.BeltSlots,
		Equipment = actor.Equipment,
		LastSaved = os.time(),
	}

	playerData.Characters[slotIndex] = characterData
	playerData.LastPlayedSlot = slotIndex

	return PlayerDataService.SavePlayerData(userId, playerData)
end

-- Get character list for selection screen
function PlayerDataService.GetCharacterList(userId: number): { CharacterData? }
	local playerData = PlayerDataService.LoadPlayerData(userId)
	if not playerData then
		return {}
	end

	return playerData.Characters
end

return PlayerDataService
