--!strict

local TweenService = game:GetService("TweenService")

local Notifications = {}

local screenGui: ScreenGui? = nil
local notificationQueue: { string } = {}
local isShowingNotification = false

function Notifications.Initialize(player: Player)
	-- Create ScreenGui for notifications
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NotificationsUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 100 -- On top of other UIs
	screenGui.Parent = player.PlayerGui
end

function Notifications.Show(message: string)
	if not screenGui then
		warn("Notifications not initialized")
		return
	end

	-- Add to queue
	table.insert(notificationQueue, message)

	-- Process queue if not already showing
	if not isShowingNotification then
		Notifications.ProcessQueue()
	end
end

function Notifications.ProcessQueue()
	if #notificationQueue == 0 then
		isShowingNotification = false
		return
	end

	isShowingNotification = true
	local message = table.remove(notificationQueue, 1)

	-- Create notification frame
	local notification = Instance.new("Frame")
	notification.Name = "Notification"
	notification.Size = UDim2.new(0, 400, 0, 60)
	notification.Position = UDim2.new(0.5, -200, 0.3, -30) -- Center-top area
	notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	notification.BorderSizePixel = 2
	notification.BorderColor3 = Color3.fromRGB(200, 100, 100)
	notification.BackgroundTransparency = 1 -- Start transparent
	notification.Parent = screenGui

	-- Add text
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -20, 1, -20)
	textLabel.Position = UDim2.new(0, 10, 0, 10)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = message
	textLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
	textLabel.TextSize = 18
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextWrapped = true
	textLabel.TextTransparency = 1 -- Start transparent
	textLabel.Parent = notification

	-- Fade in
	local fadeIn = TweenService:Create(
		notification,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.1 }
	)
	local textFadeIn = TweenService:Create(
		textLabel,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	)

	fadeIn:Play()
	textFadeIn:Play()

	-- Wait, then fade out
	task.wait(2)

	local fadeOut = TweenService:Create(
		notification,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	)
	local textFadeOut = TweenService:Create(
		textLabel,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }
	)

	fadeOut:Play()
	textFadeOut:Play()

	fadeOut.Completed:Connect(function()
		notification:Destroy()
		-- Process next notification in queue
		Notifications.ProcessQueue()
	end)
end

return Notifications
