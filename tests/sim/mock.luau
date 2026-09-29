--!nocheck
-- Just enough of Roblox to run the real Locomotion modules headlessly: Vector3/CFrame/Enum/Instance
-- stand-ins, a box-only world with raycasts, and a simple Humanoid-like body with gravity, collision and
-- the LinearVelocity driver. It is NOT a physics engine; it exists to check logic (state transitions,
-- distances, timings) and to catch runtime errors that the type checker cannot.

local Mock = {}

-- Vector3 -----------------------------------------------------------------------------------------
local Vector3 = {}
local V3 = {}

local function isV3(v)
	return type(v) == "table" and getmetatable(v) == V3
end

function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end

V3.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	elseif k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m == 0 then
			return t
		end
		return Vector3.new(t.X / m, t.Y / m, t.Z / m)
	end
	return Vector3[k]
end
V3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return string.format("(%.2f, %.2f, %.2f)", a.X, a.Y, a.Z)
end
function Vector3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function Vector3.Cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

-- CFrame (position + row-major rotation) ------------------------------------------------------------
local CFrame = {}
local CF = {}

local function makeCF(p, r)
	return setmetatable({ _p = p, _r = r }, CF)
end
local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

function CFrame.new(a, b, c)
	if isV3(a) then
		return makeCF(a, IDENTITY)
	end
	return makeCF(Vector3.new(a or 0, b or 0, c or 0), IDENTITY)
end

local function matmul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end

function CFrame.Angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return makeCF(Vector3.zero, matmul(matmul(Rx, Ry), Rz))
end

CF.__index = function(t, k)
	if k == "Position" then
		return t._p
	elseif k == "LookVector" then
		return Vector3.new(-t._r[3], -t._r[6], -t._r[9])
	end
	return CFrame[k]
end
CF.__mul = function(a, b)
	if isV3(b) then
		local r = a._r
		return a._p + Vector3.new(r[1] * b.X + r[2] * b.Y + r[3] * b.Z, r[4] * b.X + r[5] * b.Y + r[6] * b.Z, r[7] * b.X + r[8] * b.Y + r[9] * b.Z)
	end
	local rotatedPosition = a * b._p
	return makeCF(rotatedPosition, matmul(a._r, b._r))
end

-- Enum / Instance / services -----------------------------------------------------------------------
local Enum = setmetatable({}, {
	__index = function(t, group)
		local enum = setmetatable({}, {
			__index = function(_, name)
				return group .. "." .. name
			end,
		})
		rawset(t, group, enum)
		return enum
	end,
})

local Instance = {}
function Instance.new(className)
	local object = { ClassName = className, Enabled = false }
	function object:Destroy()
		self.Destroyed = true
	end
	if className == "Animator" then
		function object:LoadAnimation(_animation)
			local track = { Priority = nil, Playing = false, Speed = 1 }
			function track:Play()
				self.Playing = true
			end
			function track:Stop()
				self.Playing = false
			end
			function track:AdjustSpeed(speed)
				self.Speed = speed
			end
			function track:Destroy() end
			return track
		end
	end
	return object
end

local Random = {}
function Random.new(seed)
	local rng = {}
	if seed then
		math.randomseed(seed)
	end
	function rng:NextNumber(a, b)
		return a + math.random() * (b - a)
	end
	function rng:NextInteger(a, b)
		return math.random(a, b)
	end
	return rng
end

local function fakeSignal()
	return {
		Connect = function()
			return { Disconnect = function() end, Connected = true }
		end,
	}
end

local RaycastParams = {}
function RaycastParams.new()
	return {}
end

-- World --------------------------------------------------------------------------------------------
local workspace = { Gravity = 196.2, _boxes = {} }
local clock = 0

function workspace:GetServerTimeNow()
	return clock
end

local function boxPart(box)
	local part = { Name = box.Name, _box = box }
	function part:GetAttribute(key)
		return box.Attributes and box.Attributes[key] or nil
	end
	function part:FindFirstAncestorOfClass()
		return nil
	end
	function part:IsA(className)
		return className == "BasePart" or className == "Part"
	end
	return part
end

function Mock.addBox(name, min, max, attributes)
	local box = { Name = name, Min = min, Max = max, Attributes = attributes }
	box.Part = boxPart(box)
	table.insert(workspace._boxes, box)
	return box
end

function Mock.clearBoxes()
	table.clear(workspace._boxes)
end

-- Ray vs axis-aligned boxes. Boxes containing the ray origin are ignored, like Roblox.
function workspace:Raycast(origin, direction, _params)
	local best
	for _, box in self._boxes do
		local tmin, tmax = 0, 1
		local normal
		local valid = true
		local inside = true
		for _, axis in { "X", "Y", "Z" } do
			local o, d = origin[axis], direction[axis]
			local lo, hi = box.Min[axis], box.Max[axis]
			if o < lo or o > hi then
				inside = false
			end
			if math.abs(d) < 1e-9 then
				if o < lo or o > hi then
					valid = false
					break
				end
			else
				local t1, t2 = (lo - o) / d, (hi - o) / d
				local sign = -1
				if t1 > t2 then
					t1, t2 = t2, t1
					sign = 1
				end
				if t1 > tmin then
					tmin = t1
					normal = { axis = axis, sign = sign }
				end
				tmax = math.min(tmax, t2)
				if tmin > tmax then
					valid = false
					break
				end
			end
		end
		if valid and not inside and normal and (best == nil or tmin < best.t) then
			best = { t = tmin, box = box, normal = normal }
		end
	end
	if not best then
		return nil
	end
	local n = Vector3.new(0, 0, 0)
	n = Vector3.new(best.normal.axis == "X" and best.normal.sign or 0, best.normal.axis == "Y" and best.normal.sign or 0, best.normal.axis == "Z" and best.normal.sign or 0)
	return {
		Instance = best.box.Part,
		Position = origin + direction * best.t,
		Normal = n,
		Distance = best.t * direction.Magnitude,
	}
end

-- Fake PathfindingService: 8-connected A* on a 4-stud grid. Boxes taller than 2.5 studs are obstacles.
local CELL = 4
local AGENT_RADIUS = 2.2
local function cellBlocked(ix, iz)
	local x, z = ix * CELL, iz * CELL
	for _, box in workspace._boxes do
		if box.Max.Y > 2.5 and box.Min.Y < 2.5 and x > box.Min.X - AGENT_RADIUS and x < box.Max.X + AGENT_RADIUS and z > box.Min.Z - AGENT_RADIUS and z < box.Max.Z + AGENT_RADIUS then
			return true
		end
	end
	return false
end

local function findPath(start, goal)
	local sx, sz = math.floor(start.X / CELL + 0.5), math.floor(start.Z / CELL + 0.5)
	local gx, gz = math.floor(goal.X / CELL + 0.5), math.floor(goal.Z / CELL + 0.5)
	local minX, maxX = math.min(sx, gx) - 30, math.max(sx, gx) + 30
	local minZ, maxZ = math.min(sz, gz) - 30, math.max(sz, gz) + 30
	local function key(x, z)
		return x * 100000 + z
	end
	local open, gScore, came, closed = {}, { [key(sx, sz)] = 0 }, {}, {}
	local function h(x, z)
		return math.sqrt((x - gx) ^ 2 + (z - gz) ^ 2)
	end
	local function push(x, z, f)
		table.insert(open, { x = x, z = z, f = f })
		local i = #open
		while i > 1 do
			local parent = i // 2
			if open[parent].f <= open[i].f then
				break
			end
			open[parent], open[i] = open[i], open[parent]
			i = parent
		end
	end
	local function pop()
		local top = open[1]
		local last = table.remove(open)
		if #open > 0 then
			open[1] = last
			local i = 1
			while true do
				local l, r, smallest = i * 2, i * 2 + 1, i
				if l <= #open and open[l].f < open[smallest].f then
					smallest = l
				end
				if r <= #open and open[r].f < open[smallest].f then
					smallest = r
				end
				if smallest == i then
					break
				end
				open[smallest], open[i] = open[i], open[smallest]
				i = smallest
			end
		end
		return top
	end
	push(sx, sz, h(sx, sz))
	local iterations = 0
	while #open > 0 and iterations < 40000 do
		iterations += 1
		local current = pop()
		local ck = key(current.x, current.z)
		if not closed[ck] then
			closed[ck] = true
			if current.x == gx and current.z == gz then
				local cells = { { current.x, current.z } }
				local node = came[ck]
				while node do
					table.insert(cells, 1, { node.x, node.z })
					node = came[key(node.x, node.z)]
				end
				return cells
			end
			for dx = -1, 1 do
				for dz = -1, 1 do
					if dx ~= 0 or dz ~= 0 then
						local nx, nz = current.x + dx, current.z + dz
						if nx >= minX and nx <= maxX and nz >= minZ and nz <= maxZ and not cellBlocked(nx, nz) then
							if dx == 0 or dz == 0 or (not cellBlocked(current.x + dx, current.z) and not cellBlocked(current.x, current.z + dz)) then
								local nk = key(nx, nz)
								local tentative = gScore[ck] + math.sqrt(dx * dx + dz * dz)
								if not closed[nk] and (gScore[nk] == nil or tentative < gScore[nk]) then
									gScore[nk] = tentative
									came[nk] = { x = current.x, z = current.z }
									push(nx, nz, tentative + h(nx, nz))
								end
							end
						end
					end
				end
			end
		end
	end
	return nil
end
Mock.findPath = findPath

local PathfindingService = {}
function PathfindingService:CreatePath(_params)
	local path = { Status = "PathStatus.NoPath", _waypoints = {}, Blocked = fakeSignal() }
	function path:ComputeAsync(start, goal)
		local cells = findPath(start, goal)
		if not cells then
			self.Status = "PathStatus.NoPath"
			return
		end
		local waypoints = { { Position = start, Action = "PathWaypointAction.Walk" } }
		for i = 2, #cells do
			table.insert(waypoints, { Position = Vector3.new(cells[i][1] * CELL, start.Y, cells[i][2] * CELL), Action = "PathWaypointAction.Walk" })
		end
		table.insert(waypoints, { Position = goal, Action = "PathWaypointAction.Walk" })
		self._waypoints = waypoints
		self.Status = "PathStatus.Success"
	end
	function path:GetWaypoints()
		return self._waypoints
	end
	return path
end

local services = {
	Workspace = workspace,
	Players = { GetPlayers = function() return {} end },
	PathfindingService = PathfindingService,
}
Mock.services = services
local game = {}
function game:GetService(name)
	services[name] = services[name] or {}
	return services[name]
end

-- Character body -----------------------------------------------------------------------------------
local HALF_WIDTH = 0.9
local FEET = 3.0
local HEAD = 2.4

local function overlapsAt(p)
	for _, box in workspace._boxes do
		if
			p.X + HALF_WIDTH > box.Min.X and p.X - HALF_WIDTH < box.Max.X
			and p.Y + HEAD > box.Min.Y and p.Y - FEET < box.Max.Y
			and p.Z + HALF_WIDTH > box.Min.Z and p.Z - HALF_WIDTH < box.Max.Z
		then
			return box
		end
	end
	return nil
end

local function approachVector(current, target, maxDelta)
	local delta = target - current
	local mag = delta.Magnitude
	if mag <= maxDelta or mag < 1e-9 then
		return target
	end
	return current + delta * (maxDelta / mag)
end

function Mock.newBody(position)
	local model = { ClassName = "Model", Name = "Character" }
	local humanoid = {
		ClassName = "Humanoid",
		Health = 100,
		Sit = false,
		HipHeight = 2,
		WalkSpeed = 16,
		JumpPower = 50,
		UseJumpPower = true,
		AutoRotate = true,
		Jump = false,
		FloorMaterial = Enum.Material.Air,
		Parent = model,
		_move = Vector3.zero,
		_state = "HumanoidStateType.Freefall",
		_jumpRequested = false,
		Died = fakeSignal(),
	}
	function humanoid:FindFirstChildOfClass()
		return nil
	end
	function humanoid:Move(direction, _relative)
		self._move = direction
	end
	function humanoid:GetState()
		return self._state
	end
	function humanoid:SetStateEnabled() end
	function humanoid:ChangeState(state)
		if state == Enum.HumanoidStateType.Jumping then
			self._jumpRequested = true
		end
	end

	local root = { ClassName = "Part", Size = Vector3.new(2, 2, 1), AssemblyLinearVelocity = Vector3.zero, AssemblyAngularVelocity = Vector3.zero, Parent = model }
	root._cf = CFrame.new(position)
	function root:IsA(className)
		return className == "BasePart" or className == "Part"
	end
	setmetatable(root, {
		__index = function(t, k)
			if k == "CFrame" then
				return rawget(t, "_cf")
			elseif k == "Position" then
				return rawget(t, "_cf")._p
			end
			return nil
		end,
		__newindex = function(t, k, v)
			if k == "CFrame" then
				rawset(t, "_cf", v)
			elseif k == "Position" then
				rawset(t, "_cf", makeCF(v, rawget(t, "_cf")._r))
			else
				rawset(t, k, v)
			end
		end,
	})
	humanoid.RootPart = root

	function model:FindFirstChildOfClass(className)
		if className == "Humanoid" then
			return humanoid
		end
		return nil
	end
	function model:FindFirstChild(name)
		if name == "HumanoidRootPart" then
			return root
		end
		return nil
	end
	local attributes = {}
	function model:SetAttribute(key, value)
		attributes[key] = value
	end
	function model:GetAttribute(key)
		return attributes[key]
	end

	return { model = model, humanoid = humanoid, root = root }
end

-- Advance the body one physics step (with sub-steps for collision stability).
function Mock.stepBody(body, dt)
	local sub = 4
	local h = dt / sub
	local root, humanoid = body.root, body.humanoid
	for _ = 1, sub do
		local v = root.AssemblyLinearVelocity
		local hv = Vector3.new(v.X, 0, v.Z)
		local vy = v.Y
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air

		local move = humanoid._move
		local magnitude = math.min(move.Magnitude, 1)
		local desired = Vector3.zero
		if magnitude > 0.001 then
			desired = move.Unit * (humanoid.WalkSpeed * magnitude)
		end
		if grounded then
			hv = approachVector(hv, desired, 250 * h)
		elseif magnitude > 0.001 then
			hv = approachVector(hv, desired, 25 * h)
		end

		if humanoid._jumpRequested then
			vy = humanoid.JumpPower
			humanoid._jumpRequested = false
			grounded = false
		end

		local drivesY = false
		local driver = body.driver
		if driver and driver.Enabled then
			local force = driver.MaxAxesForce
			local velocity = driver.VectorVelocity
			if force.X > 0 then
				hv = Vector3.new(velocity.X, 0, hv.Z)
			end
			if force.Z > 0 then
				hv = Vector3.new(hv.X, 0, velocity.Z)
			end
			if force.Y > 0 then
				vy = velocity.Y
				drivesY = true
			end
		end
		if not drivesY then
			vy -= workspace.Gravity * h
		end

		local pos = root.Position
		for _, axis in { "X", "Z" } do
			local delta = (axis == "X" and hv.X or hv.Z) * h
			local nextPos = pos + Vector3.new(axis == "X" and delta or 0, 0, axis == "Z" and delta or 0)
			local hit = overlapsAt(nextPos)
			if hit then
				local stepped
				local topAboveFeet = hit.Max.Y - (pos.Y - FEET)
				if topAboveFeet > 0.001 and topAboveFeet <= 1.0 then
					local candidate = Vector3.new(nextPos.X, hit.Max.Y + FEET + 0.01, nextPos.Z)
					if not overlapsAt(candidate) then
						stepped = candidate
					end
				end
				if stepped then
					pos = stepped
				else
					if axis == "X" then
						hv = Vector3.new(0, 0, hv.Z)
					else
						hv = Vector3.new(hv.X, 0, 0)
					end
				end
			else
				pos = nextPos
			end
		end

		local nextY = pos + Vector3.new(0, vy * h, 0)
		local hitY = overlapsAt(nextY)
		if hitY then
			if vy <= 0 then
				pos = Vector3.new(pos.X, hitY.Max.Y + FEET + 0.001, pos.Z)
			else
				pos = Vector3.new(pos.X, hitY.Min.Y - HEAD - 0.001, pos.Z)
			end
			vy = 0
		else
			pos = nextY
		end

		root.CFrame = makeCF(pos, root.CFrame._r)
		root.AssemblyLinearVelocity = Vector3.new(hv.X, vy, hv.Z)

		-- Floor detection: within a hair of a walkable top surface and not rising.
		local onFloor = false
		if vy <= 0.5 then
			local probe = Vector3.new(pos.X, pos.Y - 0.12, pos.Z)
			onFloor = overlapsAt(probe) ~= nil
		end
		humanoid.FloorMaterial = onFloor and Enum.Material.Plastic or Enum.Material.Air
		humanoid._state = onFloor and "HumanoidStateType.Running" or "HumanoidStateType.Freefall"
	end
end

function Mock.advanceClock(dt)
	clock += dt
end

-- Environment for the loaded modules --------------------------------------------------------------
-- (The Luau CLI's global table is read-only, so modules get their Roblox globals through setfenv.)
local realTypeof = typeof
function Mock.makeEnv()
	local env = {
		Vector3 = Vector3,
		CFrame = CFrame,
		Enum = Enum,
		Instance = Instance,
		RaycastParams = RaycastParams,
		game = game,
		workspace = workspace,
		warn = print,
		Random = Random,
		Color3 = {
			fromRGB = function(r, g, b)
				return { R = r / 255, G = g / 255, B = b / 255 }
			end,
			new = function(r, g, b)
				return { R = r, G = g, B = b }
			end,
		},
		task = {
			spawn = function(fn, ...)
				fn(...)
			end,
			delay = function() end,
			wait = function() end,
		},
		typeof = function(v)
			if isV3(v) then
				return "Vector3"
			end
			return realTypeof(v)
		end,
	}
	return setmetatable(env, { __index = getfenv(0) })
end

Mock.Vector3 = Vector3
Mock.CFrame = CFrame
Mock.Enum = Enum
Mock.workspace = workspace

return Mock
