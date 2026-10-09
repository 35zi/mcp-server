-- SpeedData (ModuleScript in ReplicatedStorage)
--
-- Numbers for the Speed side of the game, shared by SpeedService (server) and SpeedClient / TrailShopClient.
--   Speed      a leaderstat that only goes up: treadmills add Speed every second while you run on them.
--   Walk speed grows with Speed, but slowly (log scale, capped), so big numbers feel good without breaking the game.
--   Trails     bought once in the trail shop (the blue stall + neon circle); the equipped one adds a little walk speed
--              and multiplies the Speed you gain per second.
--   Treadmills everyone starts on Basic; upgrades are per player and raise the Speed per second.
local SpeedData = {}

SpeedData.BaseWalk = 16
SpeedData.MaxSpeedBonus = 20 -- walk speed you can ever get from the Speed stat (on top of BaseWalk + trail)

-- walk speed added by your Speed stat: 200 Speed ~ +4, 2K ~ +8, 20K ~ +12, 200K ~ +16, 2M ~ +20 (cap)
function SpeedData.WalkBonus(speed)
	return math.min(SpeedData.MaxSpeedBonus, 4 * math.log10(1 + math.max(0, speed or 0) / 20))
end

-- colors = the trail's color, front to back; rainbow = cycles through every colour
SpeedData.Trails = {
	{ id = "Blue", name = "Blue Trail", price = 10000, walk = 1, gain = 1.1, colors = { Color3.fromRGB(120, 215, 255), Color3.fromRGB(25, 110, 255) } },
	{ id = "Toxic", name = "Toxic Trail", price = 50000, walk = 2, gain = 1.2, colors = { Color3.fromRGB(200, 255, 90), Color3.fromRGB(40, 200, 60) } },
	{ id = "Galaxy", name = "Galaxy Trail", price = 150000, walk = 3, gain = 1.35, colors = { Color3.fromRGB(255, 120, 230), Color3.fromRGB(120, 60, 255), Color3.fromRGB(30, 20, 120) } },
	{ id = "Fire", name = "Fire Trail", price = 500000, walk = 4, gain = 1.5, colors = { Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 140, 30), Color3.fromRGB(230, 40, 20) } },
	{ id = "Golden", name = "Golden Trail", price = 2000000, walk = 5, gain = 1.75, colors = { Color3.fromRGB(255, 255, 210), Color3.fromRGB(255, 205, 50), Color3.fromRGB(210, 140, 20) } },
	{ id = "Rainbow", name = "Rainbow Trail", price = 5000000, walk = 6, gain = 2, rainbow = true },
}

SpeedData.Treadmills = {
	{ name = "Basic", price = 0, rate = 5, color = Color3.fromRGB(150, 160, 175) },
	{ name = "Bronze", price = 10000, rate = 15, color = Color3.fromRGB(215, 130, 60) },
	{ name = "Silver", price = 50000, rate = 40, color = Color3.fromRGB(205, 220, 240) },
	{ name = "Gold", price = 250000, rate = 100, color = Color3.fromRGB(255, 200, 40) },
	{ name = "Diamond", price = 1000000, rate = 250, color = Color3.fromRGB(80, 230, 255) },
	{ name = "Rainbow", price = 5000000, rate = 600, rainbow = true, color = Color3.fromRGB(255, 90, 200) },
}

SpeedData.RainbowColors = {
	Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 240, 60),
	Color3.fromRGB(70, 230, 90), Color3.fromRGB(60, 170, 255), Color3.fromRGB(170, 90, 255),
}

function SpeedData.Trail(id)
	for i, t in ipairs(SpeedData.Trails) do
		if t.id == id then
			return t, i
		end
	end
	return nil
end

function SpeedData.TrailColors(trail)
	return trail.rainbow and SpeedData.RainbowColors or trail.colors
end

function SpeedData.ColorSequence(colors)
	local keys = {}
	for i, c in ipairs(colors) do
		table.insert(keys, ColorSequenceKeypoint.new(#colors == 1 and 0 or (i - 1) / (#colors - 1), c))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, colors[1]))
	end
	return ColorSequence.new(keys)
end

-- Speed per second on a treadmill of this tier with this trail equipped
function SpeedData.Gain(tier, trailId)
	local t = SpeedData.Treadmills[tier] or SpeedData.Treadmills[1]
	local trail = trailId and SpeedData.Trail(trailId)
	return math.floor(t.rate * (trail and trail.gain or 1) + 0.5)
end

function SpeedData.Walk(speed, trailId)
	local trail = trailId and SpeedData.Trail(trailId)
	return SpeedData.BaseWalk + SpeedData.WalkBonus(speed) + (trail and trail.walk or 0)
end

-- 62189 -> "62,189"
function SpeedData.Commas(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local sign, digits = s:match("^(-?)(%d+)$")
	if not digits then
		return s
	end
	return sign .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- 10000 -> "10K", 2500000 -> "2.5M"
function SpeedData.Short(n)
	n = tonumber(n) or 0
	for _, unit in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
		if n >= unit[1] then
			local v = n / unit[1]
			local s = v >= 100 and string.format("%d", math.floor(v)) or string.format("%.1f", math.floor(v * 10) / 10)
			return (s:gsub("%.0$", "")) .. unit[2]
		end
	end
	return tostring(math.floor(n))
end

return SpeedData
