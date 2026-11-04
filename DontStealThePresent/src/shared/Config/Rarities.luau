-- Rarezas de los regalos. "Weight" es la probabilidad relativa de que salga en la cinta.

export type RarityInfo = {
	Id: string,
	Index: number,
	Name: string,
	Color: Color3,
	Dark: Color3,
	Weight: number,
	Scale: number, -- tamaño del regalo respecto a uno común
	Light: boolean,
	Sparkles: boolean,
	Beam: boolean, -- pilar de luz sobre el regalo en la cinta
	Rainbow: boolean,
}

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local list: { [string]: RarityInfo } = {
	Common = {
		Id = "Common",
		Index = 1,
		Name = "Común",
		Color = Color3.fromRGB(214, 222, 232),
		Dark = Color3.fromRGB(96, 104, 118),
		Weight = 56,
		Scale = 1,
		Light = false,
		Sparkles = false,
		Beam = false,
		Rainbow = false,
	},
	Uncommon = {
		Id = "Uncommon",
		Index = 2,
		Name = "Poco común",
		Color = Color3.fromRGB(96, 226, 118),
		Dark = Color3.fromRGB(24, 110, 52),
		Weight = 26,
		Scale = 1.08,
		Light = false,
		Sparkles = false,
		Beam = false,
		Rainbow = false,
	},
	Rare = {
		Id = "Rare",
		Index = 3,
		Name = "Raro",
		Color = Color3.fromRGB(72, 168, 255),
		Dark = Color3.fromRGB(18, 70, 160),
		Weight = 11.5,
		Scale = 1.18,
		Light = true,
		Sparkles = false,
		Beam = false,
		Rainbow = false,
	},
	Epic = {
		Id = "Epic",
		Index = 4,
		Name = "Épico",
		Color = Color3.fromRGB(190, 104, 255),
		Dark = Color3.fromRGB(84, 30, 150),
		Weight = 4.6,
		Scale = 1.3,
		Light = true,
		Sparkles = true,
		Beam = false,
		Rainbow = false,
	},
	Legendary = {
		Id = "Legendary",
		Index = 5,
		Name = "Legendario",
		Color = Color3.fromRGB(255, 196, 46),
		Dark = Color3.fromRGB(150, 90, 0),
		Weight = 1.5,
		Scale = 1.42,
		Light = true,
		Sparkles = true,
		Beam = true,
		Rainbow = false,
	},
	Mythic = {
		Id = "Mythic",
		Index = 6,
		Name = "Mítico",
		Color = Color3.fromRGB(255, 70, 104),
		Dark = Color3.fromRGB(140, 0, 40),
		Weight = 0.33,
		Scale = 1.56,
		Light = true,
		Sparkles = true,
		Beam = true,
		Rainbow = false,
	},
	Secret = {
		Id = "Secret",
		Index = 7,
		Name = "SECRETO",
		Color = Color3.fromRGB(255, 255, 255),
		Dark = Color3.fromRGB(20, 20, 30),
		Weight = 0.07,
		Scale = 1.72,
		Light = true,
		Sparkles = true,
		Beam = true,
		Rainbow = true,
	},
}

Rarities.List = list

function Rarities.Get(id: string): RarityInfo
	return list[id] or list.Common
end

-- Pesos ajustados por la suerte: las rarezas altas se multiplican más que las bajas.
function Rarities.WeightWithLuck(id: string, luck: number): number
	local info = Rarities.Get(id)
	if luck <= 1 then
		return info.Weight
	end
	return info.Weight * luck ^ ((info.Index - 1) / 2)
end

return Rarities
