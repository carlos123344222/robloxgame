-- Eventos globales del servidor. Cada cierto tiempo empieza uno al azar.

export type EventInfo = {
	Id: string,
	Name: string,
	Description: string,
	Duration: number,
	Color: Color3,
	Luck: number,
	MutationChances: { [string]: number }, -- sustituyen a la probabilidad base de esas mutaciones
	SpawnRateMult: number,
}

local Events = {}

Events.Order = { "Blizzard", "Aurora", "SantaNight", "GoldRain" }

local list: { [string]: EventInfo } = {
	Blizzard = {
		Id = "Blizzard",
		Name = "❄️ ¡VENTISCA!",
		Description = "Muchos regalos salen con mutación ESCARCHA (x2.5)",
		Duration = 150,
		Color = Color3.fromRGB(170, 220, 255),
		Luck = 1.3,
		MutationChances = { Frost = 0.3 },
		SpawnRateMult = 1,
	},
	Aurora = {
		Id = "Aurora",
		Name = "🌌 AURORA BOREAL",
		Description = "Los regalos ARCOÍRIS (x5) son mucho más comunes",
		Duration = 150,
		Color = Color3.fromRGB(110, 255, 200),
		Luck = 1.5,
		MutationChances = { Rainbow = 0.05, Diamond = 0.06 },
		SpawnRateMult = 1,
	},
	SantaNight = {
		Id = "SantaNight",
		Name = "🎅 NOCHE DE SANTA",
		Description = "¡Suerte x3 en la cinta y salen regalos más rápido!",
		Duration = 150,
		Color = Color3.fromRGB(255, 90, 90),
		Luck = 3,
		MutationChances = {},
		SpawnRateMult = 1.5,
	},
	GoldRain = {
		Id = "GoldRain",
		Name = "✨ LLUVIA DE ORO",
		Description = "Llueven regalos DORADOS (x1.5) y DIAMANTE (x2)",
		Duration = 150,
		Color = Color3.fromRGB(255, 210, 70),
		Luck = 1.2,
		MutationChances = { Gold = 0.4, Diamond = 0.08 },
		SpawnRateMult = 1,
	},
}

Events.List = list

function Events.Get(id: string?): EventInfo?
	if id == nil or id == "" then
		return nil
	end
	return list[id]
end

return Events
