-- Brainrot Bay: the client. Builds the HUD over the 3D world and asks the
-- server for things (shop upgrades, rebirth, base lock, slap). The client
-- never touches money or ownership; it only shows what the server sends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local ClientRequest = remotes:WaitForChild("ClientRequest")
local ServerUpdate = remotes:WaitForChild("ServerUpdate")

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotBayGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Top bar, kept clear of the top-left corner where Roblox puts its menus.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 8)
topBar.Size = UDim2.fromOffset(560, 44)
topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
topBar.Parent = gui

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.Position = UDim2.fromOffset(12, 0)
cashLabel.Size = UDim2.new(0.4, -12, 1, 0)
cashLabel.BackgroundTransparency = 1
cashLabel.Text = "Cash: $100"
cashLabel.TextColor3 = Color3.fromRGB(120, 255, 130)
cashLabel.TextScaled = true
cashLabel.Font = Enum.Font.SourceSansBold
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Parent = topBar

local incomeLabel = Instance.new("TextLabel")
incomeLabel.Name = "IncomeLabel"
incomeLabel.Position = UDim2.new(0.4, 0, 0, 0)
incomeLabel.Size = UDim2.new(0.35, 0, 1, 0)
incomeLabel.BackgroundTransparency = 1
incomeLabel.Text = "$0/s"
incomeLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
incomeLabel.TextScaled = true
incomeLabel.Font = Enum.Font.SourceSansBold
incomeLabel.Parent = topBar

local rebirthLabel = Instance.new("TextLabel")
rebirthLabel.Name = "RebirthLabel"
rebirthLabel.Position = UDim2.new(0.75, 0, 0, 0)
rebirthLabel.Size = UDim2.new(0.25, -12, 1, 0)
rebirthLabel.BackgroundTransparency = 1
rebirthLabel.Text = "Rebirths: 0"
rebirthLabel.TextColor3 = Color3.fromRGB(200, 160, 255)
rebirthLabel.TextScaled = true
rebirthLabel.Font = Enum.Font.SourceSansBold
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Right
rebirthLabel.Parent = topBar

-- Event banner under the top bar: wave warnings and server messages.
local banner = Instance.new("TextLabel")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 60)
banner.Size = UDim2.fromOffset(560, 36)
banner.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
banner.BackgroundTransparency = 0.35
banner.Text = "Welcome to Brainrot Bay!"
banner.TextColor3 = Color3.fromRGB(255, 255, 255)
banner.TextScaled = true
banner.Font = Enum.Font.SourceSansBold
banner.Parent = gui

local bannerUntil = 0
local function showBanner(text, seconds)
	banner.Text = text
	bannerUntil = os.clock() + (seconds or 4)
end

-- Buttons down the right side: Shop, Rebirth, Lock Base, Slap.
local function makeButton(name, text, yOffset)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -12, 0, yOffset)
	button.Size = UDim2.fromOffset(150, 40)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.SourceSansBold
	button.Parent = gui
	return button
end

local shopButton = makeButton("ShopButton", "Shop", 110)
local rebirthButton = makeButton("RebirthButton", "Rebirth", 158)
local lockButton = makeButton("LockButton", "Lock Base", 206)
local slapButton = makeButton("SlapButton", "Slap (F)", 254)

-- The shop panel: one row per upgrade, with its level and next price.
local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.AnchorPoint = Vector2.new(1, 0)
shopPanel.Position = UDim2.new(1, -12, 0, 306)
shopPanel.Size = UDim2.fromOffset(280, 190)
shopPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
shopPanel.BackgroundTransparency = 0.15
shopPanel.Visible = false
shopPanel.Parent = gui

local shopTitle = Instance.new("TextLabel")
shopTitle.Name = "ShopTitle"
shopTitle.Size = UDim2.new(1, 0, 0, 30)
shopTitle.BackgroundTransparency = 1
shopTitle.Text = "UPGRADES"
shopTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
shopTitle.TextScaled = true
shopTitle.Font = Enum.Font.SourceSansBold
shopTitle.Parent = shopPanel

local upgradeRows = {}
local rowY = 34
for _, kind in ipairs({ "Speed", "Income", "Slots" }) do
	local upgrade = Config.Upgrades[kind]
	local row = Instance.new("Frame")
	row.Name = kind .. "Row"
	row.Position = UDim2.new(0, 8, 0, rowY)
	row.Size = UDim2.new(1, -16, 0, 46)
	row.BackgroundTransparency = 1
	row.Parent = shopPanel

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "UpgradeName"
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.Size = UDim2.new(0.6, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = upgrade.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "UpgradeDescription"
	descLabel.Position = UDim2.new(0, 0, 0.55, 0)
	descLabel.Size = UDim2.new(0.6, 0, 0.45, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = upgrade.Description
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.TextScaled = true
	descLabel.Font = Enum.Font.SourceSans
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = row

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "UpgradeBuyButton"
	buyButton.Position = UDim2.new(0.62, 0, 0, 0)
	buyButton.Size = UDim2.new(0.38, 0, 1, 0)
	buyButton.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
	buyButton.Text = "Buy"
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.TextScaled = true
	buyButton.Font = Enum.Font.SourceSansBold
	buyButton.Parent = row
	buyButton.MouseButton1Click:Connect(function()
		ClientRequest:FireServer("BuyUpgrade", kind)
	end)

	upgradeRows[kind] = { BuyButton = buyButton, NameLabel = nameLabel }
	rowY += 50
end

-- A hint line at the bottom of the screen.
local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -12)
hint.Size = UDim2.fromOffset(620, 30)
hint.BackgroundTransparency = 1
hint.Text = "Walk to the belt  -  press E on a brainrot to buy it  -  guard your base!"
hint.TextColor3 = Color3.fromRGB(255, 255, 255)
hint.TextScaled = true
hint.Font = Enum.Font.SourceSans
hint.Parent = gui

local currentState = nil

shopButton.MouseButton1Click:Connect(function()
	shopPanel.Visible = not shopPanel.Visible
end)

rebirthButton.MouseButton1Click:Connect(function()
	ClientRequest:FireServer("Rebirth")
end)

lockButton.MouseButton1Click:Connect(function()
	ClientRequest:FireServer("ToggleLock")
end)

slapButton.MouseButton1Click:Connect(function()
	ClientRequest:FireServer("Slap")
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		ClientRequest:FireServer("Slap")
	end
end)

-- What the server sends us: HUD numbers, messages, wave countdown.
ServerUpdate.OnClientEvent:Connect(function(kind, payload)
	if kind == "HUD" then
		currentState = payload
		cashLabel.Text = "Cash: $" .. tostring(payload.Cash)
		incomeLabel.Text = "$" .. tostring(payload.IncomePerSecond) .. "/s"
		rebirthLabel.Text = "Rebirths: " .. tostring(payload.Rebirths)
		lockButton.Text = payload.BaseLocked and "Base Locked" or "Lock Base"
		for upgradeKind, row in pairs(upgradeRows) do
			local level = payload.Upgrades[upgradeKind] or 0
			local upgrade = Config.Upgrades[upgradeKind]
			if level >= upgrade.MaxLevel then
				row.BuyButton.Text = "MAX"
			else
				local cost = upgrade.Cost(level)
				row.BuyButton.Text = "Lv " .. tostring(level) .. "  $" .. tostring(cost)
			end
		end
		if payload.WaveIn and payload.WaveIn <= Config.WaveWarningSeconds and payload.WaveIn > 0 then
			banner.Text = "TSUNAMI IN " .. tostring(payload.WaveIn) .. "s - GET TO YOUR BASE!"
			bannerUntil = os.clock() + 1.2
		end
	elseif kind == "Notify" then
		showBanner(payload.Text, 4)
	end
end)

-- Keep the banner until its time runs out.
while true do
	task.wait(0.5)
	if bannerUntil > 0 and os.clock() > bannerUntil then
		bannerUntil = 0
		banner.Text = ""
	end
end
