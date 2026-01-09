--!strict

-- Damage types
export type DamageType = "Physical" | "Fire" | "Ice" | "Poison" | "Arcane"

-- Damage info structure
export type DamageInfo = {
	Amount: number,
	Type: DamageType,
	IsCrit: boolean,
	Source: any?, -- Actor who dealt damage
}

-- Status effect types
export type StatusEffectType = "Bleed" | "Ignite" | "Chill" | "Freeze" | "Poison" | "Stun" | "Root"

-- Status effect data
export type StatusEffect = {
	Type: StatusEffectType,
	Duration: number,
	TickDamage: number?, -- For DOTs
	MovementModifier: number?, -- For slows/roots (0-1)
	StartTime: number,
}

-- AI states for monsters
export type AIState = "Idle" | "Patrol" | "Alert" | "Chase" | "Attack" | "Disengage"

return {}
