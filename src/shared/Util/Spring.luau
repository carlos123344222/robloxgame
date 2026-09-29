--!strict
-- Damped spring for smooth camera / pose values. Zeta 1 = critically damped, < 1 overshoots (bounce).

export type Spring = {
	Position: number,
	Velocity: number,
	Target: number,
	Omega: number,
	Zeta: number,
	Update: (self: Spring, dt: number) -> number,
	Impulse: (self: Spring, amount: number) -> (),
	Reset: (self: Spring, value: number?) -> (),
}

local Spring = {}
Spring.__index = Spring

local SUBSTEPS = 3

function Spring.new(initial: number, omega: number, zeta: number?): Spring
	local self = setmetatable({
		Position = initial,
		Velocity = 0,
		Target = initial,
		Omega = omega,
		Zeta = zeta or 1,
	}, Spring)
	return (self :: any) :: Spring
end

function Spring.Update(self: Spring, dt: number): number
	local h = math.min(dt, 1 / 20) / SUBSTEPS
	local omega, zeta = self.Omega, self.Zeta
	for _ = 1, SUBSTEPS do
		local accel = omega * omega * (self.Target - self.Position) - 2 * zeta * omega * self.Velocity
		self.Velocity += accel * h
		self.Position += self.Velocity * h
	end
	return self.Position
end

function Spring.Impulse(self: Spring, amount: number)
	self.Velocity += amount
end

function Spring.Reset(self: Spring, value: number?)
	local v = value or self.Target
	self.Position = v
	self.Target = v
	self.Velocity = 0
end

return Spring
