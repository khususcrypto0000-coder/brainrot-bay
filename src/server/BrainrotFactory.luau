-- Brainrot Bay: builds the 3D brainrot character models.
-- A brainrot is a small creature made of plain parts (no uploaded assets):
-- a body, a head, two eyes and one accent feature (ears, hat, horns or a
-- crown), plus a floating name label and a ProximityPrompt to buy or steal it.

local BrainrotFactory = {}

-- Build one brainrot model from a catalog entry and an optional mutation.
-- The model is anchored and ready to walk the belt or sit in a base slot.
function BrainrotFactory.buildBrainrotModel(entry, mutation)
	local size = entry.Size
	local bodyColor = entry.Color
	local displayName = entry.Name
	local income = entry.Income
	local cost = entry.Cost
	if mutation then
		bodyColor = mutation.Color
		displayName = mutation.Name .. " " .. entry.Name
		income = math.floor(entry.Income * mutation.Multiplier + 0.5)
		cost = math.floor(entry.Cost * mutation.Multiplier + 0.5)
	end

	local model = Instance.new("Model")
	model.Name = displayName

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3 * size, 3 * size, 3 * size)
	body.Color = bodyColor
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.2 * size, 2.2 * size, 2.2 * size)
	head.Color = bodyColor
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Position = Vector3.new(0, 2.6 * size, 0)
	head.Parent = model

	-- Two eyes on the front of the head.
	for _, xOffset in ipairs({ -0.55, 0.55 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.45 * size, 0.6 * size, 0.2 * size)
		eye.Color = Color3.fromRGB(20, 20, 20)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Anchored = true
		eye.CanCollide = false
		eye.Position = Vector3.new(xOffset * size, 2.7 * size, 1.15 * size)
		eye.Parent = model
	end

	-- One accent feature, so each character reads differently at a glance.
	local accentColor = entry.Accent
	if entry.Feature == "Ears" then
		for _, xOffset in ipairs({ -0.9, 0.9 }) do
			local ear = Instance.new("Part")
			ear.Name = "Ear"
			ear.Size = Vector3.new(0.7 * size, 1.2 * size, 0.7 * size)
			ear.Color = accentColor
			ear.Material = Enum.Material.SmoothPlastic
			ear.Anchored = true
			ear.CanCollide = false
			ear.Position = Vector3.new(xOffset * size, 4.1 * size, 0)
			ear.Parent = model
		end
	elseif entry.Feature == "Hat" then
		local hat = Instance.new("Part")
		hat.Name = "Hat"
		hat.Size = Vector3.new(3 * size, 0.5 * size, 3 * size)
		hat.Color = accentColor
		hat.Material = Enum.Material.SmoothPlastic
		hat.Anchored = true
		hat.CanCollide = false
		hat.Position = Vector3.new(0, 3.9 * size, 0)
		hat.Parent = model
	elseif entry.Feature == "Horns" then
		for _, xOffset in ipairs({ -0.9, 0.9 }) do
			local horn = Instance.new("Part")
			horn.Name = "Horn"
			horn.Size = Vector3.new(0.5 * size, 1.4 * size, 0.5 * size)
			horn.Color = accentColor
			horn.Material = Enum.Material.SmoothPlastic
			horn.Anchored = true
			horn.CanCollide = false
			horn.Position = Vector3.new(xOffset * size, 4 * size, 0)
			horn.Parent = model
		end
	elseif entry.Feature == "Crown" then
		local crown = Instance.new("Part")
		crown.Name = "Crown"
		crown.Size = Vector3.new(2.4 * size, 0.8 * size, 2.4 * size)
		crown.Color = Color3.fromRGB(255, 210, 0)
		crown.Material = Enum.Material.Neon
		crown.Anchored = true
		crown.CanCollide = false
		crown.Position = Vector3.new(0, 4 * size, 0)
		crown.Parent = model
	end

	-- Floating label: name, rarity and money per second, readable from afar.
	local label = Instance.new("BillboardGui")
	label.Name = "BrainrotLabel"
	label.Size = UDim2.fromOffset(140, 56)
	label.StudsOffsetWorldSpace = Vector3.new(0, 5.2 * size, 0)
	label.AlwaysOnTop = true
	label.Adornee = body
	label.Parent = model

	local nameText = Instance.new("TextLabel")
	nameText.Name = "NameLabel"
	nameText.Size = UDim2.fromScale(1, 0.55)
	nameText.BackgroundTransparency = 1
	nameText.Text = displayName
	nameText.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameText.TextScaled = true
	nameText.Font = Enum.Font.SourceSansBold
	nameText.TextStrokeTransparency = 0
	nameText.Parent = label

	local incomeText = Instance.new("TextLabel")
	incomeText.Name = "IncomeLabel"
	incomeText.Position = UDim2.fromScale(0, 0.55)
	incomeText.Size = UDim2.fromScale(1, 0.45)
	incomeText.BackgroundTransparency = 1
	incomeText.Text = "$" .. tostring(income) .. "/s  -  " .. entry.Rarity
	incomeText.TextColor3 = Color3.fromRGB(255, 230, 120)
	incomeText.TextScaled = true
	incomeText.Font = Enum.Font.SourceSansBold
	incomeText.TextStrokeTransparency = 0
	incomeText.Parent = label

	-- The buy / steal prompt players use to claim this brainrot.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ObjectText = displayName
	prompt.ActionText = "Buy"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	model.PrimaryPart = body
	model:SetAttribute("BrainrotName", entry.Name)
	model:SetAttribute("DisplayName", displayName)
	model:SetAttribute("Rarity", entry.Rarity)
	model:SetAttribute("Cost", cost)
	model:SetAttribute("Income", income)
	local mutationName = "Normal"
	if mutation then
		mutationName = mutation.Name
	end
	model:SetAttribute("Mutation", mutationName)
	model:SetAttribute("Owner", "")
	model:SetAttribute("Speed", entry.Speed)

	return model
end

-- Move a brainrot model so its body centre sits at the given position.
function BrainrotFactory.moveBrainrotTo(model, position)
	model:PivotTo(CFrame.new(position))
end

return BrainrotFactory
