--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Actor = require(ReplicatedStorage.Shared.Data.Actor)

local MonsterHealthBar = {}

-- Create a health bar UI above a monster
function MonsterHealthBar.Create(monster: Actor.Actor, model: Model): BillboardGui?
	if not model.PrimaryPart then
		return nil
	end

	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.new(4, 0, 0.5, 0)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = model.PrimaryPart

	-- Background frame
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	background.BorderSizePixel = 1
	background.BorderColor3 = Color3.fromRGB(0, 0, 0)
	background.Parent = billboard

	-- Health bar (foreground)
	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = background

	-- Health text
	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.TextSize = 14
	healthText.Font = Enum.Font.GothamBold
	healthText.TextStrokeTransparency = 0.5
	healthText.Text = string.format(
		"%d / %d",
		monster.Stats.RuntimeStats.CurrentHealth,
		monster.Stats.DerivedStats.MaxHealth
	)
	healthText.Parent = background

	-- Monster name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
	nameLabel.Position = UDim2.new(0, 0, -0.7, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	nameLabel.TextSize = 16
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Text = monster.Name
	nameLabel.Parent = background

	return billboard
end

-- Update health bar to reflect current health
function MonsterHealthBar.Update(billboard: BillboardGui, monster: Actor.Actor)
	local background = billboard:FindFirstChild("Background") :: Frame?
	if not background then
		return
	end

	local healthBar = background:FindFirstChild("HealthBar") :: Frame?
	local healthText = background:FindFirstChild("HealthText") :: TextLabel?

	if not healthBar or not healthText then
		return
	end

	local currentHealth = monster.Stats.RuntimeStats.CurrentHealth
	local maxHealth = monster.Stats.DerivedStats.MaxHealth
	local healthPercent = math.max(0, currentHealth / maxHealth)

	-- Update bar size
	healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)

	-- Update text
	healthText.Text = string.format("%d / %d", math.floor(currentHealth), maxHealth)

	-- Change color based on health percentage
	if healthPercent > 0.6 then
		healthBar.BackgroundColor3 = Color3.fromRGB(50, 200, 50) -- Green
	elseif healthPercent > 0.3 then
		healthBar.BackgroundColor3 = Color3.fromRGB(200, 200, 50) -- Yellow
	else
		healthBar.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Red
	end
end

-- Remove health bar
function MonsterHealthBar.Destroy(billboard: BillboardGui?)
	if billboard then
		billboard:Destroy()
	end
end

return MonsterHealthBar
