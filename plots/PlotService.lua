-- Server-owned plot assignment and owner signs.
local Players = game:GetService("Players")
local PlotService = {}
local plots = {}
local assigned = {}
local owners = {}
local characterConnections = {}
local waiting = {}
local started = false
local fallbackSpawn

local function uiParts(plot)
	local ui = plot.Hitbox.PlayerUI
	local top = ui.Frame.Top
	return top:FindFirstChild("Name"), top:FindFirstChild("ImageButton")
end

local function clearSign(plot)
	local label, image = uiParts(plot)
	label.Text = "Unclaimed"
	image.Image = ""
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("OwnerDisplayName", "")
end

local function updateSign(plot, player)
	local label, image = uiParts(plot)
	label.Text = player.DisplayName
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("OwnerName", player.Name)
	plot:SetAttribute("OwnerDisplayName", player.DisplayName)
	image.Image = ""
	if player.UserId <= 0 then
		-- Studio's simulated users do not have a Roblox avatar thumbnail.
		return
	end
	image.Image = string.format(
		"rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420", player.UserId
	)
	task.spawn(function()
		for attempt = 1, 4 do
			if owners[plot] ~= player or player.Parent ~= Players then
				return
			end
			local ok, content, ready = pcall(function()
				return Players:GetUserThumbnailAsync(
					player.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size420x420
				)
			end)
			-- A request can finish after the owner leaves. Never overwrite a new owner's sign.
			if owners[plot] ~= player or player.Parent ~= Players then
				return
			end
			if ok and ready and content ~= "" then
				image.Image = content
				return
			end
			if attempt < 4 then
				task.wait(2)
			end
		end
	end)
end

local function placeCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not root or not humanoid or player.Character ~= character then
		return
	end
	local plot = assigned[player]
	local spawn = plot and plot:FindFirstChild("SpawnPoint") or fallbackSpawn
	if not spawn or not spawn.Parent or humanoid.Health <= 0 then
		return
	end
	local height = spawn.Size.Y / 2 + humanoid.HipHeight + root.Size.Y / 2 + 0.5
	-- Move the root to the spawn without depending on the model's pivot offset.
	local targetRoot = spawn.CFrame + Vector3.new(0, height, 0)
	character:PivotTo(targetRoot * root.CFrame:ToObjectSpace(character:GetPivot()))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

function PlotService.GetPlot(player)
	return assigned[player]
end

function PlotService.Assign(player)
	assert(started, "PlotService.Start must be called first")
	if assigned[player] then
		return assigned[player]
	end
	for _, plot in ipairs(plots) do
		if not owners[plot] then
			-- Reserve synchronously before any thumbnail request or character wait.
			owners[plot] = player
			assigned[player] = plot
			waiting[player] = nil
			player.RespawnLocation = plot.SpawnPoint
			player:SetAttribute("PlotName", plot.Name)
			player:SetAttribute("PlotId", tonumber(plot.Name:match("%d+$")))
			player:SetAttribute("WaitingForPlot", false)
			updateSign(plot, player)
			if player.Character then
				task.spawn(placeCharacter, player, player.Character)
			end
			return plot
		end
	end
	waiting[player] = true
	player.RespawnLocation = fallbackSpawn
	player:SetAttribute("PlotName", "")
	player:SetAttribute("PlotId", nil)
	player:SetAttribute("WaitingForPlot", true)
	return nil
end

function PlotService.Release(player)
	waiting[player] = nil
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
	local plot = assigned[player]
	assigned[player] = nil
	if plot and owners[plot] == player then
		owners[plot] = nil
		clearSign(plot)
	end
	player.RespawnLocation = fallbackSpawn
	player:SetAttribute("PlotName", "")
	player:SetAttribute("PlotId", nil)
	player:SetAttribute("WaitingForPlot", false)
	-- Reuse the free plot for a connected player who was waiting.
	if plot then
		for _, candidate in ipairs(Players:GetPlayers()) do
			if candidate ~= player and waiting[candidate] then
				PlotService.Assign(candidate)
				break
			end
		end
	end
end

local function playerAdded(player)
	if characterConnections[player] then
		return
	end
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		placeCharacter(player, character)
	end)
	PlotService.Assign(player)
end

function PlotService.Start()
	if started then
		return
	end
	fallbackSpawn = workspace:FindFirstChild("SpawnLocation")
	assert(fallbackSpawn and fallbackSpawn:IsA("SpawnLocation"), "Central SpawnLocation is missing")
	for _, plot in ipairs(workspace:GetChildren()) do
		if plot:IsA("Model") and plot.Name:match("^Plot%d+$") then
			assert(plot:FindFirstChild("Hitbox"), plot.Name .. " is missing Hitbox")
			assert(plot.Hitbox:FindFirstChild("PlayerUI"), plot.Name .. " is missing PlayerUI")
			assert(plot:FindFirstChild("SpawnPoint"), plot.Name .. " is missing SpawnPoint")
			local label, image = uiParts(plot)
			assert(label and label:IsA("TextLabel"), plot.Name .. " is missing the name label")
			assert(image and image:IsA("ImageButton"), plot.Name .. " is missing the headshot button")
			table.insert(plots, plot)
		end
	end
	table.sort(plots, function(a, b)
		return tonumber(a.Name:match("%d+$")) < tonumber(b.Name:match("%d+$"))
	end)
	assert(#plots > 0, "No plots found")
	for _, plot in ipairs(plots) do
		clearSign(plot)
	end
	started = true
	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(PlotService.Release)
	for _, player in ipairs(Players:GetPlayers()) do
		playerAdded(player)
	end
end

return PlotService
