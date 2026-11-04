-- Montañas nevadas alrededor del mapa con Terrain (solo en ejecución: Lune no puede hornear terreno).

local Layout = require(script.Parent.Layout)
local Rng = require(game:GetService("ReplicatedStorage").Shared.Util.Rng)

local TerrainBuilder = {}

function TerrainBuilder.Build()
	local terrain = workspace.Terrain
	if terrain:GetAttribute("DSTPBuilt") then
		return
	end
	terrain:SetAttribute("DSTPBuilt", true)
	pcall(function()
		terrain.WaterWaveSize = 0
		terrain.Decoration = false
	end)
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(240, 246, 255))
		terrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromRGB(170, 215, 255))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(120, 128, 145))
	end)

	local rng = Rng.new(31)
	local b = Layout.Bounds
	local margin = 26
	local function hill(x: number, z: number, radius: number)
		local pos = Vector3.new(x, -radius * 0.35, z)
		terrain:FillBall(pos, radius, Enum.Material.Snow)
		if radius > 50 then
			terrain:FillBall(pos + Vector3.new(rng:Range(-10, 10), radius * 0.45, rng:Range(-10, 10)), radius * 0.45, Enum.Material.Glacier)
			terrain:FillBall(pos + Vector3.new(0, radius * 0.6, 0), radius * 0.32, Enum.Material.Snow)
		end
	end

	-- norte y sur
	for x = b.MinX - 60, b.MaxX + 60, 42 do
		hill(x + rng:Range(-12, 12), b.MinZ - margin - rng:Range(10, 40), rng:Range(40, 72))
		hill(x + rng:Range(-12, 12), b.MaxZ + margin + rng:Range(10, 40), rng:Range(40, 72))
	end
	-- este y oeste
	for z = b.MinZ - 40, b.MaxZ + 40, 42 do
		hill(b.MinX - margin - rng:Range(10, 40), z + rng:Range(-12, 12), rng:Range(44, 76))
		hill(b.MaxX + margin + rng:Range(10, 40), z + rng:Range(-12, 12), rng:Range(44, 76))
	end
	-- picos lejanos
	for _ = 1, 14 do
		local angle = rng:Range(0, math.pi * 2)
		local dist = rng:Range(420, 520)
		local center = Vector3.new(15 + math.cos(angle) * dist, 0, math.sin(angle) * dist * 0.75)
		hill(center.X, center.Z, rng:Range(80, 120))
	end
end

return TerrainBuilder
