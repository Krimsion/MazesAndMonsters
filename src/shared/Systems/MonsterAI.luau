--!strict

local CombatTypes = require(script.Parent.Parent.Types.Combat)
local Actor = require(script.Parent.Parent.Data.Actor)

export type MonsterAI = {
	CurrentState: CombatTypes.AIState,
	Target: Actor.Actor?,
	AggroRange: number,
	AttackRange: number,
	PatrolOrigin: Vector3?,
	PatrolRadius: number,
	LastAttackTime: number,
	LastStateChange: number,
	ChaseStartTime: number,
	CurrentPath: { Vector3 }?,
	PathIndex: number,
}

local MonsterAI = {}

-- Create a new AI instance for a monster
function MonsterAI.new(aggroRange: number?, attackRange: number?, patrolOrigin: Vector3?): MonsterAI
	return {
		CurrentState = "Idle",
		Target = nil,
		AggroRange = aggroRange or 8,
		AttackRange = attackRange or 1,
		PatrolOrigin = patrolOrigin,
		PatrolRadius = 3,
		LastAttackTime = 0,
		LastStateChange = 0,
		ChaseStartTime = 0,
		CurrentPath = nil,
		PathIndex = 1,
	}
end

-- Check if target is in aggro range
function MonsterAI.IsTargetInAggroRange(monsterPos: Vector3, targetPos: Vector3, aggroRange: number): boolean
	local distance = (monsterPos - targetPos).Magnitude
	return distance <= (aggroRange * 4) -- Convert tiles to studs
end

-- Check if target is in attack range
function MonsterAI.IsTargetInAttackRange(monsterPos: Vector3, targetPos: Vector3, attackRange: number): boolean
	local distance = (monsterPos - targetPos).Magnitude
	return distance <= (attackRange * 4) -- Convert tiles to studs
end

-- Update AI state machine (called from GameService)
function MonsterAI.Update(ai: MonsterAI, deltaTime: number, monster: Actor.Actor, players: {[Player]: Actor.Actor}, monsters: any, gameService: any)
	local currentTime = tick()
	local self = ai

	-- Build list of potential targets (players only for now)
	local potentialTargets = {}
	for _, playerActor in players do
		table.insert(potentialTargets, playerActor)
	end

	-- State machine
	if self.CurrentState == "Idle" or self.CurrentState == "Patrol" then
		-- Look for targets in aggro range
		for _, target in potentialTargets do
			if target:IsAlive() and MonsterAI.IsTargetInAggroRange(monster.Position, target.Position, self.AggroRange) then
				self.Target = target
				self.CurrentState = "Alert"
				self.LastStateChange = currentTime
				break
			end
		end

	elseif self.CurrentState == "Alert" then
		-- Transition to chase after a brief alert period
		if currentTime - self.LastStateChange > 0.5 then
			self.CurrentState = "Chase"
			self.LastStateChange = currentTime
			self.ChaseStartTime = currentTime
		end

	elseif self.CurrentState == "Chase" then
		if not self.Target or not self.Target:IsAlive() then
			-- Target died or lost, return to idle
			self.Target = nil
			self.CurrentState = "Idle"
			self.LastStateChange = currentTime
			self.CurrentPath = nil
		else
			-- Check distance for attack range
			local distance = (monster.Position - self.Target.Position).Magnitude
			local attackRangeStuds = self.AttackRange * 4

			if distance <= attackRangeStuds then
				-- Target is in attack range
				self.CurrentState = "Attack"
				self.LastStateChange = currentTime
				self.CurrentPath = nil
			else
				-- Check if target is out of aggro range
				local aggroRangeStuds = self.AggroRange * 4 * 1.5
				local chaseDuration = currentTime - self.ChaseStartTime

				if distance > aggroRangeStuds and chaseDuration > 10.0 then
					-- Target moved too far and chase timer expired, disengage
					self.Target = nil
					self.CurrentState = "Disengage"
					self.LastStateChange = currentTime
					self.CurrentPath = nil
				else
					-- Continue chasing - move towards target
					MonsterAI.MoveTowardsTarget(self, monster, self.Target, deltaTime, gameService)
				end
			end
		end

	elseif self.CurrentState == "Attack" then
		if not self.Target or not self.Target:IsAlive() then
			-- Target died, return to idle
			self.Target = nil
			self.CurrentState = "Idle"
			self.LastStateChange = currentTime
			self.CurrentPath = nil
		else
			-- Check if target moved out of attack range (with buffer)
			local distance = (monster.Position - self.Target.Position).Magnitude
			local attackRangeStuds = (self.AttackRange + 1) * 4

			if distance > attackRangeStuds then
				-- Target moved out of range, chase again
				self.CurrentState = "Chase"
				self.LastStateChange = currentTime
				self.ChaseStartTime = currentTime
				self.CurrentPath = nil
			else
				-- Perform attack
				local attackCooldown = 1.5
				if currentTime - self.LastAttackTime >= attackCooldown then
					self.LastAttackTime = currentTime
					gameService:MonsterAttack(monster, self.Target)
				end
			end
		end

	elseif self.CurrentState == "Disengage" then
		-- Return to idle
		self.CurrentState = "Idle"
		self.LastStateChange = currentTime
		self.CurrentPath = nil
	end
end

-- Move monster towards target
function MonsterAI.MoveTowardsTarget(ai: MonsterAI, monster: Actor.Actor, target: Actor.Actor, deltaTime: number, gameService: any)
	-- Simple direct movement for now (can add pathfinding later if needed)
	local direction = (target.Position - monster.Position).Unit
	local moveSpeed = 0.8 -- Slightly slower than player
	local studsPerSecond = (1 / moveSpeed) * 4

	-- Move towards target
	local moveAmount = studsPerSecond * deltaTime
	monster.Position = monster.Position + (direction * moveAmount)

	-- Update model position - use PivotTo to move entire model
	if monster.Model and monster.Model.PrimaryPart then
		monster.Model:PivotTo(CFrame.lookAt(monster.Position, target.Position))
	end
end

return MonsterAI
