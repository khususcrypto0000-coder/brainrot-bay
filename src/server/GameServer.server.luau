-- Brainrot Bay: the server. One script runs the whole game loop.
-- Brainrots spawn and walk the conveyor belt, players buy them into their
-- base, every owned brainrot earns money per second, other players can
-- steal from an unlocked base, and a tsunami wave sweeps the map on a timer.
-- All money, ownership and progression live here on the server; the client
-- only asks for things, and this script checks every request.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local BrainrotFactory = require(script.Parent:WaitForChild("BrainrotFactory"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

-- Remotes: ClientRequest (client asks) and ServerUpdate (server tells).
local remotes = Instance.new("Folder")
remotes.Name = "BrainrotRemotes"
remotes.Parent = ReplicatedStorage
local ClientRequest = Instance.new("RemoteEvent")
ClientRequest.Name = "ClientRequest"
ClientRequest.Parent = remotes
local ServerUpdate = Instance.new("RemoteEvent")
ServerUpdate.Name = "ServerUpdate"
ServerUpdate.Parent = remotes

local BrainrotsFolder = Instance.new("Folder")
BrainrotsFolder.Name = "Brainrots"
BrainrotsFolder.Parent = Workspace

local states = {} -- Player -> PlayerData state
local bases = {} -- base index -> { Owners = {Player,...}, Slots = {model or nil} }
for i = 1, #Config.Bases do
	bases[i] = { Owners = {}, Slots = { nil, nil, nil, nil } }
end
local walking = {} -- { Model = model, Speed = number }
local nextWaveIn = Config.WaveInterval
local waveRunning = false

-- Send one update to one player, or to everyone when player is nil.
local function sendUpdate(player, kind, payload)
	if player then
		ServerUpdate:FireClient(player, kind, payload)
	else
		ServerUpdate:FireAllClients(kind, payload)
	end
end

local function notify(player, text)
	sendUpdate(player, "Notify", { Text = text })
end

local function stateFor(player)
	return states[player]
end

-- The HUD numbers one player needs: cash, income, rebirths, slots, upgrades.
local function sendHudUpdate(player)
	local state = states[player]
	if not state then
		return
	end
	sendUpdate(player, "HUD", {
		Cash = math.floor(state.Cash),
		IncomePerSecond = PlayerData.incomePerSecond(state),
		Rebirths = state.Rebirths,
		OwnedCount = #state.Owned,
		MaxSlots = PlayerData.maxSlots(state),
		WalkSpeed = PlayerData.walkSpeed(state),
		Upgrades = state.Upgrades,
		BaseLocked = PlayerData.isBaseLocked(state, os.clock()),
		WaveIn = math.floor(nextWaveIn + 0.5),
	})
end

-- The sign above a base: who owns it, and whether it is locked.
local function updateBaseSign(baseIndex)
	local board = Workspace:FindFirstChild("Sign" .. tostring(baseIndex))
	if not board then
		return
	end
	local gui = board:FindFirstChild("BaseSignGui")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "BaseSignGui"
		gui.Size = UDim2.fromOffset(220, 70)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = board
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Name = "SignText"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.3
		label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.Parent = gui
	end
	local base = bases[baseIndex]
	local names = {}
	for _, owner in ipairs(base.Owners) do
		table.insert(names, owner.Name)
	end
	local ownerText = "Empty Base"
	if #names > 0 then
		ownerText = table.concat(names, " & ") .. "'s Base"
	end
	local lockText = ""
	for _, owner in ipairs(base.Owners) do
		local ownerState = states[owner]
		if ownerState and PlayerData.isBaseLocked(ownerState, os.clock()) then
			lockText = "  [LOCKED]"
			break
		end
	end
	gui.SignText.Text = "Base " .. tostring(baseIndex) .. "\n" .. ownerText .. lockText
end

-- The little light on a base: green when open, red when locked.
local function updateLockLight(baseIndex)
	local light = Workspace:FindFirstChild("LockLight" .. tostring(baseIndex))
	if not light then
		return
	end
	local locked = false
	for _, owner in ipairs(bases[baseIndex].Owners) do
		local ownerState = states[owner]
		if ownerState and PlayerData.isBaseLocked(ownerState, os.clock()) then
			locked = true
		end
	end
	light.Color = locked and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(80, 255, 120)
end

local function updateBaseDisplays(baseIndex)
	updateBaseSign(baseIndex)
	updateLockLight(baseIndex)
end

-- Give a joining player the emptiest base (bases are shared when full).
local function assignBase(player)
	local bestIndex = 1
	local bestCount = math.huge
	for i, base in ipairs(bases) do
		if #base.Owners < bestCount then
			bestCount = #base.Owners
			bestIndex = i
		end
	end
	table.insert(bases[bestIndex].Owners, player)
	return bestIndex
end

-- First free slot position on a player's base, or nil when it is full.
local function findFreeSlot(baseIndex)
	local base = bases[baseIndex]
	for slotIndex = 1, 4 do
		if base.Slots[slotIndex] == nil then
			local center = Config.Bases[baseIndex].Center
			local offset = Config.SlotOffsets[slotIndex]
			return slotIndex, Vector3.new(center.X + offset.X, Config.SlotY, center.Z + offset.Z)
		end
	end
	return nil, nil
end

-- Place a bought brainrot into a slot and mark it owned.
local function placeBrainrotInBase(model, ownerPlayer, baseIndex, slotIndex, position)
	local base = bases[baseIndex]
	base.Slots[slotIndex] = model
	model:SetAttribute("Owner", ownerPlayer.Name)
	local prompt = model:FindFirstChild("Body") and model.Body:FindFirstChild("BuyPrompt")
	if prompt then
		prompt.ActionText = "Steal"
		prompt.HoldDuration = 2
	end
	BrainrotFactory.moveBrainrotTo(model, position)
end

-- A brainrot leaves its slot (sold by rebirth, or stolen away).
local function removeBrainrotFromSlot(model, baseIndex)
	local base = bases[baseIndex]
	for slotIndex = 1, 4 do
		if base.Slots[slotIndex] == model then
			base.Slots[slotIndex] = nil
		end
	end
end

local function findStateByName(name)
	for player, state in pairs(states) do
		if player.Name == name then
			return state
		end
	end
	return nil
end

-- Buy a walking brainrot: cash and a free slot, then it moves to your base.
local function buyBrainrot(player, model)
	local state = states[player]
	if not state then
		return
	end
	if model:GetAttribute("Owner") ~= "" then
		notify(player, "That brainrot already has an owner!")
		return
	end
	local cost = model:GetAttribute("Cost") or 0
	if state.Cash < cost then
		notify(player, "Not enough cash! You need $" .. tostring(cost) .. ".")
		return
	end
	local slotIndex, position = findFreeSlot(state.BaseIndex)
	if not slotIndex then
		notify(player, "Your base is full! Buy more slots in the Shop.")
		return
	end
	state.Cash -= cost
	for i, walkingEntry in ipairs(walking) do
		if walkingEntry.Model == model then
			table.remove(walking, i)
			break
		end
	end
	table.insert(state.Owned, model)
	placeBrainrotInBase(model, player, state.BaseIndex, slotIndex, position)
	notify(player, "You bought " .. model:GetAttribute("DisplayName") .. " for $" .. tostring(cost) .. "!")
	sendHudUpdate(player)
end

-- Steal a brainrot from another player's base, if it is not locked.
local function stealBrainrot(player, model)
	local state = states[player]
	if not state then
		return
	end
	local ownerName = model:GetAttribute("Owner") or ""
	if ownerName == "" then
		buyBrainrot(player, model)
		return
	end
	if ownerName == player.Name then
		notify(player, "That brainrot is already yours!")
		return
	end
	local ownerState = findStateByName(ownerName)
	if ownerState and PlayerData.isBaseLocked(ownerState, os.clock()) then
		notify(player, ownerName .. "'s base is LOCKED. Come back later!")
		return
	end
	local slotIndex, position = findFreeSlot(state.BaseIndex)
	if not slotIndex then
		notify(player, "Your base is full! Buy more slots in the Shop.")
		return
	end
	if ownerState then
		for i, owned in ipairs(ownerState.Owned) do
			if owned == model then
				table.remove(ownerState.Owned, i)
				break
			end
		end
		removeBrainrotFromSlot(model, ownerState.BaseIndex)
		notify(ownerState.Player, player.Name .. " stole your " .. model:GetAttribute("DisplayName") .. "!")
		sendHudUpdate(ownerState.Player)
	end
	table.insert(state.Owned, model)
	placeBrainrotInBase(model, player, state.BaseIndex, slotIndex, position)
	notify(player, "You stole " .. model:GetAttribute("DisplayName") .. " from " .. ownerName .. "!")
	sendHudUpdate(player)
end

-- Hook a brainrot's prompt up to the buy / steal logic.
local function connectBrainrotPrompt(model)
	local body = model:FindFirstChild("Body")
	if not body then
		return
	end
	local prompt = body:FindFirstChild("BuyPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		if model:GetAttribute("Owner") == "" then
			buyBrainrot(player, model)
		else
			stealBrainrot(player, model)
		end
	end)
end

-- Spawn one brainrot at the start of the belt and let it walk.
local function spawnBrainrot(entry, mutation)
	entry = entry or BrainrotData.rollEntry()
	mutation = mutation or BrainrotData.rollMutation()
	local model = BrainrotFactory.buildBrainrotModel(entry, mutation)
	BrainrotFactory.moveBrainrotTo(model, Vector3.new(Config.Belt.X, Config.Belt.WalkY, Config.Belt.ZStart))
	model.Parent = BrainrotsFolder
	connectBrainrotPrompt(model)
	table.insert(walking, { Model = model, Speed = entry.Speed })
	return model
end

-- Every second: each owned brainrot pays its owner, and the HUD refreshes.
local function collectIncomePerSecond()
	while true do
		task.wait(1)
		for player, state in pairs(states) do
			local income = PlayerData.incomePerSecond(state)
			if income > 0 then
				state.Cash += income
				state.TotalEarned += income
			end
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local cashValue = leaderstats:FindFirstChild("Cash")
				if cashValue then
					cashValue.Value = math.floor(state.Cash)
				end
			end
			sendHudUpdate(player)
		end
		if nextWaveIn > 0 then
			nextWaveIn -= 1
			if nextWaveIn == Config.WaveWarningSeconds then
				sendUpdate(nil, "Notify", { Text = "TSUNAMI INCOMING! Get to your base in 15 seconds!" })
			end
		end
	end
end

-- Move the walking brainrots down the belt; despawn the ones that reach the end.
local function moveWalkingBrainrots(dt)
	for i = #walking, 1, -1 do
		local entry = walking[i]
		local model = entry.Model
		if not model.Parent then
			table.remove(walking, i)
		else
			local position = model:GetPivot().Position
			local newZ = position.Z + entry.Speed * dt
			if newZ >= Config.Belt.ZEnd then
				model:Destroy()
				table.remove(walking, i)
			else
				BrainrotFactory.moveBrainrotTo(model, Vector3.new(Config.Belt.X, Config.Belt.WalkY, newZ))
			end
		end
	end
end

-- The tsunami wave: a wall of water sweeps the map and throws players home.
local function runTsunamiWave()
	waveRunning = true
	sendUpdate(nil, "Notify", { Text = "THE BRAINROT TSUNAMI IS HERE! RUN TO YOUR BASE!" })
	local wave = Instance.new("Part")
	wave.Name = "TsunamiWave"
	wave.Size = Vector3.new(16, 40, 220)
	wave.Color = Color3.fromRGB(40, 140, 255)
	wave.Material = Enum.Material.Neon
	wave.Transparency = 0.45
	wave.Anchored = true
	wave.CanCollide = false
	wave.Position = Vector3.new(-130, 10, 0)
	wave.Parent = Workspace

	-- A rare brainrot rides the wave: a bonus for whoever grabs it after.
	local bonus = spawnBrainrot(BrainrotData.rollEntryAtLeast("Legendary"), nil)

	local caught = {}
	local waveX = -130
	while waveX < 130 do
		task.wait(0.1)
		waveX += Config.WaveSpeed * 0.1
		wave.Position = Vector3.new(waveX, 10, 0)
		for player, _ in pairs(states) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and not caught[player] then
				local distance = math.abs(root.Position.X - waveX)
				if distance < Config.WaveHalfWidth + 2 and math.abs(root.Position.Z) < 110 then
					caught[player] = true
					root.CFrame = CFrame.new(Config.SpawnPosition)
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.WalkSpeed = 8
						task.delay(3, function()
							local state = states[player]
							if state and humanoid.Parent then
								humanoid.WalkSpeed = PlayerData.walkSpeed(state)
							end
						end)
					end
					notify(player, "The wave caught you! Back to spawn you go.")
				end
			end
		end
	end
	wave:Destroy()
	waveRunning = false
	nextWaveIn = Config.WaveInterval
	if bonus and bonus.Parent then
		notify(nil, "A " .. (bonus:GetAttribute("DisplayName") or "rare brainrot") .. " rode in on the wave!")
	end
end

-- Keep spawning brainrots, and run the wave on its timer.
local function spawnLoop()
	while true do
		task.wait(Config.SpawnInterval)
		if #walking < Config.MaxWalking then
			spawnBrainrot(nil, nil)
		end
		if nextWaveIn <= 0 and not waveRunning then
			runTsunamiWave()
		end
	end
end

-- A player buys a shop upgrade.
local function buyUpgrade(player, kind)
	local state = states[player]
	if not state then
		return
	end
	local level = state.Upgrades[kind]
	if level == nil then
		return
	end
	local cost = PlayerData.upgradeCost(kind, level)
	if not cost then
		notify(player, "That upgrade is already maxed out!")
		return
	end
	if state.Cash < cost then
		notify(player, "Not enough cash! You need $" .. tostring(cost) .. ".")
		return
	end
	state.Cash -= cost
	state.Upgrades[kind] = level + 1
	local upgrade = Config.Upgrades[kind]
	notify(player, "Bought " .. upgrade.Name .. " level " .. tostring(level + 1) .. "!")
	if kind == "Speed" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = PlayerData.walkSpeed(state)
		end
	end
	sendHudUpdate(player)
end

-- Rebirth: trade everything for a permanent income boost.
local function applyRebirth(player)
	local state = states[player]
	if not state then
		return
	end
	if state.TotalEarned < Config.RebirthEarningsRequired then
		notify(player, "Rebirth needs $" .. tostring(Config.RebirthEarningsRequired) .. " earned in total. You have $" .. tostring(math.floor(state.TotalEarned)) .. ".")
		return
	end
	for _, model in ipairs(state.Owned) do
		removeBrainrotFromSlot(model, state.BaseIndex)
		model:Destroy()
	end
	state.Owned = {}
	state.Cash = Config.StartCash
	state.TotalEarned = 0
	state.Upgrades = { Speed = 0, Income = 0, Slots = 0 }
	state.Rebirths += 1
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirthsValue = leaderstats:FindFirstChild("Rebirths")
		if rebirthsValue then
			rebirthsValue.Value = state.Rebirths
		end
		local cashValue = leaderstats:FindFirstChild("Cash")
		if cashValue then
			cashValue.Value = math.floor(state.Cash)
		end
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = PlayerData.walkSpeed(state)
	end
	notify(player, "REBIRTH! You now earn +" .. tostring(state.Rebirths * 25) .. "% income forever.")
	sendHudUpdate(player)
end

-- Lock your base against stealing for a while.
local function toggleBaseLock(player)
	local state = states[player]
	if not state then
		return
	end
	local now = os.clock()
	if now < state.LockCooldownUntil then
		notify(player, "Base lock is on cooldown for " .. tostring(math.floor(state.LockCooldownUntil - now)) .. " more seconds.")
		return
	end
	state.LockUntil = now + Config.LockDuration
	state.LockCooldownUntil = now + Config.LockDuration + Config.LockCooldown
	updateBaseDisplays(state.BaseIndex)
	notify(player, "Base LOCKED for " .. tostring(Config.LockDuration) .. " seconds!")
	sendHudUpdate(player)
end

-- Slap: shove nearby players away from you.
local function slapNearbyPlayers(player)
	local state = states[player]
	if not state then
		return
	end
	local now = os.clock()
	if now < state.SlapCooldownUntil then
		return
	end
	state.SlapCooldownUntil = now + 2
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for otherPlayer, _ in pairs(states) do
		if otherPlayer ~= player then
			local otherCharacter = otherPlayer.Character
			local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				if offset.Magnitude < 14 and offset.Magnitude > 0.1 then
					local direction = offset.Unit
					otherRoot.AssemblyLinearVelocity = direction * 45 + Vector3.new(0, 25, 0)
					notify(otherPlayer, player.Name .. " slapped you!")
				end
			end
		end
	end
end

ClientRequest.OnServerEvent:Connect(function(player, action, arg)
	if action == "BuyUpgrade" then
		buyUpgrade(player, arg)
	elseif action == "Rebirth" then
		applyRebirth(player)
	elseif action == "ToggleLock" then
		toggleBaseLock(player)
	elseif action == "Slap" then
		slapNearbyPlayers(player)
	end
end)

local function onPlayerAdded(player)
	local state = PlayerData.newState(player)
	states[player] = state
	state.BaseIndex = assignBase(player)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = Config.StartCash
	cashValue.Parent = leaderstats
	local rebirthsValue = Instance.new("IntValue")
	rebirthsValue.Name = "Rebirths"
	rebirthsValue.Value = 0
	rebirthsValue.Parent = leaderstats

	updateBaseDisplays(state.BaseIndex)
	sendHudUpdate(player)
	notify(player, "Welcome to Brainrot Bay! Walk to the belt, buy a brainrot, bring it home!")

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = PlayerData.walkSpeed(state)
	end)
end

local function onPlayerRemoving(player)
	local state = states[player]
	if not state then
		return
	end
	for _, model in ipairs(state.Owned) do
		removeBrainrotFromSlot(model, state.BaseIndex)
		model:Destroy()
	end
	for i, owner in ipairs(bases[state.BaseIndex].Owners) do
		if owner == player then
			table.remove(bases[state.BaseIndex].Owners, i)
			break
		end
	end
	states[player] = nil
	updateBaseDisplays(state.BaseIndex)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Warm up the belt so the first players see brainrots right away.
spawnBrainrot(nil, nil)
spawnBrainrot(nil, nil)
spawnBrainrot(nil, nil)

RunService.Heartbeat:Connect(moveWalkingBrainrots)
task.spawn(collectIncomePerSecond)
task.spawn(spawnLoop)
