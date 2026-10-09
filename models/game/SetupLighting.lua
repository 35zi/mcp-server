-- SetupLighting (run in Studio's command bar / via MCP, edit mode; safe to re-run)
--
-- Bright, clean cartoon daylight like Steal an Egg: clear blue sky, vivid but not blown-out colours (the floor tiles
-- stay visible), soft light shadows, no haze or glare. The Sky itself is left as it is.
-- The look before this (Brightness 10, purple/green tinted ambient, hazy atmosphere) is kept in the Lighting
-- attribute OldLighting the first time this runs, so it can be put back by hand.
local L = game:GetService("Lighting")
local CHS = game:GetService("ChangeHistoryService")

if not L:GetAttribute("OldLighting") then
	local a = L:FindFirstChildOfClass("Atmosphere")
	local cc = L:FindFirstChildOfClass("ColorCorrectionEffect")
	L:SetAttribute("OldLighting", string.format(
		"Brightness=%s ClockTime=%s Lat=%s Ambient=%s Outdoor=%s ShiftTop=%s ShiftBottom=%s Diffuse=%s Specular=%s Softness=%s | Atmos D=%s C=%s Decay=%s Glare=%s Haze=%s | CC B=%s C=%s S=%s",
		L.Brightness, L.ClockTime, L.GeographicLatitude, tostring(L.Ambient), tostring(L.OutdoorAmbient), tostring(L.ColorShift_Top),
		tostring(L.ColorShift_Bottom), L.EnvironmentDiffuseScale, L.EnvironmentSpecularScale, L.ShadowSoftness,
		a and a.Density, a and tostring(a.Color), a and tostring(a.Decay), a and a.Glare, a and a.Haze,
		cc and cc.Brightness, cc and cc.Contrast, cc and cc.Saturation
	))
end

local rec = CHS:TryBeginRecording("Steal an Egg lighting")
L.Brightness = 2
L.ClockTime = 14 -- early afternoon: sun high, short soft shadows
L.GeographicLatitude = 41.7
L.Ambient = Color3.fromRGB(120, 120, 120) -- neutral grey: shadows stay light and keep their colour
L.OutdoorAmbient = Color3.fromRGB(120, 120, 120)
L.ColorShift_Top = Color3.new(1, 1, 1)
L.ColorShift_Bottom = Color3.new(0, 0, 0)
L.EnvironmentDiffuseScale = 1
L.EnvironmentSpecularScale = 0.2 -- a little shine, no mirror-like plastic
L.ExposureCompensation = 0
L.GlobalShadows = true
L.ShadowSoftness = 0.5

local atmosphere = L:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", L)
atmosphere.Density = 0.12 -- just enough to soften the far end of the worlds
atmosphere.Offset = 0
atmosphere.Color = Color3.fromRGB(200, 225, 255)
atmosphere.Decay = Color3.fromRGB(150, 185, 235)
atmosphere.Glare = 0
atmosphere.Haze = 0

local cc = L:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect", L)
cc.Brightness = 0
cc.Contrast = 0.08
cc.Saturation = 0.05
cc.TintColor = Color3.new(1, 1, 1)

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return "Lighting set"
