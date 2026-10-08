-- SetupGameWorld (run in Studio's command bar / via MCP, edit mode; safe to re-run)
--
-- The non-script pieces the animal + weapon systems need, so the place can be rebuilt from this repo:
--   * ReplicatedStorage.GameAudio          the game's sounds (licensed Roblox ProSoundEffects + one built-in),
--                                           each trimmed with a PlaybackRegion to the useful slice
--   * ServerStorage.AnimalTemplates        the animal models, moved out of the world and kept intact:
--                                           scripts removed, PrimaryPart = Body / <Species>_Body (front = -Z)
--   * Workspace.AnimalSpawnZones.Zone1     invisible box over the green area past the red line; animals spawn and
--                                           wander only inside the zones (resize it or add more Parts in Studio)
-- The gun models / Tools are set up by models/weaponshop/BuildWeapons.lua.
local CHS = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local rec = CHS:TryBeginRecording("Setup game world")
local out = {}

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

---------------------------------------------------------------- sounds
-- { name, id, volume, playback speed, region start, region end }
local SOUNDS = {
	{ "Fire", "rbxassetid://9117402631", 0.9, 1.0, 0, 1.1 }, -- .45 pistol single shot
	{ "Cock", "rbxassetid://9120407333", 0.7, 1.0, 0.36, 0.72 }, -- metallic click-clack (hammer, pump, bolt)
	{ "HitTick", "rbxassetid://9113728756", 0.6, 1.4, 0, 0.15 }, -- crisp click (hit confirmation)
	{ "Impact", "rbxasset://sounds/action_jump_land.mp3", 0.5, 1.5 }, -- built-in thud (bullet hits the world)
	{ "Squeak", "rbxassetid://9120222027", 0.7, 1.0, 0.05, 0.6 }, -- toy squeak (animal hurt)
	{ "Catch", "rbxassetid://9113728049", 0.8, 1.0, 0.45, 1.05 }, -- cash register (caught!)
}
local audio = folder(ReplicatedStorage, "GameAudio")
for _, s in ipairs(SOUNDS) do
	local sound = audio:FindFirstChild(s[1]) or Instance.new("Sound")
	sound.Name = s[1]
	sound.SoundId = s[2]
	sound.Volume = s[3]
	sound.PlaybackSpeed = s[4]
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 260
	sound.PlaybackRegionsEnabled = s[5] ~= nil
	if s[5] then
		sound.PlaybackRegion = NumberRange.new(s[5], s[6])
	end
	sound.Parent = audio
end
table.insert(out, "GameAudio: " .. #audio:GetChildren() .. " sounds")

---------------------------------------------------------------- animal templates
-- { name in Workspace, species name }: the Bunny is the Parts model (BuildBunny), the rest are the imported
-- Blender meshes (models/blender). Imported meshes keep their import Scale (~0.017); AnimalManager sizes relative to it.
local MOVE = { { "Bunny", "Bunny" }, { "frog", "Frog" }, { "duckling", "Duckling" }, { "mouse", "Mouse" }, { "hedgehog", "Hedgehog" } }
local templates = folder(ServerStorage, "AnimalTemplates")
for _, pair in ipairs(MOVE) do
	local m = workspace:FindFirstChild(pair[1])
	if m and m:IsA("Model") and not templates:FindFirstChild(pair[2]) then
		m.Name = pair[2]
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy() -- e.g. the old BunnyBrain: AnimalManager moves the animals now
			end
		end
		for name in pairs(m:GetAttributes()) do
			if name:sub(1, 4) ~= "RBX_" then -- RBX_ attributes belong to the importer (CoreScript only)
				m:SetAttribute(name, nil)
			end
		end
		local body = m:FindFirstChild(pair[2] == "Bunny" and "Body" or (pair[2] .. "_Body"), true)
		if body then
			m.PrimaryPart = body
		end
		m.Parent = templates
	end
	local t = templates:FindFirstChild(pair[2])
	table.insert(out, string.format("template %s: %s", pair[2], t and ("ok, PrimaryPart " .. tostring(t.PrimaryPart)) or "MISSING"))
end

---------------------------------------------------------------- spawn zone
local zones = folder(workspace, "AnimalSpawnZones")
if #zones:GetChildren() == 0 then
	local zone = Instance.new("Part")
	zone.Name = "Zone1"
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.CastShadow = false
	zone.Transparency = 1
	zone.Size = Vector3.new(98, 10, 40)
	zone.CFrame = CFrame.new(1, 7, -113)
	zone.Parent = zones
end
table.insert(out, "AnimalSpawnZones: " .. #zones:GetChildren() .. " zone(s)")

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return table.concat(out, "\n")
