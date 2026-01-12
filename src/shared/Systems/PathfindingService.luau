--!strict

local PathfindingService = game:GetService("PathfindingService")

local PathfindingHelper = {}
PathfindingHelper.__index = PathfindingHelper

export type PathfindingHelper = typeof(setmetatable(
	{} :: {
		AgentParameters: PathfindingService.AgentParameters,
	},
	PathfindingHelper
))

function PathfindingHelper.new(): PathfindingHelper
	local self = setmetatable({} :: any, PathfindingHelper)

	-- Set up agent parameters for humanoid pathfinding
	self.AgentParameters = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4, -- Spacing between waypoints
		Costs = {},
	}

	return self
end

-- Find a path from start to goal position
function PathfindingHelper:FindPath(startPos: Vector3, goalPos: Vector3): { Vector3 }?
	local path = PathfindingService:CreatePath(self.AgentParameters)

	local success, errorMessage = pcall(function()
		path:ComputeAsync(startPos, goalPos)
	end)

	if not success then
		warn("Pathfinding failed:", errorMessage)
		return nil
	end

	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local positions: { Vector3 } = {}

		-- Convert waypoints to Vector3 positions
		for _, waypoint in waypoints do
			table.insert(positions, waypoint.Position)
		end

		return positions
	else
		-- Path failed, return direct line
		return { startPos, goalPos }
	end
end

-- Calculate world distance between two positions
function PathfindingHelper.GetDistance(pos1: Vector3, pos2: Vector3): number
	return (pos1 - pos2).Magnitude
end

-- Check if position is within range of target
function PathfindingHelper.IsInRange(pos1: Vector3, pos2: Vector3, range: number): boolean
	return PathfindingHelper.GetDistance(pos1, pos2) <= range
end

return PathfindingHelper
