-- WeaponClient (LocalScript in StarterPlayer.StarterPlayerScripts)
--
-- Everything the player sees and hears when using a weapon (any Tool with a WeaponId attribute):
--   * third person (default): a small precise aim dot sits exactly where the shot will land (red over an animal,
--     faded when the target is out of range); the mouse cursor is hidden while a weapon is out
--   * hold RIGHT-CLICK (or L2): third person glides to an over-the-shoulder view; first person lines up the
--     iron sights (or the scope overlay for scoped weapons); a viewmodel of the gun with blocky hands is drawn;
--     Accuracy turns into a gentle sight sway (the AR has stable ADS); release to glide back out
--   * LEFT-CLICK (or R2, or tap): fire. The shot is shown instantly (kick, muzzle flash + smoke, tracer, impact,
--     gunshot) and the server is told; the server decides damage and confirms hits (hit tick + hit marker)
--   * per-weapon animation from WeaponConfig: hammer drop/re-cock with a click, cylinder turning, pump, bolt,
--     charging handle. Automatic weapons fire while the trigger is held.
-- Tool attributes (set by BuildWeapons, Handle space): EyePos, SightTarget, MuzzlePos, SupportPos.
-- The weapon is disabled while the Weapon Shop view or an animal menu (Index / Inventory) is open.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local catalog = require(ReplicatedStorage:WaitForChild("WeaponShopCatalog"))
local WeaponStats = require(ReplicatedStorage:WaitForChild("WeaponStats"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local combat = ReplicatedStorage:WaitForChild("WeaponCombat")
local audio = ReplicatedStorage:WaitForChild("GameAudio")
local userSettings = UserSettings():GetService("UserGameSettings")
local GuiService = game:GetService("GuiService")

local RENDER_STEP = "WeaponClientRender"
local ADS_SPEED = 11 -- how fast the camera glides into / out of the sights
local HIP_POSE = CFrame.new(0.95, -1.05, -1.6) * CFrame.Angles(0, math.rad(4), 0) -- viewmodel when not aiming
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(15, 15, 18)
local RED = Color3.fromRGB(255, 70, 60)
local rng = Random.new()

---------------------------------------------------------------- HUD
local function make(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local hud = make("ScreenGui", {
	Name = "WeaponHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 5,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- aim dot: a small dot inside a thin ring
local reticle = make("Frame", { Name = "Reticle", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Parent = hud })
local ring = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = reticle })
make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
local ringStroke = make("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.25, Parent = ring })
local dot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = WHITE, Parent = reticle })
make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
make("UIStroke", { Color = BLACK, Thickness = 1, Parent = dot })

-- hit marker: four short diagonal lines around the aim point
local hitMarker = make("Frame", { Name = "HitMarker", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Parent = hud })
local hitLines = {}
for i, offset in ipairs({ Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) }) do
	hitLines[i] = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, offset.X * 10, 0.5, offset.Y * 10),
		Size = UDim2.fromOffset(10, 2),
		Rotation = (offset.X * offset.Y > 0) and 45 or -45,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = hitMarker,
	})
end

-- soft dark vignette while aiming
local vignette = {}
for i, spec in ipairs({
	{ UDim2.new(1, 0, 0.18, 0), UDim2.new(0, 0, 0, 0), 90 },
	{ UDim2.new(1, 0, 0.18, 0), UDim2.new(0, 0, 0.82, 0), -90 },
	{ UDim2.new(0.14, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 },
	{ UDim2.new(0.14, 0, 1, 0), UDim2.new(0.86, 0, 0, 0), 180 },
}) do
	local f = make("Frame", { Size = spec[1], Position = spec[2], BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = hud })
	make("UIGradient", { Rotation = spec[3], Transparency = NumberSequence.new(0, 1), Parent = f })
	vignette[i] = f
end

-- scope overlay: a round window (huge black stroke around a circle) with thin cross-hairs
local scope = make("Frame", { Name = "Scope", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = hud })
local scopeCircle = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = scope })
make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = scopeCircle })
make("UIStroke", { Color = BLACK, Thickness = 2500, Parent = scopeCircle })
make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = scopeCircle })
make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = scopeCircle })
local scopeDot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = RED, Parent = scopeCircle })
make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = scopeDot })

local function flashHitMarker(big)
	hitMarker.Position = reticle.Visible and reticle.Position or UDim2.fromScale(0.5, 0.5)
	for _, line in ipairs(hitLines) do
		line.BackgroundColor3 = big and RED or WHITE
		line.BackgroundTransparency = 0
		line.Size = UDim2.fromOffset(big and 14 or 10, 2)
		TweenService:Create(line, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.08), { BackgroundTransparency = 1 }):Play()
	end
end

---------------------------------------------------------------- sound + effects
local function playSound(name, at, pitch, volume)
	local template = audio:FindFirstChild(name)
	if not template then
		return
	end
	local sound = template:Clone()
	sound.PlaybackSpeed *= pitch or 1
	sound.Volume *= volume or 1
	if typeof(at) == "Vector3" then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Position = at
		holder.Parent = workspace
		sound.Parent = holder
		Debris:AddItem(holder, 4)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 4)
	end
	sound:Play()
end

local function effectPart(position)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Position = position
	p.Parent = workspace
	return p
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local function muzzleFlash(cf, scale)
	scale = scale or 1
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 200, 90)
	flash.Size = Vector3.new(0.45, 0.45, 0.6) * scale
	flash.CFrame = cf * CFrame.new(0, 0, -0.3 * scale) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(0, 90)))
	flash.Parent = workspace
	local star = flash:Clone()
	star.Size = Vector3.new(0.9, 0.12, 0.12) * scale
	star.Color = Color3.fromRGB(255, 240, 180)
	star.CFrame = flash.CFrame * CFrame.Angles(0, 0, math.rad(45))
	star.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Brightness = 6
	light.Range = 12
	light.Parent = flash
	Debris:AddItem(flash, 0.05)
	Debris:AddItem(star, 0.05)

	local holder = effectPart(cf.Position)
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local smoke = emitter(attachment, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(200, 200, 200)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25 * scale), NumberSequenceKeypoint.new(1, 1.1 * scale) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(1, 2.5),
		SpreadAngle = Vector2.new(25, 25),
		Drag = 3,
		Acceleration = Vector3.new(0, 1.5, 0),
	})
	attachment.WorldCFrame = cf
	smoke:Emit(4)
	Debris:AddItem(holder, 1.5)
end

local function tracer(from, to)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local line = Instance.new("Part")
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.CastShadow = false
	line.Material = Enum.Material.Neon
	line.Color = Color3.fromRGB(255, 236, 170)
	line.Transparency = 0.2
	line.Size = Vector3.new(0.06, 0.06, distance)
	line.CFrame = CFrame.lookAt((from + to) / 2, to)
	line.Parent = workspace
	TweenService:Create(line, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	Debris:AddItem(line, 0.2)
end

local function impact(position, normal, kind)
	local holder = effectPart(position)
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	attachment.WorldCFrame = CFrame.lookAt(position, position + (normal or Vector3.yAxis)) * CFrame.Angles(math.rad(-90), 0, 0)
	if kind ~= "animal" and kind ~= "killed" then
		emitter(attachment, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(176, 150, 112)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.9) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.35, 0.6),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(35, 35),
			Drag = 4,
		}):Emit(6)
		playSound("Impact", position, rng:NextNumber(1.4, 1.7), 0.6)
	end
	emitter(attachment, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 140)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(50, 50),
	}):Emit(5)
	Debris:AddItem(holder, 1.2)
end

---------------------------------------------------------------- state
local current = nil -- the equipped weapon (see equip)
local aiming = false
local alpha = 0 -- 0 = third person, 1 = fully aimed
local camOwned = false
local saved = nil -- camera settings to restore when aiming ends
local yaw, pitch = 0, 0
local gamepadLook = Vector2.zero
local aimInput = nil
local windowFocused = true
local hiddenState = false

-- the shop view or an animal menu (Index / Inventory) is open: the weapon steps aside and the cursor shows
local function shopOpen()
	local gui = player.PlayerGui:FindFirstChild("WeaponShopUI")
	local menu = player.PlayerGui:FindFirstChild("GameUI")
	return (gui ~= nil and gui.Enabled) or (menu ~= nil and menu:GetAttribute("Open") == true) or GuiService.MenuIsOpen
end

local function isAnimal(instance)
	local animals = workspace:FindFirstChild("Animals")
	return instance ~= nil and animals ~= nil and instance:IsDescendantOf(animals)
end

local function setCharacterHidden(hidden)
	if not hidden and not hiddenState then
		return
	end
	hiddenState = hidden
	local character = player.Character
	if not character then
		return
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function rayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace.CurrentCamera }
	return params
end

---------------------------------------------------------------- viewmodel (first-person gun + hands)
local function bar(parent, a, b, thickness, color)
	local p = Instance.new("Part")
	p.Size = Vector3.new(thickness, thickness, (b - a).Magnitude)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	parent:Add(p, CFrame.lookAt((a + b) / 2, b))
end

local function buildViewmodel(tool, cfg)
	local handle = tool:FindFirstChild("Handle")
	local model = Instance.new("Model")
	model.Name = "WeaponViewmodel"
	local vm = { model = model, parts = {}, rel = {}, group = {}, visible = true }

	function vm:Add(part, rel, group)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = model
		table.insert(self.parts, part)
		self.rel[part] = rel
		self.group[part] = group
	end

	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") and d ~= handle then
			local copy = d:Clone()
			for _, child in ipairs(copy:GetChildren()) do
				if child:IsA("JointInstance") or child:IsA("LuaSourceContainer") then
					child:Destroy()
				end
			end
			local group = nil
			if cfg.Hammer and d.Name:match(cfg.Hammer) then
				group = "hammer"
			elseif cfg.Cylinder and d.Name:match(cfg.Cylinder) then
				group = "cylinder"
			elseif cfg.Slide and d.Name:match(cfg.Slide) then
				group = "slide"
			end
			local rel = handle.CFrame:ToObjectSpace(d.CFrame)
			vm:Add(copy, rel, group)
			if group == "hammer" then
				vm.hammerPivot = rel.Position - Vector3.new(0, d.Size.Y * 0.45, 0)
			elseif group == "cylinder" then
				vm.cylinderPivot = rel.Position
			end
		end
	end

	-- blocky hands in the player's colours
	local character = player.Character
	local skinPart = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("Head"))
	local sleevePart = character and (character:FindFirstChild("RightUpperArm") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	local skin = skinPart and skinPart.Color or Color3.fromRGB(255, 204, 153)
	local sleeve = sleevePart and sleevePart.Color or Color3.fromRGB(60, 70, 90)
	local function box(size, rel, color)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		vm:Add(p, rel)
	end
	box(Vector3.new(0.42, 0.5, 0.42), CFrame.new(0.02, -0.1, 0.05) * CFrame.Angles(math.rad(-15), 0, 0), skin)
	bar(vm, Vector3.new(0.12, -0.3, 0.25), Vector3.new(0.85, -1.45, 2.4), 0.38, sleeve)
	local support = tool:GetAttribute("SupportPos") or Vector3.new(0, -0.3, -0.2)
	box(Vector3.new(0.42, 0.36, 0.46), CFrame.new(support + Vector3.new(-0.05, -0.12, 0)), skin)
	bar(vm, support + Vector3.new(-0.12, -0.2, 0.15), Vector3.new(-1.0, -1.5, 2.2), 0.38, sleeve)

	local muzzle = tool:GetAttribute("MuzzlePos") or Vector3.new(0, 0.5, -2)
	vm.muzzleRel = CFrame.new(muzzle)
	model.Parent = workspace.CurrentCamera
	return vm
end

local function setViewmodelVisible(vm, visible)
	if vm.visible == visible then
		return
	end
	vm.visible = visible
	for _, p in ipairs(vm.parts) do
		p.LocalTransparencyModifier = visible and 0 or 1
	end
end

---------------------------------------------------------------- equip / camera
local function releaseCamera(restore)
	if not camOwned then
		return
	end
	camOwned = false
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if humanoid then
		humanoid.AutoRotate = saved.autoRotate
	end
	-- Roblox may have already locked the mouse for right-click before InputBegan.
	-- Do not restore that transient lock; the default camera reapplies first-person/shift-lock itself.
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	setCharacterHidden(false)
	if restore then
		if head then
			-- hand the camera back exactly where third person expects it, so there is no snap
			local rootPart=character:FindFirstChild("HumanoidRootPart")
			local eye = rootPart and rootPart.Position+saved.eyeOffset or head.Position+Vector3.new(0,0.15,0)
			camera.CFrame = CFrame.new(eye) * CFrame.fromOrientation(pitch, yaw, 0) * CFrame.new(0, 0, saved.dist)
		end
		camera.FieldOfView = saved.fov
		camera.CameraType = Enum.CameraType.Custom
	end
	if current and current.vm then
		setViewmodelVisible(current.vm, false)
	end
	hud.Enabled = current ~= nil
end

local function takeCamera()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if camOwned or not humanoid or not head or camera.CameraType == Enum.CameraType.Scriptable then
		return false
	end
	saved = {
		fov = camera.FieldOfView,
		dist = math.clamp((camera.CFrame.Position - head.Position).Magnitude, 0.5, 60),
		autoRotate = humanoid.AutoRotate,
		eyeOffset = head.Position - character.HumanoidRootPart.Position + Vector3.new(0,0.15,0),
		firstPerson = player.CameraMode == Enum.CameraMode.LockFirstPerson or (camera.CFrame.Position-camera.Focus.Position).Magnitude < 1,
	}
	local look = camera.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	pitch = math.asin(math.clamp(look.Y, -1, 1))
	humanoid.AutoRotate = false
	camera.CameraType = Enum.CameraType.Scriptable
	camOwned = true
	return true
end

-- the third-person shot: from the muzzle towards whatever is under the mouse, stopped by the first thing it hits
local function thirdPersonAim(centered)
	local camera = workspace.CurrentCamera
	local mouse = centered and camera.ViewportSize/2 or UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y) -- GetMouseLocation is in viewport space (includes the top bar)
	local params = rayParams()
	local result = workspace:Raycast(ray.Origin, ray.Direction * math.max(1500, current.stats.Range + 60), params)
	local aimPoint = result and result.Position or ray.Origin + ray.Direction * 1000
	local muzzle = current.muzzleAttachment and current.muzzleAttachment.WorldPosition or ray.Origin
	local toAim = aimPoint - muzzle
	local direction = toAim.Magnitude > 0.05 and toAim.Unit or ray.Direction
	local reach = math.min(toAim.Magnitude, current.stats.Range)
	local shot = workspace:Raycast(muzzle, direction * reach, params)
	local landing = shot and shot.Position or muzzle + direction * reach
	local outOfRange = not shot and toAim.Magnitude > current.stats.Range
	return landing, shot and shot.Instance, shot and shot.Normal, outOfRange, muzzle
end

local function adsAim()
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local result = workspace:Raycast(ray.Origin, ray.Direction * current.stats.Range, rayParams())
	local landing = result and result.Position or ray.Origin + ray.Direction * current.stats.Range
	return landing, result and result.Instance, result and result.Normal
end

local function fire()
	local c = current
	if not c or not windowFocused or shopOpen() then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - c.lastShot < c.stats.Cooldown then
		return
	end
	c.lastShot = now
	c.kickT = now
	c.recocked = false
	c.cylinderTarget += math.rad(60)

	local aimed = camOwned and alpha > 0.6
	local landing, hitInstance, normal, muzzleCF
	if aimed then
		if saved.firstPerson then
			landing, hitInstance, normal = adsAim()
			muzzleCF = c.vmGunCF and (c.vmGunCF * c.vm.muzzleRel) or workspace.CurrentCamera.CFrame
			muzzleCF = CFrame.lookAt(muzzleCF.Position, landing)
		else
			local muzzle
			landing, hitInstance, normal, _, muzzle = thirdPersonAim(true)
			muzzleCF = CFrame.lookAt(muzzle, landing)
		end
	else
		local muzzle
		landing, hitInstance, normal, _, muzzle = thirdPersonAim()
		muzzleCF = CFrame.lookAt(muzzle, landing)
	end
	combat:FireServer(c.id, landing, aimed and saved.firstPerson, hitInstance)

	-- instant feedback
	playSound("Fire", nil, c.cfg.Pitch * rng:NextNumber(0.97, 1.03), c.cfg.Volume)
	muzzleFlash(muzzleCF, (c.cfg.Kick or 1) > 1.2 and 1.3 or 1)
	tracer(muzzleCF.Position, landing)
	if hitInstance then
		impact(landing, normal, isAnimal(hitInstance) and "animal" or "world")
	end
	if c.cfg.Cycle == "pump" or c.cfg.Cycle == "bolt" then
		task.delay(c.stats.Cooldown * 0.25, function()
			if current == c then
				playSound("Cock", nil, c.cfg.Cycle == "pump" and 0.8 or 0.95, 0.9)
			end
		end)
	end
end

-- animation values for the viewmodel parts (updated every frame)
local function cycleTransforms(c, now)
	local t = now - c.lastShot
	local cd = c.stats.Cooldown
	local hammerCF, cylinderCF, slideCF = CFrame.identity, CFrame.identity, CFrame.identity
	if c.cfg.Cycle == "hammer" then
		-- hammer falls on the shot, re-cocks with a click just before the next shot is ready
		local cockStart = math.max(cd - 0.28, 0.12)
		local cocked
		if t >= cd or c.lastShot < 0 then
			cocked = 1
		elseif t < 0.03 then
			cocked = 1 - t / 0.03
		elseif t < cockStart then
			cocked = 0
		else
			cocked = math.clamp((t - cockStart) / 0.18, 0, 1)
			if not c.recocked and cocked >= 1 then
				c.recocked = true
				playSound("Cock", nil, 1.15, 0.7)
			end
		end
		if c.vm.hammerPivot then
			local pivot = c.vm.hammerPivot
			hammerCF = CFrame.new(pivot) * CFrame.Angles(math.rad(30 * cocked), 0, 0) * CFrame.new(-pivot)
		end
		c.cylinderAngle += (c.cylinderTarget - c.cylinderAngle) * math.clamp((t - 0.05) * 12, 0, 1) * 0.35
		if c.vm.cylinderPivot then
			local pivot = c.vm.cylinderPivot
			cylinderCF = CFrame.new(pivot) * CFrame.Angles(0, 0, c.cylinderAngle) * CFrame.new(-pivot)
		end
	elseif c.cfg.Cycle == "pump" or c.cfg.Cycle == "bolt" then
		local a, b = cd * 0.25, cd * 0.8
		local s = (t > a and t < b) and math.sin(math.pi * (t - a) / (b - a)) or 0
		slideCF = CFrame.new(0, 0, (c.cfg.SlideAmount or 0.4) * s)
	elseif c.cfg.Cycle == "charge" then
		local s = t < 0.12 and math.sin(math.pi * t / 0.12) or 0
		slideCF = CFrame.new(0, 0, (c.cfg.SlideAmount or 0.15) * s)
	end
	return hammerCF, cylinderCF, slideCF
end

local function onRender(dt)
	local c = current
	if not c then
		return
	end
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not head or not root then
		aiming=false alpha=0 releaseCamera(true)
		return
	end
	local now = os.clock()
	-- Recover even when release occurred outside Studio/game focus or UI swallowed it.
	if aiming and aimInput=="Mouse" and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then aiming=false aimInput=nil end
	if not windowFocused then
		c.triggerHeld=false aiming=false alpha=0 releaseCamera(true)
		UserInputService.MouseIconEnabled=true
		return
	end

	if shopOpen() then
		-- the shop owns the camera: step aside without touching it
		if camOwned then
			local weaponShop=player.PlayerGui:FindFirstChild("WeaponShopUI")
			releaseCamera(not (weaponShop and weaponShop.Enabled))
		end
		aiming, alpha, aimInput = false, 0, nil
		c.triggerHeld=false
		UserInputService.MouseBehavior=Enum.MouseBehavior.Default
		setViewmodelVisible(c.vm, false)
		hud.Enabled = false
		UserInputService.MouseIconEnabled = true
		return
	end
	hud.Enabled = true

	if c.cfg.Automatic and c.triggerHeld then
		fire()
	end

	local target = (aiming and camOwned) and 1 or 0
	alpha += (target - alpha) * math.min(1, dt * ADS_SPEED)
	if math.abs(target - alpha) < 0.003 then
		alpha = target
	end
	local e = alpha * alpha * (3 - 2 * alpha)

	local t = now - c.kickT
	local kick = 0
	if t >= 0 then
		kick = t < 0.045 and t / 0.045 or math.max(0, 1 - (t - 0.045) / 0.32) ^ 2
	end
	local kickStrength = c.cfg.Kick or 1
	local cooling = now - c.lastShot < c.stats.Cooldown

	if camOwned then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		local scoped = saved.firstPerson and c.scope and e > 0.92
		local sensitivity = 0.0034 * userSettings.MouseSensitivity * (1 - 0.4 * e) * (scoped and 0.35 or 1)
		local delta = UserInputService:GetMouseDelta()
		yaw -= delta.X * sensitivity
		pitch = math.clamp(pitch - delta.Y * sensitivity, -1.35, 1.35)
		if gamepadLook.Magnitude > 0.15 then
			yaw -= gamepadLook.X * dt * 2.6 * (1 - 0.5 * e)
			pitch = math.clamp(pitch + gamepadLook.Y * dt * 2.0 * (1 - 0.5 * e), -1.35, 1.35)
		end
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)

		local eye = root.Position + saved.eyeOffset
		local amp = c.cfg.StableADS and 0 or math.rad(c.stats.AdsSway) * e
		local sway = CFrame.Angles(math.sin(now * 1.1) * amp * 0.6, math.sin(now * 0.7 + 1) * amp, 0)
		local recoil = CFrame.Angles(math.rad(2.5 * kickStrength * kick) * e, 0, 0)
		local rotation = CFrame.fromOrientation(pitch, yaw, 0) * sway * recoil
		local offset = saved.firstPerson and Vector3.new(0,0,saved.dist*(1-e))
			or Vector3.new(0,0,saved.dist):Lerp(Vector3.new(2.25,.35,5.5),e)
		local camCF = CFrame.new(eye) * rotation * CFrame.new(offset)
		if not saved.firstPerson then
			-- Stop before walls while retaining third-person visibility and the real gun.
			local deltaPosition=camCF.Position-eye
			local hit=workspace:Raycast(eye,deltaPosition,rayParams())
			if hit then
				local position=eye+deltaPosition.Unit*math.max(.4,hit.Distance-.5)
				camCF=CFrame.new(position)*rotation
			end
		end
		camera.CFrame = camCF
		local targetFov=saved.firstPerson and (c.cfg.Fov or 50) or math.min(saved.fov,60)
		camera.FieldOfView = saved.fov + (targetFov - saved.fov) * e
		setCharacterHidden(saved.firstPerson and e > 0.55)

		local pose = HIP_POSE:Lerp(c.adsPose, e)
		-- Camera recoil moves the sight and shot ray together. Extra gun recoil fades out in ADS.
		local visualKick=kick*(1-e)
		local kickCF = CFrame.new(0, 0.04 * visualKick, 0.25 * visualKick * kickStrength) * CFrame.Angles(math.rad(7 * visualKick * kickStrength), 0, 0)
		local gunCF = camCF * pose * kickCF
		c.vmGunCF = gunCF
		local showVm = saved.firstPerson and e > 0.35 and not scoped
		setViewmodelVisible(c.vm, showVm)
		if showVm then
			local hammerCF, cylinderCF, slideCF = cycleTransforms(c, now)
			local cfs = table.create(#c.vm.parts)
			for i, part in ipairs(c.vm.parts) do
				local group = c.vm.group[part]
				local extra = group == "hammer" and hammerCF or group == "cylinder" and cylinderCF or group == "slide" and slideCF or CFrame.identity
				cfs[i] = gunCF * extra * c.vm.rel[part]
			end
			workspace:BulkMoveTo(c.vm.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		else
			cycleTransforms(c, now) -- keep the hammer click timing even when the gun isn't drawn
		end

		reticle.Visible = not saved.firstPerson
		if reticle.Visible then
			local landing,hit,_,outOfRange=thirdPersonAim(true)
			reticle.Visible=true reticle.Position=UDim2.fromScale(0.5,0.5)
			dot.BackgroundColor3=isAnimal(hit) and RED or WHITE ringStroke.Color=dot.BackgroundColor3
			ringStroke.Transparency=(outOfRange or cooling) and .7 or .25
			dot.BackgroundTransparency=outOfRange and .6 or 0
		end
		scope.Visible = scoped
		if scoped then
			local size = math.min(camera.ViewportSize.X, camera.ViewportSize.Y) * 0.92
			scopeCircle.Size = UDim2.fromOffset(size, size)
		end
		for _, f in ipairs(vignette) do
			f.BackgroundTransparency = 1 - 0.6 * e
		end
		if alpha == 0 and not aiming then
			releaseCamera(true)
		end
	else
		UserInputService.MouseIconEnabled = false
		scope.Visible = false
		for _, f in ipairs(vignette) do
			f.BackgroundTransparency = 1
		end
		setViewmodelVisible(c.vm, false)
		cycleTransforms(c, now)
		local landing, hit, _, outOfRange = thirdPersonAim()
		local mouse=UserInputService:GetMouseLocation()
		reticle.Visible = true
		reticle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
		local color = isAnimal(hit) and RED or WHITE
		dot.BackgroundColor3 = color
		ringStroke.Color = color
		ringStroke.Transparency = (outOfRange or cooling) and 0.7 or 0.25
		dot.BackgroundTransparency = outOfRange and 0.6 or 0
		-- third-person kick: nudge the gun in the hand
		c.tool.Grip = CFrame.new(0, 0, -0.2 * kick * kickStrength) * CFrame.Angles(-math.rad(10 * kick * kickStrength), 0, 0)
	end
end

local function unequip()
	local c = current
	if not c then
		return
	end
	RunService:UnbindFromRenderStep(RENDER_STEP)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	releaseCamera(humanoid ~= nil and humanoid.Health > 0)
	for _, connection in ipairs(c.connections) do
		connection:Disconnect()
	end
	if c.vm then
		c.vm.model:Destroy()
	end
	if c.tool.Parent then
		c.tool.Grip = CFrame.new()
	end
	current = nil
	aiming, alpha, aimInput = false, 0, nil
	UserInputService.MouseBehavior=Enum.MouseBehavior.Default
	hud.Enabled = false
	setCharacterHidden(false)
	UserInputService.MouseIconEnabled = true
end

local function equip(tool)
	if current then
		unequip()
	end
	local id = tool:GetAttribute("WeaponId")
	local stats = WeaponStats.forId(catalog, id)
	local handle = tool:WaitForChild("Handle", 5)
	if not stats or not handle or tool.Parent ~= player.Character then
		return
	end
	local cfg = WeaponConfig[id] or { Fov = 50, Kick = 1, Pitch = 1, Volume = 0.9 }
	local eyePos = tool:GetAttribute("EyePos") or Vector3.new(0, 1, 0.5)
	local sightTarget = tool:GetAttribute("SightTarget") or Vector3.new(0, 1, -2)
	-- per-weapon sight picture tweaks (see WeaponConfig)
	sightTarget += Vector3.new(0, cfg.SightLift or 0, 0)
	eyePos += Vector3.new(0, (cfg.SightLift or 0) + (cfg.EyeLift or 0), 0)
	eyePos += (eyePos - sightTarget).Unit * (cfg.EyeBack or 0)
	local c = {
		tool = tool,
		id = id,
		cfg = cfg,
		stats = stats,
		scope = tool:GetAttribute("Scope") == true or cfg.Scope == true,
		muzzleAttachment = handle:FindFirstChild("MuzzleAttachment"),
		adsPose = CFrame.lookAt(eyePos, sightTarget):Inverse(),
		lastShot = -1e9,
		kickT = -1e9,
		recocked = true,
		cylinderAngle = 0,
		cylinderTarget = 0,
		triggerHeld = false,
		connections = {},
	}
	c.vm = buildViewmodel(tool, cfg)
	setViewmodelVisible(c.vm, false)
	current = c
	table.insert(c.connections, tool.Activated:Connect(function()
		c.triggerHeld = true
		fire()
	end))
	table.insert(c.connections, tool.Deactivated:Connect(function()
		c.triggerHeld = false
	end))
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, onRender)
	hud.Enabled = true
end

---------------------------------------------------------------- input
UserInputService.InputBegan:Connect(function(input, processed)
	-- A fresh unprocessed game input also resumes after Studio focus changes.
	if not processed then windowFocused=true end
	if not current or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		if not shopOpen() and (camOwned or takeCamera()) then
			aiming=true
			aimInput=input.UserInputType==Enum.UserInputType.MouseButton2 and "Mouse" or "Gamepad"
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		aiming = false aimInput=nil
	end
end)
UserInputService.WindowFocusReleased:Connect(function()
	windowFocused=false aiming=false alpha=0 aimInput=nil gamepadLook=Vector2.zero
	if current then current.triggerHeld=false end
	releaseCamera(true)
	UserInputService.MouseBehavior=Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled=true
end)
UserInputService.WindowFocused:Connect(function() windowFocused=true end)
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		gamepadLook = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

---------------------------------------------------------------- what other players' shots look like + hit confirmation
combat.OnClientEvent:Connect(function(shooterId, weaponId, muzzlePos, hitPos, hitNormal, kind)
	if shooterId == player.UserId then
		if kind == "animal" or kind == "humanoid" or kind == "killed" then
			flashHitMarker(kind == "killed")
			playSound("HitTick", nil, kind == "killed" and 1.25 or 1, 0.8)
		end
		return
	end
	local cfg = WeaponConfig[weaponId] or {}
	playSound("Fire", muzzlePos, cfg.Pitch, cfg.Volume)
	muzzleFlash(CFrame.lookAt(muzzlePos, hitPos))
	tracer(muzzlePos, hitPos)
	if kind ~= "none" then
		impact(hitPos, hitNormal, kind)
	end
end)

---------------------------------------------------------------- equip tracking
local function watchCharacter(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			equip(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if current and current.tool == child then
			unequip()
		end
	end)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(unequip)
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") then
			equip(child)
		end
	end
end
player.CharacterAdded:Connect(watchCharacter)
player.CharacterRemoving:Connect(unequip)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end
