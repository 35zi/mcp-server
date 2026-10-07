-- Run in Studio with the installed PlotService. Uses isolated fixtures, not live plots.
local service = game:GetService("ServerScriptService"):FindFirstChild("PlotService")
assert(service and service:IsA("ModuleScript"), "Install PlotService before running QA")
local prelude = [[
local fixture = Instance.new("Folder")
for i = 1, 5 do
	local realPlot = workspace:FindFirstChild("Plot" .. i)
	assert(realPlot, "Test requires Plot" .. i)
	local plot = Instance.new("Model")
	plot.Name = realPlot.Name
	realPlot.Hitbox:Clone().Parent = plot
	realPlot.SpawnPoint:Clone().Parent = plot
	plot.Parent = fixture
end
local fallback = Instance.new("SpawnLocation")
fallback.Name = "SpawnLocation"
fallback.Parent = fixture
local joined = Instance.new("BindableEvent")
local leaving = Instance.new("BindableEvent")
local playersList = {}
local mockPlayers = {
	PlayerAdded = joined.Event,
	PlayerRemoving = leaving.Event,
	GetPlayers = function() return playersList end,
}
local workspace = fixture
local game = {
	GetService = function(_, name)
		assert(name == "Players", "Unexpected service " .. name)
		return mockPlayers
	end,
}
]]
local checks = [[
PlotService.Start()
local users = {}
local seen = {}
local function user(i)
	local attrs = {}
	return {
		Name = "QAUser" .. i,
		DisplayName = "QA Display " .. i,
		UserId = -i,
		Parent = mockPlayers,
		SetAttribute = function(_, key, value) attrs[key] = value end,
		GetAttribute = function(_, key) return attrs[key] end,
	}
end
for i = 1, 6 do
	local player = user(i)
	table.insert(users, player)
	table.insert(playersList, player)
	local plot = PlotService.Assign(player)
	if i <= 5 then
		assert(plot and not seen[plot], "Two players received the same plot")
		seen[plot] = true
		assert(player.RespawnLocation == plot.SpawnPoint, "Wrong owner spawn")
		assert(plot.Hitbox.PlayerUI.Frame.Top:FindFirstChild("Name").Text == player.DisplayName, "Wrong name")
		assert(plot:GetAttribute("OwnerUserId") == player.UserId, "Wrong owner ID")
		assert(PlotService.Assign(player) == plot, "Assignment is not idempotent")
	else
		assert(plot == nil, "An occupied plot was reused")
		assert(player.RespawnLocation == fallback, "Overflow player needs central spawn")
		assert(player:GetAttribute("WaitingForPlot"), "Overflow player is not queued")
	end
end
local freed = PlotService.GetPlot(users[3])
table.remove(playersList, 3)
users[3].Parent = nil
PlotService.Release(users[3])
assert(PlotService.GetPlot(users[6]) == freed, "Waiting player did not receive released plot")
assert(users[6].RespawnLocation == freed.SpawnPoint, "Waiting player's spawn was not updated")
assert(freed.Hitbox.PlayerUI.Frame.Top:FindFirstChild("Name").Text == users[6].DisplayName, "Released plot sign is stale")
assert(not users[6]:GetAttribute("WaitingForPlot"), "Assigned player is still queued")
for _, player in ipairs(users) do
	player.Parent = nil
	PlotService.Release(player)
end
for i = 1, 5 do
	local plot = fixture:FindFirstChild("Plot" .. i)
	assert(plot:GetAttribute("OwnerUserId") == 0, "Owner was not cleared")
	assert(plot.Hitbox.PlayerUI.Frame.Top:FindFirstChild("Name").Text == "Unclaimed", "Sign was not cleared")
	assert(plot.Hitbox.PlayerUI.Frame.Top.ImageButton.Image == "", "Headshot was not cleared")
end
fixture:Destroy()
joined:Destroy()
leaving:Destroy()
return "PASS: unique assignment for five players, idempotent assignment, capacity overflow, released-plot reuse, waiting-player spawn update, and owner UI cleanup."
]]
local source, count = service.Source:gsub("return PlotService%s*$", function() return checks end)
assert(count == 1, "Could not locate PlotService return")
local testModule = Instance.new("ModuleScript")
testModule.Name = "QAPlotAllocation"
testModule.Source = prelude .. source
testModule.Parent = game:GetService("ServerScriptService")
local ok, result = pcall(require, testModule)
testModule:Destroy()
assert(ok, result)
return result
