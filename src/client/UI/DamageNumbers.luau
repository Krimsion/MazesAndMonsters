--!strict

local TweenService = game:GetService("TweenService")

local DamageNumbers = {}

-- Show a damage number floating up from a world position
function DamageNumbers.Show(
	worldPosition: Vector3,
	amount: number,
	damageType: string,
	isCrit: boolean,
	isMiss: boolean
)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- Create a BillboardGui at the world position
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.Parent = workspace

	-- Create an attachment point for the billboard
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = worldPosition
	attachment.Parent = workspace.Terrain
	billboard.Adornee = attachment

	-- Create the text label
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextStrokeTransparency = 0.5
	textLabel.TextScaled = false
	textLabel.Parent = billboard

	-- Configure based on damage type
	if isMiss then
		textLabel.Text = "MISS"
		textLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		textLabel.TextSize = 18
	elseif isCrit then
		textLabel.Text = tostring(amount) .. "!"
		textLabel.TextColor3 = Color3.fromRGB(255, 200, 0) -- Gold for crits
		textLabel.TextSize = 28
	else
		textLabel.Text = tostring(amount)
		textLabel.TextSize = 20

		-- Color based on damage type
		if damageType == "Physical" then
			textLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White
		elseif damageType == "Fire" then
			textLabel.TextColor3 = Color3.fromRGB(255, 100, 0) -- Orange
		elseif damageType == "Ice" then
			textLabel.TextColor3 = Color3.fromRGB(100, 200, 255) -- Light blue
		elseif damageType == "Poison" then
			textLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green
		elseif damageType == "Arcane" then
			textLabel.TextColor3 = Color3.fromRGB(200, 100, 255) -- Purple
		else
			textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	-- Animate the damage number floating up and fading out
	local tweenInfo = TweenInfo.new(
		1.5, -- Duration
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	-- Float upward
	local offsetTween = TweenService:Create(billboard, tweenInfo, {
		StudsOffset = Vector3.new(math.random(-1, 1), 6, 0),
	})

	-- Fade out
	local fadeTween = TweenService:Create(textLabel, tweenInfo, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	offsetTween:Play()
	fadeTween:Play()

	-- Cleanup after animation
	task.delay(1.5, function()
		billboard:Destroy()
		attachment:Destroy()
	end)
end

return DamageNumbers
