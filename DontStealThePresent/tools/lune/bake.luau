-- Hornea el mapa dentro del lugar: abre el .rbxl que genera Rojo, ejecuta MapBuilder.Build sobre su
-- Workspace y guarda el resultado. Así el mapa se ve y se puede editar en Studio sin darle a Play.
--
-- lune run tools/lune/bake.luau build/base.rbxl DontStealThePresent.rbxl

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local harness = require("./harness")

local input = process.args[1] or "build/base.rbxl"
local output = process.args[2] or "DontStealThePresent.rbxl"

local env = harness.open(input)
local game = env.game
local workspace = game:GetService("Workspace")

local existing = workspace:FindFirstChild("Map")
if existing then
	existing:Destroy()
end

local MapBuilder = env.require(harness.find(game, "ServerScriptService.Server.World.MapBuilder"))
local started = os.clock()
local map = MapBuilder.Build(workspace)
local parts = MapBuilder.CountParts(map)
print(string.format("Mapa construido: %d piezas, %d instancias (%.2fs)", parts, #map:GetDescendants(), os.clock() - started))

-- La cámara inicial del editor apunta a la cinta
local camera = workspace:FindFirstChildOfClass("Camera")
if not camera then
	camera = roblox.Instance.new("Camera")
	camera.Name = "Camera"
	camera.Parent = workspace
end
camera.CFrame = roblox.CFrame.lookAt(roblox.Vector3.new(-40, 70, 150), roblox.Vector3.new(0, 0, 0))

fs.writeFile(output, roblox.serializePlace(game))
print("Guardado en " .. output)
