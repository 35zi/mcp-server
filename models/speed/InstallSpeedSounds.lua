-- InstallSpeedSounds (run in Studio's command bar / via MCP, edit mode; safe to re-run)
--
-- The treadmill / trail sounds, added to ReplicatedStorage.GameAudio (all from Roblox's licensed Pro Sound Effects
-- library, so they play in every experience). SpeedClient plays them by name.
local audio = game:GetService("ReplicatedStorage"):WaitForChild("GameAudio")
local SOUNDS = {
	SpeedChime = { 9116394876, 0.35 }, -- Magic Glow soft chimes: once a second while you run (smooth, not poppy)
	SpeedWhoosh = { 9125807267, 0.6 }, -- Rising Whoosh: you start running / snap onto the belt
	SpeedDing = { 9126073001, 0.7 }, -- Synth Sparkle Ding: Speed milestones + every 4 s of running
	SpeedUpgrade = { 9116395089, 0.8 }, -- Magic Glow chimes: treadmill upgraded
	SpeedTrail = { 9116394545, 0.8 }, -- Magic Glow chimes: trail bought
}
for name, v in pairs(SOUNDS) do
	local s = audio:FindFirstChild(name) or Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. v[1]
	s.Volume = v[2]
	s.Parent = audio
end
return "Speed sounds installed"
