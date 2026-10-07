-- Run once in Studio Edit mode. Keeps the existing Plot4 UI design.
local template = workspace.Plot4.Hitbox:FindFirstChild("PlayerUI")
assert(template and template:IsA("BillboardGui"), "Plot4 PlayerUI template is missing")
local plots = {}
for _, plot in ipairs(workspace:GetChildren()) do
	if plot:IsA("Model") and plot.Name:match("^Plot%d+$") then
		assert(plot:FindFirstChild("Hitbox"), plot.Name .. " has no Hitbox")
		table.insert(plots, plot)
	end
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = plots
params.RespectCanCollide = true
local report = {}
for _, plot in ipairs(plots) do
	local hitbox = plot.Hitbox
	local ui = hitbox:FindFirstChild("PlayerUI")
	if not ui then
		ui = template:Clone()
		ui.Parent = hitbox
	end
	ui.Adornee = hitbox
	ui.Enabled = true
	ui.Frame.Top:FindFirstChild("Name").Text = "Unclaimed"
	ui.Frame.Top:FindFirstChild("ImageButton").Image = ""
	local spawn = plot:FindFirstChild("SpawnPoint")
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "SpawnPoint"
		spawn.Parent = plot
	end
	assert(spawn:IsA("SpawnLocation"), plot.Name .. " SpawnPoint is not a SpawnLocation")
	local ground = workspace:Raycast(
		hitbox.Position + Vector3.new(0, hitbox.Size.Y / 2 + 2, 0),
		Vector3.new(0, -50, 0), params
	)
	local groundY = ground and ground.Position.Y or hitbox.Position.Y - hitbox.Size.Y / 2
	local position = Vector3.new(hitbox.Position.X, groundY - 0.5, hitbox.Position.Z)
	local direction = Vector3.new(-position.X, 0, -position.Z)
	if direction.Magnitude < 0.01 then direction = Vector3.new(0, 0, -1) end
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.lookAt(position, position + direction.Unit)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CastShadow = false
	spawn.Enabled = true
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("OwnerDisplayName", "")
	table.insert(report, {plot = plot.Name, ui = ui:GetFullName(), spawn = tostring(spawn.Position)})
end
return game:GetService("HttpService"):JSONEncode(report)
