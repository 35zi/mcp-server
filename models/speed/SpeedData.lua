-- SpeedData (ModuleScript in ReplicatedStorage)
--
-- Numbers for the Speed side of the game, shared by SpeedService (server) and SpeedClient / TrailShopClient.
--   Stamina    a leaderstat (shown as "Stamina"; the code still calls it Speed) that only goes up: treadmills add it every
--              second while you run on them. Heavy animals need enough of it to be picked up (StaminaToCarry).
--   Walk speed follows a saturating curve of Stamina (fast at the start, slower and slower later); see WalkBonus.
--   Trails     bought once in the trail shop (the blue stall + neon circle); the equipped one multiplies the Stamina you gain per second.
--              Walking speed still increases naturally as your Stamina increases.
--   Treadmills everyone starts on Basic; upgrades are per player, raise the Speed per second and swap the model.
local SpeedData = {}

SpeedData.BaseWalk = 16
SpeedData.MaxWalk = 125 -- a soft ceiling; late Stamina still adds smaller speed gains
SpeedData.CurveHalf = 150000 -- half the bonus at this Stamina milestone

-- Square-root saturation: 500 ~22, 2K ~27, 100K ~65, 1M ~95, 2M ~102.
-- Diminishing returns keep late progression useful without runaway movement speed.
function SpeedData.WalkBonus(speed)
 speed = math.max(0, tonumber(speed) or 0)
 local progress = math.sqrt(speed)
 local half = math.sqrt(SpeedData.CurveHalf)
 return (SpeedData.MaxWalk-SpeedData.BaseWalk)*progress/(progress+half)
end

-- colors = the trail's color, front to back; rainbow = cycles through every colour
-- Card1..Card8 follow the supplied artwork. Existing ownership IDs stay valid.
SpeedData.Trails = {
 { id = "Cyan", name = "Cyan Trail", rarity = "Common", price = 200, walk = 0, gain = 1.5, colors = { Color3.fromRGB(105,245,255), Color3.fromRGB(20,185,205) } },
 { id = "Toxic", productId = 3717891550, robuxPrice = 9, name = "Green Trail", rarity = "Uncommon", price = 6500, walk = 0, gain = 2, colors = { Color3.fromRGB(115,255,65), Color3.fromRGB(25,185,35) } },
 { id = "Blue", productId = 3717891626, robuxPrice = 19, name = "Blue Trail", rarity = "Rare", price = 65000, walk = 0, gain = 3, colors = { Color3.fromRGB(105,175,255), Color3.fromRGB(25,75,245) } },
 { id = "Golden", productId = 3717891726, robuxPrice = 39, name = "Gold Trail", rarity = "Epic", price = 650000, walk = 0, gain = 5, colors = { Color3.fromRGB(255,245,110), Color3.fromRGB(235,170,25) } },
 { id = "Galaxy", productId = 3717891829, robuxPrice = 69, name = "Purple Trail", rarity = "Legendary", price = 6500000, walk = 0, gain = 8, colors = { Color3.fromRGB(220,120,255), Color3.fromRGB(125,35,235) } },
 { id = "Fire", productId = 3717891884, robuxPrice = 99, name = "Red Trail", rarity = "Mythic", price = 65000000, walk = 0, gain = 12, colors = { Color3.fromRGB(255,100,90), Color3.fromRGB(205,25,35) } },
 { id = "Grey", productId = 3717891941, robuxPrice = 149, name = "Grey Trail", rarity = "Secret", price = 350000000, walk = 0, gain = 20, colors = { Color3.fromRGB(225,230,240), Color3.fromRGB(110,120,135) } },
 -- Rainbow is the legacy ownership key for the final slot; its new artwork and effect are black.
 { id = "Rainbow", productId = 3717892043, robuxPrice = 249, name = "Black Trail", rarity = "Divine", price = 1000000000, walk = 0, gain = 30, colors = { Color3.fromRGB(95,95,115), Color3.fromRGB(15,15,25) } },
}

-- color = the treadmill model's own main colour, one clearly different colour per tier (the floating "+N" lungs
-- popup, screen glow, sparkles, upgrade banner and burst all use it)
SpeedData.Treadmills = { -- V3 monument models: ReplicatedStorage.TreadmillModels.Tier1..Tier7
	{ name = "Basic", price = 0, rate = 10, color = Color3.fromHex("B4C0CC") }, -- silver frame
	{ name = "Twin Turbo", price = 10000, rate = 30, color = Color3.fromHex("2F8FFF") }, -- blue turbines
	{ name = "Fusion Reactor", price = 50000, rate = 80, color = Color3.fromHex("A77BFF") }, -- purple reactor ring
	{ name = "Dragon Inferno", price = 250000, rate = 200, color = Color3.fromHex("FF6A12") }, -- dragon fire orange
	{ name = "Crystal Citadel", price = 1000000, rate = 500, color = Color3.fromHex("67EFFF") }, -- ice crystal cyan
	{ name = "Royal Ascension", price = 5000000, rate = 1200, color = Color3.fromHex("FFC22E") }, -- royal gold
	{ name = "Celestial Eternity", price = 25000000, rate = 3000, color = Color3.fromHex("FFF398") }, -- starlight white-gold
}

SpeedData.RainbowColors = {
	Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 240, 60),
	Color3.fromRGB(70, 230, 90), Color3.fromRGB(60, 170, 255), Color3.fromRGB(170, 90, 255),
}

-- each plot's treadmill sits on Workspace.Treadmills.<PlotName>.Spot (floor frame, LookVector = the way you run);
-- the belt is this box on top of it. Server (paying) and client (conveyor) both use OnBelt, so they always agree.
SpeedData.Belt = { center = Vector3.new(0, 0.8, 0), size = Vector3.new(5.8, 0.2, 12.6) } -- = the Blender designs' Belt
function SpeedData.OnBelt(spotCF, position, margin)
	local p = spotCF:PointToObjectSpace(position) - SpeedData.Belt.center
	local half = SpeedData.Belt.size / 2
	margin = margin or 0
	return math.abs(p.X) <= half.X + margin and math.abs(p.Z) <= half.Z + margin and p.Y > 0 and p.Y < 7
end

function SpeedData.Trail(id)
	for i, t in ipairs(SpeedData.Trails) do
		if t.id == id then
			return t, i
		end
	end
	return nil
end

function SpeedData.TrailProduct(productId)
 for _,trail in ipairs(SpeedData.Trails) do if trail.productId==productId then return trail end end
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
function SpeedData.Gain(tier, trailId, stamina, shopMultiplier)
	local t = SpeedData.Treadmills[tier] or SpeedData.Treadmills[1]
	local trail = trailId and SpeedData.Trail(trailId)
	-- beginner boost: x3 income at 0 Stamina, fading out to x1 at 5,000, so the first minutes feel fast
	local boost = 1 + 2 * math.max(0, 1 - (stamina or 5000) / 5000)
	return math.floor(t.rate * (trail and trail.gain or 1) * boost * (shopMultiplier or 1) + 0.5)
end

function SpeedData.Walk(speed, trailId)
	local trail = trailId and SpeedData.Trail(trailId)
	return math.min(SpeedData.MaxWalk, SpeedData.BaseWalk + SpeedData.WalkBonus(speed) + (trail and trail.walk or 0))
end

-- Stamina you need to pick up a stunned animal of this weight (AnimalCarry checks it): nothing up to 10 kg, 400 just
-- above, then up with the weight. Penguin 25 kg ~1,200 / Wolf 45 kg ~2,450 / Camel 500 kg ~44K / Yeti 900 kg ~89K.
SpeedData.CarryFreeKg = 10
function SpeedData.StaminaToCarry(kg)
	kg = tonumber(kg) or 0
	if kg <= SpeedData.CarryFreeKg then
		return 0
	end
	local need = 400 * (kg / SpeedData.CarryFreeKg) ^ 1.2
	local step = need < 10000 and 50 or 500 -- round numbers that are easy to read
	return math.max(400, math.floor(need / step + 0.5) * step)
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
