--!strict

local CombatTypes = require(script.Parent.Parent.Types.Combat)
local GridTypes = require(script.Parent.Parent.Types.Grid)
local Actor = require(script.Parent.Parent.Data.Actor)
local GridSystem = require(script.Parent.Parent.Systems.GridSystem)

export type MonsterAI = {
	CurrentState: CombatTypes.AIState,
	Target: Actor.Actor?,
	AggroRange: number,
	AttackRange: number,
	PatrolOrigin: GridTypes.GridPosition?,
	PatrolRadius: number,
	LastAttackTime: number,
	LastStateChange: number,
}

local MonsterAI = {}

-- Create a new AI instance for a monster
function MonsterAI.new(aggroRange: number, attackRange: number, patrolOrigin: GridTypes.GridPosition?): MonsterAI
	return {
		CurrentState = "Idle",
		Target = nil,
		AggroRange = aggroRange,
		AttackRange = attackRange,
		PatrolOrigin = patrolOrigin,
		PatrolRadius = 3,
		LastAttackTime = 0,
		LastStateChange = 0,
	}
end

-- Check if target is in aggro range
function MonsterAI.IsTargetInAggroRange(
	monsterPos: GridTypes.GridPosition,
	targetPos: GridTypes.GridPosition,
	aggroRange: number
): boolean
	local distance = GridSystem.GetDistance(monsterPos, targetPos)
	return distance <= aggroRange
end

-- Check if target is in attack range
function MonsterAI.IsTargetInAttackRange(
	monsterPos: GridTypes.GridPosition,
	targetPos: GridTypes.GridPosition,
	attackRange: number
): boolean
	local distance = GridSystem.GetDistance(monsterPos, targetPos)
	return distance <= attackRange
end

-- Update AI state machine
function MonsterAI.Update(
	ai: MonsterAI,
	monster: Actor.Actor,
	gridSystem: GridSystem.GridSystem,
	potentialTargets: { Actor.Actor },
	currentTime: number,
	deltaTime: number
): CombatTypes.AIState
	local previousState = ai.CurrentState

	-- State machine
	if ai.CurrentState == "Idle" or ai.CurrentState == "Patrol" then
		-- Look for targets in aggro range
		for _, target in potentialTargets do
			if target:IsAlive() and MonsterAI.IsTargetInAggroRange(monster.GridPosition, target.GridPosition, ai.AggroRange) then
				ai.Target = target
				ai.CurrentState = "Alert"
				ai.LastStateChange = currentTime
				break
			end
		end

		-- If no target found, continue patrolling (TODO: implement patrol movement)
	elseif ai.CurrentState == "Alert" then
		-- Transition to chase after a brief alert period
		if currentTime - ai.LastStateChange > 0.5 then
			ai.CurrentState = "Chase"
			ai.LastStateChange = currentTime
		end
	elseif ai.CurrentState == "Chase" then
		if not ai.Target or not ai.Target:IsAlive() then
			-- Target died or lost, return to idle
			ai.Target = nil
			ai.CurrentState = "Idle"
			ai.LastStateChange = currentTime
		elseif MonsterAI.IsTargetInAttackRange(monster.GridPosition, ai.Target.GridPosition, ai.AttackRange) then
			-- Target is in attack range
			ai.CurrentState = "Attack"
			ai.LastStateChange = currentTime
		elseif not MonsterAI.IsTargetInAggroRange(monster.GridPosition, ai.Target.GridPosition, ai.AggroRange * 1.5) then
			-- Target moved too far, disengage (use 1.5x aggro range for leash)
			ai.Target = nil
			ai.CurrentState = "Disengage"
			ai.LastStateChange = currentTime
		else
			-- Continue chasing (movement handled externally)
		end
	elseif ai.CurrentState == "Attack" then
		if not ai.Target or not ai.Target:IsAlive() then
			-- Target died, return to idle
			ai.Target = nil
			ai.CurrentState = "Idle"
			ai.LastStateChange = currentTime
		elseif not MonsterAI.IsTargetInAttackRange(monster.GridPosition, ai.Target.GridPosition, ai.AttackRange) then
			-- Target moved out of range, chase again
			ai.CurrentState = "Chase"
			ai.LastStateChange = currentTime
		else
			-- Continue attacking (attack logic handled externally)
		end
	elseif ai.CurrentState == "Disengage" then
		-- Return to patrol origin or just go idle
		ai.CurrentState = "Idle"
		ai.LastStateChange = currentTime
	end

	return ai.CurrentState
end

-- Get next movement position for monster (pathfinding)
function MonsterAI.GetNextMovePosition(
	ai: MonsterAI,
	monster: Actor.Actor,
	gridSystem: GridSystem.GridSystem
): GridTypes.GridPosition?
	if ai.CurrentState ~= "Chase" or not ai.Target then
		return nil
	end

	-- Find path to target
	local path = gridSystem:FindPath(monster.GridPosition, ai.Target.GridPosition, 50)

	if not path then
		print(string.format(
			"Monster pathfinding failed from (%d,%d) to (%d,%d)",
			monster.GridPosition.X,
			monster.GridPosition.Z,
			ai.Target.GridPosition.X,
			ai.Target.GridPosition.Z
		))
		return nil
	end

	if #path < 2 then
		print(string.format("Monster path too short: %d positions", #path))
		return nil
	end

	-- Return next step (skip first which is current position)
	return path[2]
end

-- Check if monster should attack (based on attack speed cooldown)
function MonsterAI.CanAttack(ai: MonsterAI, monster: Actor.Actor, currentTime: number): boolean
	if ai.CurrentState ~= "Attack" or not ai.Target then
		return false
	end

	-- Check attack cooldown based on attack speed
	local attackCooldown = 1.0 / monster.Stats.DerivedStats.AttackSpeed
	return (currentTime - ai.LastAttackTime) >= attackCooldown
end

-- Mark that an attack was performed
function MonsterAI.MarkAttack(ai: MonsterAI, currentTime: number)
	ai.LastAttackTime = currentTime
end

-- Force aggro on a specific target
function MonsterAI.ForceAggro(ai: MonsterAI, target: Actor.Actor, currentTime: number)
	ai.Target = target
	ai.CurrentState = "Alert"
	ai.LastStateChange = currentTime
end

-- Reset AI to idle state
function MonsterAI.Reset(ai: MonsterAI, currentTime: number)
	ai.CurrentState = "Idle"
	ai.Target = nil
	ai.LastStateChange = currentTime
end

return MonsterAI
