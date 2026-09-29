--!strict
-- A parkour test course so movement can be felt (and tuned) in an empty place.
-- Everything lives under Workspace.DevArena; set GameConfig.BuildDevArena = false to drop it.

local Workspace = game:GetService("Workspace")

local DevArena = {}

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local function makeLabel(parent: Instance, text: string, position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "Label"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = parent

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 44)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 160
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
end

-- A slab whose low end sits on the ground at `start`, rising `angle` degrees along `yaw` degrees.
local function makeRamp(parent: Instance, name: string, start: Vector3, length: number, width: number, angle: number, yaw: number, color: Color3): Part
	local thickness = 2
	local rad = math.rad(angle)
	local rise = math.sin(rad) * length
	local run = math.cos(rad) * length
	local cframe = CFrame.new(start)
		* CFrame.Angles(0, math.rad(yaw), 0)
		* CFrame.new(0, rise / 2 - thickness / 2 * math.cos(rad), -run / 2)
		* CFrame.Angles(rad, 0, 0)
	return makePart(parent, name, Vector3.new(width, thickness, length), cframe, color)
end

function DevArena.Build()
	if Workspace:FindFirstChild("DevArena") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "DevArena"
	folder.Parent = Workspace

	if not Workspace:FindFirstChild("Baseplate") then
		makePart(folder, "Floor", Vector3.new(900, 2, 900), CFrame.new(0, -1, 0), Color3.fromRGB(96, 104, 112))
	end

	if not Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "ArenaSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(14, 1, 14)
		spawn.Position = Vector3.new(0, 0.5, 20)
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Color = Color3.fromRGB(60, 200, 130)
		spawn.Parent = folder
	end

	-- East: ledges to mantle (3.6 -> 7.2 studs).
	makeLabel(folder, "LEDGES: jump at them / run into them", Vector3.new(50, 12, 0))
	for i, height in { 3.6, 5, 6.4, 7.2 } do
		makePart(folder, `Ledge{i}`, Vector3.new(10, height, 10), CFrame.new(50 + (i - 1) * 16, height / 2, 0), Color3.fromRGB(190, 140, 90))
	end

	-- West: wall-run corridor, gap wide enough to zig-zag with wall jumps.
	makeLabel(folder, "WALL RUN: sprint + jump toward a wall", Vector3.new(-60, 32, -26))
	for z, name in { [-20] = "WallA", [-34] = "WallB" } do
		makePart(folder, name, Vector3.new(80, 32, 2), CFrame.new(-80, 16, z), Color3.fromRGB(110, 150, 190))
	end

	-- South: a hill to slide down (climb it, then sprint + slide down the far side).
	makeLabel(folder, "SLIDE HILL: sprint downhill + C", Vector3.new(0, 24, 120))
	makeRamp(folder, "SlideHill", Vector3.new(0, 0, 150), 70, 26, 18, 0, Color3.fromRGB(150, 175, 120))

	-- Far east: gaps that need dash / double jump.
	makeLabel(folder, "GAPS: dash (Q) + double jump", Vector3.new(112, 14, -60))
	makePart(folder, "GapStart", Vector3.new(14, 6, 14), CFrame.new(112, 3, -60), Color3.fromRGB(160, 70, 90))
	local edge = 119
	for i, gap in { 10, 15, 20, 24 } do
		local centerX = edge + gap + 6
		makePart(folder, `GapPad{i}`, Vector3.new(12, 2, 12), CFrame.new(centerX, 5, -60), Color3.fromRGB(200, 90, 110))
		edge = centerX + 6
	end

	-- West: a tall tower to fall from and practise landing rolls (press C just before landing).
	makeLabel(folder, "DROP: fall + C before landing = roll", Vector3.new(-180, 46, 60))
	makePart(folder, "Tower", Vector3.new(24, 40, 24), CFrame.new(-180, 20, 60), Color3.fromRGB(120, 120, 150))
	makeRamp(folder, "TowerRamp", Vector3.new(-180, 0, 188.2), 123, 16, 19, 0, Color3.fromRGB(140, 140, 170))

	-- North: pillar forest, mostly there so NPC pathfinding has something to chew on.
	makeLabel(folder, "PILLARS: watch the NPCs route through", Vector3.new(0, 14, -120))
	local rng = Random.new(42)
	for i = 1, 46 do
		local px = rng:NextNumber(-70, 70)
		local pz = rng:NextNumber(-190, -80)
		local h = rng:NextNumber(6, 18)
		if rng:NextInteger(0, 1) == 0 then
			makePart(folder, `Pillar{i}`, Vector3.new(4, h, 4), CFrame.new(px, h / 2, pz), Color3.fromRGB(150, 150, 160))
		else
			makePart(
				folder,
				`Pillar{i}`,
				Vector3.new(h, 5, 5),
				CFrame.new(px, h / 2, pz) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(165, 150, 150),
				Enum.PartType.Cylinder
			)
		end
	end
end

return DevArena
