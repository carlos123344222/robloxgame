-- Generador pseudoaleatorio determinista (mismo resultado con la misma semilla). Se usa para decorar el
-- mapa siempre igual y para que la lógica pueda probarse fuera de Roblox.

export type Rng = {
	Next: (self: Rng) -> number,
	Range: (self: Rng, min: number, max: number) -> number,
	Int: (self: Rng, min: number, max: number) -> number,
	Pick: <T>(self: Rng, list: { T }) -> T,
	state: number,
}

local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number?): Rng
	local self = setmetatable({}, Rng) :: any
	self.state = math.floor(seed or (os.clock() * 1000003)) % 2147483647
	if self.state <= 0 then
		self.state += 2147483646
	end
	return self
end

-- Park–Miller "minimal standard" (cabe sin problemas en un double).
function Rng:Next(): number
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end

function Rng:Range(min: number, max: number): number
	return min + (max - min) * self:Next()
end

function Rng:Int(min: number, max: number): number
	return math.min(max, min + math.floor(self:Next() * (max - min + 1)))
end

function Rng:Pick<T>(list: { T }): T
	return list[self:Int(1, #list)]
end

return Rng
