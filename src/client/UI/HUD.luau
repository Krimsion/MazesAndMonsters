--!strict

local Players = game:GetService("Players")

local HUD = {}
HUD.__index = HUD

export type HUD = typeof(setmetatable(
	{} :: {
		Player: Player,
		ScreenGui: ScreenGui,
		HealthBar: Frame,
		HealthFill: Frame,
		HealthText: TextLabel,
		ManaBar: Frame,
		ManaFill: Frame,
		ManaText: TextLabel,
		XPBar: Frame,
		XPFill: Frame,
		XPText: TextLabel,
		LevelText: TextLabel,
	},
	HUD
))

function HUD.new(player: Player): HUD
	local self = setmetatable({
		Player = player,
	} :: any, HUD)

	self:CreateUI()

	return self
end

function HUD:CreateUI()
	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MazesAndMonstersHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = self.Player.PlayerGui

	self.ScreenGui = screenGui

	-- Create HP Bar
	self.HealthBar = self:CreateBar(UDim2.new(0, 20, 0, 20), UDim2.new(0, 250, 0, 30), "HP")
	self.HealthFill = self.HealthBar:FindFirstChild("Fill") :: Frame
	self.HealthText = self.HealthBar:FindFirstChild("Text") :: TextLabel

	-- Create Mana Bar
	self.ManaBar = self:CreateBar(UDim2.new(0, 20, 0, 60), UDim2.new(0, 250, 0, 30), "MP")
	self.ManaFill = self.ManaBar:FindFirstChild("Fill") :: Frame
	self.ManaText = self.ManaBar:FindFirstChild("Text") :: TextLabel

	-- Recolor mana bar
	self.ManaFill.BackgroundColor3 = Color3.fromRGB(0, 100, 255)

	-- Create XP Bar
	self.XPBar = self:CreateBar(UDim2.new(0, 20, 0, 100), UDim2.new(0, 250, 0, 20), "XP")
	self.XPFill = self.XPBar:FindFirstChild("Fill") :: Frame
	self.XPText = self.XPBar:FindFirstChild("Text") :: TextLabel

	-- Recolor XP bar and initialize at 0
	self.XPFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	self.XPFill.Size = UDim2.new(0, 0, 1, 0)
	self.XPText.Text = "XP: 0/50"

	-- Create Level Display
	local levelText = Instance.new("TextLabel")
	levelText.Name = "LevelText"
	levelText.Size = UDim2.new(0, 100, 0, 30)
	levelText.Position = UDim2.new(0, 20, 0, 130)
	levelText.BackgroundTransparency = 1
	levelText.Text = "Level 1"
	levelText.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelText.TextSize = 18
	levelText.Font = Enum.Font.GothamBold
	levelText.TextXAlignment = Enum.TextXAlignment.Left
	levelText.Parent = screenGui

	self.LevelText = levelText
end

function HUD:CreateBar(position: UDim2, size: UDim2, labelText: string): Frame
	-- Background
	local barBg = Instance.new("Frame")
	barBg.Name = labelText .. "Bar"
	barBg.Position = position
	barBg.Size = size
	barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	barBg.BorderSizePixel = 2
	barBg.BorderColor3 = Color3.fromRGB(0, 0, 0)
	barBg.Parent = self.ScreenGui

	-- Fill
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(200, 0, 0) -- Red for health by default
	fill.BorderSizePixel = 0
	fill.Parent = barBg

	-- Text
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = labelText .. ": 100/100"
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextSize = 14
	text.Font = Enum.Font.GothamBold
	text.TextStrokeTransparency = 0.5
	text.Parent = barBg

	return barBg
end

-- Update HP bar
function HUD:UpdateHealth(current: number, max: number)
	local percent = math.clamp(current / max, 0, 1)
	self.HealthFill.Size = UDim2.new(percent, 0, 1, 0)
	self.HealthText.Text = string.format("HP: %d/%d", math.floor(current), math.floor(max))
end

-- Update Mana bar
function HUD:UpdateMana(current: number, max: number)
	local percent = math.clamp(current / max, 0, 1)
	self.ManaFill.Size = UDim2.new(percent, 0, 1, 0)
	self.ManaText.Text = string.format("MP: %d/%d", math.floor(current), math.floor(max))
end

-- Update XP bar
function HUD:UpdateXP(current: number, required: number)
	local percent = math.clamp(current / required, 0, 1)
	self.XPFill.Size = UDim2.new(percent, 0, 1, 0)
	self.XPText.Text = string.format("XP: %d/%d", math.floor(current), math.floor(required))
end

-- Update level display
function HUD:UpdateLevel(level: number)
	self.LevelText.Text = string.format("Level %d", level)
end

-- Cleanup
function HUD:Destroy()
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

return HUD
