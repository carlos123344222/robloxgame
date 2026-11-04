-- Gears: se compran en la tienda, se guardan y se dan al reaparecer. El servidor resuelve todos los
-- golpes e impactos (el cliente solo dice hacia dónde apunta).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Gears = require(Shared.Config.Gears)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Net.Remotes)

local ToolBuilder = require(script.Parent.Parent.World.ToolBuilder)
local DataService = require(script.Parent.DataService)
local CharacterService = require(script.Parent.CharacterService)
local StealService = require(script.Parent.StealService)

local GearService = {}

local templates: { [string]: Tool } = {}
local cooldowns: { [Player]: { [string]: number } } = {}
local projectileId = 0

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "Info")
end

local function onCooldown(player: Player, gearId: string, duration: number): boolean
	local list = cooldowns[player]
	if not list then
		list = {}
		cooldowns[player] = list
	end
	local t = os.clock()
	if (list[gearId] or 0) > t then
		return true
	end
	list[gearId] = t + duration * 0.92 -- un pelín de margen por la latencia
	return false
end

local function equippedGear(player: Player, gearId: string): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("GearId") == gearId then
			return child
		end
	end
	return nil
end

local function characterPlayer(instance: Instance): Player?
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			return player
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Golpe a otro jugador: suelta el regalo, empujón y efectos
local function hitPlayer(attacker: Player, victim: Player, direction: Vector3, force: number, freeze: number?, kind: string)
	local victimRoot = CharacterService.GetRoot(victim)
	if not victimRoot then
		return
	end
	local dropped = StealService.ForceDrop(victim, if kind == "Bat" then "¡Te han dado un bastonazo!" else "¡Te han congelado!")
	if dropped then
		notify(attacker, "🛡️ ¡Has hecho soltar el regalo a " .. victim.DisplayName .. "!", "Success")
		DataService.AddStat(attacker, "Defended", 1)
	end
	if freeze and freeze > 0 then
		CharacterService.Freeze(victim, freeze)
	end
	if force > 0 then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude < 0.01 then
			flat = Vector3.new(0, 0, 1)
		end
		Remotes.Event("Knockback"):FireClient(victim, flat.Unit * force + Vector3.new(0, force * 0.45, 0))
	end
	Remotes.Event("Fx"):FireAllClients("Hit", {
		Position = victimRoot.Position,
		Kind = kind,
	})
end

-- Bastón ----------------------------------------------------------------------------------------------------

local function swingBat(player: Player, tool: Tool)
	local info = Gears.List.CandyBat
	if onCooldown(player, "CandyBat", info.Cooldown) then
		return
	end
	local root = CharacterService.GetRoot(player)
	if not root or CharacterService.IsFrozen(player) then
		return
	end
	-- animación de golpe del Animate por defecto
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	task.delay(0.5, function()
		if anim.Parent then
			anim:Destroy()
		end
	end)
	Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Swing", Position = root.Position })

	local range = info.Range or 9
	local best: Player? = nil
	local bestDistance = math.huge
	local look = root.CFrame.LookVector
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = CharacterService.GetRoot(other)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance <= range then
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local facing = if flat.Magnitude > 0.01 then look:Dot(flat.Unit) else 1
					if (facing > 0.1 or distance < 4.5) and distance < bestDistance then
						best = other
						bestDistance = distance
					end
				end
			end
		end
	end
	if best then
		local otherRoot = CharacterService.GetRoot(best) :: BasePart
		hitPlayer(player, best, otherRoot.Position - root.Position, info.Knockback or 60, nil, "Bat")
	end
end

-- Bola de nieve ----------------------------------------------------------------------------------------------

local function throwSnowball(player: Player, target: Vector3)
	local info = Gears.List.Snowball
	if onCooldown(player, "Snowball", info.Cooldown) then
		return
	end
	local character = player.Character
	local root = CharacterService.GetRoot(player)
	if not character or not root or CharacterService.IsFrozen(player) then
		return
	end
	local origin = root.Position + Vector3.new(0, 1.6, 0) + root.CFrame.LookVector * 1.5
	local direction = target - origin
	if direction.Magnitude < 1 then
		direction = root.CFrame.LookVector
	end
	local speed = info.ProjectileSpeed or 120
	local velocity = direction.Unit * speed + Vector3.new(0, 6, 0)
	local gravity = Vector3.new(0, -workspace.Gravity * 0.2, 0)
	projectileId += 1
	local id = projectileId
	Remotes.Event("Fx"):FireAllClients("Projectile", { Id = id, Origin = origin, Velocity = velocity, Gravity = gravity, Kind = "Snowball" })
	Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Throw", Position = origin })

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { character }
	local carried = workspace:FindFirstChild("CarriedPresents")
	if carried then
		table.insert(exclude, carried)
	end
	params.FilterDescendantsInstances = exclude

	task.spawn(function()
		local position = origin
		local vel = velocity
		local elapsed = 0
		while elapsed < 2.2 do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			local step = vel * dt + gravity * (0.5 * dt * dt)
			-- un poco de radio: spherecast
			local result = workspace:Spherecast(position, 0.6, step, params)
			if result then
				local victim = characterPlayer(result.Instance)
				Remotes.Event("Fx"):FireAllClients("SnowBurst", { Id = id, Position = result.Position })
				if victim and victim ~= player then
					hitPlayer(player, victim, vel, info.Knockback or 20, info.FreezeTime, "Snowball")
				end
				return
			end
			position += step
			vel += gravity * dt
		end
		Remotes.Event("Fx"):FireAllClients("SnowBurst", { Id = id, Position = position })
	end)
end

-- Rayo congelador -------------------------------------------------------------------------------------------

local function fireFreezeRay(player: Player, tool: Tool, target: Vector3)
	local info = Gears.List.FreezeRay
	if onCooldown(player, "FreezeRay", info.Cooldown) then
		notify(player, "🧊 El rayo se está recargando...", "Info")
		return
	end
	local character = player.Character
	local root = CharacterService.GetRoot(player)
	if not character or not root or CharacterService.IsFrozen(player) then
		return
	end
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local muzzle = handle and handle:FindFirstChild("Muzzle") :: Attachment?
	local origin = if muzzle then muzzle.WorldPosition else root.Position + Vector3.new(0, 1.5, 0)
	local direction = target - origin
	if direction.Magnitude < 1 then
		direction = root.CFrame.LookVector
	end
	direction = direction.Unit * (info.Range or 150)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { character }
	local carried = workspace:FindFirstChild("CarriedPresents")
	if carried then
		table.insert(exclude, carried)
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Spherecast(origin, 1.2, direction, params)
	local hitPosition = if result then result.Position else origin + direction
	Remotes.Event("Fx"):FireAllClients("Beam", { From = origin, To = hitPosition, Color = info.Color })
	Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Zap", Position = origin })
	if result then
		local victim = characterPlayer(result.Instance)
		if victim and victim ~= player then
			hitPlayer(player, victim, direction, 10, info.FreezeTime, "Freeze")
			Remotes.Event("Fx"):FireAllClients("Sound", { Name = "Freeze", Position = hitPosition })
		end
	end
end

-- Dar herramientas -----------------------------------------------------------------------------------------

local function hookTool(player: Player, tool: Tool)
	local gearId = tool:GetAttribute("GearId")
	if gearId == "CandyBat" then
		tool.Activated:Connect(function()
			swingBat(player, tool)
		end)
	elseif gearId == "ReindeerBoots" then
		tool.Equipped:Connect(function()
			CharacterService.SetFlag(player, "Boots", true)
		end)
		tool.Unequipped:Connect(function()
			CharacterService.SetFlag(player, "Boots", false)
		end)
	elseif gearId == "JingleBell" then
		tool.Equipped:Connect(function()
			CharacterService.SetFlag(player, "Bell", true)
		end)
		tool.Unequipped:Connect(function()
			CharacterService.SetFlag(player, "Bell", false)
		end)
	end
end

local function hasTool(player: Player, gearId: string): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in { backpack, player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("GearId") == gearId then
					return true
				end
			end
		end
	end
	return false
end

function GearService.Give(player: Player, gearId: string)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local template = templates[gearId]
	if not backpack or not template or hasTool(player, gearId) then
		return
	end
	local tool = template:Clone()
	hookTool(player, tool)
	tool.Parent = backpack
end

function GearService.GiveOwned(player: Player)
	local data = DataService.Get(player)
	for _, gearId in Gears.Order do
		if gearId == "CandyBat" or (data and data.Gears[gearId]) then
			GearService.Give(player, gearId)
		end
	end
end

function GearService.Track(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		task.wait(0.1)
		if player.Parent then
			GearService.GiveOwned(player)
		end
	end)
	if player.Character then
		task.spawn(GearService.GiveOwned, player)
	end
end

function GearService.OnLoaded(player: Player)
	GearService.GiveOwned(player)
end

function GearService.Buy(player: Player, gearId: string): (boolean, string)
	local info = Gears.Get(gearId)
	local data = DataService.Get(player)
	if not info or not data then
		return false, "No disponible"
	end
	if data.Gears[gearId] then
		GearService.Give(player, gearId)
		return false, "Ya lo tienes"
	end
	if not DataService.SpendCash(player, info.Price) then
		return false, "Te faltan " .. Format.Cash(info.Price - data.Cash)
	end
	data.Gears[gearId] = true
	DataService.MarkChanged(player)
	GearService.Give(player, gearId)
	notify(player, info.Icon .. " ¡Has comprado " .. info.FullName .. "! Ya está en tu mochila.", "Success")
	Remotes.Event("Fx"):FireClient(player, "Sound", { Name = "Buy" })
	return true, "OK"
end

function GearService.Start()
	for _, gearId in Gears.Order do
		templates[gearId] = ToolBuilder.Build(gearId)
	end

	Remotes.Function("BuyGear").OnServerInvoke = function(player, gearId)
		if type(gearId) ~= "string" then
			return false, "Petición inválida"
		end
		return GearService.Buy(player, gearId)
	end

	Remotes.Event("UseGear").OnServerEvent:Connect(function(player, gearId, target)
		if type(gearId) ~= "string" or typeof(target) ~= "Vector3" then
			return
		end
		if target.Magnitude ~= target.Magnitude or target.Magnitude > 1e5 then
			return
		end
		local tool = equippedGear(player, gearId)
		if not tool then
			return
		end
		if gearId == "Snowball" then
			throwSnowball(player, target)
		elseif gearId == "FreezeRay" then
			fireFreezeRay(player, tool, target)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return GearService
