--!strict

local GridTypes = require(script.Parent.Parent.Types.Grid)

local GridSystem = {}
GridSystem.__index = GridSystem

export type GridSystem = typeof(setmetatable(
	{} :: {
		TileSize: number,
		Grid: { [string]: GridTypes.GridTile },
	},
	GridSystem
))

-- Create a new grid system
function GridSystem.new(tileSize: number): GridSystem
	local self = setmetatable({
		TileSize = tileSize,
		Grid = {},
	}, GridSystem)

	return self
end

-- Convert world position to grid coordinates
function GridSystem:WorldToGrid(worldPos: Vector3): GridTypes.GridPosition
	return {
		X = math.floor(worldPos.X / self.TileSize + 0.5),
		Z = math.floor(worldPos.Z / self.TileSize + 0.5),
	}
end

-- Convert grid coordinates to world position
function GridSystem:GridToWorld(gridPos: GridTypes.GridPosition): Vector3
	return Vector3.new(gridPos.X * self.TileSize, 0, gridPos.Z * self.TileSize)
end

-- Get tile key for storage
function GridSystem:GetTileKey(gridPos: GridTypes.GridPosition): string
	return string.format("%d,%d", gridPos.X, gridPos.Z)
end

-- Get or create tile at grid position
function GridSystem:GetTile(gridPos: GridTypes.GridPosition): GridTypes.GridTile
	local key = self:GetTileKey(gridPos)

	if not self.Grid[key] then
		self.Grid[key] = {
			Position = gridPos,
			IsWalkable = true,
			OccupiedBy = nil,
			HasItem = nil,
		}
	end

	return self.Grid[key]
end

-- Set tile walkability
function GridSystem:SetWalkable(gridPos: GridTypes.GridPosition, walkable: boolean)
	local tile = self:GetTile(gridPos)
	tile.IsWalkable = walkable
end

-- Check if tile is walkable and unoccupied
function GridSystem:IsTileAvailable(gridPos: GridTypes.GridPosition): boolean
	local tile = self:GetTile(gridPos)
	return tile.IsWalkable and tile.OccupiedBy == nil
end

-- Occupy a tile with an actor/object
function GridSystem:OccupyTile(gridPos: GridTypes.GridPosition, occupant: any): boolean
	local tile = self:GetTile(gridPos)

	if not tile.IsWalkable or tile.OccupiedBy ~= nil then
		return false
	end

	tile.OccupiedBy = occupant
	return true
end

-- Clear tile occupation
function GridSystem:ClearTile(gridPos: GridTypes.GridPosition)
	local tile = self:GetTile(gridPos)
	tile.OccupiedBy = nil
end

-- Move occupant from one tile to another
function GridSystem:MoveOccupant(fromPos: GridTypes.GridPosition, toPos: GridTypes.GridPosition): boolean
	local fromTile = self:GetTile(fromPos)
	local toTile = self:GetTile(toPos)

	if not toTile.IsWalkable or toTile.OccupiedBy ~= nil then
		return false
	end

	toTile.OccupiedBy = fromTile.OccupiedBy
	fromTile.OccupiedBy = nil
	return true
end

-- Place item on tile
function GridSystem:PlaceItem(gridPos: GridTypes.GridPosition, item: any): boolean
	local tile = self:GetTile(gridPos)

	-- Can only hold one item per tile
	if tile.HasItem ~= nil then
		return false
	end

	tile.HasItem = item
	return true
end

-- Remove item from tile
function GridSystem:RemoveItem(gridPos: GridTypes.GridPosition): any?
	local tile = self:GetTile(gridPos)
	local item = tile.HasItem
	tile.HasItem = nil
	return item
end

-- Get Manhattan distance between two grid positions
function GridSystem.GetDistance(from: GridTypes.GridPosition, to: GridTypes.GridPosition): number
	return math.abs(to.X - from.X) + math.abs(to.Z - from.Z)
end

-- Get adjacent tiles (4-directional)
function GridSystem.GetAdjacentPositions(gridPos: GridTypes.GridPosition): { GridTypes.GridPosition }
	return {
		{ X = gridPos.X + 1, Z = gridPos.Z }, -- Right
		{ X = gridPos.X - 1, Z = gridPos.Z }, -- Left
		{ X = gridPos.X, Z = gridPos.Z + 1 }, -- Forward
		{ X = gridPos.X, Z = gridPos.Z - 1 }, -- Back
	}
end

-- Get all 8 surrounding tiles (including diagonals)
function GridSystem.GetSurroundingPositions(gridPos: GridTypes.GridPosition): { GridTypes.GridPosition }
	return {
		{ X = gridPos.X + 1, Z = gridPos.Z },
		{ X = gridPos.X - 1, Z = gridPos.Z },
		{ X = gridPos.X, Z = gridPos.Z + 1 },
		{ X = gridPos.X, Z = gridPos.Z - 1 },
		{ X = gridPos.X + 1, Z = gridPos.Z + 1 },
		{ X = gridPos.X + 1, Z = gridPos.Z - 1 },
		{ X = gridPos.X - 1, Z = gridPos.Z + 1 },
		{ X = gridPos.X - 1, Z = gridPos.Z - 1 },
	}
end

-- Simple A* pathfinding
function GridSystem:FindPath(
	startPos: GridTypes.GridPosition,
	endPos: GridTypes.GridPosition,
	maxSteps: number
): { GridTypes.GridPosition }?
	maxSteps = maxSteps or 100

	-- Note: We allow pathfinding TO an occupied tile (like an enemy)
	-- The pathfinding will find a path adjacent to it

	local openSet: { { pos: GridTypes.GridPosition, parent: any?, g: number, f: number } } = {}
	local closedSet: { [string]: boolean } = {}

	local startNode = {
		pos = startPos,
		parent = nil,
		g = 0,
		f = GridSystem.GetDistance(startPos, endPos),
	}

	table.insert(openSet, startNode)

	local steps = 0
	while #openSet > 0 and steps < maxSteps do
		steps += 1

		-- Get node with lowest f score
		table.sort(openSet, function(a, b)
			return a.f < b.f
		end)

		local current = table.remove(openSet, 1)
		local currentKey = self:GetTileKey(current.pos)

		-- Check if we reached the goal
		if current.pos.X == endPos.X and current.pos.Z == endPos.Z then
			-- Reconstruct path
			local path = {}
			local node = current
			while node do
				table.insert(path, 1, node.pos)
				node = node.parent
			end
			return path
		end

		closedSet[currentKey] = true

		-- Check adjacent tiles
		local adjacent = GridSystem.GetAdjacentPositions(current.pos)
		for _, neighborPos in adjacent do
			local neighborKey = self:GetTileKey(neighborPos)

			if not closedSet[neighborKey] then
				local tile = self:GetTile(neighborPos)

				-- Allow pathfinding to goal even if occupied
				local isGoal = neighborPos.X == endPos.X and neighborPos.Z == endPos.Z
				if tile.IsWalkable and (tile.OccupiedBy == nil or isGoal) then
					local g = current.g + 1
					local h = GridSystem.GetDistance(neighborPos, endPos)
					local f = g + h

					-- Check if neighbor is already in open set with better score
					local existingNode = nil
					for i, node in openSet do
						if node.pos.X == neighborPos.X and node.pos.Z == neighborPos.Z then
							existingNode = node
							break
						end
					end

					if existingNode then
						if g < existingNode.g then
							existingNode.g = g
							existingNode.f = f
							existingNode.parent = current
						end
					else
						table.insert(openSet, {
							pos = neighborPos,
							parent = current,
							g = g,
							f = f,
						})
					end
				end
			end
		end
	end

	return nil -- No path found
end

return GridSystem
