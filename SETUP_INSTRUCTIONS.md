# GameConfig Setup Instructions

## Problem
Rojo's JSON model format doesn't properly sync attributes to Studio, so the GameConfig attributes aren't visible in the Properties panel after building.

## Solution: Create GameConfig in Studio

### Method 1: Command Bar (Quickest)

1. Open your place file in Roblox Studio
2. Go to **View → Command Bar** (or press Ctrl+')
3. Copy and paste this entire block into the Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
local c = RS:FindFirstChild("GameConfig")
if c then c:Destroy() end
c = Instance.new("Configuration")
c.Name = "GameConfig"
c:SetAttribute("PlayerAttackCooldown", 1.0)
c:SetAttribute("MonsterAttackCooldown", 1.5)
c:SetAttribute("MonsterAlertRange", 8)
c:SetAttribute("MonsterChaseRange", 12)
c:SetAttribute("MonsterAlertDuration", 0.5)
c:SetAttribute("MonsterChaseDuration", 10.0)
c:SetAttribute("MonsterAttackRange", 1)
c:SetAttribute("MonsterAttackRangeBuffer", 1)
c:SetAttribute("MonsterRespawnTime", 20.0)
c:SetAttribute("PlayerStartingHealth", 100)
c:SetAttribute("PlayerStartingMana", 50)
c:SetAttribute("PlayerMovementSpeed", 0.65)
c:SetAttribute("GridTileSize", 4)
c:SetAttribute("LootPickupRange", 2)
c.Parent = RS
print("✓ GameConfig created! Check ReplicatedStorage")
```

4. Press **Enter**
5. You should see "✓ GameConfig created! Check ReplicatedStorage" in the output
6. Navigate to **ReplicatedStorage → GameConfig**
7. Select it and view the **Properties** panel - all attributes should be visible!
8. **Save your place file** (Ctrl+S)

### Method 2: Run Once

1. Open your place file in Roblox Studio
2. Press **F5** to run the game (or click Play)
3. Wait 2-3 seconds for the server to initialize
4. Stop the game (Shift+F5 or click Stop)
5. Navigate to **ReplicatedStorage → GameConfig**
6. The object should now have all attributes visible in Properties
7. **Save your place file** (Ctrl+S)

### Method 3: Setup Script

1. Open `SetupGameConfig.server.lua`
2. Copy the entire contents
3. In Studio, go to **ServerScriptService**
4. Right-click → Insert Object → Script
5. Paste the copied code
6. Name it "SetupGameConfig"
7. Run the game briefly
8. The script creates GameConfig and disables itself
9. Stop the game and save

## After Setup

Once GameConfig exists in your place file:
- You can edit any attribute in the Properties panel
- Changes are saved with your place file
- No need to run the game to edit values
- Rebuild with `rojo build` won't overwrite your custom values

## Editing Attributes

1. Select **GameConfig** in ReplicatedStorage
2. In Properties panel, scroll to the **Attributes** section
3. Click any attribute value to edit
4. Changes take effect immediately in game
5. Save your place to persist changes

## Available Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| PlayerAttackCooldown | 1.0 | Player attack speed (seconds) |
| MonsterAttackCooldown | 1.5 | Monster attack speed (seconds) |
| MonsterAlertRange | 8 | Monster detection range (tiles) |
| MonsterChaseRange | 12 | Max chase distance (tiles) |
| MonsterAlertDuration | 0.5 | Alert delay before chase (seconds) |
| MonsterChaseDuration | 10.0 | Max chase time (seconds) |
| MonsterAttackRange | 1 | Monster attack range (tiles) |
| MonsterAttackRangeBuffer | 1 | Anti-jitter buffer (tiles) |
| MonsterRespawnTime | 20.0 | Respawn delay (seconds) |
| PlayerStartingHealth | 100 | Starting HP |
| PlayerStartingMana | 50 | Starting mana |
| PlayerMovementSpeed | 0.65 | Time per tile movement (seconds) |
| GridTileSize | 4 | Tile size (studs) |
| LootPickupRange | 2 | Loot collection range (tiles) |
