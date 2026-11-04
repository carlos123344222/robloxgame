--!nocheck
-- Emulador mínimo del motor de Roblox para ejecutar el juego sin Studio (dentro de Lune).
--
-- Las instancias se validan contra el volcado oficial de la API (Full-API-Dump.json): leer o escribir un
-- miembro que no existe, asignar un tipo incorrecto, usar un Enum que no corresponde, crear una clase que
-- no se puede crear o reparentar algo destruido da el mismo error que daría Roblox.
-- Los tipos de datos (Vector3, CFrame, Color3, Enum...) son los de @lune/roblox.
--
-- No hay física ni render: los métodos que no están implementados devuelven nil y se apuntan en
-- Emu.Stubs para revisarlos.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local luauLib = require("@lune/luau")
local taskLib = require("@lune/task")

local Emu = {}
Emu.Errors = {}
Emu.Warnings = {}
Emu.Stubs = {}
Emu.Quiet = true

local NIL = newproxy(false)
local data = setmetatable({}, { __mode = "k" })
local classes = {}
local memberCache = {}

-- Errores -----------------------------------------------------------------------------------------------

local function record(kind: string, message: string)
	table.insert(Emu.Errors, { Kind = kind, Message = message })
	print("\27[31m[" .. kind .. "]\27[0m " .. message)
end
Emu.Record = record

local function wrap(fn, label)
	return function(...)
		local ok, err = xpcall(fn, debug.traceback, ...)
		if not ok then
			record(label or "error", tostring(err))
		end
	end
end
Emu.Wrap = wrap

-- API ----------------------------------------------------------------------------------------------------

function Emu.LoadApi(path: string)
	local dump = serde.decode("json", fs.readFile(path))
	for _, c in dump.Classes do
		local members = {}
		for _, m in c.Members do
			members[m.Name] = m
		end
		local tags = {}
		for _, t in c.Tags or {} do
			if type(t) == "string" then
				tags[t] = true
			end
		end
		classes[c.Name] = { Name = c.Name, Superclass = c.Superclass, Members = members, Tags = tags }
	end
end

local function findMember(className: string, name: string)
	local key = className .. "." .. name
	local cached = memberCache[key]
	if cached ~= nil then
		return cached or nil
	end
	local c = classes[className]
	while c do
		local m = c.Members[name]
		if m then
			memberCache[key] = m
			return m
		end
		c = classes[c.Superclass]
	end
	memberCache[key] = false
	return nil
end

local function classIsA(className: string, base: string): boolean
	local c = classes[className]
	while c do
		if c.Name == base then
			return true
		end
		c = classes[c.Superclass]
	end
	return false
end
Emu.ClassIsA = classIsA

local function hasTag(m, tag)
	for _, t in m.Tags or {} do
		if t == tag then
			return true
		end
	end
	return false
end

local function securityOk(m, mode: string): boolean
	local sec = m.Security
	if type(sec) == "table" then
		sec = sec[mode]
	end
	return sec == nil or sec == "None"
end

-- Señales -------------------------------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal
local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	self.Connected = false
	self._signal.Handlers[self] = nil
end

local function newSignal(name)
	return setmetatable({ Handlers = {}, Waiting = {}, Name = name }, Signal)
end
Emu.NewSignal = newSignal

function Signal:Connect(fn)
	assert(type(fn) == "function", "Attempt to connect failed: Passed value is not a function")
	local c = setmetatable({ Connected = true, _signal = self }, Connection)
	self.Handlers[c] = fn
	return c
end
Signal.connect = Signal.Connect
function Signal:ConnectParallel(fn)
	return self:Connect(fn)
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Wait()
	local thread = coroutine.running()
	table.insert(self.Waiting, thread)
	return coroutine.yield()
end
function Signal:Fire(...)
	for c, fn in self.Handlers do
		if c.Connected then
			taskLib.spawn(wrap(fn, "event " .. tostring(self.Name)), ...)
		end
	end
	local waiting = self.Waiting
	self.Waiting = {}
	for _, thread in waiting do
		taskLib.spawn(thread, ...)
	end
end
function Signal:HasHandlers()
	return next(self.Handlers) ~= nil or #self.Waiting > 0
end

-- Tipos extra que Lune no trae ----------------------------------------------------------------------------

local customTypes = setmetatable({}, { __mode = "k" })

local function custom(typeName, tbl)
	customTypes[tbl] = typeName
	return tbl
end

local RandomMT = {}
RandomMT.__index = RandomMT
local function lcg(self)
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function RandomMT:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * lcg(self)
end
function RandomMT:NextInteger(a, b)
	return math.min(b, a + math.floor(lcg(self) * (b - a + 1)))
end
function RandomMT:Clone()
	return custom("Random", setmetatable({ s = self.s }, RandomMT))
end
local RandomLib = {
	new = function(seed)
		local s = math.floor(seed or (os.clock() * 100000)) % 2147483647
		if s <= 0 then
			s += 12345
		end
		return custom("Random", setmetatable({ s = s }, RandomMT))
	end,
}

local TweenInfoLib = {
	new = function(time, style, direction, repeatCount, reverses, delayTime)
		return custom("TweenInfo", {
			Time = time or 1,
			EasingStyle = style or roblox.Enum.EasingStyle.Quad,
			EasingDirection = direction or roblox.Enum.EasingDirection.Out,
			RepeatCount = repeatCount or 0,
			Reverses = reverses or false,
			DelayTime = delayTime or 0,
		})
	end,
}

local RaycastParamsLib = {
	new = function()
		return custom("RaycastParams", {
			FilterType = roblox.Enum.RaycastFilterType.Exclude,
			FilterDescendantsInstances = {},
			IgnoreWater = false,
			CollisionGroup = "Default",
			RespectCanCollide = false,
		})
	end,
}

local OverlapParamsLib = {
	new = function()
		return custom("OverlapParams", { FilterType = roblox.Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, MaxParts = 0 })
	end,
}

local function emuTypeof(v)
	if data[v] then
		return "Instance"
	end
	local t = customTypes[v]
	if t then
		return t
	end
	local mt = getmetatable(v)
	if mt == Signal then
		return "RBXScriptSignal"
	elseif mt == Connection then
		return "RBXScriptConnection"
	end
	return typeof(v)
end
Emu.typeof = emuTypeof

-- Instancias --------------------------------------------------------------------------------------------

local InstanceMT = {}
local getters = {}
local setters = {}
local impl = {}
local tagMap = {}
local tagSignals = {}

Emu.Data = data

local function isInstance(v)
	return data[v] ~= nil
end
Emu.IsInstance = isInstance

local function fullName(inst)
	local d = data[inst]
	local parts = {}
	while d do
		table.insert(parts, 1, d.Name)
		local p = d.Parent
		if not p or data[p].Class == "DataModel" then
			break
		end
		d = data[p]
	end
	return table.concat(parts, ".")
end
Emu.FullName = fullName

local function newInstance(className: string, internal: boolean?)
	local c = classes[className]
	if not c then
		error(string.format('Unable to create an Instance of type "%s"', tostring(className)), 3)
	end
	if not internal and (c.Tags.NotCreatable or c.Tags.Service) then
		error(string.format('Unable to create an Instance of type "%s"', className), 3)
	end
	local self = setmetatable({}, InstanceMT)
	data[self] = {
		Class = className,
		Name = className,
		Parent = nil,
		Children = {},
		Props = {},
		Attrs = {},
		Tags = {},
		Signals = {},
		PropSignals = {},
		AttrSignals = {},
		Locked = false,
	}
	return self
end
Emu.New = newInstance

local function getSignal(d, name)
	local s = d.Signals[name]
	if not s then
		s = newSignal(d.Class .. "." .. name)
		d.Signals[name] = s
	end
	return s
end

function Emu.Fire(inst, eventName, ...)
	local d = data[inst]
	assert(d, "Emu.Fire: no es una instancia")
	assert(findMember(d.Class, eventName), eventName .. " no es un evento de " .. d.Class)
	getSignal(d, eventName):Fire(...)
end

local function firePropChanged(d, key)
	local s = d.PropSignals[key]
	if s then
		s:Fire()
	end
	local changed = d.Signals.Changed
	if changed then
		changed:Fire(key)
	end
end

local function isDescendantOf(inst, ancestor)
	local p = data[inst].Parent
	while p do
		if p == ancestor then
			return true
		end
		p = data[p].Parent
	end
	return false
end

local function forEachDescendant(inst, fn)
	for _, child in data[inst].Children do
		fn(child)
		forEachDescendant(child, fn)
	end
end

local function setParent(inst, newParent)
	local d = data[inst]
	if d.Locked then
		error(string.format("The Parent property of %s is locked, current parent: NULL, new parent %s", d.Name, if newParent then data[newParent].Name else "NULL"), 3)
	end
	if newParent ~= nil and not isInstance(newParent) then
		error("Unable to assign property Parent. Instance expected, got " .. emuTypeof(newParent), 3)
	end
	if newParent == inst or (newParent and isDescendantOf(newParent, inst)) then
		error("Attempt to set " .. d.Name .. " as its own parent", 3)
	end
	local old = d.Parent
	if old == newParent then
		return
	end
	if old then
		local siblings = data[old].Children
		for i, child in siblings do
			if child == inst then
				table.remove(siblings, i)
				break
			end
		end
		local removed = data[old].Signals.ChildRemoved
		if removed then
			removed:Fire(inst)
		end
	end
	d.Parent = newParent
	if newParent then
		table.insert(data[newParent].Children, inst)
		local pd = data[newParent]
		if pd.Signals.ChildAdded then
			pd.Signals.ChildAdded:Fire(inst)
		end
		-- DescendantAdded en los antepasados que lo escuchan
		local ancestor = newParent
		while ancestor do
			local ad = data[ancestor]
			local sig = ad.Signals.DescendantAdded
			if sig and sig:HasHandlers() then
				sig:Fire(inst)
				forEachDescendant(inst, function(x)
					sig:Fire(x)
				end)
			end
			ancestor = ad.Parent
		end
	end
	if d.Signals.AncestryChanged then
		d.Signals.AncestryChanged:Fire(inst, newParent)
	end
	firePropChanged(d, "Parent")
end

local function findChild(d, name)
	for _, child in d.Children do
		if data[child].Name == name then
			return child
		end
	end
	return nil
end

-- Valores por defecto
local function parseDefault(vt, str)
	if type(str) ~= "string" or string.sub(str, 1, 10) == "__api_dump" then
		return nil
	end
	local cat, name = vt.Category, vt.Name
	if cat == "Primitive" then
		if name == "bool" then
			return str == "true"
		elseif name == "string" then
			return str
		else
			return tonumber(str)
		end
	elseif cat == "Enum" then
		local ok, item = pcall(function()
			return roblox.Enum[name]:FromName(str)
		end)
		return if ok then item else nil
	elseif cat == "DataType" then
		local nums = {}
		for n in string.gmatch(str, "[-%d%.e]+") do
			table.insert(nums, tonumber(n))
		end
		if name == "Vector3" and #nums == 3 then
			return roblox.Vector3.new(nums[1], nums[2], nums[3])
		elseif name == "Vector2" and #nums == 2 then
			return roblox.Vector2.new(nums[1], nums[2])
		elseif name == "Color3" and #nums == 3 then
			return roblox.Color3.new(nums[1], nums[2], nums[3])
		elseif name == "UDim2" and #nums == 4 then
			return roblox.UDim2.new(nums[1], nums[2], nums[3], nums[4])
		elseif name == "UDim" and #nums == 2 then
			return roblox.UDim.new(nums[1], nums[2])
		elseif name == "Content" or name == "ContentId" then
			return str
		end
	end
	return nil
end

local OVERRIDES = {
	Visible = true,
	Enabled = true,
	Archivable = true,
	Health = 100,
	MaxHealth = 100,
	WalkSpeed = 16,
	JumpHeight = 7.2,
	JumpPower = 50,
	CanCollide = true,
	CanQuery = true,
	CanTouch = true,
	Scale = 1,
	Volume = 0.5,
	FieldOfView = 70,
	PlaybackSpeed = 1,
	Gravity = 196.2,
	Brightness = 1,
	TextScaled = false,
	RequiresHandle = true,
	CanBeDropped = true,
	CharacterAutoLoads = true,
	Thickness = 1,
	Size = nil,
}

local function typeDefault(vt)
	local cat, name = vt.Category, vt.Name
	if cat == "Primitive" then
		if name == "bool" then
			return false
		elseif name == "string" then
			return ""
		else
			return 0
		end
	elseif cat == "Enum" then
		local ok, items = pcall(function()
			return roblox.Enum[name]:GetEnumItems()
		end)
		return if ok then items[1] else nil
	elseif cat == "DataType" then
		local map = {
			Vector3 = function()
				return roblox.Vector3.zero
			end,
			Vector2 = function()
				return roblox.Vector2.zero
			end,
			CFrame = function()
				return roblox.CFrame.new()
			end,
			Color3 = function()
				return roblox.Color3.new(1, 1, 1)
			end,
			UDim2 = function()
				return roblox.UDim2.new()
			end,
			UDim = function()
				return roblox.UDim.new()
			end,
			NumberRange = function()
				return roblox.NumberRange.new(0)
			end,
			NumberSequence = function()
				return roblox.NumberSequence.new(0)
			end,
			ColorSequence = function()
				return roblox.ColorSequence.new(roblox.Color3.new(1, 1, 1))
			end,
			Content = function()
				return ""
			end,
			ContentId = function()
				return ""
			end,
			Font = function()
				return roblox.Font.fromEnum(roblox.Enum.Font.SourceSans)
			end,
		}
		local f = map[name]
		return if f then f() else nil
	end
	return nil
end

local defaultCache = {}
local function defaultFor(className, key, m)
	local cacheKey = className .. "." .. key
	local cached = defaultCache[cacheKey]
	if cached ~= nil then
		return if cached == NIL then nil else cached
	end
	local value = nil
	local own = classes[className] and classes[className].Members[key]
	if own then
		value = parseDefault(own.ValueType, own.Default)
	end
	if value == nil and OVERRIDES[key] ~= nil then
		value = OVERRIDES[key]
	end
	if value == nil and key == "Size" and classIsA(className, "BasePart") then
		value = roblox.Vector3.new(4, 1, 2)
	end
	if value == nil and key == "Color" and classIsA(className, "BasePart") then
		value = roblox.Color3.fromRGB(163, 162, 165)
	end
	if value == nil then
		value = typeDefault(m.ValueType)
	end
	defaultCache[cacheKey] = if value == nil then NIL else value
	return value
end

local function checkValue(d, key, m, value)
	local vt = m.ValueType
	local cat, name = vt.Category, vt.Name
	local function fail()
		error(string.format("Unable to assign property %s. %s expected, got %s", key, name, emuTypeof(value)), 4)
	end
	if cat == "Primitive" then
		if name == "bool" then
			if type(value) ~= "boolean" then
				fail()
			end
		elseif name == "string" then
			if type(value) == "number" then
				return tostring(value)
			elseif type(value) ~= "string" then
				fail()
			end
		elseif name == "float" or name == "double" or name == "int" or name == "int64" then
			if type(value) ~= "number" then
				fail()
			end
			if value ~= value then
				record("nan", "NaN asignado a " .. d.Class .. "." .. key)
			end
		end
	elseif cat == "DataType" then
		if name == "Content" or name == "ContentId" then
			if type(value) ~= "string" then
				fail()
			end
		elseif value == nil then
			if name ~= "PhysicalProperties" then
				fail()
			end
		else
			local t = emuTypeof(value)
			if t ~= name then
				fail()
			end
			if t == "CFrame" then
				local look = value.LookVector
				if value.X ~= value.X or look.X ~= look.X or look.Y ~= look.Y then
					record("nan", "CFrame con NaN asignado a " .. d.Class .. "." .. key)
				end
			elseif t == "Vector3" and (value.X ~= value.X or value.Y ~= value.Y or value.Z ~= value.Z) then
				record("nan", "Vector3 con NaN asignado a " .. d.Class .. "." .. key)
			end
		end
	elseif cat == "Enum" then
		if emuTypeof(value) == "EnumItem" then
			local enumName = string.match(tostring(value.EnumType), "Enum%.([%w_]+)")
			if enumName ~= name then
				fail()
			end
		elseif type(value) == "string" then
			local ok, item = pcall(function()
				return roblox.Enum[name]:FromName(value)
			end)
			if not ok or not item then
				fail()
			end
			return item
		elseif type(value) == "number" then
			return value
		else
			fail()
		end
	elseif cat == "Class" then
		if value ~= nil then
			if not isInstance(value) or not classIsA(data[value].Class, name) then
				fail()
			end
		end
	end
	return value
end

local function rawProp(d, key)
	local v = d.Props[key]
	if v == NIL then
		return nil, true
	end
	return v, v ~= nil
end

local function getProp(inst, key)
	local d = data[inst]
	local v, set = rawProp(d, key)
	if set then
		return v
	end
	local m = findMember(d.Class, key)
	if not m then
		return nil
	end
	local getter = getters[key]
	if getter then
		local ok, gv = getter(inst, d)
		if ok then
			return gv
		end
	end
	return defaultFor(d.Class, key, m)
end
Emu.Get = getProp

local function setRaw(inst, key, value)
	local d = data[inst]
	if key == "Name" then
		d.Name = value
	elseif key == "Parent" then
		setParent(inst, value)
		return
	else
		d.Props[key] = if value == nil then NIL else value
	end
	firePropChanged(d, key)
end
Emu.Set = setRaw

local function methodFor(className, name)
	local c = classes[className]
	while c do
		local cls = impl[c.Name]
		if cls and cls[name] then
			return cls[name]
		end
		c = classes[c.Superclass]
	end
	return function()
		local key = className .. ":" .. name
		Emu.Stubs[key] = (Emu.Stubs[key] or 0) + 1
		return nil
	end
end

InstanceMT.__index = function(self, key)
	local d = data[self]
	if key == "ClassName" then
		return d.Class
	elseif key == "Name" then
		return d.Name
	elseif key == "Parent" then
		return d.Parent
	end
	if type(key) ~= "string" then
		error("invalid key", 2)
	end
	local m = findMember(d.Class, key)
	if m then
		local kind = m.MemberType
		if kind == "Property" then
			if not securityOk(m, "Read") then
				error(string.format("The current thread cannot access '%s' (lacking capability)", key), 2)
			end
			local getter = getters[key]
			if getter then
				local ok, v = getter(self, d)
				if ok then
					return v
				end
			end
			local v, set = rawProp(d, key)
			if set then
				return v
			end
			return defaultFor(d.Class, key, m)
		elseif kind == "Function" then
			if not securityOk(m) then
				error(string.format("The current thread cannot call '%s' (lacking capability)", key), 2)
			end
			return methodFor(d.Class, key)
		elseif kind == "Event" then
			return getSignal(d, key)
		elseif kind == "Callback" then
			local v = rawProp(d, key)
			return v
		end
	end
	local child = findChild(d, key)
	if child then
		return child
	end
	error(string.format('%s is not a valid member of %s "%s"', tostring(key), d.Class, fullName(self)), 2)
end

InstanceMT.__newindex = function(self, key, value)
	local d = data[self]
	if key == "Parent" then
		setParent(self, value)
		return
	elseif key == "Name" then
		if type(value) ~= "string" and type(value) ~= "number" then
			error("Unable to assign property Name. string expected, got " .. emuTypeof(value), 2)
		end
		d.Name = tostring(value)
		firePropChanged(d, "Name")
		return
	end
	local m = findMember(d.Class, key)
	if not m then
		error(string.format('%s is not a valid member of %s "%s"', tostring(key), d.Class, fullName(self)), 2)
	end
	if m.MemberType == "Callback" then
		d.Props[key] = value
		return
	end
	if m.MemberType ~= "Property" then
		error(string.format("%s is a %s, not a property", key, m.MemberType), 2)
	end
	if not securityOk(m, "Write") then
		error(string.format("The current thread cannot write '%s' (lacking capability)", key), 2)
	end
	if hasTag(m, "ReadOnly") then
		error(string.format("Unable to assign property %s. Property is read only", key), 2)
	end
	value = checkValue(d, key, m, value)
	local setter = setters[key]
	if setter and setter(self, d, value) then
		firePropChanged(d, key)
		return
	end
	d.Props[key] = if value == nil then NIL else value
	firePropChanged(d, key)
end

InstanceMT.__tostring = function(self)
	return data[self].Name
end

-- Propiedades derivadas -----------------------------------------------------------------------------------

local function isClass(d, base)
	return classIsA(d.Class, base)
end

getters.Position = function(inst, d)
	if isClass(d, "BasePart") or isClass(d, "Attachment") then
		return true, getProp(inst, "CFrame").Position
	end
	return false
end
setters.Position = function(inst, d, value)
	if isClass(d, "BasePart") or isClass(d, "Attachment") then
		local cf = getProp(inst, "CFrame")
		d.Props.CFrame = roblox.CFrame.new(value) * cf.Rotation
		return true
	end
	return false
end
getters.Orientation = function(inst, d)
	if isClass(d, "BasePart") or isClass(d, "Attachment") then
		local rx, ry, rz = getProp(inst, "CFrame"):ToOrientation()
		return true, roblox.Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz))
	end
	return false
end
getters.WorldPosition = function(inst, d)
	if isClass(d, "Attachment") then
		local parent = d.Parent
		local base = if parent and isClass(data[parent], "BasePart") then getProp(parent, "CFrame") else roblox.CFrame.new()
		return true, (base * getProp(inst, "CFrame")).Position
	end
	return false
end
getters.WorldCFrame = function(inst, d)
	if isClass(d, "Attachment") then
		local parent = d.Parent
		local base = if parent and isClass(data[parent], "BasePart") then getProp(parent, "CFrame") else roblox.CFrame.new()
		return true, base * getProp(inst, "CFrame")
	end
	return false
end
setters.WorldCFrame = function(_, d, value)
	if isClass(d, "Attachment") then
		local parent = d.Parent
		local base = if parent and isClass(data[parent], "BasePart") then getProp(parent, "CFrame") else roblox.CFrame.new()
		d.Props.CFrame = base:Inverse() * value
		return true
	end
	return false
end
getters.RootPart = function(_, d)
	if isClass(d, "Humanoid") then
		local parent = d.Parent
		return true, if parent then findChild(data[parent], "HumanoidRootPart") else nil
	end
	return false
end
getters.AbsoluteSize = function()
	return true, roblox.Vector2.new(100, 40)
end
getters.AbsolutePosition = function()
	return true, roblox.Vector2.zero
end
getters.ViewportSize = function()
	return true, roblox.Vector2.new(1280, 720)
end
getters.LocalPlayer = function(_, d)
	if d.Class == "Players" then
		return true, Emu.LocalPlayer
	end
	return false
end
getters.Hit = function(_, d)
	if isClass(d, "Mouse") then
		return true, Emu.MouseHit or roblox.CFrame.new(0, 0, -50)
	end
	return false
end
getters.Terrain = function(inst, d)
	if d.Class == "Workspace" then
		local terrain = findChild(d, "Terrain")
		if not terrain then
			terrain = newInstance("Terrain", true)
			data[terrain].Name = "Terrain"
			setParent(terrain, inst)
		end
		return true, terrain
	end
	return false
end
getters.CurrentCamera = function(inst, d)
	if d.Class == "Workspace" then
		local v, set = rawProp(d, "CurrentCamera")
		if set and v then
			return true, v
		end
		local camera = newInstance("Camera")
		data[camera].Name = "Camera"
		setParent(camera, inst)
		d.Props.CurrentCamera = camera
		return true, camera
	end
	return false
end

-- Métodos ---------------------------------------------------------------------------------------------------

local function cloneTree(inst, map)
	local d = data[inst]
	if getProp(inst, "Archivable") == false then
		return nil
	end
	local copy = newInstance(d.Class, true)
	local cd = data[copy]
	cd.Name = d.Name
	for k, v in d.Props do
		cd.Props[k] = v
	end
	for k, v in d.Attrs do
		cd.Attrs[k] = v
	end
	for k in d.Tags do
		cd.Tags[k] = true
		tagMap[k] = tagMap[k] or setmetatable({}, { __mode = "k" })
		tagMap[k][copy] = true
	end
	cd.Source = d.Source
	map[inst] = copy
	for _, child in d.Children do
		local c = cloneTree(child, map)
		if c then
			data[c].Parent = copy
			table.insert(cd.Children, c)
		end
	end
	return copy
end

local function destroy(inst)
	local d = data[inst]
	for _, child in table.clone(d.Children) do
		destroy(child)
	end
	if d.Parent then
		setParent(inst, nil)
	end
	d.Locked = true
	d.Destroyed = true
	for _, s in d.Signals do
		s.Handlers = {}
	end
	if d.Signals.Destroying then
		d.Signals.Destroying:Fire()
	end
end

impl.Instance = {
	Destroy = function(self)
		destroy(self)
	end,
	Remove = function(self)
		setParent(self, nil)
	end,
	ClearAllChildren = function(self)
		for _, child in table.clone(data[self].Children) do
			destroy(child)
		end
	end,
	Clone = function(self)
		local map = {}
		local copy = cloneTree(self, map)
		if not copy then
			return nil
		end
		-- reapuntar referencias internas (Weld.Part0, Model.PrimaryPart...)
		for _, new in map do
			local nd = data[new]
			for k, v in nd.Props do
				if isInstance(v) and map[v] then
					nd.Props[k] = map[v]
				end
			end
		end
		return copy
	end,
	FindFirstChild = function(self, name, recursive)
		local d = data[self]
		local found = findChild(d, name)
		if found or not recursive then
			return found
		end
		for _, child in d.Children do
			local f = impl.Instance.FindFirstChild(child, name, true)
			if f then
				return f
			end
		end
		return nil
	end,
	FindFirstDescendant = function(self, name)
		return impl.Instance.FindFirstChild(self, name, true)
	end,
	FindFirstChildOfClass = function(self, className)
		for _, child in data[self].Children do
			if data[child].Class == className then
				return child
			end
		end
		return nil
	end,
	FindFirstChildWhichIsA = function(self, className, recursive)
		for _, child in data[self].Children do
			if classIsA(data[child].Class, className) then
				return child
			end
		end
		if recursive then
			for _, child in data[self].Children do
				local f = impl.Instance.FindFirstChildWhichIsA(child, className, true)
				if f then
					return f
				end
			end
		end
		return nil
	end,
	FindFirstAncestor = function(self, name)
		local p = data[self].Parent
		while p do
			if data[p].Name == name then
				return p
			end
			p = data[p].Parent
		end
		return nil
	end,
	FindFirstAncestorOfClass = function(self, className)
		local p = data[self].Parent
		while p do
			if data[p].Class == className then
				return p
			end
			p = data[p].Parent
		end
		return nil
	end,
	FindFirstAncestorWhichIsA = function(self, className)
		local p = data[self].Parent
		while p do
			if classIsA(data[p].Class, className) then
				return p
			end
			p = data[p].Parent
		end
		return nil
	end,
	WaitForChild = function(self, name, timeout)
		local found = findChild(data[self], name)
		if found then
			return found
		end
		local start = os.clock()
		while os.clock() - start < (timeout or 6) do
			taskLib.wait(0.05)
			found = findChild(data[self], name)
			if found then
				return found
			end
		end
		if timeout then
			return nil
		end
		record("WaitForChild", string.format('Infinite yield possible on %s:WaitForChild("%s")', fullName(self), name))
		error("WaitForChild timeout", 2)
	end,
	GetChildren = function(self)
		return table.clone(data[self].Children)
	end,
	GetDescendants = function(self)
		local out = {}
		forEachDescendant(self, function(x)
			table.insert(out, x)
		end)
		return out
	end,
	IsA = function(self, className)
		return classIsA(data[self].Class, className)
	end,
	IsDescendantOf = function(self, ancestor)
		return isDescendantOf(self, ancestor)
	end,
	IsAncestorOf = function(self, descendant)
		return isDescendantOf(descendant, self)
	end,
	GetFullName = function(self)
		return fullName(self)
	end,
	GetAttribute = function(self, name)
		return data[self].Attrs[name]
	end,
	GetAttributes = function(self)
		return table.clone(data[self].Attrs)
	end,
	SetAttribute = function(self, name, value)
		local t = emuTypeof(value)
		local allowed = {
			["nil"] = true, string = true, boolean = true, number = true, UDim = true, UDim2 = true, BrickColor = true,
			Color3 = true, Vector2 = true, Vector3 = true, CFrame = true, NumberSequence = true, ColorSequence = true,
			NumberRange = true, Rect = true, Font = true, EnumItem = true,
		}
		if not allowed[t] then
			error("SetAttribute: tipo no soportado " .. t, 2)
		end
		local d = data[self]
		d.Attrs[name] = value
		local s = d.AttrSignals[name]
		if s then
			s:Fire()
		end
		if d.Signals.AttributeChanged then
			d.Signals.AttributeChanged:Fire(name)
		end
	end,
	GetAttributeChangedSignal = function(self, name)
		local d = data[self]
		local s = d.AttrSignals[name]
		if not s then
			s = newSignal("Attr." .. name)
			d.AttrSignals[name] = s
		end
		return s
	end,
	GetPropertyChangedSignal = function(self, name)
		local d = data[self]
		if name ~= "Name" and name ~= "Parent" and not findMember(d.Class, name) then
			error(string.format("%s is not a valid property name.", tostring(name)), 2)
		end
		local s = d.PropSignals[name]
		if not s then
			s = newSignal("Prop." .. name)
			d.PropSignals[name] = s
		end
		return s
	end,
	AddTag = function(self, tag)
		local d = data[self]
		if d.Tags[tag] then
			return
		end
		d.Tags[tag] = true
		tagMap[tag] = tagMap[tag] or setmetatable({}, { __mode = "k" })
		tagMap[tag][self] = true
		local s = tagSignals[tag]
		if s then
			s:Fire(self)
		end
	end,
	RemoveTag = function(self, tag)
		data[self].Tags[tag] = nil
		if tagMap[tag] then
			tagMap[tag][self] = nil
		end
	end,
	HasTag = function(self, tag)
		return data[self].Tags[tag] == true
	end,
	GetTags = function(self)
		local out = {}
		for t in data[self].Tags do
			table.insert(out, t)
		end
		return out
	end,
}

impl.PVInstance = {
	GetPivot = function(self)
		local d = data[self]
		if classIsA(d.Class, "BasePart") then
			return getProp(self, "CFrame")
		end
		local primary = getProp(self, "PrimaryPart")
		if primary then
			return getProp(primary, "CFrame")
		end
		for _, x in impl.Instance.GetDescendants(self) do
			if classIsA(data[x].Class, "BasePart") then
				return getProp(x, "CFrame")
			end
		end
		return roblox.CFrame.new()
	end,
	PivotTo = function(self, cf)
		assert(emuTypeof(cf) == "CFrame", "PivotTo espera un CFrame")
		local d = data[self]
		if classIsA(d.Class, "BasePart") then
			setRaw(self, "CFrame", cf)
			return
		end
		local current = impl.PVInstance.GetPivot(self)
		local delta = cf * current:Inverse()
		for _, x in impl.Instance.GetDescendants(self) do
			if classIsA(data[x].Class, "BasePart") then
				data[x].Props.CFrame = delta * getProp(x, "CFrame")
			end
		end
	end,
}

impl.Model = {
	GetBoundingBox = function(self)
		return impl.PVInstance.GetPivot(self), roblox.Vector3.new(4, 4, 4)
	end,
	GetExtentsSize = function()
		return roblox.Vector3.new(4, 4, 4)
	end,
}

impl.ServiceProvider = {
	GetService = function(self, name)
		local d = data[self]
		local existing = findChild(d, name)
		if existing and data[existing].Class == name then
			return existing
		end
		local c = classes[name]
		if not c or not c.Tags.Service then
			error(string.format("'%s' is not a valid Service name", tostring(name)), 2)
		end
		local service = newInstance(name, true)
		data[service].Name = name
		setParent(service, self)
		return service
	end,
}
impl.ServiceProvider.FindService = impl.ServiceProvider.GetService

Emu.CloseCallbacks = {}
impl.DataModel = {
	BindToClose = function(_, fn)
		table.insert(Emu.CloseCallbacks, fn)
	end,
	IsLoaded = function()
		return true
	end,
}

Emu.Players = {}
impl.Players = {
	GetPlayers = function()
		local out = {}
		for _, p in Emu.Players do
			if data[p].Parent then
				table.insert(out, p)
			end
		end
		return out
	end,
	GetPlayerFromCharacter = function(_, character)
		for _, p in Emu.Players do
			if getProp(p, "Character") == character and character ~= nil then
				return p
			end
		end
		return nil
	end,
	GetPlayerByUserId = function(_, id)
		for _, p in Emu.Players do
			if getProp(p, "UserId") == id then
				return p
			end
		end
		return nil
	end,
}

impl.Player = {
	GetMouse = function(self)
		local d = data[self]
		if not d.Mouse then
			d.Mouse = newInstance("PlayerMouse", true)
		end
		return d.Mouse
	end,
	Kick = function(self, reason)
		record("kick", "Kick " .. data[self].Name .. ": " .. tostring(reason))
	end,
}

Emu.RenderSteps = {}
impl.RunService = {
	IsStudio = function()
		return Emu.IsStudio ~= false
	end,
	IsServer = function()
		return true
	end,
	IsClient = function()
		return true
	end,
	IsRunning = function()
		return true
	end,
	BindToRenderStep = function(_, name, priority, fn)
		Emu.RenderSteps[name] = { Priority = priority, Fn = fn }
	end,
	UnbindFromRenderStep = function(_, name)
		Emu.RenderSteps[name] = nil
	end,
}

Emu.TimeOffset = 1000
impl.WorldRoot = {
	Raycast = function(_, origin, direction, params)
		assert(emuTypeof(origin) == "Vector3" and emuTypeof(direction) == "Vector3", "Raycast espera Vector3")
		return Emu.RaycastHook and Emu.RaycastHook(origin, direction, params) or nil
	end,
	Spherecast = function(_, origin, radius, direction, params)
		assert(emuTypeof(origin) == "Vector3" and type(radius) == "number" and emuTypeof(direction) == "Vector3", "Spherecast: argumentos inválidos")
		if params ~= nil then
			assert(emuTypeof(params) == "RaycastParams", "Spherecast espera RaycastParams")
		end
		return Emu.RaycastHook and Emu.RaycastHook(origin, direction, params) or nil
	end,
	GetPartBoundsInBox = function()
		return {}
	end,
	GetPartBoundsInRadius = function()
		return {}
	end,
}
impl.Workspace = {
	GetServerTimeNow = function()
		return os.clock() + Emu.TimeOffset
	end,
}

impl.Terrain = {
	FillBall = function(_, position, radius, material)
		assert(emuTypeof(position) == "Vector3" and type(radius) == "number" and emuTypeof(material) == "EnumItem", "FillBall: argumentos inválidos")
	end,
	FillBlock = function(_, cf, size, material)
		assert(emuTypeof(cf) == "CFrame" and emuTypeof(size) == "Vector3" and emuTypeof(material) == "EnumItem", "FillBlock: argumentos inválidos")
	end,
	SetMaterialColor = function(_, material, color)
		assert(emuTypeof(material) == "EnumItem" and emuTypeof(color) == "Color3", "SetMaterialColor: argumentos inválidos")
	end,
}

impl.TweenService = {
	Create = function(_, inst, info, props)
		assert(isInstance(inst), "TweenService:Create espera una instancia")
		assert(emuTypeof(info) == "TweenInfo", "TweenService:Create espera TweenInfo")
		for k, v in props do
			local m = findMember(data[inst].Class, k)
			if not m or m.MemberType ~= "Property" then
				error(string.format("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a 'nil', but given type is '%s')", k, emuTypeof(v)), 2)
			end
			checkValue(data[inst], k, m, v)
		end
		local tween = newInstance("Tween", true)
		data[tween].Target = inst
		data[tween].Goal = props
		data[tween].Info = info
		return tween
	end,
}
impl.Tween = {
	Play = function(self)
		local d = data[self]
		taskLib.delay(math.min(d.Info.Time, 0.05), function()
			if data[d.Target].Destroyed then
				return
			end
			for k, v in d.Goal do
				data[d.Target].Props[k] = v
			end
			getSignal(d, "Completed"):Fire(roblox.Enum.PlaybackState.Completed)
		end)
	end,
	Cancel = function() end,
	Pause = function() end,
}

-- DataStore en memoria
Emu.Store = {}
Emu.StoreError = nil
impl.DataStoreService = {
	GetDataStore = function(_, name)
		local store = newInstance("DataStore", true)
		data[store].Name = name
		return store
	end,
}
impl.GlobalDataStore = {
	GetAsync = function(_, key)
		if Emu.StoreError then
			error(Emu.StoreError, 2)
		end
		taskLib.wait(0.05)
		local v = Emu.Store[key]
		return if v then serde.decode("json", v) else nil
	end,
	SetAsync = function(_, key, value)
		if Emu.StoreError then
			error(Emu.StoreError, 2)
		end
		Emu.Store[key] = serde.encode("json", value)
	end,
	UpdateAsync = function(_, key, fn)
		if Emu.StoreError then
			error(Emu.StoreError, 2)
		end
		taskLib.wait(0.05)
		local old = Emu.Store[key]
		local new = fn(if old then serde.decode("json", old) else nil)
		if new ~= nil then
			Emu.Store[key] = serde.encode("json", new)
		end
		return new
	end,
}

-- Remotes: servidor y cliente comparten proceso (como "Play" en Studio)
local function copyArg(v, seen)
	if type(v) ~= "table" or isInstance(v) or customTypes[v] then
		return v
	end
	seen = seen or {}
	if seen[v] then
		record("remote", "tabla cíclica enviada por un remote")
		return nil
	end
	seen[v] = true
	local out = {}
	local numeric, stringKeys = 0, 0
	for k, x in v do
		if type(k) == "number" then
			numeric += 1
		elseif type(k) == "string" then
			stringKeys += 1
		else
			record("remote", "clave no válida en tabla enviada por remote: " .. emuTypeof(k))
		end
		if type(x) == "function" then
			record("remote", "función enviada por remote")
		end
		out[k] = copyArg(x, seen)
	end
	if numeric > 0 and stringKeys > 0 then
		record("remote", "tabla mixta (números y textos como claves) enviada por remote")
	end
	return out
end

local function copyArgs(...)
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = copyArg(args[i])
	end
	return args
end

impl.RemoteEvent = {
	FireServer = function(self, ...)
		local args = copyArgs(...)
		getSignal(data[self], "OnServerEvent"):Fire(Emu.LocalPlayer, table.unpack(args, 1, args.n))
	end,
	FireClient = function(self, player, ...)
		assert(isInstance(player) and data[player].Class == "Player", "FireClient: el primer argumento debe ser un Player")
		if player == Emu.LocalPlayer then
			local args = copyArgs(...)
			getSignal(data[self], "OnClientEvent"):Fire(table.unpack(args, 1, args.n))
		end
	end,
	FireAllClients = function(self, ...)
		local args = copyArgs(...)
		getSignal(data[self], "OnClientEvent"):Fire(table.unpack(args, 1, args.n))
	end,
}
impl.RemoteFunction = {
	InvokeServer = function(self, ...)
		local cb = rawProp(data[self], "OnServerInvoke")
		if not cb then
			record("remote", "InvokeServer sin OnServerInvoke en " .. data[self].Name)
			return nil
		end
		local args = copyArgs(...)
		local results = table.pack(cb(Emu.LocalPlayer, table.unpack(args, 1, args.n)))
		for i = 1, results.n do
			results[i] = copyArg(results[i])
		end
		return table.unpack(results, 1, results.n)
	end,
}
impl.BindableEvent = {
	Fire = function(self, ...)
		getSignal(data[self], "Event"):Fire(...)
	end,
}

impl.CollectionService = {
	GetTagged = function(_, tag)
		local out = {}
		for inst in tagMap[tag] or {} do
			if isDescendantOf(inst, Emu.game) then
				table.insert(out, inst)
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function(_, tag)
		local s = tagSignals[tag]
		if not s then
			s = newSignal("Tag." .. tag)
			tagSignals[tag] = s
		end
		return s
	end,
	GetInstanceRemovedSignal = function(_, tag)
		return newSignal("TagRemoved." .. tag)
	end,
	AddTag = function(_, inst, tag)
		impl.Instance.AddTag(inst, tag)
	end,
	HasTag = function(_, inst, tag)
		return impl.Instance.HasTag(inst, tag)
	end,
}

impl.Debris = {
	AddItem = function(_, inst, life)
		taskLib.delay(life or 10, function()
			if not data[inst].Destroyed then
				destroy(inst)
			end
		end)
	end,
}

impl.Humanoid = {
	ChangeState = function(_, state)
		assert(emuTypeof(state) == "EnumItem", "ChangeState espera un EnumItem")
	end,
	GetState = function()
		return roblox.Enum.HumanoidStateType.Running
	end,
	UnequipTools = function(self)
		local character = data[self].Parent
		local player = character and impl.Players.GetPlayerFromCharacter(nil, character)
		if not player then
			return
		end
		local backpack = impl.Instance.FindFirstChildOfClass(player, "Backpack")
		for _, child in table.clone(data[character].Children) do
			if data[child].Class == "Tool" then
				setParent(child, backpack)
			end
		end
	end,
	EquipTool = function(self, tool)
		setParent(tool, data[self].Parent)
	end,
}

impl.ParticleEmitter = {
	Emit = function(_, count)
		assert(type(count) == "number", "Emit espera un número")
	end,
}

-- Entorno de los scripts ------------------------------------------------------------------------------------

Emu.TimeScale = 1

local function wrapTaskFn(f)
	if type(f) == "thread" then
		return f
	end
	assert(type(f) == "function", "task: se esperaba una función")
	return wrap(f, "task")
end

local taskShim = {
	spawn = function(f, ...)
		return taskLib.spawn(wrapTaskFn(f), ...)
	end,
	defer = function(f, ...)
		return taskLib.defer(wrapTaskFn(f), ...)
	end,
	delay = function(t, f, ...)
		return taskLib.delay((t or 0) * Emu.TimeScale, wrapTaskFn(f), ...)
	end,
	wait = function(t)
		local seconds = t or 0
		taskLib.wait(math.max(0.001, seconds * Emu.TimeScale))
		return seconds
	end,
	cancel = function(thread)
		return taskLib.cancel(thread)
	end,
	synchronize = function() end,
	desynchronize = function() end,
}

local InstanceLib = {
	new = function(className, parent)
		local inst = newInstance(className)
		if parent ~= nil then
			setParent(inst, parent)
		end
		return inst
	end,
}

function Emu.MakeEnv(side: string, scriptInstance, requireFn)
	return {
		script = scriptInstance,
		game = Emu.game,
		workspace = Emu.workspace,
		Workspace = Emu.workspace,
		Instance = InstanceLib,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		BrickColor = roblox.BrickColor,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Rect = roblox.Rect,
		Enum = roblox.Enum,
		Font = roblox.Font,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		PhysicalProperties = roblox.PhysicalProperties,
		Ray = roblox.Ray,
		Region3 = roblox.Region3,
		Random = RandomLib,
		TweenInfo = TweenInfoLib,
		RaycastParams = RaycastParamsLib,
		OverlapParams = OverlapParamsLib,
		task = taskShim,
		typeof = emuTypeof,
		require = requireFn,
		tick = os.clock,
		time = os.clock,
		elapsedTime = os.clock,
		wait = taskShim.wait,
		delay = taskShim.delay,
		spawn = taskShim.spawn,
		print = function(...)
			if not Emu.Quiet then
				print("[" .. side .. "]", ...)
			end
		end,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring((select(i, ...))))
			end
			table.insert(Emu.Warnings, side .. ": " .. table.concat(parts, " "))
		end,
	}
end

function Emu.MakeRequire(side: string)
	local cache = {}
	local loading = {}
	local req
	req = function(target)
		if cache[target] ~= nil then
			return cache[target]
		end
		if not isInstance(target) or data[target].Class ~= "ModuleScript" then
			error("Attempted to call require with invalid argument(s).", 2)
		end
		if loading[target] then
			error("Requested module was required recursively: " .. fullName(target), 2)
		end
		loading[target] = true
		local env = Emu.MakeEnv(side, target, req)
		local chunk = luauLib.load(data[target].Source, { debugName = fullName(target), environment = env })
		local result = chunk()
		loading[target] = nil
		if result == nil then
			error("Module code did not return exactly one value: " .. fullName(target), 2)
		end
		cache[target] = result
		return result
	end
	return req
end

function Emu.RunScript(side: string, scriptInstance, requireFn)
	local env = Emu.MakeEnv(side, scriptInstance, requireFn)
	local chunk = luauLib.load(data[scriptInstance].Source, { debugName = fullName(scriptInstance), environment = env })
	taskLib.spawn(wrap(chunk, side .. " script " .. data[scriptInstance].Name))
end

-- Árbol del proyecto (como Rojo) --------------------------------------------------------------------------

local function loadDir(path: string, target)
	for _, name in fs.readDir(path) do
		local full = path .. "/" .. name
		if fs.isDir(full) then
			local container
			if fs.isFile(full .. "/init.server.luau") then
				container = newInstance("Script")
				data[container].Source = fs.readFile(full .. "/init.server.luau")
			elseif fs.isFile(full .. "/init.client.luau") then
				container = newInstance("LocalScript")
				data[container].Source = fs.readFile(full .. "/init.client.luau")
			elseif fs.isFile(full .. "/init.luau") then
				container = newInstance("ModuleScript")
				data[container].Source = fs.readFile(full .. "/init.luau")
			else
				container = newInstance("Folder")
			end
			data[container].Name = name
			loadDir(full, container)
			setParent(container, target)
		elseif string.sub(name, -5) == ".luau" and not string.match(name, "^init%.") then
			local inst
			local base
			if string.sub(name, -12) == ".server.luau" then
				inst = newInstance("Script")
				base = string.sub(name, 1, -13)
			elseif string.sub(name, -12) == ".client.luau" then
				inst = newInstance("LocalScript")
				base = string.sub(name, 1, -13)
			else
				inst = newInstance("ModuleScript")
				base = string.sub(name, 1, -6)
			end
			data[inst].Name = base
			data[inst].Source = fs.readFile(full)
			setParent(inst, target)
		end
	end
end

-- Crea el DataModel con el proyecto montado como lo haría Rojo
function Emu.Boot(projectRoot: string)
	local game = newInstance("DataModel", true)
	data[game].Name = "Game"
	Emu.game = game
	local gs = impl.ServiceProvider.GetService
	Emu.workspace = gs(game, "Workspace")
	local rs = gs(game, "ReplicatedStorage")
	local sss = gs(game, "ServerScriptService")
	local sp = gs(game, "StarterPlayer")
	local shared = newInstance("Folder")
	data[shared].Name = "Shared"
	loadDir(projectRoot .. "/src/shared", shared)
	setParent(shared, rs)
	local server = newInstance("Script")
	data[server].Name = "Server"
	data[server].Source = fs.readFile(projectRoot .. "/src/server/init.server.luau")
	loadDir(projectRoot .. "/src/server", server)
	setParent(server, sss)
	local sps = newInstance("StarterPlayerScripts", true)
	data[sps].Name = "StarterPlayerScripts"
	setParent(sps, sp)
	local client = newInstance("LocalScript")
	data[client].Name = "Client"
	data[client].Source = fs.readFile(projectRoot .. "/src/client/init.client.luau")
	loadDir(projectRoot .. "/src/client", client)
	setParent(client, sps)
	return game
end

-- Jugadores y personajes ----------------------------------------------------------------------------------

function Emu.AddPlayer(name: string, userId: number)
	local players = impl.ServiceProvider.GetService(Emu.game, "Players")
	local player = newInstance("Player", true)
	data[player].Name = name
	data[player].Props.UserId = userId
	data[player].Props.DisplayName = name
	for _, className in { "Backpack", "PlayerGui", "PlayerScripts" } do
		local child = newInstance(className, true)
		data[child].Name = className
		setParent(child, player)
	end
	table.insert(Emu.Players, player)
	setParent(player, players)
	Emu.Fire(players, "PlayerAdded", player)
	return player
end

function Emu.SpawnCharacter(player, position)
	local character = newInstance("Model")
	data[character].Name = data[player].Name
	local root = newInstance("Part")
	data[root].Name = "HumanoidRootPart"
	data[root].Props.Size = roblox.Vector3.new(2, 2, 1)
	data[root].Props.CFrame = roblox.CFrame.new(position or roblox.Vector3.new(0, 5, 0))
	setParent(root, character)
	local head = newInstance("Part")
	data[head].Name = "Head"
	data[head].Props.CFrame = roblox.CFrame.new((position or roblox.Vector3.new(0, 5, 0)) + roblox.Vector3.new(0, 2, 0))
	setParent(head, character)
	local humanoid = newInstance("Humanoid")
	data[humanoid].Name = "Humanoid"
	setParent(humanoid, character)
	data[character].Props.PrimaryPart = root
	data[player].Props.Character = character
	setParent(character, Emu.workspace)
	Emu.Fire(player, "CharacterAdded", character)
	return character
end

function Emu.RemovePlayer(player)
	local players = impl.ServiceProvider.GetService(Emu.game, "Players")
	Emu.Fire(players, "PlayerRemoving", player)
	taskLib.wait(0.3)
	setParent(player, nil)
end

-- Bucle de frames: Heartbeat, RenderStepped y BindToRenderStep
function Emu.Step(dt: number)
	local runService = impl.ServiceProvider.GetService(Emu.game, "RunService")
	local d = data[runService]
	for _, name in { "Stepped", "Heartbeat", "PreSimulation", "PostSimulation" } do
		local s = d.Signals[name]
		if s then
			if name == "Stepped" then
				s:Fire(os.clock(), dt)
			else
				s:Fire(dt)
			end
		end
	end
	local rs = d.Signals.RenderStepped
	if rs then
		rs:Fire(dt)
	end
	for name, step in Emu.RenderSteps do
		local ok, err = xpcall(step.Fn, debug.traceback, dt)
		if not ok then
			record("renderstep " .. name, tostring(err))
		end
	end
end

function Emu.Run(seconds: number, fps: number?)
	local dt = 1 / (fps or 20)
	local start = os.clock()
	while os.clock() - start < seconds do
		Emu.Step(dt)
		taskLib.wait(dt)
	end
end

return Emu
