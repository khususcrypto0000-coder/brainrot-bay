-- Brainrot Bay: the brainrot cast.
-- Every character is an original absurd meme creature with its own name,
-- rarity, price, money-per-second, colour and size. Rarer brainrots cost
-- more and earn more. Mutations roll on spawn and multiply the income.

local BrainrotData = {}

BrainrotData.RarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 160),
}

-- Rarity weights for the spawn roll: common faces show up most.
BrainrotData.RarityWeights = {
	Common = 45,
	Rare = 30,
	Epic = 15,
	Legendary = 7,
	Mythic = 3,
}

-- The cast, cheapest first. Size scales the whole model; Speed is how fast
-- it walks down the conveyor belt (studs per second).
BrainrotData.Catalog = {
	{ Name = "Noodle Cat", Rarity = "Common", Cost = 50, Income = 2, Size = 0.9, Speed = 7,
		Color = Color3.fromRGB(255, 220, 90), Accent = Color3.fromRGB(255, 140, 60), Feature = "Ears",
		Blurb = "A cat that is also a noodle. It purrs in carbohydrates." },
	{ Name = "Soggy Croissant", Rarity = "Common", Cost = 120, Income = 5, Size = 0.9, Speed = 7,
		Color = Color3.fromRGB(220, 170, 90), Accent = Color3.fromRGB(150, 90, 40), Feature = "Horns",
		Blurb = "Left in the rain. Still flaky. Still French." },
	{ Name = "DJ Pigeon", Rarity = "Rare", Cost = 300, Income = 12, Size = 1.0, Speed = 6,
		Color = Color3.fromRGB(120, 120, 140), Accent = Color3.fromRGB(255, 60, 120), Feature = "Hat",
		Blurb = "Drops beats and breadcrumbs at the same time." },
	{ Name = "Turbo Toilet", Rarity = "Rare", Cost = 600, Income = 25, Size = 1.1, Speed = 8,
		Color = Color3.fromRGB(240, 240, 245), Accent = Color3.fromRGB(60, 140, 255), Feature = "Hat",
		Blurb = "Flushes at 200 km/h. Do not race it." },
	{ Name = "Captain Banana Shark", Rarity = "Epic", Cost = 1200, Income = 55, Size = 1.2, Speed = 6,
		Color = Color3.fromRGB(255, 230, 80), Accent = Color3.fromRGB(90, 140, 255), Feature = "Horns",
		Blurb = "Half banana, half shark, all captain." },
	{ Name = "Professor Pickle", Rarity = "Epic", Cost = 2500, Income = 120, Size = 1.0, Speed = 5,
		Color = Color3.fromRGB(90, 200, 90), Accent = Color3.fromRGB(40, 40, 40), Feature = "Hat",
		Blurb = "Holds a PhD in being pickled. Lectures nightly." },
	{ Name = "Sir Barksalot III", Rarity = "Legendary", Cost = 6000, Income = 300, Size = 1.3, Speed = 5,
		Color = Color3.fromRGB(180, 130, 70), Accent = Color3.fromRGB(30, 30, 30), Feature = "Crown",
		Blurb = "A very good boy of noble blood. Barks in Latin." },
	{ Name = "Quantum Toaster", Rarity = "Legendary", Cost = 12000, Income = 650, Size = 1.2, Speed = 6,
		Color = Color3.fromRGB(200, 200, 210), Accent = Color3.fromRGB(255, 100, 0), Feature = "Crown",
		Blurb = "Toasts bread in two timelines at once." },
	{ Name = "The Grand Noodler", Rarity = "Mythic", Cost = 30000, Income = 1800, Size = 1.5, Speed = 4,
		Color = Color3.fromRGB(255, 120, 200), Accent = Color3.fromRGB(255, 220, 0), Feature = "Crown",
		Blurb = "Ancient noodle wizard. Noodles the fabric of reality." },
	{ Name = "Galactic Giraffe", Rarity = "Mythic", Cost = 75000, Income = 5000, Size = 1.6, Speed = 4,
		Color = Color3.fromRGB(140, 90, 220), Accent = Color3.fromRGB(255, 255, 255), Feature = "Horns",
		Blurb = "Its neck reaches orbit. Its spots are constellations." },
}

-- Mutations: rolled on spawn. A mutated brainrot earns more and costs more.
BrainrotData.Mutations = {
	{ Name = "Golden", Chance = 0.08, Multiplier = 2, Color = Color3.fromRGB(255, 200, 0) },
	{ Name = "Rainbow", Chance = 0.03, Multiplier = 5, Color = Color3.fromRGB(255, 80, 200) },
	{ Name = "Diamond", Chance = 0.015, Multiplier = 10, Color = Color3.fromRGB(180, 240, 255) },
	{ Name = "Cursed", Chance = 0.05, Multiplier = 0.5, Color = Color3.fromRGB(90, 200, 90) },
}

-- Roll one mutation (or none) for a newly spawned brainrot.
function BrainrotData.rollMutation()
	local roll = math.random()
	local running = 0
	for _, mutation in ipairs(BrainrotData.Mutations) do
		running += mutation.Chance
		if roll <= running then
			return mutation
		end
	end
	return nil
end

-- Pick a random catalog entry, weighted so common faces show up most.
function BrainrotData.rollEntry()
	local pool = {}
	for _, entry in ipairs(BrainrotData.Catalog) do
		local weight = BrainrotData.RarityWeights[entry.Rarity] or 1
		for _ = 1, weight do
			table.insert(pool, entry)
		end
	end
	return pool[math.random(1, #pool)]
end

-- Pick a random entry of at least the given rarity (used for wave bonuses).
function BrainrotData.rollEntryAtLeast(rarity)
	local order = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
	local minIndex = 1
	for i, name in ipairs(order) do
		if name == rarity then
			minIndex = i
		end
	end
	local pool = {}
	for _, entry in ipairs(BrainrotData.Catalog) do
		for i, name in ipairs(order) do
			if name == entry.Rarity and i >= minIndex then
				table.insert(pool, entry)
			end
		end
	end
	return pool[math.random(1, #pool)]
end

function BrainrotData.getByName(name)
	for _, entry in ipairs(BrainrotData.Catalog) do
		if entry.Name == name then
			return entry
		end
	end
	return nil
end

return BrainrotData
