-- SpeedService (Script in ServerScriptService)
--
-- Speed stat, treadmills and trails (numbers in ReplicatedStorage.SpeedData).
--   * leaderstats.Stamina goes up every second while you stand on the treadmill of YOUR plot (the belt area above
--     Workspace.Treadmills.<PlotName>.Spot, see SpeedData.OnBelt; the treadmill itself is drawn by SpeedClient);
--     how much = your treadmill tier's rate x your equipped trail's gain.
--   * Player attributes: TreadmillTier (1..), OwnedTrails ("Blue,Toxic"), EquippedTrail, OnTreadmill (= PlotName
--     while training, so other clients show that treadmill).
--   * ReplicatedStorage.SpeedRemote (RemoteFunction): "BuyTrail" id / "EquipTrail" id / "Unequip" / "UpgradeTreadmill".
--   * ReplicatedStorage.SpeedEvent (RemoteEvent, server -> client): "Gain" {amount, total, tier},
--     "Upgraded" {tier}, "Bought" {id}, "Notice" {text}. Upgrading is the green button on the sign by your treadmill.
-- Money goes through CashAdapter. Nothing is saved yet (same as Cash).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local SpeedData = require(ReplicatedStorage:WaitForChild("SpeedData"))
local CashAdapter = require(ServerScriptService:WaitForChild("CashAdapter"))

local function remoteOf(class, name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local remote = remoteOf("RemoteFunction", "SpeedRemote")
local event = remoteOf("RemoteEvent", "SpeedEvent")
local treadmills = workspace:WaitForChild("Treadmills")

local GAIN_EVERY = 0.25 -- seconds between Speed payouts while running (4 small payouts a second: lots of +N pops)
local pending = {} -- player -> Speed earned but not paid out yet (fractions)
local lastPay = {}
local lastAsk = {}

---------------------------------------------------------------- player data
local function speedValue(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Stamina")
end

local function owned(player)
	local set = {}
	for id in string.gmatch(player:GetAttribute("OwnedTrails") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

-- the equipped trail: a Trail between two attachments on the HumanoidRootPart (everyone sees it)
local function applyTrail(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, name in ipairs({ "SpeedTrail", "SpeedTrailTop", "SpeedTrailBottom" }) do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local trail = SpeedData.Trail(player:GetAttribute("EquippedTrail") or "")
	if not trail then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "SpeedTrailTop"
	top.Position = Vector3.new(0, 0.9, 0.35)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "SpeedTrailBottom"
	bottom.Position = Vector3.new(0, -1.1, 0.35)
	bottom.Parent = root
	local t = Instance.new("Trail")
	t.Name = "SpeedTrail"
	t.Attachment0 = top
	t.Attachment1 = bottom
	t.Color = SpeedData.ColorSequence(SpeedData.TrailColors(trail))
	t.Lifetime = 0.55
	t.MinLength = 0.05
	t.LightEmission = 0.5
	t.LightInfluence = 0.3
	t.FaceCamera = true
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	t.Parent = root
end

local function setup(player)
	CashAdapter.Setup(player)
	local stats = player:WaitForChild("leaderstats")
	if not stats:FindFirstChild("Stamina") then
		local v = Instance.new("IntValue")
		v.Name = "Stamina" -- the treadmill stat (was called Speed)
		v.Value = 0
		v.Parent = stats
	end
	if not player:GetAttribute("TreadmillTier") then
		player:SetAttribute("TreadmillTier", 1)
	end
	if player:GetAttribute("OwnedTrails") == nil then
		player:SetAttribute("OwnedTrails", "")
	end
	if player:GetAttribute("EquippedTrail") == nil then
		player:SetAttribute("EquippedTrail", "")
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		applyTrail(player)
	end)
	if player.Character then
		applyTrail(player)
	end
end

Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(setup, p)
end
Players.PlayerRemoving:Connect(function(player)
	pending[player], lastPay[player], lastAsk[player] = nil, nil, nil
end)

---------------------------------------------------------------- actions
local function upgrade(player)
	local tier = player:GetAttribute("TreadmillTier") or 1
	local nextTier = SpeedData.Treadmills[tier + 1]
	if not nextTier then
		return false, "Your treadmill is already MAX!"
	end
	if not CashAdapter.Spend(player, nextTier.price) then
		return false, string.format("You need $%s to upgrade.", SpeedData.Commas(nextTier.price))
	end
	player:SetAttribute("TreadmillTier", tier + 1)
	event:FireClient(player, "Upgraded", { tier = tier + 1 })
	return true, string.format("Treadmill upgraded to %s!", nextTier.name)
end

local actions = {}
function actions.BuyTrail(player, id)
	local trail = SpeedData.Trail(id)
	if not trail then
		return false, "Unknown trail."
	end
	if owned(player)[id] then
		return false, "You already own this trail."
	end
	if not CashAdapter.Spend(player, trail.price) then
		return false, string.format("You need $%s.", SpeedData.Commas(trail.price))
	end
	local list = player:GetAttribute("OwnedTrails") or ""
	player:SetAttribute("OwnedTrails", list == "" and id or (list .. "," .. id))
	player:SetAttribute("EquippedTrail", id)
	applyTrail(player)
	event:FireClient(player, "Bought", { id = id })
	return true, trail.name .. " unlocked!"
end
function actions.EquipTrail(player, id)
	if not owned(player)[id] then
		return false, "Buy this trail first."
	end
	player:SetAttribute("EquippedTrail", id)
	applyTrail(player)
	return true, SpeedData.Trail(id).name .. " equipped!"
end
function actions.Unequip(player)
	player:SetAttribute("EquippedTrail", "")
	applyTrail(player)
	return true, "Trail unequipped."
end
function actions.UpgradeTreadmill(player)
	return upgrade(player)
end

remote.OnServerInvoke = function(player, action, arg)
	local now = os.clock()
	if now - (lastAsk[player] or 0) < 0.25 then
		return false, "Slow down!"
	end
	lastAsk[player] = now
	local f = type(action) == "string" and actions[action]
	if not f then
		return false, "Unknown action."
	end
	return f(player, arg)
end

---------------------------------------------------------------- running (only on your own plot's treadmill)
local function ownSpot(player)
	local plotName = player:GetAttribute("PlotName")
	local plot = type(plotName) == "string" and workspace:FindFirstChild(plotName)
	if not plot or plot:GetAttribute("OwnerUserId") ~= player.UserId then
		return nil
	end
	local tm = treadmills:FindFirstChild(plotName)
	local spot = tm and tm:FindFirstChild("Spot")
	return spot and tm, spot
end

local function onBelt(player, root)
	local tm, spot = ownSpot(player)
	if tm and SpeedData.OnBelt(spot.CFrame, root.Position, 0.5) then
		return tm
	end
	return nil
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then
		return
	end
	local step = acc
	acc = 0
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local tm = root and humanoid and humanoid.Health > 0 and not player:GetAttribute("Carrying") and onBelt(player, root)
		player:SetAttribute("OnTreadmill", tm and tm.Name or nil)
		if tm then
			local tier = player:GetAttribute("TreadmillTier") or 1
			pending[player] = (pending[player] or 0) + SpeedData.Gain(tier, player:GetAttribute("EquippedTrail")) * step
			if now - (lastPay[player] or 0) >= GAIN_EVERY then
				lastPay[player] = now
				local amount = math.floor(pending[player])
				local value = speedValue(player)
				if amount > 0 and value then
					pending[player] -= amount
					value.Value += amount
					event:FireClient(player, "Gain", { amount = amount, total = value.Value, tier = tier })
				end
			end
		else
			pending[player] = nil
			lastPay[player] = now -- first payout one second after stepping on
		end
	end
end)
