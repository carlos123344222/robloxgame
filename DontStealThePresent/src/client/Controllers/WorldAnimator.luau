-- Todo lo que se mueve en el mundo, animado en el cliente (suave y sin coste de red):
--   · regalos de la cinta (posición calculada con la hora del servidor), saltito al llegar a un pedestal,
--     flotar y girar en los pedestales, piezas que giran dentro de los regalos
--   · rayas de la cinta, engranajes de la fábrica, estrella del árbol gigante, cristal del altar
--   · luces que parpadean y piezas/textos arcoíris

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ClientState = require(script.Parent.Parent.ClientState)

local WorldAnimator = {}

type Tracked = {
	Model: Model,
	Root: BasePart,
	Mode: string,
	Home: CFrame,
	Phase: number,
	Spins: { { Weld: Weld, Base: CFrame, Speed: number, Axis: Vector3 } },
}

local tracked: { [Model]: Tracked } = {}
local rainbowParts: { [BasePart]: number } = {}
local rainbowGradients: { [UIGradient]: boolean } = {}

local stripes: { { Part: BasePart, X: number } } = {}
local stripeMin, stripeRange, stripeSpeed = 0, 1, 7

local gears: { { Part: BasePart, Base: CFrame, Speed: number, Children: { { Part: BasePart, Offset: CFrame } } } } = {}
local stars: { { Part: BasePart, Offset: CFrame } } = {}
local starCenter: CFrame? = nil
local floaters: { { Part: BasePart, Base: CFrame } } = {}
local bulbs: { BasePart } = {}

local ARRIVE_TIME = 0.9

local function collectSpins(model: Model)
	local spins = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and d.Name == "SpinWeld" then
			local axis = d:GetAttribute("SpinAxis")
			table.insert(spins, {
				Weld = d,
				Base = d.C0,
				Speed = (d:GetAttribute("SpinSpeed") :: number?) or 1,
				Axis = if typeof(axis) == "Vector3" then axis else Vector3.new(0, 1, 0),
			})
		end
	end
	return spins
end

local function track(model: Model)
	if tracked[model] then
		return
	end
	local mode = model:GetAttribute("Mode")
	if type(mode) ~= "string" or mode == "Carried" then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root") :: BasePart?
	if not root then
		return
	end
	tracked[model] = {
		Model = model,
		Root = root,
		Mode = mode,
		Home = root.CFrame,
		Phase = math.random() * math.pi * 2,
		Spins = collectSpins(model),
	}
end

local function onDescendant(instance: Instance)
	if instance:IsA("Model") and instance:GetAttribute("Mode") ~= nil then
		-- esperar a que lleguen las piezas
		task.defer(function()
			if instance.Parent then
				track(instance)
			end
		end)
	end
end

local function addRainbowPart(instance: Instance)
	if instance:IsA("BasePart") then
		rainbowParts[instance] = (instance:GetAttribute("HueOffset") :: number?) or math.random()
	end
end

local function addRainbowText(instance: Instance)
	local gradient = instance:FindFirstChildOfClass("UIGradient")
	if gradient then
		rainbowGradients[gradient] = true
	end
end

local function setupMap(map: Instance)
	local conveyor = map:FindFirstChild("Conveyor")
	local stripeFolder = conveyor and conveyor:FindFirstChild("Stripes")
	if stripeFolder then
		stripeMin = (stripeFolder:GetAttribute("MinX") :: number?) or -196
		local maxX = (stripeFolder:GetAttribute("MaxX") :: number?) or 196
		stripeRange = maxX - stripeMin
		for _, part in stripeFolder:GetChildren() do
			if part:IsA("BasePart") then
				table.insert(stripes, { Part = part, X = part.Position.X })
			end
		end
	end
	local gearByIndex: { [number]: any } = {}
	for _, part in CollectionService:GetTagged("SpinGear") do
		if part:IsA("BasePart") and part:IsDescendantOf(map) then
			local entry = { Part = part, Base = part.CFrame, Speed = (part:GetAttribute("SpinSpeed") :: number?) or 0.5, Children = {} }
			table.insert(gears, entry)
			gearByIndex[(part:GetAttribute("GearIndex") :: number?) or 0] = entry
		end
	end
	for _, tooth in CollectionService:GetTagged("SpinGearTooth") do
		if tooth:IsA("BasePart") then
			local gear = gearByIndex[(tooth:GetAttribute("Gear") :: number?) or -1]
			if gear then
				table.insert(gear.Children, { Part = tooth, Offset = gear.Base:Inverse() * tooth.CFrame })
			end
		end
	end
	local core: BasePart? = nil
	for _, part in CollectionService:GetTagged("SpinStar") do
		if part:IsA("BasePart") and part.Name == "StarCore" then
			core = part
		end
	end
	if core then
		starCenter = core.CFrame
		for _, part in CollectionService:GetTagged("SpinStar") do
			if part:IsA("BasePart") then
				table.insert(stars, { Part = part, Offset = core.CFrame:Inverse() * part.CFrame })
			end
		end
	end
	for _, part in CollectionService:GetTagged("FloatSpin") do
		if part:IsA("BasePart") then
			table.insert(floaters, { Part = part, Base = part.CFrame })
		end
	end
	for _, part in CollectionService:GetTagged("TwinkleBulb") do
		if part:IsA("BasePart") then
			table.insert(bulbs, part)
		end
	end
end

local function updatePresents(t: number, now: number)
	for model, entry in tracked do
		if not model.Parent then
			tracked[model] = nil
			continue
		end
		local mode = model:GetAttribute("Mode")
		if mode == "Carried" then
			tracked[model] = nil
			continue
		end
		local root = entry.Root
		if mode == "Belt" then
			local spawnT = (model:GetAttribute("SpawnT") :: number?) or now
			local speed = (model:GetAttribute("Speed") :: number?) or 7
			local startX = (model:GetAttribute("StartX") :: number?) or -190
			local endX = (model:GetAttribute("EndX") :: number?) or 190
			local beltZ = (model:GetAttribute("BeltZ") :: number?) or 0
			local beltY = (model:GetAttribute("BeltY") :: number?) or 2.6
			local x = startX + speed * (now - spawnT)
			local sink = 0
			if x > endX - 4 then
				sink = math.min(6, (x - (endX - 4)) * 1.2)
			end
			local wobble = math.sin(t * 3 + entry.Phase) * 0.06
			root.CFrame = CFrame.new(math.min(x, endX + 2), beltY - sink, beltZ) * CFrame.Angles(0, -math.pi / 2 + wobble, 0)
		elseif mode == "Slot" then
			local home = entry.Home
			local arriveT = model:GetAttribute("ArriveT") :: number?
			local from = model:GetAttribute("ArriveFrom") :: Vector3?
			if arriveT and from and now - arriveT < ARRIVE_TIME then
				local alpha = math.clamp((now - arriveT) / ARRIVE_TIME, 0, 1)
				local eased = 1 - (1 - alpha) * (1 - alpha)
				local position = from:Lerp(home.Position, eased) + Vector3.new(0, math.sin(alpha * math.pi) * 12, 0)
				root.CFrame = CFrame.new(position) * home.Rotation * CFrame.Angles(0, alpha * math.pi * 4, 0)
			else
				local bob = 0.35 + math.sin(t * 2 + entry.Phase) * 0.25
				root.CFrame = home * CFrame.new(0, bob, 0) * CFrame.Angles(0, math.sin(t * 0.7 + entry.Phase) * 0.6, 0)
			end
		end
		for _, spin in entry.Spins do
			if spin.Weld.Parent then
				spin.Weld.C0 = spin.Base * CFrame.fromAxisAngle(spin.Axis, t * spin.Speed)
			end
		end
	end
end

local twinkleTimer = 0

local function updateWorld(t: number, dt: number)
	-- rayas de la cinta
	local offset = t * stripeSpeed
	for _, stripe in stripes do
		local x = stripeMin + ((stripe.X - stripeMin + offset) % stripeRange)
		local cf = stripe.Part.CFrame
		stripe.Part.CFrame = CFrame.new(x, cf.Y, cf.Z)
	end
	-- engranajes
	for _, gear in gears do
		local cf = gear.Base * CFrame.Angles(t * gear.Speed, 0, 0)
		gear.Part.CFrame = cf
		for _, child in gear.Children do
			child.Part.CFrame = cf * child.Offset
		end
	end
	-- estrella del árbol
	if starCenter then
		local cf = starCenter * CFrame.Angles(0, t * 0.6, 0)
		for _, star in stars do
			star.Part.CFrame = cf * star.Offset
		end
	end
	for i, floater in floaters do
		floater.Part.CFrame = floater.Base * CFrame.new(0, math.sin(t * 1.4 + i) * 0.8, 0) * CFrame.Angles(0, t * 0.8, 0)
	end
	-- luces que parpadean
	twinkleTimer += dt
	if twinkleTimer > 0.12 and #bulbs > 0 then
		twinkleTimer = 0
		for _ = 1, math.min(40, #bulbs) do
			local bulb = bulbs[math.random(1, #bulbs)]
			bulb.Transparency = if bulb.Transparency > 0.1 then 0 else 0.55
		end
	end
	-- arcoíris
	local hueBase = t * 0.25
	for part, hueOffset in rainbowParts do
		if part.Parent then
			part.Color = Color3.fromHSV((hueBase + hueOffset) % 1, 0.75, 1)
		else
			rainbowParts[part] = nil
		end
	end
	local rotation = (t * 120) % 360
	for gradient in rainbowGradients do
		if gradient.Parent then
			gradient.Rotation = rotation
			gradient.Offset = Vector2.new(math.sin(t * 2) * 0.3, 0)
		else
			rainbowGradients[gradient] = nil
		end
	end
end

function WorldAnimator.Start()
	local map = workspace:WaitForChild("Map", 60)
	if map then
		setupMap(map)
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Mode") ~= nil then
			track(d)
		end
	end
	workspace.DescendantAdded:Connect(onDescendant)
	for _, part in CollectionService:GetTagged("Rainbow") do
		addRainbowPart(part)
	end
	CollectionService:GetInstanceAddedSignal("Rainbow"):Connect(addRainbowPart)
	for _, label in CollectionService:GetTagged("RainbowText") do
		addRainbowText(label)
	end
	CollectionService:GetInstanceAddedSignal("RainbowText"):Connect(function(label)
		task.defer(addRainbowText, label)
	end)
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		updatePresents(t, ClientState.Now())
		updateWorld(t, dt)
	end)
end

return WorldAnimator
