-- Brainrot Bay: shared world layout and tuning.
-- One source of truth for positions, so the place file (default.project.json)
-- and the server scripts always agree about where things are.

local Config = {}

-- Cash every player starts with.
Config.StartCash = 100

-- The conveyor belt brainrots walk along: straight down the Z axis.
Config.Belt = {
	X = -30,
	ZStart = -88,
	ZEnd = 88,
	WalkY = 3, -- height of a walking brainrot's body centre
}

-- How often a new brainrot spawns on the belt, and how many may walk at once.
Config.SpawnInterval = 4
Config.MaxWalking = 10

-- Player bases: six plots in a row on the east side of the belt.
-- Each base is a 26x26 platform; its four slots sit at (+-6, +-6) from its centre.
Config.Bases = {
	{ Center = Vector3.new(35, 1, -75), Color = Color3.fromRGB(255, 170, 170) },
	{ Center = Vector3.new(35, 1, -45), Color = Color3.fromRGB(255, 220, 130) },
	{ Center = Vector3.new(35, 1, -15), Color = Color3.fromRGB(170, 230, 170) },
	{ Center = Vector3.new(35, 1, 15), Color = Color3.fromRGB(150, 200, 255) },
	{ Center = Vector3.new(35, 1, 45), Color = Color3.fromRGB(220, 170, 255) },
	{ Center = Vector3.new(35, 1, 75), Color = Color3.fromRGB(255, 190, 220) },
}
Config.SlotOffsets = {
	Vector3.new(-6, 0, -6),
	Vector3.new(6, 0, -6),
	Vector3.new(-6, 0, 6),
	Vector3.new(6, 0, 6),
}
Config.SlotY = 3 -- height of a brainrot's body centre when it sits in a slot

-- Base lock: how long a lock lasts, and how long before it can be used again.
Config.LockDuration = 45
Config.LockCooldown = 90

-- The tsunami wave: first warning, then the wave itself.
Config.WaveInterval = 180
Config.WaveWarningSeconds = 15
Config.WaveSpeed = 22 -- studs per second across the map
Config.WaveHalfWidth = 9 -- catching a player this far from the wave front

-- Rebirth: lifetime earnings needed, and the income bonus each rebirth gives.
Config.RebirthEarningsRequired = 50000
Config.RebirthIncomeBonus = 0.25

-- Shop upgrades: each level's cost and effect.
Config.Upgrades = {
	Speed = {
		Name = "Speed Boots",
		Description = "+2 walk speed per level",
		MaxLevel = 5,
		Cost = function(level) return 500 * (2 ^ level) end,
	},
	Income = {
		Name = "Golden Magnet",
		Description = "+10% income per level",
		MaxLevel = 5,
		Cost = function(level) return 800 * (2 ^ level) end,
	},
	Slots = {
		Name = "Extra Base Slots",
		Description = "+2 brainrot slots per level",
		MaxLevel = 3,
		Cost = function(level) return 1000 * (2 ^ level) end,
	},
}

-- Where players respawn after a wave catches them.
Config.SpawnPosition = Vector3.new(0, 4, 105)

return Config
