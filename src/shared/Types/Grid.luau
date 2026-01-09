--!strict

-- Grid position (tile coordinates)
export type GridPosition = {
	X: number,
	Z: number,
}

-- Grid tile data
export type GridTile = {
	Position: GridPosition,
	IsWalkable: boolean,
	OccupiedBy: any?, -- Reference to actor/object
	HasItem: any?, -- Reference to item on ground
}

return {}
