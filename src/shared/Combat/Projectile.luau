--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SkillTypes = require(ReplicatedStorage.Shared.Types.Skill)

local Projectile = {}
Projectile.__index = Projectile

export type Projectile = typeof(setmetatable(
	{} :: {
		Id: string,
		CasterName: string,
		Skill: SkillTypes.Skill,
		SkillLevel: number,
		Position: Vector3,
		Direction: Vector3,
		Damage: number,
		Speed: number,
		Range: number,
		DistanceTraveled: number,
		Model: Model?,
		OnHitCallback: ((Projectile, BasePart?) -> ())?,
		IsDestroyed: boolean,
		StartTime: number,
	},
	Projectile
))

function Projectile.new(
	id: string,
	casterName: string,
	skill: SkillTypes.Skill,
	skillLevel: number,
	startPosition: Vector3,
	direction: Vector3,
	damage: number,
	onHitCallback: ((Projectile, BasePart?) -> ())?
): Projectile
	local self = setmetatable({
		Id = id,
		CasterName = casterName,
		Skill = skill,
		SkillLevel = skillLevel,
		Position = startPosition,
		Direction = direction.Unit,
		Damage = damage,
		Speed = skill.ProjectileSpeed or 40,
		Range = skill.ProjectileRange or 100,
		DistanceTraveled = 0,
		Model = nil,
		OnHitCallback = onHitCallback,
		IsDestroyed = false,
		StartTime = tick(),
	}, Projectile)

	return self
end

-- Update projectile position and check for collisions
function Projectile:Update(deltaTime: number): boolean
	if self.IsDestroyed then
		return false
	end

	-- Move projectile
	local movement = self.Direction * self.Speed * deltaTime
	self.Position = self.Position + movement
	self.DistanceTraveled = self.DistanceTraveled + movement.Magnitude

	-- Update model position if it exists
	if self.Model and self.Model.PrimaryPart then
		self.Model:SetPrimaryPartCFrame(CFrame.new(self.Position, self.Position + self.Direction))
	end

	-- Check if exceeded range
	if self.DistanceTraveled >= self.Range then
		self:Destroy()
		return false
	end

	-- Check for collisions
	local hitPart = self:CheckCollision()
	if hitPart then
		if self.OnHitCallback then
			self.OnHitCallback(self, hitPart)
		end
		self:Destroy()
		return false
	end

	return true
end

-- Check for collision with environment or characters
function Projectile:CheckCollision(): BasePart?
	-- Use sphere check for better collision detection with characters
	local checkRadius = 3 -- Check 3 studs around projectile

	-- Get all parts near the projectile
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { self.Model }

	local partsInSphere = workspace:GetPartBoundsInRadius(self.Position, checkRadius, overlapParams)

	-- Find closest part
	local closestPart = nil
	local closestDistance = math.huge

	for _, part in partsInSphere do
		local distance = (part.Position - self.Position).Magnitude
		if distance < closestDistance and distance <= checkRadius then
			closestPart = part
			closestDistance = distance
		end
	end

	return closestPart
end

-- Destroy the projectile
function Projectile:Destroy()
	if self.IsDestroyed then
		return
	end

	self.IsDestroyed = true

	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
end

-- Create visual model for projectile
function Projectile:CreateModel(color: Color3, size: Vector3)
	local model = Instance.new("Model")
	model.Name = "Projectile_" .. self.Id

	local part = Instance.new("Part")
	part.Name = "ProjectilePart"
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Position = self.Position
	part.Parent = model

	model.PrimaryPart = part
	model.Parent = workspace

	self.Model = model
end

return Projectile
