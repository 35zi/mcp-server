-- BuildWorldLayout (run in Studio's command bar / via MCP, edit mode; safe to re-run)
--
-- Makes the hunting worlds big and open (like Steal an Egg / Steal a Brainrot maps): every world is as wide as the
-- home area (300 studs, between the home's side-wall lines) and much longer, laid out one after another past the red
-- line. The walls next to the entrance go, so the red line runs across the full width.
-- It reuses the original floor / wall / trim Parts (names them World<N>Floor, World<N>WallL/R, World<N>TrimL/R,
-- EndWall the first time). Re-run SetupGameWorld + BuildDecor afterwards (spawn zones + decorations follow the worlds).
local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("Big world layout")

local X_LEFT, X_RIGHT = -151, 154 -- wall centres (same lines as the home area's side walls)
local X_MID, WIDTH = 1, 300 -- floor centre / width
local WORLDS = { -- z0 = near end (towards home), z1 = far end; old* = where the original small parts are
	{ n = 1, z0 = -86, z1 = -346, oldFloorZ = -138, oldWallZ = -140, floor = "Lime green", wall = "CGA brown", trim = "Lime green" },
	{ n = 2, z0 = -346, z1 = -686, oldFloorZ = -269, oldWallZ = -270, floor = "Gold", wall = "Br. yellowish orange", trim = "Cork" },
	{ n = 3, z0 = -686, z1 = -1006, oldFloorZ = -466, oldWallZ = -466, floor = "Ghost grey", wall = "Fog", trim = "Institutional white" },
	{ n = 4, z0 = -1006, z1 = -1326, oldFloorZ = -736, oldWallZ = -736, floor = "Black", wall = "Maroon", trim = "Really black" },
}
local out = {}

local function near(a, b, tol)
	return math.abs(a - b) <= tol
end

-- find a top-level Part by its new name, or (first run) by where the original one is
local function claim(name, match)
	local part = workspace:FindFirstChild(name)
	if part then
		return part
	end
	for _, p in ipairs(workspace:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Part" and match(p) then
			p.Name = name
			return p
		end
	end
	return nil
end

local function place(part, cf, size)
	if part then
		part.Size = size
		part.CFrame = cf
	end
end

for _, w in ipairs(WORLDS) do
	local len = w.z0 - w.z1
	local mid = (w.z0 + w.z1) / 2
	local floor = claim("World" .. w.n .. "Floor", function(p)
		return p.Size.Y > 2 and near(p.Position.Z, w.oldFloorZ, 4) and near(p.Position.X, 1, 3) and p.BrickColor.Name == w.floor
	end)
	if floor then
		place(floor, CFrame.new(X_MID, floor.Position.Y, mid), Vector3.new(WIDTH, floor.Size.Y, len))
	end
	for _, side in ipairs({ { "L", X_LEFT, -1 }, { "R", X_RIGHT, 1 } }) do
		local wall = claim("World" .. w.n .. "Wall" .. side[1], function(p)
			return p.Size.Y > 20 and near(p.Position.Z, w.oldWallZ, 6) and math.sign(p.Position.X) == side[3] and p.BrickColor.Name == w.wall
		end)
		local trim = claim("World" .. w.n .. "Trim" .. side[1], function(p)
			return p.Size.Y < 2 and p.Position.Y > 20 and near(p.Position.Z, w.oldWallZ, 6) and math.sign(p.Position.X) == side[3] and p.BrickColor.Name == w.trim
		end)
		-- walls run along Z: keep their orientation, Size.X is their length
		if wall then
			place(wall, CFrame.new(side[2], wall.Position.Y, mid) * wall.CFrame.Rotation, Vector3.new(len + 5, wall.Size.Y, wall.Size.Z))
		end
		if trim then
			place(trim, CFrame.new(side[2], trim.Position.Y, mid) * trim.CFrame.Rotation, Vector3.new(len + 5, trim.Size.Y, trim.Size.Z))
		end
	end
	table.insert(out, string.format("World %d: z %d..%d (%d x %d)%s", w.n, w.z0, w.z1, WIDTH, len, floor and "" or "  FLOOR NOT FOUND"))
end

-- the far end wall
local last = WORLDS[#WORLDS]
local endWall = claim("EndWall", function(p)
	return p.Size.Y > 20 and p.Position.Z < -880 and near(p.Position.X, 1, 3)
end)
if endWall then
	place(endWall, CFrame.new(X_MID, endWall.Position.Y, last.z1 - 2.5) * endWall.CFrame.Rotation, Vector3.new(X_RIGHT - X_LEFT + 5, endWall.Size.Y, endWall.Size.Z))
end

-- open the entrance: the short walls (and their trims) left and right of the old 110-wide gap go
local removed = 0
for _, p in ipairs(workspace:GetChildren()) do
	if p:IsA("BasePart") and p.Name == "Part" and near(p.Position.Z, -88, 1.5) and math.abs(p.Position.X) > 80 and p.Size.X <= 101 then
		p:Destroy()
		removed += 1
	end
end
table.insert(out, "entrance walls removed: " .. removed)

-- the red line runs across the whole width
local redLine = workspace:FindFirstChild("RedLine")
if redLine then
	redLine.Size = Vector3.new(WIDTH, redLine.Size.Y, redLine.Size.Z)
	redLine.CFrame = CFrame.new(X_MID, redLine.Position.Y, redLine.Position.Z)
end

-- taller, thicker walls everywhere (home area too): every wall (a ~30-tall top-level Part, or one already raised)
-- becomes WALL_HEIGHT tall and WALL_THICK thick, growing outwards so the play area stays the same; the thin
-- coloured caps on top follow
local WALL_HEIGHT, WALL_THICK = 50, 8
local MAP_CENTRE = Vector3.new(1, 0, -600)
local walls, caps = {}, {}
for _, p in ipairs(workspace:GetChildren()) do
	if p:IsA("BasePart") and p ~= redLine then
		if p.Size.Y >= 29 and (p.Size.Y <= 31 or near(p.Size.Y, WALL_HEIGHT, 0.5)) then
			table.insert(walls, p)
		elseif p.Size.Y < 2 and p.Position.Y > 28 then
			table.insert(caps, p)
		end
	end
end
local function resize(p, height, bottom, top)
	-- thickness = the shorter horizontal side; push it outwards (away from the map centre)
	local thickAxisIsX = p.Size.X < p.Size.Z
	local axis = thickAxisIsX and p.CFrame.RightVector or p.CFrame.LookVector
	local away = Vector3.new(p.Position.X, 0, p.Position.Z) - MAP_CENTRE
	if math.abs(axis.X) > 0.5 then
		away = Vector3.new(away.X, 0, 0)
	else
		away = Vector3.new(0, 0, away.Z)
	end
	local oldThick = thickAxisIsX and p.Size.X or p.Size.Z
	local shift = away.Unit * (WALL_THICK - oldThick) / 2
	local size = thickAxisIsX and Vector3.new(WALL_THICK, height, p.Size.Z) or Vector3.new(p.Size.X, height, WALL_THICK)
	local y = top and (top + height / 2) or (bottom + height / 2)
	p.Size = size
	p.CFrame = CFrame.new(p.Position.X + shift.X, y, p.Position.Z + shift.Z) * p.CFrame.Rotation
end
local WALL_BOTTOM = -1 -- all walls start just below the floors
local wallTop = WALL_BOTTOM + WALL_HEIGHT
for _, w in ipairs(walls) do
	resize(w, WALL_HEIGHT, WALL_BOTTOM)
end
for _, c in ipairs(caps) do
	resize(c, c.Size.Y, nil, wallTop)
end
table.insert(out, string.format("walls raised to %d (thickness %d): %d walls, %d caps", WALL_HEIGHT, WALL_THICK, #walls, #caps))

if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
return table.concat(out, "\n")
