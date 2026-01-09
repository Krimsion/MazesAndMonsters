--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GridTypes = require(Shared.Types.Grid)

local PlayerController = {}
PlayerController.__index = PlayerController

export type PlayerController = typeof(setmetatable(
	{} :: {
		Player: Player,
		Camera: Camera,
		Mouse: PlayerMouse,
		CurrentPath: { GridTypes.GridPosition }?,
		TargetPosition: GridTypes.GridPosition?,
	},
	PlayerController
))

function PlayerController.new(player: Player): PlayerController
	local self = setmetatable({
		Player = player,
		Camera = workspace.CurrentCamera,
		Mouse = player:GetMouse(),
		CurrentPath = nil,
		TargetPosition = nil,
	}, PlayerController)

	self:SetupCamera()
	self:SetupInput()

	return self
end

-- Setup camera for 2/3 birds-eye view
function PlayerController:SetupCamera()
	if not self.Camera then
		return
	end

	-- Set camera type to scriptable for custom control
	self.Camera.CameraType = Enum.CameraType.Scriptable
end

-- Update camera to follow player
function PlayerController:UpdateCamera(playerPosition: Vector3)
	if not self.Camera then
		return
	end

	-- Birds-eye view: elevated and angled down
	-- Distance and angle can be adjusted
	local cameraOffset = Vector3.new(10, 20, 10) -- Offset from player
	local cameraPosition = playerPosition + cameraOffset

	self.Camera.CFrame = CFrame.lookAt(cameraPosition, playerPosition)
end

-- Setup input handlers
function PlayerController:SetupInput()
	-- Left click for movement and interaction
	self.Mouse.Button1Down:Connect(function()
		self:OnLeftClick()
	end)

	-- Right click for abilities
	self.Mouse.Button2Down:Connect(function()
		self:OnRightClick()
	end)

	-- Keyboard shortcuts
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.I then
			-- Open inventory
			self:OnInventoryKey()
		elseif input.KeyCode == Enum.KeyCode.C then
			-- Open character/stats
			self:OnCharacterKey()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			-- Pause/options
			self:OnEscapeKey()
		end
	end)
end

-- Handle left click (movement, attack, interact)
function PlayerController:OnLeftClick()
	-- Get mouse hit position in world
	local mouseHit = self.Mouse.Hit

	if not mouseHit then
		return
	end

	-- Fire event to server for processing
	-- Server will determine if this is movement, attack, or interaction
	local clickEvent = ReplicatedStorage:FindFirstChild("PlayerClick")
	if clickEvent and clickEvent:IsA("RemoteEvent") then
		clickEvent:FireServer(mouseHit.Position)
	end
end

-- Handle right click (ability use)
function PlayerController:OnRightClick()
	local mouseHit = self.Mouse.Hit

	if not mouseHit then
		return
	end

	-- Fire event to server for ability usage
	local abilityEvent = ReplicatedStorage:FindFirstChild("PlayerAbility")
	if abilityEvent and abilityEvent:IsA("RemoteEvent") then
		abilityEvent:FireServer(mouseHit.Position)
	end
end

-- Handle inventory key
function PlayerController:OnInventoryKey()
	-- TODO: Open inventory UI
	print("Inventory pressed")
end

-- Handle character sheet key
function PlayerController:OnCharacterKey()
	-- TODO: Open character sheet UI
	print("Character sheet pressed")
end

-- Handle escape key
function PlayerController:OnEscapeKey()
	-- TODO: Open pause menu
	print("Escape pressed")
end

-- Visual feedback for movement path
function PlayerController:ShowPath(path: { GridTypes.GridPosition })
	self.CurrentPath = path
	-- TODO: Draw path indicators on ground
end

-- Clear path visualization
function PlayerController:ClearPath()
	self.CurrentPath = nil
	-- TODO: Clear path indicators
end

return PlayerController
