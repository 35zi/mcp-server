-- SetupGameWorld (run in Studio's command bar / via MCP, edit mode; safe to re-run)
--
-- The non-script pieces the animal + weapon systems need, so the place can be rebuilt from this repo:
--   * ReplicatedStorage.GameAudio          the game's sounds (licensed Roblox ProSoundEffects + one built-in),
--                                           each trimmed with a PlaybackRegion to the useful slice
--   * ServerStorage.AnimalTemplates        the animal models, moved out of the world and kept intact:
--                                           scripts removed, PrimaryPart = Body / <Species>_Body (front = -Z)
--   * Workspace.AnimalSpawnZones           invisible boxes, one per world (attribute World): Zone1 over the green
--                                           floor past the red line, Zone2 over the desert floor after it; animals
--                                           spawn and wander only inside them (resize them or add more in Studio)
--   * Workspace.RedLine                    the neon red line: carry a dead animal over it to bring it home
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
-- { name in Workspace, species name, main part, size factor }: the Bunny is the Parts model (BuildBunny), the rest
-- are imported Blender meshes (Codex's block models). Imported meshes keep their import Scale (~0.017 / 0.010);
-- AnimalManager sizes relative to it. The size factor brings an imported model to its Medium size (once, on move).
-- Fox + Turkey have no mesh yet: models/game/BuildWorldAnimals.lua builds them.
local MOVE = {
	{ "Bunny", "Bunny" },
	{ "frog", "Frog" },
	{ "duckling", "Duckling" },
	{ "mouse", "Mouse" },
	{ "hedgehog", "Hedgehog" },
	{ "spider", "Spider", "Spider_Abdomen", 1.25 },
	{ "scorpion", "Scorpion", nil, 1.4 },
	{ "camel", "Camel", nil, 3.5 },
}
local templates = folder(ServerStorage, "AnimalTemplates")
for _, pair in ipairs(MOVE) do
	local m = workspace:FindFirstChild(pair[1])
	if m and m:IsA("Model") and not templates:FindFirstChild(pair[2]) then
		if pair[4] then
			m:ScaleTo(m:GetScale() * pair[4])
		end
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
		local body = m:FindFirstChild(pair[3] or (pair[2] == "Bunny" and "Body" or (pair[2] .. "_Body")), true)
		if body then
			m.PrimaryPart = body
		end
		m.Parent = templates
	end
	local t = templates:FindFirstChild(pair[2])
	table.insert(out, string.format("template %s: %s", pair[2], t and ("ok, PrimaryPart " .. tostring(t.PrimaryPart)) or "MISSING"))
end

---------------------------------------------------------------- spawn zones (one per world)
-- World 1 = the green floor past the red line (z -190 .. -86), World 2 = the gold/desert floor after it
-- (z -347 .. -190); both 110 wide between the side walls. Population = animals alive in that zone after each wave.
local ZONES = {
	{ "Zone1", 1, CFrame.new(1, 7, -139), Vector3.new(104, 10, 98) },
	{ "Zone2", 2, CFrame.new(1, 7, -269), Vector3.new(104, 10, 152) },
}
local zones = folder(workspace, "AnimalSpawnZones")
for _, z in ipairs(ZONES) do
	local zone = zones:FindFirstChild(z[1]) or Instance.new("Part")
	zone.Name = z[1]
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.CastShadow = false
	zone.Transparency = 1
	zone.Size = z[4]
	zone.CFrame = z[3]
	zone:SetAttribute("World", z[2])
	zone:SetAttribute("Population", zone:GetAttribute("Population") or 10)
	zone.Parent = zones
end
table.insert(out, "AnimalSpawnZones: " .. #zones:GetChildren() .. " zone(s)")

---------------------------------------------------------------- the red line
-- AnimalCarry looks for Workspace.RedLine: carrying a dead animal over it (towards the plots) brings it home.
if not workspace:FindFirstChild("RedLine") then
	for _, p in ipairs(workspace:GetChildren()) do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon and p.BrickColor == BrickColor.new("Bright red") then
			p.Name = "RedLine"
			break
		end
	end
end
table.insert(out, "RedLine: " .. tostring(workspace:FindFirstChild("RedLine") ~= nil))

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return table.concat(out, "\n")
