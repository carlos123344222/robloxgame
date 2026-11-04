-- Objetos (gears) que se compran en la tienda del elfo. Se guardan para siempre.

export type GearInfo = {
	Id: string,
	Name: string, -- nombre corto que aparece en la barra de herramientas
	FullName: string,
	Price: number,
	Icon: string,
	Description: string,
	Color: Color3,
	Cooldown: number,
	-- valores específicos (no todos los usa cada gear)
	Range: number?,
	Knockback: number?,
	FreezeTime: number?,
	ProjectileSpeed: number?,
	SpeedMult: number?,
	JumpHeight: number?,
}

local Gears = {}

Gears.Order = { "CandyBat", "Snowball", "ReindeerBoots", "JingleBell", "FreezeRay" }

local list: { [string]: GearInfo } = {
	CandyBat = {
		Id = "CandyBat",
		Name = "Bastón",
		FullName = "Bastón Golpeador",
		Price = 0,
		Icon = "🍭",
		Description = "Golpea a los ladrones para que suelten el regalo. ¡Gratis para todos!",
		Color = Color3.fromRGB(230, 40, 60),
		Cooldown = 0.85,
		Range = 9.5,
		Knockback = 62,
	},
	Snowball = {
		Id = "Snowball",
		Name = "Bola de Nieve",
		FullName = "Lanzador de Bolas de Nieve",
		Price = 7500,
		Icon = "⛄",
		Description = "Lanza bolas de nieve: congelan un momento y hacen soltar el regalo.",
		Color = Color3.fromRGB(220, 240, 255),
		Cooldown = 2.2,
		FreezeTime = 1.4,
		ProjectileSpeed = 125,
		Knockback = 24,
	},
	ReindeerBoots = {
		Id = "ReindeerBoots",
		Name = "Botas de Reno",
		FullName = "Botas de Reno",
		Price = 60000,
		Icon = "🦌",
		Description = "Corre un 45% más rápido mientras las llevas equipadas.",
		Color = Color3.fromRGB(150, 95, 55),
		Cooldown = 0,
		SpeedMult = 1.45,
	},
	JingleBell = {
		Id = "JingleBell",
		Name = "Campana",
		FullName = "Campana Saltarina",
		Price = 450000,
		Icon = "🔔",
		Description = "Saltos gigantes: ¡pasa por encima de los muros!",
		Color = Color3.fromRGB(255, 205, 60),
		Cooldown = 0,
		JumpHeight = 24,
	},
	FreezeRay = {
		Id = "FreezeRay",
		Name = "Rayo de Hielo",
		FullName = "Rayo Congelador",
		Price = 8000000,
		Icon = "🧊",
		Description = "Congela por completo a quien apuntes durante 3 segundos.",
		Color = Color3.fromRGB(110, 210, 255),
		Cooldown = 9,
		Range = 150,
		FreezeTime = 3,
	},
}

Gears.List = list

function Gears.Get(id: string): GearInfo?
	return list[id]
end

return Gears
