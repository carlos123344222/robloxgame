-- Mutaciones: variantes especiales de un regalo que multiplican su precio y lo que genera.

export type MutationInfo = {
	Id: string,
	Name: string,
	Mult: number,
	Chance: number, -- probabilidad base al aparecer en la cinta (0..1)
	TextColor: Color3,
	Body: Color3?, -- color del cuerpo del regalo (nil = mantener)
	Ribbon: Color3?,
	Material: Enum.Material?,
	Reflectance: number?,
	Transparency: number?,
	Sparkle: Color3,
	Rainbow: boolean,
	Candy: boolean,
}

local Mutations = {}

Mutations.Order = { "Gold", "Diamond", "Frost", "Candy", "Rainbow" }

local list: { [string]: MutationInfo } = {
	Gold = {
		Id = "Gold",
		Name = "Dorado",
		Mult = 1.5,
		Chance = 0.06,
		TextColor = Color3.fromRGB(255, 210, 70),
		Body = Color3.fromRGB(255, 196, 54),
		Ribbon = Color3.fromRGB(190, 120, 20),
		Material = Enum.Material.Foil,
		Reflectance = 0.15,
		Transparency = nil,
		Sparkle = Color3.fromRGB(255, 220, 120),
		Rainbow = false,
		Candy = false,
	},
	Diamond = {
		Id = "Diamond",
		Name = "Diamante",
		Mult = 2,
		Chance = 0.02,
		TextColor = Color3.fromRGB(120, 236, 255),
		Body = Color3.fromRGB(150, 236, 255),
		Ribbon = Color3.fromRGB(235, 252, 255),
		Material = Enum.Material.Glass,
		Reflectance = 0.35,
		Transparency = 0.12,
		Sparkle = Color3.fromRGB(200, 250, 255),
		Rainbow = false,
		Candy = false,
	},
	Frost = {
		Id = "Frost",
		Name = "Escarcha",
		Mult = 2.5,
		Chance = 0.004,
		TextColor = Color3.fromRGB(180, 226, 255),
		Body = Color3.fromRGB(176, 220, 255),
		Ribbon = Color3.fromRGB(245, 250, 255),
		Material = Enum.Material.Ice,
		Reflectance = 0.1,
		Transparency = 0.05,
		Sparkle = Color3.fromRGB(230, 245, 255),
		Rainbow = false,
		Candy = false,
	},
	Candy = {
		Id = "Candy",
		Name = "Caramelo",
		Mult = 3,
		Chance = 0.006,
		TextColor = Color3.fromRGB(255, 120, 190),
		Body = Color3.fromRGB(255, 132, 196),
		Ribbon = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.05,
		Transparency = nil,
		Sparkle = Color3.fromRGB(255, 170, 220),
		Rainbow = false,
		Candy = true,
	},
	Rainbow = {
		Id = "Rainbow",
		Name = "Arcoíris",
		Mult = 5,
		Chance = 0.0015,
		TextColor = Color3.fromRGB(255, 255, 255),
		Body = nil,
		Ribbon = nil,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.05,
		Transparency = nil,
		Sparkle = Color3.fromRGB(255, 255, 255),
		Rainbow = true,
		Candy = false,
	},
}

Mutations.List = list

function Mutations.Get(id: string?): MutationInfo?
	if id == nil or id == "" then
		return nil
	end
	return list[id]
end

function Mutations.Multiplier(id: string?): number
	local info = Mutations.Get(id)
	return if info then info.Mult else 1
end

function Mutations.DisplayName(id: string?): string
	local info = Mutations.Get(id)
	return if info then info.Name else "Normal"
end

return Mutations
