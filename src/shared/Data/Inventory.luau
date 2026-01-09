--!strict

local ItemTypes = require(script.Parent.Parent.Types.Item)

export type Inventory = {
	Slots: { [number]: ItemTypes.ItemStack? }, -- 1-25 for 5x5 grid
	Size: number,
}

local Inventory = {}
Inventory.__index = Inventory

-- Create a new inventory with specified size
function Inventory.new(size: number): Inventory
	local self = setmetatable({
		Slots = {},
		Size = size,
	}, Inventory)

	-- Initialize empty slots
	for i = 1, size do
		self.Slots[i] = nil
	end

	return self :: any
end

-- Add an item to the inventory (returns true if successful)
function Inventory:AddItem(item: ItemTypes.Item, count: number): boolean
	count = count or 1

	-- First, try to stack with existing items
	if item.MaxStack > 1 then
		for i = 1, self.Size do
			local stack = self.Slots[i]
			if stack and stack.Item.Id == item.Id then
				local spaceAvailable = item.MaxStack - stack.Count
				if spaceAvailable > 0 then
					local amountToAdd = math.min(count, spaceAvailable)
					stack.Count += amountToAdd
					count -= amountToAdd

					if count == 0 then
						return true
					end
				end
			end
		end
	end

	-- Create new stacks for remaining items
	while count > 0 do
		local emptySlot = self:FindEmptySlot()
		if not emptySlot then
			return false -- Inventory full
		end

		local stackSize = math.min(count, item.MaxStack)
		self.Slots[emptySlot] = {
			Item = item,
			Count = stackSize,
		}
		count -= stackSize
	end

	return true
end

-- Remove an item from the inventory
function Inventory:RemoveItem(slotIndex: number, count: number): boolean
	count = count or 1

	local stack = self.Slots[slotIndex]
	if not stack then
		return false
	end

	if stack.Count <= count then
		-- Remove entire stack
		self.Slots[slotIndex] = nil
	else
		-- Reduce stack count
		stack.Count -= count
	end

	return true
end

-- Get item at slot
function Inventory:GetItem(slotIndex: number): ItemTypes.ItemStack?
	return self.Slots[slotIndex]
end

-- Find first empty slot
function Inventory:FindEmptySlot(): number?
	for i = 1, self.Size do
		if not self.Slots[i] then
			return i
		end
	end
	return nil
end

-- Move item from one slot to another
function Inventory:MoveItem(fromSlot: number, toSlot: number): boolean
	if fromSlot == toSlot then
		return false
	end

	local fromStack = self.Slots[fromSlot]
	local toStack = self.Slots[toSlot]

	if not fromStack then
		return false
	end

	-- If destination is empty, just move
	if not toStack then
		self.Slots[toSlot] = fromStack
		self.Slots[fromSlot] = nil
		return true
	end

	-- If same item and can stack, combine
	if fromStack.Item.Id == toStack.Item.Id and toStack.Item.MaxStack > 1 then
		local spaceAvailable = toStack.Item.MaxStack - toStack.Count
		if spaceAvailable > 0 then
			local amountToMove = math.min(fromStack.Count, spaceAvailable)
			toStack.Count += amountToMove
			fromStack.Count -= amountToMove

			if fromStack.Count == 0 then
				self.Slots[fromSlot] = nil
			end
			return true
		end
	end

	-- Otherwise, swap
	self.Slots[toSlot] = fromStack
	self.Slots[fromSlot] = toStack
	return true
end

-- Get number of a specific item in inventory
function Inventory:GetItemCount(itemId: string): number
	local count = 0
	for i = 1, self.Size do
		local stack = self.Slots[i]
		if stack and stack.Item.Id == itemId then
			count += stack.Count
		end
	end
	return count
end

-- Check if inventory is full
function Inventory:IsFull(): boolean
	return self:FindEmptySlot() == nil
end

return Inventory
