--!nocheck
-- Headless movement scenarios. Run from the repo root:
--   python3 tests/sim/bundle.py && luau tests/sim/run.luau
-- (`luau` is the standalone Luau CLI from https://github.com/luau-lang/luau)

local Mock = require("./mock")
local env = Mock.makeEnv()
local bundle = require("./bundle_data")
local Vector3 = Mock.Vector3

-- Fake instance tree so the modules' `script.Parent...` requires resolve to the real sources ---------
local function newNode(name, parent)
	local node = { Name = name, Parent = parent, _children = {} }
	setmetatable(node, {
		__index = function(t, k)
			return rawget(t, "_children")[k]
		end,
	})
	if parent then
		parent._children[name] = node
	end
	return node
end

local rootNode = newNode("root", nil)
for key, source in bundle do
	local node = rootNode
	for _, part in string.split(key, "/") do
		node = node._children[part] or newNode(part, node)
	end
	node.Source = source
	node.Path = key
end

local cache = {}
local function requireNode(node)
	if cache[node] ~= nil then
		return cache[node]
	end
	local chunk, err = loadstring("local script, require = ...\n" .. node.Source, "=" .. node.Path)
	assert(chunk, err)
	setfenv(chunk, env)
	local result = chunk(node, requireNode)
	cache[node] = result
	return result
end

local Locomotion = requireNode(rootNode.Shared.Movement.Locomotion)
local baseConfig = requireNode(rootNode.Shared.Config.MovementConfig)

-- Simulation harness ---------------------------------------------------------------------------------
local FEET = 3.0
local FORWARD = Vector3.new(0, 0, -1)

local function newSim(opts)
	opts = opts or {}
	Mock.clearBoxes()
	Mock.addBox("Ground", Vector3.new(-3000, -20, -3000), Vector3.new(3000, 0, 3000))
	for _, box in opts.boxes or {} do
		Mock.addBox(box.name, box.min, box.max, box.attributes)
	end

	local body = Mock.newBody(opts.position or Vector3.new(0, FEET + 0.01, 0))
	if opts.velocity then
		body.root.AssemblyLinearVelocity = opts.velocity
	end
	local cfg = table.clone(baseConfig)
	for k, v in opts.cfg or {} do
		cfg[k] = v
	end
	local loco = Locomotion.new(body.model, cfg, true)
	body.driver = loco.Driver

	local sim = { body = body, loco = loco, cfg = cfg, t = 0, intent = Locomotion.newIntent(), events = {}, states = {} }
	loco.Events:Connect(function(name, data)
		table.insert(sim.events, { t = sim.t, name = name, data = data })
	end)
	loco.StateChanged:Connect(function(new, old)
		table.insert(sim.states, { t = sim.t, state = new, from = old, pos = sim.body.root.Position })
	end)

	function sim:pos()
		return self.body.root.Position
	end
	function sim:hspeed()
		local v = self.body.root.AssemblyLinearVelocity
		return math.sqrt(v.X * v.X + v.Z * v.Z)
	end
	function sim:vy()
		return self.body.root.AssemblyLinearVelocity.Y
	end
	function sim:state()
		return self.loco.StateName
	end
	function sim:step(dt, fn)
		local intent = self.intent
		intent.JumpPressed = false
		intent.DashPressed = false
		intent.SlidePressed = false
		intent.DashDirection = nil
		if fn then
			fn(self, intent)
		end
		self.loco:Step(dt, intent)
		Mock.stepBody(self.body, dt)
		self.t += dt
		Mock.advanceClock(dt)
	end
	function sim:run(seconds, fn, dt)
		dt = dt or 1 / 60
		for _ = 1, math.floor(seconds / dt + 0.5) do
			self:step(dt, fn)
		end
	end
	function sim:hasEvent(name)
		for _, e in self.events do
			if e.name == name then
				return e
			end
		end
		return nil
	end
	function sim:hasState(name)
		for _, s in self.states do
			if s.state == name then
				return s
			end
		end
		return nil
	end
	return sim
end

local failures = 0
local function check(label, condition, detail)
	if condition then
		print(`  ok    {label}{detail and " — " .. detail or ""}`)
	else
		failures += 1
		print(`  FAIL  {label}{detail and " — " .. detail or ""}`)
	end
end
local function heading(text)
	print("\n" .. text)
end
local function fmt(n)
	return string.format("%.2f", n)
end

-- Scenarios ------------------------------------------------------------------------------------------

heading("[ground] acceleration, sprint and stopping")
do
	local s = newSim()
	s:run(0.3) -- settle onto the ground
	check("settles into Ground", s:state() == "Ground", s:state())

	s.intent.Move = FORWARD
	local startZ = s:pos().Z
	local samples = {}
	for _, t in { 0.1, 0.2, 0.4, 0.8 } do
		s:run(t - (samples.last or 0))
		samples.last = t
		table.insert(samples, `{t}s:{fmt(s:hspeed())}`)
	end
	print("  run speed ramp  " .. table.concat(samples, "  "))
	check("reaches run speed", math.abs(s:hspeed() - baseConfig.RunSpeed) < 1.5, fmt(s:hspeed()))

	s.intent.Sprint = true
	s:run(0.7)
	check("reaches sprint speed", math.abs(s:hspeed() - baseConfig.SprintSpeed) < 1.5, fmt(s:hspeed()))

	local zBefore = s:pos().Z
	s.intent.Move = Vector3.zero
	s.intent.Sprint = false
	s:run(0.6)
	local glide = zBefore - s:pos().Z
	check("stops with a short glide", s:hspeed() < 0.5 and glide < 6.5, `glide {fmt(glide)} studs`)
	check("ran forward", s:pos().Z < startZ - 10)
end

heading("[ground] reversing at speed skids first")
do
	local s = newSim()
	s.intent.Move = FORWARD
	s.intent.Sprint = true
	s:run(1.2)
	s.intent.Move = Vector3.new(0, 0, 1)
	local minSpeed = math.huge
	s:run(0.6, function(sim)
		minSpeed = math.min(minSpeed, sim:hspeed())
	end)
	check("Skid event fired", s:hasEvent("Skid") ~= nil)
	check("speed dropped through the pivot", minSpeed < 8, fmt(minSpeed))
	check("now heading back", s.body.root.AssemblyLinearVelocity.Z > 5, fmt(s.body.root.AssemblyLinearVelocity.Z))
end

heading("[air] jump height, hang time, variable height")
do
	local s = newSim()
	s:run(0.3)
	local groundY = s:pos().Y
	local apex, airTime, jumped = 0, 0, false
	s.intent.JumpHeld = true
	s:run(1.6, function(sim, intent)
		if not jumped then
			intent.JumpPressed = true
			jumped = true
		end
		apex = math.max(apex, sim:pos().Y - groundY)
		if sim:state() == "Air" then
			airTime += 1 / 60
		end
	end)
	check("jump apex is a comfortable ~7-9 studs", apex > 6.5 and apex < 9.5, `apex {fmt(apex)}`)
	check("air time is short and snappy", airTime > 0.45 and airTime < 0.75, `air {fmt(airTime)}s`)
	check("lands back in Ground", s:state() == "Ground", s:state())

	local short = newSim()
	short:run(0.3)
	local y0, apex2, pressed = short:pos().Y, 0, false
	short:run(1.2, function(sim, intent)
		if not pressed then
			intent.JumpPressed = true
			pressed = true
		end
		intent.JumpHeld = false
		apex2 = math.max(apex2, sim:pos().Y - y0)
	end)
	check("tapping jump gives a shorter hop", apex2 < apex * 0.6, `tap {fmt(apex2)} vs held {fmt(apex)}`)
end

heading("[air] apex height is frame-rate independent")
do
	local results = {}
	for _, fps in { 30, 60, 144 } do
		local s = newSim()
		local dt = 1 / fps
		s:run(0.3, nil, dt)
		local y0, apex, pressed = s:pos().Y, 0, false
		s.intent.JumpHeld = true
		s:run(1.2, function(sim, intent)
			if not pressed then
				intent.JumpPressed = true
				pressed = true
			end
			apex = math.max(apex, sim:pos().Y - y0)
		end, dt)
		results[fps] = apex
	end
	print(`  apex @30fps {fmt(results[30])}  @60fps {fmt(results[60])}  @144fps {fmt(results[144])}`)
	check("30fps within 12% of 144fps", math.abs(results[30] - results[144]) / results[144] < 0.12)
	check("60fps within 8% of 144fps", math.abs(results[60] - results[144]) / results[144] < 0.08)
end

heading("[air] coyote time and buffered jump")
do
	local platform = { { name = "Platform", min = Vector3.new(-20, 0, -30), max = Vector3.new(20, 60, 20) } }
	local function runOff(pressDelay, extra)
		local s = newSim({ boxes = platform, position = Vector3.new(0, 60 + FEET + 0.01, 0), cfg = { AirJumps = 0 } })
		s.intent.Move = FORWARD
		s.intent.Sprint = false
		s:run(0.4) -- land on the platform first (the body spawns in the air)
		local leftAt, pressedAt, peakVy = nil, nil, -math.huge
		s:run(3, function(sim, intent)
			if leftAt == nil and sim:state() == "Air" then
				leftAt = sim.t
			end
			if leftAt and pressedAt == nil and sim.t >= leftAt + pressDelay then
				intent.JumpPressed = true
				pressedAt = sim.t
			end
			if pressedAt and sim.t > pressedAt then
				peakVy = math.max(peakVy, sim:vy())
			end
		end)
		return peakVy, leftAt
	end
	local vyInside = runOff(0.04)
	local vyOutside = runOff(0.3)
	check("jump just after leaving the ledge still works", vyInside > 30, `vy {fmt(vyInside)}`)
	check("jump 0.3s after leaving the ledge does not", vyOutside < 30, `vy {fmt(vyOutside)}`)

	-- buffered: press just before touchdown, expect an immediate hop on landing
	local s = newSim({ position = Vector3.new(0, 4 + FEET, 0) })
	local pressed, jumpedAfterLanding = false, false
	s:run(1.5, function(sim, intent)
		if not pressed and sim.loco.FloorDistance < 1.5 and sim:vy() < 0 then
			intent.JumpPressed = true
			pressed = true
		end
		if pressed and sim:vy() > 30 then
			jumpedAfterLanding = true
		end
	end)
	check("jump pressed just before landing fires on touchdown", jumpedAfterLanding)
end

heading("[air] double jump")
do
	local s = newSim()
	s:run(0.3)
	s.intent.JumpHeld = true
	local step = 0
	local vyAfterSecond = nil
	s:run(1.5, function(sim, intent)
		step += 1
		if step == 1 then
			intent.JumpPressed = true
		elseif step == 25 then
			intent.JumpPressed = true
		elseif step == 27 then
			vyAfterSecond = sim:vy()
		end
	end)
	check("AirJump event", s:hasEvent("AirJump") ~= nil)
	check("second jump re-launches upward", vyAfterSecond ~= nil and vyAfterSecond > 35, vyAfterSecond and fmt(vyAfterSecond))
	local jumps = 0
	for _, e in s.events do
		if e.name == "AirJump" then
			jumps += 1
		end
	end
	check("only one double jump allowed", jumps == 1, tostring(jumps))
end

heading("[dash] ground dash distance, exit speed, charges")
do
	local s = newSim()
	s.intent.Move = FORWARD
	s:run(0.6)
	local startZ = s:pos().Z
	local peak, dashFrames = 0, 0
	local dashed = false
	s:run(0.5, function(sim, intent)
		if not dashed then
			intent.DashPressed = true
			dashed = true
		end
		if sim:state() == "Dash" then
			dashFrames += 1
			peak = math.max(peak, sim:hspeed())
		end
	end)
	local distance = startZ - s:pos().Z
	check("entered Dash", s:hasState("Dash") ~= nil)
	check("dash peaks near DashSpeed", peak > baseConfig.DashSpeed * 0.85, fmt(peak))
	check("dash lasts ~0.2s", dashFrames >= 10 and dashFrames <= 14, `{dashFrames} frames`)
	print(`  dash+following 0.3s covered {fmt(distance)} studs`)
	check("returns to Ground with sprint-ish speed", s:state() == "Ground" and s:hspeed() > 18, `{s:state()} {fmt(s:hspeed())}`)
	check("one charge spent", s.loco.DashCharges == baseConfig.DashCharges - 1, tostring(s.loco.DashCharges))
	s:run(2.6)
	check("charge recharged", s.loco.DashCharges == baseConfig.DashCharges, tostring(s.loco.DashCharges))

	-- spamming: cooldown then charges
	local spam = newSim()
	spam.intent.Move = FORWARD
	spam:run(0.4)
	local count = 0
	spam:run(2.0, function(sim, intent)
		intent.DashPressed = true
	end)
	for _, st in spam.states do
		if st.state == "Dash" then
			count += 1
		end
	end
	check("spamming dash is limited by charges", count >= 2 and count <= 3, `{count} dashes in 2s`)
end

heading("[dash] air dash hovers, and is limited to one per airtime")
do
	local s = newSim({ position = Vector3.new(0, 30, 0) })
	s.intent.Move = FORWARD
	local yAtDash, yAfter
	local presses = 0
	s:run(0.8, function(sim, intent)
		if sim.t > 0.1 and presses < 3 and sim.t < 0.5 then
			intent.DashPressed = true
			presses += 1
		end
		if sim:state() == "Dash" and not yAtDash then
			yAtDash = sim:pos().Y
		end
		if sim:state() == "Dash" then
			yAfter = sim:pos().Y
		end
	end)
	check("air dash keeps height during the dash", yAtDash ~= nil and math.abs(yAtDash - yAfter) < 0.6, `dy {fmt(yAtDash - yAfter)}`)
	local dashes = 0
	for _, st in s.states do
		if st.state == "Dash" then
			dashes += 1
		end
	end
	check("only one air dash per airtime", dashes == 1, tostring(dashes))
end

heading("[slide] sprint slide distance, decay and steering exit")
do
	local s = newSim()
	s.intent.Move = FORWARD
	s.intent.Sprint = true
	s:run(1.4)
	local startZ = s:pos().Z
	local startSpeed = s:hspeed()
	local slid = false
	local slideTime, endSpeed = 0, nil
	s.intent.SlideHeld = true
	s:run(3.2, function(sim, intent)
		if not slid then
			intent.SlidePressed = true
			slid = true
		end
		if sim:state() == "Slide" then
			slideTime += 1 / 60
			endSpeed = sim:hspeed()
		end
	end)
	check("entered Slide", s:hasState("Slide") ~= nil)
	check("slide lasts a while, then ends", slideTime > 1.2 and slideTime <= baseConfig.SlideMaxTime + 0.1, `{fmt(slideTime)}s`)
	check("slide starts faster than the sprint", s:hasEvent("SlideStart") and s:hasEvent("SlideStart").data > startSpeed, s:hasEvent("SlideStart") and fmt(s:hasEvent("SlideStart").data) or "")
	print(`  slid {fmt(startZ - s:pos().Z)} studs, ended at {fmt(endSpeed or 0)} studs/s`)

	-- releasing the key ends it early with momentum kept
	local r = newSim()
	r.intent.Move = FORWARD
	r.intent.Sprint = true
	r:run(1.4)
	local first = true
	r.intent.SlideHeld = true
	r:run(0.5, function(sim, intent)
		if first then
			intent.SlidePressed = true
			first = false
		end
	end)
	r.intent.SlideHeld = false
	r:run(0.2)
	check("releasing slide returns to Ground keeping speed", r:state() == "Ground" and r:hspeed() > 12, `{r:state()} {fmt(r:hspeed())}`)

	-- slide-jump
	local j = newSim()
	j.intent.Move = FORWARD
	j.intent.Sprint = true
	j:run(1.4)
	local stage = 0
	j.intent.SlideHeld = true
	local jumpSpeed
	j:run(1.2, function(sim, intent)
		if stage == 0 then
			intent.SlidePressed = true
			stage = 1
		elseif stage == 1 and sim.loco.StateTime > 0.3 and sim:state() == "Slide" then
			intent.JumpPressed = true
			stage = 2
		elseif stage == 2 and sim:state() == "Air" and not jumpSpeed then
			jumpSpeed = sim:hspeed()
		end
	end)
	local kind
	for _, e in j.events do
		if e.name == "Jump" then
			kind = e.data
		end
	end
	check("slide-jump launches with the slide's speed", kind == "SlideJump" and jumpSpeed and jumpSpeed > 24, `{kind} {jumpSpeed and fmt(jumpSpeed)}`)
end

heading("[wall] wall run, timeout, wall jump")
do
	local wall = { { name = "Wall", min = Vector3.new(2.3, 0, -400), max = Vector3.new(4, 60, 50) } }
	local s = newSim({ boxes = wall, position = Vector3.new(0, 20, 0), velocity = Vector3.new(0, 4, -26), cfg = {} })
	s.intent.Move = FORWARD
	s.intent.Sprint = true
	s:run(0.4)
	check("attached to the wall", s:hasState("WallRun") ~= nil, s:state())
	local startT = s:hasState("WallRun") and s:hasState("WallRun").t or 0
	local ended
	s:run(2.4, function(sim)
		if not ended and sim:state() ~= "WallRun" and sim:hasState("WallRun") then
			ended = sim.t
		end
	end)
	check("wall run ends by itself around WallRunDuration", ended ~= nil and ended - startT < baseConfig.WallRunDuration + 0.4, ended and fmt(ended - startT) .. "s")

	local j = newSim({ boxes = wall, position = Vector3.new(0, 20, 0), velocity = Vector3.new(0, 4, -26) })
	j.intent.Move = FORWARD
	j.intent.Sprint = true
	j:run(0.5)
	local pressed = false
	local vxAfter, vyAfter
	j.intent.JumpHeld = true
	j:run(0.3, function(sim, intent)
		if not pressed and sim:state() == "WallRun" then
			intent.JumpPressed = true
			pressed = true
		elseif pressed and vxAfter == nil then
			vxAfter = sim.body.root.AssemblyLinearVelocity.X
			vyAfter = sim:vy()
		end
	end)
	local kind
	for _, e in j.events do
		if e.name == "Jump" then
			kind = e.data
		end
	end
	check("wall jump event", kind == "WallJump", tostring(kind))
	check("kicks away from the wall", vxAfter ~= nil and vxAfter < -15, vxAfter and fmt(vxAfter))
	check("and upward", vyAfter ~= nil and vyAfter > 30, vyAfter and fmt(vyAfter))
	check("air jump refreshed", j.loco.AirJumps == baseConfig.AirJumps)

	-- a wall you're running head-on into doesn't count as a wall run
	local head = newSim({ boxes = { { name = "Wall", min = Vector3.new(-30, 0, -40), max = Vector3.new(30, 60, -38) } }, position = Vector3.new(0, 20, 0), velocity = Vector3.new(0, 0, -26) })
	head.intent.Move = FORWARD
	head.intent.Sprint = true
	head:run(0.6)
	check("head-on wall does not trigger a wall run", head:hasState("WallRun") == nil)
end

heading("[mantle] climbing a ledge")
do
	for _, height in { 3.8, 5, 7 } do
		local ledge = { { name = "Ledge", min = Vector3.new(-6, 0, -22), max = Vector3.new(6, height, -8) } }
		local s = newSim({ boxes = ledge })
		s.intent.Move = FORWARD
		s.intent.Sprint = true
		local pressed = false
		s:run(2.5, function(sim, intent)
			if not pressed and sim:pos().Z < -5.2 then
				intent.JumpPressed = true
				pressed = true
			end
		end)
		check(`ledge {height}: mantle triggered`, s:hasState("Mantle") ~= nil)
		local entered = s:hasState("Mantle")
		local finished
		for _, st in s.states do
			if entered and st.from == "Mantle" then
				finished = st
				break
			end
		end
		if finished then
			local feet = finished.pos.Y - FEET
			check(`ledge {height}: finishes standing on top`, math.abs(feet - height) < 0.4 and finished.pos.Z < -8, `feet y {fmt(feet)} z {fmt(finished.pos.Z)}`)
			print(`  height {height}: mantle took {fmt(finished.t - entered.t)}s`)
		else
			check(`ledge {height}: finishes`, false, "never left Mantle")
		end
	end

	local tooHigh = newSim({ boxes = { { name = "Wall", min = Vector3.new(-6, 0, -22), max = Vector3.new(6, 12, -8) } } })
	tooHigh.intent.Move = FORWARD
	tooHigh.intent.Sprint = true
	tooHigh:run(1.5, function(sim, intent)
		if sim:pos().Z < -5.2 then
			intent.JumpPressed = true
		end
	end)
	check("a 12-stud wall is not climbable", tooHigh:hasState("Mantle") == nil)

	local flagged = newSim({ boxes = { { name = "Ledge", min = Vector3.new(-6, 0, -22), max = Vector3.new(6, 5, -8), attributes = { NoMantle = true } } } })
	flagged.intent.Move = FORWARD
	flagged.intent.Sprint = true
	flagged:run(1.5, function(sim, intent)
		if sim:pos().Z < -5.2 then
			intent.JumpPressed = true
		end
	end)
	check("NoMantle attribute is respected", flagged:hasState("Mantle") == nil)
end

heading("[landing] roll turns a big fall into speed; skipping it costs momentum")
do
	local function drop(height, roll)
		local s = newSim({ position = Vector3.new(0, height + FEET, 0), velocity = Vector3.new(0, 0, -20) })
		s.intent.Move = FORWARD
		s.intent.Sprint = true
		local pressed = false
		s:run(3.5, function(sim, intent)
			if roll and not pressed and sim.loco.FloorDistance < 14 and sim:vy() < -20 then
				intent.SlidePressed = true
				intent.SlideHeld = true
				pressed = true
			end
			if pressed and sim:state() ~= "Air" then
				intent.SlideHeld = false
			end
		end)
		return s
	end

	local rolled = drop(40, true)
	check("Roll state used", rolled:hasState("Roll") ~= nil)
	local land = rolled:hasEvent("Land")
	print(`  40-stud drop: impact {land and fmt(land.data) or "?"}`)
	check("no landing penalty when rolling", rolled.loco.LandPenaltyUntil < 0)

	local hard = drop(60, false)
	check("hard landing without a roll hurts", hard:hasEvent("HardLand") ~= nil)
	check("and slows you", hard.loco.LandPenaltyUntil > -math.huge)

	local soft = drop(4, false)
	check("small drops are free", soft:hasEvent("HardLand") == nil and soft:hasState("Roll") == nil)

	-- roll speed carries out
	local r = drop(40, true)
	local rollState = r:hasState("Roll")
	local afterRoll
	for _, st in r.states do
		if rollState and st.from == "Roll" then
			afterRoll = st
			break
		end
	end
	check("roll exits into Ground", afterRoll ~= nil and afterRoll.state == "Ground")
end

heading("[flow] chaining moves builds and decays flow")
do
	local s = newSim()
	s.intent.Move = FORWARD
	s.intent.Sprint = true
	s:run(1.0)
	local step = 0
	s:run(1.5, function(sim, intent)
		step += 1
		if step == 1 then
			intent.DashPressed = true
		elseif step == 30 then
			intent.JumpPressed = true
		end
	end)
	check("flow built up", s.loco.Flow > 0.09, fmt(s.loco.Flow))
	s.intent.Move = Vector3.zero
	s:run(8)
	check("flow decays when idle", s.loco.Flow < 0.05, fmt(s.loco.Flow))
end

heading("[stun] knockback locks control then releases")
do
	local s = newSim()
	s:run(0.3)
	s.loco:Stun(0.5, Vector3.new(30, 30, 0))
	s.intent.Move = FORWARD
	s:run(0.3)
	check("stunned", s:state() == "Stun")
	s:run(1.0)
	check("recovers", s:state() == "Ground" or s:state() == "Air", s:state())
end

heading("[robustness] random input never errors")
do
	local rng = Random and Random.new(7)
	local seed = 12345
	local function rand()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local ledges = {
		{ name = "A", min = Vector3.new(-6, 0, -30), max = Vector3.new(6, 5, -18) },
		{ name = "W", min = Vector3.new(10, 0, -200), max = Vector3.new(12, 50, 50) },
		{ name = "B", min = Vector3.new(-30, 0, 10), max = Vector3.new(-20, 3, 20) },
	}
	local ok, err = pcall(function()
		for run = 1, 30 do
			local s = newSim({ boxes = ledges, position = Vector3.new(rand() * 20 - 10, 3.1 + rand() * 20, rand() * 20) })
			local move = Vector3.zero
			s:run(12, function(sim, intent)
				if rand() < 0.03 then
					move = Vector3.new(rand() * 2 - 1, 0, rand() * 2 - 1)
					if rand() < 0.2 then
						move = Vector3.zero
					end
				end
				intent.Move = move
				intent.Sprint = rand() < 0.7
				intent.JumpPressed = rand() < 0.03
				intent.JumpHeld = rand() < 0.5
				intent.DashPressed = rand() < 0.02
				intent.SlidePressed = rand() < 0.03
				intent.SlideHeld = rand() < 0.4
			end, if run % 3 == 0 then 1 / 30 else 1 / 60)
			local p = s:pos()
			assert(p.X == p.X and p.Y == p.Y and p.Z == p.Z, "NaN position")
			assert(p.Y > -50, "fell out of the world")
		end
	end)
	check("30 random runs, no errors / NaNs / falling through the floor", ok, err and tostring(err))
end

heading("[npc] chaser / runner behaviour (fake pathfinder)")
do
	Mock.services.ReplicatedStorage = {
		WaitForChild = function(_, name)
			return rootNode._children[name]
		end,
	}
	local NPCConfig = requireNode(rootNode.Server.NPC.NPCConfig)
	local NPCBrain = requireNode(rootNode.Server.NPC.NPCBrain)
	math.randomseed(1)

	local function newNpcWorld(opts)
		Mock.clearBoxes()
		Mock.addBox("Ground", Vector3.new(-3000, -20, -3000), Vector3.new(3000, 0, 3000))
		for _, box in opts.boxes or {} do
			Mock.addBox(box.name, box.min, box.max)
		end
		local npcBody = Mock.newBody(opts.npcStart)
		local targetBody = Mock.newBody(opts.targetStart)
		local world = { t = 0, tags = 0, states = {}, minDistance = math.huge, npc = npcBody, target = targetBody }
		local context = {
			GetChaseTargets = function()
				return { targetBody.model }
			end,
			GetThreats = function()
				return { targetBody.model }
			end,
			OnTag = function()
				world.tags += 1
			end,
		}
		world.brain = NPCBrain.new(npcBody.model, NPCConfig.Archetypes[opts.archetype], context)
		npcBody.driver = world.brain.Loco.Driver
		world.brain.Loco.StateChanged:Connect(function(new, old)
			table.insert(world.states, { t = world.t, state = new, from = old })
		end)
		function world:distance()
			local a, b = self.npc.root.Position, self.target.root.Position
			return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
		end
		function world:hasState(name)
			for _, st in self.states do
				if st.state == name then
					return true
				end
			end
			return false
		end
		function world:run(seconds, control)
			local dt = 1 / 60
			for _ = 1, math.floor(seconds / dt + 0.5) do
				if control then
					control(self, self.target, dt)
				end
				self.brain:Update(dt)
				Mock.stepBody(self.npc, dt)
				Mock.stepBody(self.target, dt)
				self.t += dt
				Mock.advanceClock(dt)
				self.minDistance = math.min(self.minDistance, self:distance())
			end
		end
		return world
	end

	-- 1. Open ground: straight-line chase, dashing in.
	local w = newNpcWorld({ archetype = "Chaser", npcStart = Vector3.new(0, 3.01, 0), targetStart = Vector3.new(0, 3.01, -70) })
	local reached
	w:run(10, function(world)
		if not reached and world:distance() < 5 then
			reached = world.t
		end
	end)
	check("chaser reaches a stationary target in open ground", reached ~= nil, reached and `{fmt(reached)}s` or `closest {fmt(w.minDistance)}`)
	check("chaser tagged the target", w.tags >= 1, tostring(w.tags))
	check("chaser used its dash on the approach", w:hasState("Dash"))

	-- 2. A wall in the way: has to route around it.
	local wall = { { name = "Wall", min = Vector3.new(-40, 0, -34), max = Vector3.new(40, 20, -30) } }
	local d = newNpcWorld({ archetype = "Chaser", npcStart = Vector3.new(0, 3.01, 0), targetStart = Vector3.new(0, 3.01, -70), boxes = wall })
	local detour
	local slowFrames, movingFrames, lowestSpeed = 0, 0, math.huge
	d:run(16, function(world)
		if not detour and world:distance() < 5 then
			detour = world.t
		end
		if not detour and world.t > 1 then
			movingFrames += 1
			local speed = world.brain.Loco.HSpeed
			lowestSpeed = math.min(lowestSpeed, speed)
			if speed < 10 then
				slowFrames += 1
			end
		end
	end)
	print(`  detour: lowest speed {fmt(lowestSpeed)} studs/s, {slowFrames}/{movingFrames} frames under 10`)
	check("no stop-and-go while cutting the corner", movingFrames > 0 and slowFrames / movingFrames < 0.1, `{slowFrames}/{movingFrames}`)
	check("chaser routes around a 20-stud wall", detour ~= nil, detour and `{fmt(detour)}s` or `closest {fmt(d.minDistance)}`)
	check("navigator did not give up", d.brain.Nav ~= nil)

	-- 3. Moving target.
	local m = newNpcWorld({ archetype = "Chaser", npcStart = Vector3.new(0, 3.01, 0), targetStart = Vector3.new(0, 3.01, -40) })
	m.target.humanoid.WalkSpeed = 20
	m:run(14, function(world, target)
		target.humanoid._move = Vector3.new(1, 0, 0)
	end)
	check("chaser catches a target running at 20 studs/s", m.tags >= 1, `closest {fmt(m.minDistance)}`)

	-- 4. Runner flees from a slightly faster threat that starts close, and dashes when cornered.
	local r = newNpcWorld({ archetype = "Runner", npcStart = Vector3.new(0, 3.01, 0), targetStart = Vector3.new(0, 3.01, 14) })
	r.target.humanoid.WalkSpeed = 27
	local threatMove = function(world, target)
		local a, b = world.npc.root.Position, target.root.Position
		local dir = Vector3.new(a.X - b.X, 0, a.Z - b.Z)
		target.humanoid._move = dir.Magnitude > 0.1 and dir.Unit or Vector3.zero
	end
	r:run(6, threatMove)
	check("runner dashed when the threat got close", r:hasState("Dash"))
	check("runner escapes rather than being run down", r.minDistance > 2, `closest {fmt(r.minDistance)}`)
	check("runner covered ground", math.abs(r.npc.root.Position.Z) > 30 or math.abs(r.npc.root.Position.X) > 30)

	-- 5. Nothing to do: wanders near home without errors.
	local idle = newNpcWorld({ archetype = "Chaser", npcStart = Vector3.new(0, 3.01, 0), targetStart = Vector3.new(0, 3.01, -5000) })
	idle:run(25)
	local p = idle.npc.root.Position
	check("idle NPC wanders but stays near home", math.sqrt(p.X * p.X + p.Z * p.Z) < 90, `at ({fmt(p.X)}, {fmt(p.Z)})`)
end

print(failures == 0 and "\nall scenarios passed" or `\n{failures} check(s) failed`)
if failures > 0 then
	error("simulation checks failed")
end
