-- Brainrot Bay: one player's session state, kept in one place on the server.
-- Cash, lifetime earnings, rebirths, upgrades and the brainrots they own.
-- The server owns every number here; the client only asks, never sets.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local PlayerData = {}

-- Fresh state for a player who just joined.
function PlayerData.newState(player)
	return {
		Player = player,
		Cash = Config.StartCash,
		TotalEarned = 0,
		Rebirths = 0,
		BaseIndex = 0, -- assigned by the server when a base is free
		Upgrades = { Speed = 0, Income = 0, Slots = 0 },
		Owned = {}, -- the brainrot models sitting in this player's base
		LockUntil = 0,
		LockCooldownUntil = 0,
		SlapCooldownUntil = 0,
	}
end

-- Income multiplier from rebirths and the Golden Magnet upgrade.
function PlayerData.incomeMultiplier(state)
	return (1 + Config.RebirthIncomeBonus * state.Rebirths) * (1 + 0.10 * state.Upgrades.Income)
end

-- Money per second from everything this player owns, after multipliers.
function PlayerData.incomePerSecond(state)
	local base = 0
	for _, model in ipairs(state.Owned) do
		if model.Parent then
			base += model:GetAttribute("Income") or 0
		end
	end
	return math.floor(base * PlayerData.incomeMultiplier(state) + 0.5)
end

-- Walk speed from the Speed Boots upgrade.
function PlayerData.walkSpeed(state)
	return 16 + 2 * state.Upgrades.Speed
end

-- How many brainrot slots this player's base has.
function PlayerData.maxSlots(state)
	return 4 + 2 * state.Upgrades.Slots
end

-- Price of the next level of an upgrade, or nil when it is maxed.
function PlayerData.upgradeCost(kind, level)
	local upgrade = Config.Upgrades[kind]
	if not upgrade then
		return nil
	end
	if level >= upgrade.MaxLevel then
		return nil
	end
	return upgrade.Cost(level)
end

-- Is this player's base locked against stealing right now?
function PlayerData.isBaseLocked(state, now)
	return now < state.LockUntil
end

return PlayerData
