-- Builds the "Shoot an Animal" bunny from Parts (19 parts, feet on Y = 0, facing -Z).
-- Studio: View > Command Bar, paste this whole file, press Enter.
-- Same result as models/Bunny.rbxmx; use whichever import you prefer.
local model = Instance.new("Model")
model.Name = "Bunny"

local function part(name, hex, x, y, z, w, h, d, rz)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = Color3.fromHex(hex)
	p.Size = Vector3.new(w, h, d)
	p.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(rz))
	p.Parent = model
	return p
end

local FUR, PINK = "#f3efe8", "#ff9fb7"
part("HindFootL", FUR, 1.5, 0.5, 1, 1.4, 1, 2.4, 0)
part("HindFootR", FUR, -1.5, 0.5, 1, 1.4, 1, 2.4, 0)
part("FrontPawL", FUR, 1, 0.4, -1.8, 1, 0.8, 1.6, 0)
part("FrontPawR", FUR, -1, 0.4, -1.8, 1, 0.8, 1.6, 0)
part("HaunchL", FUR, 1.9, 1.6, 1.6, 1.6, 2.4, 2.6, 0)
part("HaunchR", FUR, -1.9, 1.6, 1.6, 1.6, 2.4, 2.6, 0)
part("Body", FUR, 0, 2.1, 0.2, 3.6, 3, 4.4, 0)
part("Tail", FUR, 0, 2.5, 2.7, 1.6, 1.6, 1.2, 0)
part("Head", FUR, 0, 4.6, -1.8, 3, 2.6, 2.6, 0)
part("Muzzle", "#fbf9f4", 0, 3.95, -3.1, 1.5, 0.9, 0.3, 0)
part("EarL", FUR, 0.8, 7.3, -1.3, 0.9, 3.4, 0.6, -8)
part("EarR", FUR, -0.8, 7.3, -1.3, 0.9, 3.4, 0.6, 8)
part("EarInnerL", PINK, 0.8, 7.3, -1.63, 0.5, 2.8, 0.1, -8)
part("EarInnerR", PINK, -0.8, 7.3, -1.63, 0.5, 2.8, 0.1, 8)
part("EyeL", "#1b1b20", 0.85, 5, -3.12, 0.5, 0.75, 0.1, 0)
part("EyeR", "#1b1b20", -0.85, 5, -3.12, 0.5, 0.75, 0.1, 0)
part("Nose", "#ff6b8e", 0, 4.25, -3.28, 0.6, 0.45, 0.1, 0)
part("CheekL", "#ffb3c6", 1.15, 4.15, -3.12, 0.5, 0.3, 0.1, 0)
part("CheekR", "#ffb3c6", -1.15, 4.15, -3.12, 0.5, 0.3, 0.1, 0)

model.PrimaryPart = model:FindFirstChild("Body")
model.Parent = workspace
game:GetService("Selection"):Set({ model })
