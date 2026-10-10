-- AssetManifest (Script in ServerScriptService)
--
-- Lists every remote asset the game uses so the loading screen (ReplicatedFirst.LoadingScreen) can download all of it
-- before a player enters. Clients can't see this on their own: Workspace streaming only sends the map near the
-- player, and the animal / weapon templates live in ServerStorage until the server clones them.
-- Published as ReplicatedStorage.AssetManifest: a StringValue with the asset numbers separated by commas.
-- Built at server start and once more a few seconds later (things built at runtime, e.g. AnimalPreviews).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CONTENT = {
	MeshPart = { "MeshId", "TextureID" },
	SpecialMesh = { "MeshId", "TextureId" },
	Decal = { "Texture" },
	Texture = { "Texture" },
	ImageLabel = { "Image" },
	ImageButton = { "Image" },
	Sound = { "SoundId" },
	Animation = { "AnimationId" },
	ParticleEmitter = { "Texture" },
	Beam = { "Texture" },
	Trail = { "Texture" },
	Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	MaterialVariant = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
	Shirt = { "ShirtTemplate" },
	Pants = { "PantsTemplate" },
	ShirtGraphic = { "Graphic" },
	Tool = { "TextureId" },
}
-- ServerStorage folders players never see (backups and installers)
local function hidden(folder)
	return folder.Name:find("Backup", 1, true) ~= nil or folder.Name:find("Install", 1, true) ~= nil
end

-- "rbxassetid://123", "http://www.roblox.com/asset/?id=123" -> "123"; local rbxasset:// files -> nil
local function assetNumber(value)
	if type(value) ~= "string" or value == "" or value:find("rbxasset://", 1, true) then
		return nil
	end
	if value:find("rbxassetid://", 1, true) or value:find("roblox.com/asset", 1, true) or value:match("^%d+$") then
		return value:match("(%d+)%s*$") or value:match("id=(%d+)")
	end
	return nil
end

local manifest = ReplicatedStorage:FindFirstChild("AssetManifest") or Instance.new("StringValue")
manifest.Name = "AssetManifest"
manifest.Parent = ReplicatedStorage

local function build()
	local seen, numbers = {}, {}
	local function scan(root)
		for i, inst in ipairs(root:GetDescendants()) do
			local properties = CONTENT[inst.ClassName]
			if properties then
				for _, property in ipairs(properties) do
					local ok, value = pcall(function()
						return inst[property]
					end)
					local number = ok and assetNumber(value)
					if number and not seen[number] then
						seen[number] = true
						table.insert(numbers, number)
					end
				end
			end
			if i % 5000 == 0 then
				task.wait()
			end
		end
	end
	for _, root in ipairs({
		workspace,
		ReplicatedStorage,
		game:GetService("ReplicatedFirst"),
		game:GetService("StarterGui"),
		game:GetService("StarterPack"),
		game:GetService("StarterPlayer"),
		game:GetService("Lighting"),
		game:GetService("SoundService"),
		game:GetService("MaterialService"),
	}) do
		scan(root)
	end
	for _, folder in ipairs(ServerStorage:GetChildren()) do
		if not hidden(folder) then
			scan(folder)
		end
	end
	manifest.Value = table.concat(numbers, ",")
	manifest:SetAttribute("Count", #numbers)
end

build()
task.delay(8, build)
