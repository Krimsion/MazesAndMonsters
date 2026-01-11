--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Projectile = require(ReplicatedStorage.Shared.Combat.Projectile)
local SkillTypes = require(ReplicatedStorage.Shared.Types.Skill)

local ProjectileManager = {}
ProjectileManager.__index = ProjectileManager

export type ProjectileManager = typeof(setmetatable(
	{} :: {
		Projectiles: { Projectile.Projectile },
		NextProjectileId: number,
		Connection: RBXScriptConnection?,
	},
	ProjectileManager
))

function ProjectileManager.new(): ProjectileManager
	local self = setmetatable({
		Projectiles = {},
		NextProjectileId = 1,
		Connection = nil,
	}, ProjectileManager)

	-- Start update loop
	self:StartUpdateLoop()

	return self
end

function ProjectileManager:StartUpdateLoop()
	self.Connection = RunService.Heartbeat:Connect(function(deltaTime)
		self:Update(deltaTime)
	end)
end

function ProjectileManager:Update(deltaTime: number)
	-- Update all projectiles
	for i = #self.Projectiles, 1, -1 do
		local projectile = self.Projectiles[i]

		-- Update returns false if projectile should be removed
		if not projectile:Update(deltaTime) then
			table.remove(self.Projectiles, i)
		end
	end
end

-- Create a projectile
function ProjectileManager:CreateProjectile(
	casterName: string,
	skill: SkillTypes.Skill,
	skillLevel: number,
	startPosition: Vector3,
	direction: Vector3,
	damage: number,
	onHitCallback: ((Projectile.Projectile, BasePart?) -> ())?
): Projectile.Projectile
	local id = tostring(self.NextProjectileId)
	self.NextProjectileId += 1

	local projectile = Projectile.new(id, casterName, skill, skillLevel, startPosition, direction, damage, onHitCallback)

	table.insert(self.Projectiles, projectile)

	return projectile
end

-- Create multiple projectiles in a spread pattern
function ProjectileManager:CreateProjectileSpread(
	casterName: string,
	skill: SkillTypes.Skill,
	skillLevel: number,
	startPosition: Vector3,
	baseDirection: Vector3,
	damage: number,
	projectileCount: number,
	spreadAngle: number,
	behavior: string,
	onHitCallback: ((Projectile.Projectile, BasePart?) -> ())?
): { Projectile.Projectile }
	local projectiles = {}

	if behavior == "Straight" then
		-- Single straight projectile
		local projectile =
			self:CreateProjectile(casterName, skill, skillLevel, startPosition, baseDirection, damage, onHitCallback)
		table.insert(projectiles, projectile)
	elseif behavior == "Erratic" then
		-- Multiple projectiles with random angles within spread
		for i = 1, projectileCount do
			-- Random angle within spread arc (using random number with decimal places)
			local randomAngle = math.rad((math.random() * spreadAngle) - (spreadAngle / 2))

			-- Also add random vertical angle for more erratic behavior
			local verticalAngle = math.rad((math.random() * 20) - 10) -- +/- 10 degrees vertical

			-- Rotate direction around Y axis (horizontal spread)
			local cos = math.cos(randomAngle)
			local sin = math.sin(randomAngle)
			local direction = Vector3.new(
				baseDirection.X * cos - baseDirection.Z * sin,
				baseDirection.Y,
				baseDirection.X * sin + baseDirection.Z * cos
			)

			-- Apply vertical angle
			local vCos = math.cos(verticalAngle)
			local vSin = math.sin(verticalAngle)
			direction = Vector3.new(
				direction.X * vCos,
				direction.Y + vSin,
				direction.Z * vCos
			).Unit

			local projectile =
				self:CreateProjectile(casterName, skill, skillLevel, startPosition, direction, damage, onHitCallback)
			table.insert(projectiles, projectile)
		end
	end

	return projectiles
end

function ProjectileManager:Destroy()
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	-- Destroy all projectiles
	for _, projectile in self.Projectiles do
		projectile:Destroy()
	end
	self.Projectiles = {}
end

return ProjectileManager
