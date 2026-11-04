-- Posiciones fijas del mapa. Las bases miran hacia la cinta: en el espacio local de una base, -Z es la
-- entrada (hacia la cinta) y +Z el fondo.

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

local Layout = {}

Layout.Version = 4

Layout.Base = {
	Width = 56, -- eje X local
	Depth = 60, -- eje Z local
	WallHeight = 12,
	EntranceWidth = 16,
	FloorTop = 1,
	PedestalTop = 2.3,
	ZoneHeight = 22,
}

local BASE_X = { -135, -45, 45, 135 }
local BASE_Z = 64

Layout.BaseThemes = {
	{ Name = "Rojo", Color = Color3.fromRGB(226, 46, 62) },
	{ Name = "Verde", Color = Color3.fromRGB(46, 190, 100) },
	{ Name = "Azul", Color = Color3.fromRGB(60, 132, 245) },
	{ Name = "Morado", Color = Color3.fromRGB(160, 86, 240) },
	{ Name = "Dorado", Color = Color3.fromRGB(245, 186, 40) },
	{ Name = "Rosa", Color = Color3.fromRGB(245, 110, 186) },
	{ Name = "Turquesa", Color = Color3.fromRGB(40, 206, 214) },
	{ Name = "Naranja", Color = Color3.fromRGB(248, 136, 40) },
}

-- CFrame del centro de cada base (a nivel del suelo), mirando hacia la cinta
function Layout.BaseCFrame(index: number): CFrame
	local col = (index - 1) % 4 + 1
	local north = index <= 4
	local center = Vector3.new(BASE_X[col], 0, if north then -BASE_Z else BASE_Z)
	local facing = if north then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
	return CFrame.lookAt(center, center + facing)
end

-- Posición local del hueco i (1..16): impares a la izquierda, pares a la derecha, de la entrada al fondo
function Layout.SlotLocal(index: number): (Vector3, Vector3, number)
	local side = if index % 2 == 1 then -1 else 1
	local row = math.ceil(index / 2)
	local z = -21 + (row - 1) * 6.5
	local pedestal = Vector3.new(side * 21, 0, z)
	local pad = Vector3.new(side * 15.4, 0, z)
	return pedestal, pad, side
end

-- CFrame de la base del regalo colocado en el hueco i, mirando hacia el pasillo central
function Layout.SlotPresentCFrame(baseCF: CFrame, index: number): CFrame
	local pedestal, _, side = Layout.SlotLocal(index)
	local yaw = if side < 0 then -math.pi / 2 else math.pi / 2
	return baseCF * CFrame.new(pedestal + Vector3.new(0, Layout.Base.PedestalTop, 0)) * CFrame.Angles(0, yaw, 0)
end

Layout.Belt = {
	StartX = GameConfig.Belt.StartX,
	EndX = GameConfig.Belt.EndX,
	Z = GameConfig.Belt.Z,
	SurfaceY = GameConfig.Belt.SurfaceY,
	BuildMinX = -196,
	BuildMaxX = 196,
	Width = 10,
}

Layout.Factory = Vector3.new(-212, 0, 0)
Layout.Furnace = Vector3.new(206, 0, 0)
Layout.Plaza = Vector3.new(262, 0, 0)
Layout.Shop = Vector3.new(238, 0, -46)
Layout.Altar = Vector3.new(238, 0, 46)
Layout.PlazaSpawn = Vector3.new(232, 0, 0)

Layout.Bounds = {
	MinX = -300,
	MaxX = 330,
	MinZ = -160,
	MaxZ = 160,
}

return Layout
